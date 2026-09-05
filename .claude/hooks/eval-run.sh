#!/usr/bin/env bash
# eval-run.sh — per-case golden-set runner with a swappable target (P1a).
# One script owns setup → respondent → grading → evidence files, so the workflow
# only orchestrates and no assert value or score passes through an LLM.
#
#   eval-run.sh setup <goldenset.json> <case-id>
#       mktemp workdir, run the case's `setup` there (CARVE_SRC exported).
#       stdout: {"dir": "...", "setupExit": N}     (dir is kept on setup failure for inspection)
#   eval-run.sh grade <goldenset.json> <case-id> <workdir> [--output FILE] [--out DIR] [--label L] [--keep]
#       Grade text asserts (contains/regex via node) against FILE and state asserts via
#       eval-state.sh against <workdir>. llm-rubric asserts are reported as pending (the
#       workflow's evaluator judges them). Writes DIR/<id>#<L>.json with the output text
#       and per-assert verdicts when --out. Deletes the workdir unless --keep.
#       stdout: {"id","asserts":[{type,value,pass,reason}],"failed":[...],"pendingRubric":[...],"green":true|false|null}
#   eval-run.sh run <goldenset.json> <case-id> --target exec:<cmd>|claude [--k N] [--out DIR] [--timeout S]
#       setup + target + grade, k times. Target contract (promptfoo `exec:` shape):
#       cwd = workdir · argv[1] = prompt · stdout = response text · CLAUDE_PROJECT_DIR = workdir
#       (so harness hooks copied by setup log into <workdir>/logs). `claude` = headless
#       `claude -p` (needs the CLI + auth; absent -> {"error":"target-unavailable"} exit 1).
#       stdout: {"id","k","greens","pending","pass_at_k","pass_pow_k","caseScore","runs":[...]}
# Fail-closed everywhere: unknown case, missing file, unparsable JSON -> exit 1.
set -o pipefail

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$HOOKS_DIR/../.." && pwd)}"
STATE_TYPES='file_exists|file_contains|cmd_exit0|git_diff_contains|log_contains'
die() { echo "[carve-harness:eval-run] $1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 미설치 — 채점 불가(fail-closed)"

CMD="${1:-}"; GS="${2:-}"; ID="${3:-}"; shift 3 2>/dev/null || die "usage: eval-run.sh setup|grade|run <goldenset.json> <case-id> ..."
[ -f "$GS" ] && jq -e --arg id "$ID" '[.cases[]? | select(.id == $id)] | length == 1' "$GS" >/dev/null 2>&1 \
  || die "골든셋/케이스 없음 또는 id 중복: $GS :: $ID"
case_field() { jq -r --arg id "$ID" ".cases[] | select(.id == \$id) | $1" "$GS"; }

# ── setup ────────────────────────────────────────────────────────────────────
do_setup() {
  local W setup rc=0
  W=$(mktemp -d) || die "mktemp 실패"
  setup=$(case_field '.setup // ""')
  if [ -n "$setup" ]; then
    ( cd "$W" && CARVE_SRC="${CARVE_SRC:-$ROOT}" bash -c "$setup" ) >/dev/null 2>&1 || rc=$?
  fi
  jq -cn --arg d "$W" --argjson rc "$rc" '{dir: $d, setupExit: $rc}'
}

# ── grade ────────────────────────────────────────────────────────────────────
# Text asserts: contains/not_contains are byte-literal; regex/not_regex use JS semantics
# (the golden-set contract) so they are node-gated — without node they FAIL with a reason,
# never pass silently.
grade_text() { # <output-file> -> JSON array of {type,value,pass,reason} for text asserts
  local OUT="$1" node_ok=0
  command -v node >/dev/null 2>&1 && node_ok=1
  jq -c --arg id "$ID" '[.cases[] | select(.id == $id) | .assert[] | select(.type == "contains" or .type == "not_contains" or .type == "regex" or .type == "not_regex")]' "$GS" \
  | if [ "$node_ok" = 1 ]; then
      node -e '
        const fs = require("fs");
        const asserts = JSON.parse(fs.readFileSync(0, "utf8"));
        const out = fs.existsSync(process.argv[1]) ? fs.readFileSync(process.argv[1], "utf8") : "";
        const res = asserts.map((a) => {
          const v = String(a.value ?? ""); let pass = false, reason = "";
          try {
            switch (a.type) {
              case "contains":     pass = out.includes(v); break;
              case "not_contains": pass = !out.includes(v); break;
              case "regex":        pass = new RegExp(v).test(out); break;
              case "not_regex":    pass = !new RegExp(v).test(out); break;
            }
          } catch (e) { pass = false; reason = "invalid regex: " + e.message; }
          if (!pass && !reason) reason = a.type + " did not hold";
          return { type: a.type, value: v, pass, reason };
        });
        process.stdout.write(JSON.stringify(res));
      ' "$OUT"
    else
      jq -c --arg o "$(cat "$OUT" 2>/dev/null)" '[ .[] | . as $a
        | if .type == "contains" then {type, value, pass: ($o | contains($a.value)), reason: "contains did not hold"}
          elif .type == "not_contains" then {type, value, pass: ($o | contains($a.value) | not), reason: "not_contains did not hold"}
          else {type, value, pass: false, reason: "node absent — JS regex cannot be evaluated (fail-closed)"} end
        | if .pass then .reason = "" else . end ]'
    fi
}

