#!/usr/bin/env bash
# carve-validate.sh — golden-set preflight validator for carve-eval.
# Catches config errors BEFORE the expensive k x N respondent runs. The graders
# (carve-eval.js, eval-state.sh) are deliberately fail-closed, so a typo'd
# assert type or an uncompilable regex silently scores 0 — indistinguishable
# from a genuine capability failure. This separates "the golden set is broken"
# from "the agent is bad" without spending a single agent call.
#   usage: carve-validate.sh [--red] [file-or-glob ...]   (default: specs/goldenset/*.json)
# stdout: ERROR/WARN/SKIP lines + summary.  exit 0 = usable, 1 = has errors.
#
# --red runs each case's setup in a throwaway dir and grades the deterministic
# asserts with NO agent work done. Any case that is already fully green is
# NO-SIGNAL: a respondent that does nothing scores it green, so the case
# measures nothing (the "프록시 충족" entry in the reward-hacking catalog).
# It executes setup and cmd_exit0 values locally — opt-in for that reason.
#
# Setup scripts are ALSO checked against the protected-path regex. carve-eval
# hands the setup to an agent as a literal Bash command, so PreToolUse sees it and
# blocks a fixture that writes under a protected path — the case can then never
# build its own precondition. Running it here from a shell variable never trips the
# hook, so the local run alone would report a false OK.
set -u

RED=0; STRICT=0
while :; do
  case "${1:-}" in
    --red) RED=1; shift ;;
    --strict) STRICT=1; shift ;;   # required 태그 0건을 WARN 이 아니라 ERROR 로 (CI 게이트용)
    *) break ;;
  esac
done

K_MAX=10   # keep in sync with K_MAX in .claude/workflows/carve-eval.js

# The harness source tree, derived from this script's own location. NOT $PWD (the
# setup subshell cds into a throwaway dir) and NOT CLAUDE_PROJECT_DIR (run-all.sh
# repoints that at a temp log root to isolate observability side effects).
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR	jq not found — carve-validate requires jq (vendor/bin/jq)"
  echo "---"
  echo "1 error(s), 0 warning(s), 0 case(s) in 0 file(s)"
  exit 1
fi

# Args win; otherwise the conventional location. Unmatched globs expand to
# themselves in sh, so existence is re-checked per file below.
if [ "$#" -gt 0 ]; then
  FILES=("$@")
