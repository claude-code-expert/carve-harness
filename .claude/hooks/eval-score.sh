#!/usr/bin/env bash
# eval-score.sh — language-agnostic build-health scorecard (blueprint §5.7).
# Every point comes from a command's exit code or a report file. NO LLM.
#   bash eval-score.sh [--stack NAME] [--k N] [--out PATH] [--json]
#     --stack NAME  score only this stack (default: every .claude/stacks/*.sh whose stack_detect matches)
#     --k N         test runs for G2 (all N must pass; default 1)
#     --out PATH    write the scorecard JSON (default $CLAUDE_PROJECT_DIR/specs/SCORE.json)
#     --json        print only the JSON line (no human summary on stderr)
#
# Scorecard (per stack; gates G1-G3 carry a veto):
#   G1 build 25 · G2 test 25 · G3 safety 15 · lint 10 · regression 10 · coverage 5 · antislop 10
# An item the stack cannot measure (tool missing, no report) is listed in `skipped` and removed
# from the denominator — never a silent pass. verdict FAIL if any gate is 0, else PASS when
# total/max >= 0.9. No stack detected -> verdict "unable", exit 1 (fail-closed).
# G3 safety and antislop are stack-independent: the first scans the change set for secrets and
# protected paths, the second runs check-slop.mjs over changed .html/.htm/.css/.svg.
# Adapter contract in .claude/stacks/<pack>.sh: stack_detect · stack_build · stack_test ·
# stack_lint (rc 0 ok / 1 fail / 2 not measurable) · stack_coverage (prints 0..1 or "skip") ·
# STACK_COVERAGE_MIN. Multi-stack projects: gates AND across stacks, total = min.
set -o pipefail

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACKS_DIR="$HOOKS_DIR/../stacks"
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
export HOOKS_DIR
ONLY=""; K=1; OUT=""; JSON_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --stack) ONLY="${2:-}"; shift 2 ;;
    --k)     K="${2:-1}"; shift 2 ;;
    --out)   OUT="${2:-}"; shift 2 ;;
    --json)  JSON_ONLY=1; shift ;;
    *) shift ;;
  esac
done
case "$K" in ''|*[!0-9]*) K=1 ;; esac; [ "$K" -lt 1 ] && K=1
[ -n "$OUT" ] || OUT="$ROOT/specs/SCORE.json"