do_grade() {
  local W="$1"; shift
  local OUTF="" OUTDIR="" LABEL="1" KEEP=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --output) OUTF="${2:-}"; shift 2 ;;
      --out)    OUTDIR="${2:-}"; shift 2 ;;
      --label)  LABEL="${2:-1}"; shift 2 ;;
      --keep)   KEEP=1; shift ;;
      *) shift ;;
    esac
  done
  [ -d "$W" ] || die "workdir 없음: $W"
  [ -n "$OUTF" ] || { OUTF=$(mktemp); : > "$OUTF"; }
  local text state pending asserts failed green
  text=$(grade_text "$OUTF")
  # State asserts straight from the golden-set file (no relay — escaping stays intact).
  state=$(bash "$HOOKS_DIR/eval-state.sh" "$W" "$GS" --case "$ID" 2>/dev/null) || state='{"failed":["eval-state:unusable"]}'
  pending=$(jq -c --arg id "$ID" '[.cases[] | select(.id == $id) | .assert[] | select(.type == "llm-rubric") | .value]' "$GS")
  asserts=$(jq -cn --argjson t "$text" --argjson s "$state" --arg id "$ID" --slurpfile gs "$GS" --argjson types "$(printf '%s' "$STATE_TYPES" | jq -R 'split("|")')" '
    ($gs[0].cases[] | select(.id == $id) | .assert) as $all
    | $t + [ $all[] | select(.type as $ty | $types | index($ty)) | . as $a
             | {type, value, pass: (($s.failed | index($a.type + ":" + $a.value)) == null and ($s.failed | index("eval-state:unusable")) == null),
                reason: (if ($s.failed | index("eval-state:unusable")) != null then "eval-state unusable" elif ($s.failed | index($a.type + ":" + $a.value)) != null then "state assert failed" else "" end)} ]')
  failed=$(printf '%s' "$asserts" | jq -c '[ .[] | select(.pass | not) | .type + ":" + .value ]')
  green=$(jq -cn --argjson f "$failed" --argjson p "$pending" 'if ($f | length) > 0 then false elif ($p | length) > 0 then null else true end')
  local result
  result=$(jq -cn --arg id "$ID" --argjson a "$asserts" --argjson f "$failed" --argjson p "$pending" --argjson g "$green" \
    '{id: $id, asserts: $a, failed: $f, pendingRubric: $p, green: $g}')
  if [ -n "$OUTDIR" ]; then
    mkdir -p "$OUTDIR"
    jq -cn --argjson r "$result" --arg label "$LABEL" --rawfile out "$OUTF" --arg dir "$W" \
      '$r + {label: $label, output: $out, workdir: $dir}' > "$OUTDIR/${ID}#${LABEL}.json"
  fi
  [ "$KEEP" = 1 ] || rm -rf "$W"
  printf '%s\n' "$result"
}