else
  FILES=()
  for f in specs/goldenset/*.json; do [ -f "$f" ] && FILES+=("$f"); done
fi

errors=0; warns=0; cases=0; files=0
ids_seen=""      # "<id>\n..." accumulator for cross-file duplicate detection
regex_items=""   # JSON objects for the optional node regex-compile pass

emit() { # <ERROR|WARN|SKIP> <text>
  printf '%s\t%s\n' "$1" "$2"
  case "$1" in ERROR) errors=$((errors + 1)) ;; WARN) warns=$((warns + 1)) ;; esac
}

# ── Per-case / per-assert structural checks (single jq pass per file) ────────
JQ_PROG='
def q($s): ($s // "?");
if (.cases | type) != "array" then ["ERROR\ttop-level .cases is missing or not an array"]
else
  [ .cases | to_entries[] as $e | $e.key as $i | $e.value as $c
    | ("case[\($i)] \(q($c.id))") as $L
    | ($c.assert // []) as $as
    | (if ($c.id | type) != "string" or ($c.id // "") == ""
         then "ERROR\tcase[\($i)]: missing id" else empty end),
      (if ($c.prompt // "") == "" then "ERROR\t\($L): missing prompt" else empty end),
      (if ($c.version // "") == ""
         then "ERROR\t\($L): missing version — 케이스를 고치면 version을 올려야 과거 점수와 비교가 성립한다"
         else empty end),
      (if ($c | has("k")) and (($c.k | type) != "number" or ($c.k | floor) != $c.k or $c.k < 1 or $c.k > '"$K_MAX"')
         then "ERROR\t\($L): k must be an integer 1..'"$K_MAX"' (got \($c.k | tostring))" else empty end),
      (if ($c | has("setup")) and (($c.setup | type) != "string" or ($c.setup // "") == "")
         then "ERROR\t\($L): setup must be a non-empty string when present" else empty end),
      (if ($c | has("tags")) and (($c.tags | type) != "array" or ([ $c.tags[]? | select(type != "string" or length == 0) ] | length) > 0)
         then "ERROR\t\($L): tags must be an array of non-empty strings (e.g. [\"required\",\"category:domain_safety\"])" else empty end),
      (if ($as | type) != "array" or ($as | length) == 0
         then "ERROR\t\($L): assert must be a non-empty array"
         else
           ( $as | to_entries[] as $ae | $ae.key as $j | $ae.value as $a
             | (if ($a.type // "") == "contains" or ($a.type // "") == "not_contains"
                   or ($a.type // "") == "regex" or ($a.type // "") == "not_regex"
                   or ($a.type // "") == "file_exists" or ($a.type // "") == "file_contains"
                   or ($a.type // "") == "cmd_exit0" or ($a.type // "") == "git_diff_contains"
                   or ($a.type // "") == "log_contains" or ($a.type // "") == "llm-rubric"
                 then empty
                 else "ERROR\t\($L) assert[\($j)]: unknown type \"\(q($a.type))\" (fail-closed at run time = silent 0)" end),
               (if ($a.value | type) != "string" or ($a.value // "") == ""
                  then "ERROR\t\($L) assert[\($j)]: value must be a non-empty string" else empty end),
               (if ($a.type // "") == "file_contains"
                   and (($a.value // "") | test("^[^:]+::.+") | not)
                  then "ERROR\t\($L) assert[\($j)]: file_contains needs \"<path>::<needle>\" (got \"\($a.value // "")\")"
                  else empty end),
               (if ($a.type // "") == "log_contains"
                   and (($a.value // "") | test("^[^:]+::.+") | not)
                  then "ERROR\t\($L) assert[\($j)]: log_contains needs \"<jsonl-glob>::<jq boolean filter>\" (got \"\($a.value // "")\")"
                  else empty end)
           ),
           (if ([ $as[] | select(
                    .type == "contains" or .type == "regex" or .type == "file_exists"
                    or .type == "file_contains" or .type == "cmd_exit0"
                    or .type == "git_diff_contains" or .type == "log_contains" or .type == "llm-rubric") ] | length) == 0
              then "ERROR\t\($L): negative asserts only — add a positive assert (과잉 충족 리워드 해킹 방지)"
              else empty end),
           (if ([ $as[] | select(.type != "llm-rubric") ] | length) == 0
              then "WARN\t\($L): llm-rubric only — 상태 assert로 대체 가능하면 대체하라(평가의 평가 회피)"
              else empty end)
         end)
  ]
end | .[]
'

for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then emit ERROR "$f: file not found"; continue; fi
  files=$((files + 1))
  if ! jq empty "$f" >/dev/null 2>&1; then
    emit ERROR "$f: invalid JSON — $(jq empty "$f" 2>&1 | head -1)"
    continue
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    emit "${line%%	*}" "$f: ${line#*	}"
  done < <(jq -r "$JQ_PROG" "$f" 2>/dev/null)

  cases=$((cases + $(jq '[.cases[]?] | length' "$f" 2>/dev/null || echo 0)))
  ids_seen="$ids_seen$(jq -r '.cases[]? | select(.id != null) | .id' "$f" 2>/dev/null)
"
  regex_items="$regex_items$(jq -c --arg f "$f" '
    .cases[]? as $c | $c.assert[]?
    | select(.type == "regex" or .type == "not_regex")
    | {f: $f, c: ($c.id // "?"), p: (.value // "")}' "$f" 2>/dev/null)
"
done

# ── Cross-file: ids must be unique (the trend keys cases by id) ──────────────
while IFS= read -r dup; do
  [ -n "$dup" ] || continue
  emit ERROR "duplicate case id \"$dup\" — ids key the score trend, they must be unique across all files"
done < <(printf '%s' "$ids_seen" | grep -v '^$' | sort | uniq -d)

# ── Regex compile check (JS semantics — the grader uses `new RegExp`) ────────
# Bash `grep -E` would mis-judge JS-only syntax (\d, lookahead), so this check
# is node-gated. No silent skip: absence is reported.
if [ -n "$(printf '%s' "$regex_items" | grep -v '^$')" ]; then
  if command -v node >/dev/null 2>&1; then
    out=$(printf '%s' "$regex_items" | grep -v '^$' | node -e '
      const lines = require("fs").readFileSync(0, "utf8").split("\n").filter(Boolean);
      for (const l of lines) {
        const it = JSON.parse(l);
        try { new RegExp(it.p) }
        catch (e) { console.log(it.f + ": case " + it.c + ": invalid regex /" + it.p + "/ — " + e.message) }
      }' 2>/dev/null)
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      emit ERROR "$line"
    done < <(printf '%s\n' "$out")
  else
    printf 'SKIP\tregex compile check — node not found (JS regex semantics cannot be verified by grep)\n'
  fi
fi

if [ "$files" -eq 0 ]; then
  emit ERROR "no golden-set files matched — write cases first (eval-goldenset 스킬 참고)"
fi

# ── required tag: gate ① fails on a single required case — without one, the gate is mean-only ──
if [ "$files" -gt 0 ] && [ "$errors" -eq 0 ]; then
  nreq=0
  for f in "${FILES[@]}"; do
    [ -f "$f" ] || continue
    nreq=$((nreq + $(jq '[.cases[]? | select((.tags // []) | index("required"))] | length' "$f" 2>/dev/null || echo 0)))
  done
  if [ "$nreq" -eq 0 ]; then
    if [ "$STRICT" -eq 1 ]; then emit ERROR "no case tagged \"required\" — eval-gate can only judge the mean; tag the safety-critical cases"
    else printf 'NOTE\tno case tagged "required" — eval-gate judges the mean only (tag safety-critical cases; --strict makes this an error)\n'; fi
  fi
fi

# ── --red: does the case measure anything? (opt-in, executes setup locally) ──
if [ "$RED" -eq 1 ] && [ "$errors" -eq 0 ]; then
  # PROTECTED_RE has exactly one definition — never restate the path list here.
  _lib="$(cd "$(dirname "$0")" && pwd)/lib-protected.sh"
  if [ -f "$_lib" ]; then
    # shellcheck source=/dev/null
    . "$_lib"
  else
    printf 'SKIP\tprotected-path check on setup — lib-protected.sh not found\n'
  fi
  for f in "${FILES[@]}"; do
    [ -f "$f" ] || continue
    while IFS= read -r -d '' id && IFS= read -r -d '' setup; do
      [ -n "$id" ] || continue
      # The hook sees the setup as a literal command; this shell never does.
      # Reuse the single-source regex instead of guessing at the path list.
      if [ -n "$setup" ] && [ -n "${PROTECTED_RE:-}" ] \
         && printf '%s' "$setup" | grep -Eq "$PROTECTED_RE"; then
        emit ERROR "$f: $id: setup writes under a protected path — pretool-guard blocks it when carve-eval runs it, so the fixture can never be built. 픽스처를 보호 경로 밖에 두라"
      fi
      W=$(mktemp -d)
      # CARVE_SRC = the harness source a setup copies hooks from. Golden sets fall
      # back to a hardcoded absolute path when it is unset, so without this the case
      # only builds on the machine that authored it. carve-eval exports the same.
      if [ -n "$setup" ] \
        && ! ( cd "$W" && CARVE_SRC="${CARVE_SRC:-$ROOT}" bash -c "$setup" ) >/dev/null 2>&1; then
        emit ERROR "$f: $id: setup script failed — the case can never run"
        rm -rf "$W"; continue
      fi
      tot=0; pre=0
      # NUL-delimited, not @tsv — @tsv escapes backslashes, so a cmd_exit0 regex
      # would be graded in a form it never runs in (the bug this file exists to catch).
      while IFS= read -r -d '' t && IFS= read -r -d '' v; do
        case "$t" in
          cmd_exit0)     tot=$((tot + 1)); ( cd "$W" && bash -c "$v" ) >/dev/null 2>&1 && pre=$((pre + 1)) ;;
          file_exists)   tot=$((tot + 1)); [ -e "$W/$v" ] && pre=$((pre + 1)) ;;
          file_contains) tot=$((tot + 1)); p="${v%%::*}"; n="${v#*::}"
                         [ -f "$W/$p" ] && grep -qF "$n" "$W/$p" && pre=$((pre + 1)) ;;
          log_contains)  tot=$((tot + 1)); p="${v%%::*}"; n="${v#*::}"
                         ( cd "$W" && cat $p 2>/dev/null | jq -es "any(.[]; $n)" >/dev/null 2>&1 ) && pre=$((pre + 1)) ;;
        esac
      done < <(jq -j --arg id "$id" '.cases[] | select(.id == $id) | .assert[] | (.type|tostring) + "\u0000" + (.value|tostring) + "\u0000"' "$f")
      # An llm-rubric still grades the agent, so all-green determinism is not
      # "nothing measures this". Tamper-detection cases (do the forbidden thing →
      # asserts prove the gate is still intact) are green at t=0 by design; the
      # rubric carries the signal. Report it, but do not call it NO-SIGNAL.
      has_rubric=$(jq -r --arg id "$id" \
        '[.cases[] | select(.id == $id) | .assert[] | select(.type == "llm-rubric")] | length' "$f" 2>/dev/null)
      if [ "$tot" -gt 0 ] && [ "$pre" -eq "$tot" ] && [ "${has_rubric:-0}" -eq 0 ]; then
        emit ERROR "$f: $id: NO-SIGNAL — 결정론 assert ${tot}건이 에이전트 작업 없이 전부 통과(프록시 충족). 태스크 완수를 요구하는 positive assert를 추가하라"
      elif [ "$tot" -gt 0 ] && [ "$pre" -eq "$tot" ]; then
        emit WARN "$f: $id: 결정론 assert ${tot}건이 t=0에 전부 통과 — 변조 탐지형이면 정상이나, 신호는 llm-rubric에만 의존한다"
      else
        printf 'RED\t%s: %s: 사전통과 %s/%s\n' "$f" "$id" "$pre" "$tot"
      fi
      rm -rf "$W"
    done < <(jq -j '.cases[] | (.id|tostring) + "\u0000" + ((.setup // "")|tostring) + "\u0000"' "$f" 2>/dev/null)
  done
fi

printf -- '---\n%s error(s), %s warning(s), %s case(s) in %s file(s)\n' "$errors" "$warns" "$cases" "$files"
[ "$errors" -eq 0 ]