emit_unable() {  # $1=reason — fail-closed, never a fake pass
  if command -v jq >/dev/null 2>&1; then jq -cn --arg r "$1" '{verdict:"unable", total:null, reason:$r}'
  else printf '{"verdict":"unable","total":null,"reason":"%s"}\n' "$1"; fi
  echo "[carve-harness:eval-score] unable — $1" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || emit_unable "jq 미설치 — 결정적 산출 불가"
[ -d "$STACKS_DIR" ] || emit_unable ".claude/stacks/ 없음 — 언어팩 미설치"
# shellcheck source=/dev/null
[ -f "$HOOKS_DIR/lib-protected.sh" ] && source "$HOOKS_DIR/lib-protected.sh"

cd "$ROOT" || emit_unable "프로젝트 디렉토리 없음: $ROOT"
have_git=0; command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1 && have_git=1

# ── G3 safety (stack-independent): secrets in added lines, protected paths touched ──
safety_points() {  # echoes "<points>|<evidence>" — runs in a subshell, so no globals
  local added changed
  if [ "$have_git" -eq 1 ]; then
    # 변경분 = 추적 파일의 diff 추가 줄 + 미추적 파일 전체(새 파일은 git diff HEAD 에 안 나온다).
    added=$( { git diff HEAD -U0 2>/dev/null; git diff --cached -U0 2>/dev/null; } | grep -E '^\+' | grep -vE '^\+\+\+'
             git ls-files --others --exclude-standard -z 2>/dev/null | xargs -0 cat 2>/dev/null )
    if [ -n "${SECRETS_RE:-}" ] && printf '%s\n' "$added" | grep -Eq "$SECRETS_RE"; then
      echo "0|secret literal in added/untracked lines"; return
    fi
    changed=$( { git diff HEAD --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null
                 git ls-files --others --exclude-standard 2>/dev/null; } )
    if [ -n "${PROTECTED_RE:-}" ] && printf '%s\n' "$changed" | grep -Eq "$PROTECTED_RE"; then
      echo "0|protected path modified"; return
    fi
  else
    # git 없음 → 작업 트리 전체를 리터럴 스캔(빌드 산출물 제외). 느리면 --stack 으로 범위를 좁힌다.
    if [ -n "${SECRETS_RE:-}" ] && grep -rEq --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=target --exclude-dir=build "$SECRETS_RE" . 2>/dev/null; then
      echo "0|secret literal in tree"; return
    fi
  fi
  echo "15|clean"
}

# ── antislop (stack-independent): check-slop.mjs over changed visual artifacts ──
# 대상 확장자는 posttool-slop.sh 와 같은 .html/.htm/.css/.svg 다 — .md 는 카피 톤 룰이
# 문서 지배적인 리포에서 상시 발화해 신호가 잡음에 묻힌다(그 훅 헤더 §10-11). 두 곳이
# 갈라지면 "훅은 통과인데 점수는 0" 이 되므로 규칙을 바꿀 때 함께 옮겨라.
# 대상 없음·node 없음·린터 없음은 실패가 아니라 미측정 → skipped(분모에서 제외).
antislop_points() {  # echoes "<points>|<evidence>" — runs in a subshell, so no globals
  local linter="$HOOKS_DIR/check-slop.mjs" cand targets f n
  [ -f "$linter" ] || { echo "null|린터 없음"; return; }
  command -v node >/dev/null 2>&1 || { echo "null|node 없음"; return; }
  if [ "$have_git" -eq 1 ]; then
    # 변경분만 본다 — 이미 리포에 있던 남의 산출물까지 채점하지 않는다(G3 safety 와 같은 범위).
    cand=$( { git diff HEAD --name-only --diff-filter=d 2>/dev/null
              git diff --cached --name-only --diff-filter=d 2>/dev/null
              git ls-files --others --exclude-standard 2>/dev/null; } )
  else
    cand=$(find . -type d \( -name .git -o -name node_modules -o -name target -o -name build -o -name dist \) -prune -o -type f -print 2>/dev/null)
  fi
  # 삭제·이동된 경로가 섞이면 린터가 exit 2 로 끝나 "위반"으로 오독된다 → 실재 파일만 남긴다.
  targets=''
  while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$f" ] && targets="${targets}${f}"$'\n'
  done <<< "$(printf '%s\n' "$cand" | grep -Ei '\.(html?|css|svg)$' | sort -u)"
  targets="${targets%$'\n'}"
  [ -n "$targets" ] || { echo "null|검사 대상 없음(.html/.htm/.css/.svg)"; return; }
  n=$(printf '%s\n' "$targets" | wc -l | tr -d ' ')
  if printf '%s\n' "$targets" | tr '\n' '\0' | xargs -0 node "$linter" >/dev/null 2>&1; then
    echo "10|${n} file(s) 0 error"
  else
    echo "0|MUST-NOT 위반 (${n} file(s)) — node .claude/hooks/check-slop.mjs <파일> 로 확인"
  fi
}

# ── regression: tests green AND no test file deleted in the change set ──
regression_points() {  # $1 = G2 points
  [ "$1" = 25 ] || { echo 0; return; }
  if [ "$have_git" -eq 1 ] && git diff HEAD --diff-filter=D --name-only 2>/dev/null | grep -Eiq '(^|/)(test|tests|spec|__tests__)(/|_|\.)|_test\.|\.test\.|Test\.java$'; then
    echo 0; return
  fi
  echo 10
}

run_rc() {  # <fn> -> rc (2 = not measurable). Missing fn = 2.
  declare -f "$1" >/dev/null 2>&1 || return 2
  "$1"; return $?
}

score_stack() {  # sources $1, echoes one JSON object
  local f="$1" name pts_build pts_test pts_lint pts_cov pts_reg pts_safe pts_slop rc i cov skipped='[]' ev='{}'
  unset -f stack_detect stack_build stack_test stack_lint stack_coverage stack_gate stack_format
  STACK_ID=''; STACK_COVERAGE_MIN=80
  # shellcheck source=/dev/null
  source "$f"
  name="${STACK_ID:-$(basename "$f" .sh)}"

  add_skip() { skipped=$(printf '%s' "$skipped" | jq -c --arg s "$1" '. + [$s]'); }
  add_ev()   { ev=$(printf '%s' "$ev" | jq -c --arg k "$1" --arg v "$2" '. + {($k): $v}'); }

  run_rc stack_build; rc=$?
  case $rc in 0) pts_build=25; add_ev G1 "build ok" ;; 2) pts_build=null; add_skip G1 ;; *) pts_build=0; add_ev G1 "build failed (rc $rc)" ;; esac

  if [ "$pts_build" = 0 ]; then
    # 빌드 실패면 나머지 실행 무의미 — 거부권 발동, 측정 생략(eval-java 관례).
    pts_test=0; add_ev G2 "not run (build failed)"
    pts_lint=null; add_skip lint; pts_cov=null; add_skip coverage
  else
    pts_test=25
    for ((i = 1; i <= K; i++)); do
      run_rc stack_test; rc=$?
      if [ "$rc" -eq 2 ]; then pts_test=null; add_skip G2; break; fi
      if [ "$rc" -ne 0 ]; then pts_test=0; add_ev G2 "tests failed on run $i/$K"; break; fi
    done
    [ "$pts_test" = 25 ] && add_ev G2 "tests green ${K}/${K}"

    run_rc stack_lint; rc=$?
    case $rc in 0) pts_lint=10; add_ev lint "clean" ;; 2) pts_lint=null; add_skip lint ;; *) pts_lint=0; add_ev lint "violations (rc $rc)" ;; esac

    cov=$(declare -f stack_coverage >/dev/null 2>&1 && stack_coverage 2>/dev/null | tail -1); cov="${cov:-skip}"
    if [ "$cov" = skip ] || ! printf '%s' "$cov" | grep -Eq '^[0-9.]+$'; then
      pts_cov=null; add_skip coverage
    else
      pts_cov=$(awk -v c="$cov" -v m="${STACK_COVERAGE_MIN:-80}" 'BEGIN{print (c*100 >= m) ? 5 : 0}')
      add_ev coverage "$(awk -v c="$cov" 'BEGIN{printf "%.1f%%", c*100}') (min ${STACK_COVERAGE_MIN:-80}%)"
    fi
  fi

  local safety; safety=$(safety_points)
  pts_safe="${safety%%|*}"; add_ev G3 "${safety#*|}"
  if [ "$pts_test" = null ]; then pts_reg=null; add_skip regression
  else pts_reg=$(regression_points "$pts_test"); add_ev regression "$([ "$pts_reg" = 10 ] && echo 'no test file deleted, tests green' || echo 'tests not green or test file deleted')"; fi
  # antislop: G3 와 같이 스택 무관이라 빌드 실패와 무관하게 측정한다(시각 산출물은 빌드 산물이 아니다).
  local slop; slop=$(antislop_points)
  pts_slop="${slop%%|*}"
  if [ "$pts_slop" = null ]; then add_skip antislop; else add_ev antislop "${slop#*|}"; fi

  jq -cn --arg name "$name" --argjson g1 "$pts_build" --argjson g2 "$pts_test" --argjson g3 "$pts_safe" \
         --argjson lint "$pts_lint" --argjson reg "$pts_reg" --argjson cov "$pts_cov" \
         --argjson slop "$pts_slop" --argjson skipped "$skipped" --argjson ev "$ev" '
    ({G1:$g1, G2:$g2, G3:$g3}) as $gates
    | ({lint:$lint, regression:$reg, coverage:$cov, antislop:$slop}) as $items
    | ({G1:25, G2:25, G3:15, lint:10, regression:10, coverage:5, antislop:10}) as $w
    | ([$gates, $items] | add) as $all
    | ([ $all | to_entries[] | select(.value != null) | .value ] | add // 0) as $total
    | ([ $all | to_entries[] | select(.value != null) | $w[.key] ] | add // 0) as $max
    | ([ $gates[] | select(. == 0) ] | length > 0) as $veto
    | { stack:$name, total:$total, max:$max, gates:$gates, items:$items, skipped:$skipped, evidence:$ev,
        verdict: (if $veto then "FAIL" elif $max > 0 and ($total / $max) >= 0.9 then "PASS" else "FAIL" end) }'
}

# ── detect + score ──
results='[]'
for f in "$STACKS_DIR"/*.sh; do
  [ -f "$f" ] || continue
  n=$(basename "$f" .sh)
  if [ -n "$ONLY" ]; then [ "$n" = "$ONLY" ] || continue
  else
    unset -f stack_detect; STACK_ID=''
    # shellcheck source=/dev/null
    source "$f"
    declare -f stack_detect >/dev/null 2>&1 && stack_detect || continue
  fi
  r=$(score_stack "$f") || continue
  results=$(printf '%s' "$results" | jq -c --argjson r "$r" '. + [$r]')
done
[ "$(printf '%s' "$results" | jq 'length')" -gt 0 ] || emit_unable "감지된 스택 없음 (${ONLY:-auto}) — 언어팩을 설치했는지, 프로젝트 루트에서 실행했는지 확인"

verdict=$(printf '%s' "$results" | jq -c '
  { pass_line: 90,
    total: ([.[] | .total] | min),
    max:   ([.[] | .max] | min),
    verdict: (if any(.[]; .verdict == "FAIL") then "FAIL" else "PASS" end),
    stacks: (map({(.stack): .}) | add) }')
mkdir -p "$(dirname "$OUT")" 2>/dev/null && printf '%s\n' "$verdict" > "$OUT"
printf '%s\n' "$verdict"
[ "$JSON_ONLY" -eq 1 ] && exit 0
{
  echo "[carve-harness:eval-score] $(printf '%s' "$verdict" | jq -r '"\(.verdict) — total \(.total)/\(.max) (pass line 90%)"') → ${OUT#"$ROOT"/}"
  printf '%s' "$results" | jq -r '.[] | "  \(.stack): G1=\(.gates.G1 // "-") G2=\(.gates.G2 // "-") G3=\(.gates.G3) lint=\(.items.lint // "-") regression=\(.items.regression // "-") coverage=\(.items.coverage // "-") skipped=\(.skipped | join(","))"'
} >&2
exit 0