# ── run (setup + target + grade, k times) ────────────────────────────────────
run_target() { # <target> <workdir> <prompt> <output-file> <timeout>
  local T="$1" W="$2" P="$3" OUTF="$4" TO="$5" rc=0
  case "$T" in
    exec:*)
      local cmd="${T#exec:}"
      ( cd "$W" && CLAUDE_PROJECT_DIR="$W" timeout "$TO" bash -c "$cmd \"\$1\"" _ "$P" ) > "$OUTF" 2>/dev/null || rc=$?
      ;;
    claude)
      command -v claude >/dev/null 2>&1 || return 127
      # Headless Claude Code as the respondent. Hooks copied by setup (if any) fire here too,
      # because CLAUDE_PROJECT_DIR points at the workdir.
      ( cd "$W" && CLAUDE_PROJECT_DIR="$W" timeout "$TO" claude -p "$P" --output-format text \
          --permission-mode acceptEdits --allowedTools "Bash Read Write Edit MultiEdit Glob Grep" ) > "$OUTF" 2>/dev/null || rc=$?
      ;;
    *) return 2 ;;
  esac
  return $rc
}

do_run() {
  local TARGET="" K=1 OUTDIR="" TO=600
  while [ $# -gt 0 ]; do
    case "$1" in
      --target)  TARGET="${2:-}"; shift 2 ;;
      --k)       K="${2:-1}"; shift 2 ;;
      --out)     OUTDIR="${2:-}"; shift 2 ;;
      --timeout) TO="${2:-600}"; shift 2 ;;
      *) shift ;;
    esac
  done
  case "$TARGET" in exec:*|claude) ;; *) die "--target exec:<cmd> | claude 필요 (session 응답자는 워크플로가 담당)" ;; esac
  case "$K" in ''|*[!0-9]*) K=1 ;; esac; [ "$K" -lt 1 ] && K=1; [ "$K" -gt 10 ] && K=10
  command -v timeout >/dev/null 2>&1 || timeout() { shift; "$@"; }
  [ "$TARGET" = claude ] && ! command -v claude >/dev/null 2>&1 \
    && { jq -cn --arg id "$ID" '{id: $id, error: "target-unavailable", reason: "claude CLI not on PATH"}'; exit 1; }
  local prompt runs='[]' i env dir rc outf g
  prompt=$(case_field '.prompt')
  for ((i = 1; i <= K; i++)); do
    env=$(do_setup); dir=$(printf '%s' "$env" | jq -r '.dir'); rc=$(printf '%s' "$env" | jq -r '.setupExit')
    if [ "$rc" != 0 ]; then
      runs=$(printf '%s' "$runs" | jq -c --argjson i "$i" --argjson rc "$rc" --arg d "$dir" \
        '. + [{label: ($i|tostring), green: false, failed: ["env:setup-failed(exit \($rc)) at \($d)"], asserts: [], pendingRubric: []}]')
      continue
    fi
    outf=$(mktemp)
    run_target "$TARGET" "$dir" "작업 디렉토리는 $dir 이다. 모든 파일 작업은 그 디렉토리 안에서만 하라.

$prompt" "$outf" "$TO" || true
    g=$(do_grade "$dir" --output "$outf" --out "$OUTDIR" --label "$i")
    rm -f "$outf"
    runs=$(printf '%s' "$runs" | jq -c --argjson g "$g" --argjson i "$i" '. + [$g + {label: ($i|tostring)}]')
  done
  printf '%s' "$runs" | jq -c --arg id "$ID" --argjson k "$K" '
    ([.[] | select(.green == true)] | length) as $greens
    | ([.[] | select(.green == null)] | length) as $pending
    | {id: $id, k: $k, greens: $greens, pending: $pending,
       pass_at_k: ($greens >= 1), pass_pow_k: ($greens == $k),
       caseScore: (($greens * 100 / $k) | round), runs: .}'
}

case "$CMD" in
  setup) do_setup ;;
  grade) W="${1:-}"; shift 2>/dev/null || true; [ -n "$W" ] || die "usage: eval-run.sh grade <gs> <id> <workdir> [...]"; do_grade "$W" "$@" ;;
  run)   do_run "$@" ;;
  *) die "usage: eval-run.sh setup|grade|run <goldenset.json> <case-id> ..." ;;
esac
