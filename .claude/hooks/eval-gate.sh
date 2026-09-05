#!/usr/bin/env bash
# eval-gate.sh — deterministic regression gate over the golden-set score trend.
# Reads specs/eval-score.json (written by eval-trend.sh for the carve-eval workflow)
# and judges the latest scored run. NO LLM, no scoring — carve-eval scores and appends,
# this only enforces, so CI never depends on a model to decide pass/fail.
#
#   bash eval-gate.sh [--mode report|block] [--delta N] [--file PATH] [--changed LIST]
#     --mode block    any non-ok verdict -> exit 1 (CI gate). default: report (always exit 0)
#     --delta N       allowed drop vs the previous run, in points (default 3)
#     --file PATH     trend file (default $CLAUDE_PROJECT_DIR/specs/eval-score.json)
#     --changed LIST  newline- or comma-separated changed paths of the PR (e.g. from
#                     `git diff --name-only base...HEAD`). Enables the `stale` verdict.
#
# Verdicts (one JSON line on stdout, human summary on stderr), checked in this order:
#   unable      no trend file, unusable JSON, or no scored run -> NEVER a silent pass
#   stale       --changed touches prompt-bearing files (CLAUDE.md · AGENTS.md · .claude/** ·
#               specs/goldenset/** · prompts/**) but not the trend -> the score was not
#               re-measured after the prompt changed (blueprint R8)
#   suspicious  every case in the latest run scored 0, or every case scored 100 (>=3 cases):
#               extreme scores mean "check the grader / the cases", not "ship" (blueprint §6.7)
#   regressed   a `required`-tagged case is not fully green (caseScore < 100), or the suite
#               dropped more than --delta below the previous run (blueprint §6.5 gate ①)
#   ok          first run, or within tolerance
set -o pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
MODE=report
DELTA=3
FILE=""
CHANGED=""
while [ $# -gt 0 ]; do
  case "$1" in
    --mode)    MODE="${2:-report}"; shift 2 ;;
    --delta)   DELTA="${2:-3}"; shift 2 ;;
    --file)    FILE="${2:-}"; shift 2 ;;
    --changed) CHANGED="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
case "$MODE" in report|block) ;; *) MODE=report ;; esac
case "$DELTA" in ''|*[!0-9]*) DELTA=3 ;; esac
[ -n "$FILE" ] || FILE="$ROOT/specs/eval-score.json"

# Prompt-bearing paths: changing any of these changes what the golden set measures.
PROMPT_RE='^(CLAUDE\.md|AGENTS\.md|\.claude/|specs/goldenset/|prompts/)'
TREND_REL="${FILE#"$ROOT"/}"

emit() {  # $1=verdict $2=reason [$3=extra JSON object] ; exit code decided by mode
  local extra="${3:-}"; [ -n "$extra" ] || extra='{}'
  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg v "$1" --arg r "$2" --arg m "$MODE" --argjson x "$extra" \
      '{verdict:$v, reason:$r, mode:$m, suiteScore:null, baseline:null, delta:null} + $x'
  else
    printf '{"verdict":"%s","reason":"%s","mode":"%s"}\n' "$1" "$2" "$MODE"
  fi
  echo "[carve-harness:eval-gate] $1 — $2" >&2
  { [ "$1" = "ok" ] || [ "$MODE" = report ]; } && exit 0
  exit 1
}

command -v jq >/dev/null 2>&1 || emit unable "jq 미설치 — 추이 파싱 불가"
[ -f "$FILE" ] || emit unable "추이 파일 없음: $TREND_REL (먼저 /eval 로 baseline을 남겨라)"
jq -e . "$FILE" >/dev/null 2>&1 || emit unable "추이 JSON 파싱 실패: $TREND_REL"

# ── stale: prompts changed, trend not re-measured ──
if [ -n "$CHANGED" ]; then
  changed_lines=$(printf '%s' "$CHANGED" | tr ',' '\n' | sed '/^[[:space:]]*$/d')
  if printf '%s\n' "$changed_lines" | grep -Eq "$PROMPT_RE" \
     && ! printf '%s\n' "$changed_lines" | grep -qxF "$TREND_REL"; then
    hits=$(printf '%s\n' "$changed_lines" | grep -E "$PROMPT_RE" | head -5 | tr '\n' ' ')
    emit stale "프롬프트·규칙·골든셋이 바뀌었는데 추이가 갱신되지 않았다 — /eval 을 다시 돌려 $TREND_REL 을 같은 PR에 넣어라 (변경: ${hits})" \
      "$(jq -cn --arg h "$hits" '{changed: ($h | split(" ") | map(select(length > 0)))}')"
  fi
fi

# Last two SCORED runs (suiteScore null = empty goldenset run, not a measurement).
read -r CUR PREV < <(jq -r '
  [ .runs[]? | select(.suiteScore != null) ] as $s
  | [ ($s[-1].suiteScore // "none"), ($s[-2].suiteScore // "none") ] | @tsv' "$FILE" 2>/dev/null)

[ "$CUR" = "none" ] || [ -z "$CUR" ] && emit unable "채점된 run이 없다 — 골든셋이 비었거나 /eval 미실행"

# ── suspicious: extreme scores across the whole latest run ──
read -r NCASES NZERO NFULL < <(jq -r '
  ([ .runs[]? | select(.suiteScore != null) ] | last | .cases // []) as $c
  | [ ($c | length), ([ $c[] | select(.caseScore == 0) ] | length), ([ $c[] | select(.caseScore == 100) ] | length) ] | @tsv' "$FILE" 2>/dev/null)
if [ "${NCASES:-0}" -ge 3 ]; then
  if [ "$NZERO" = "$NCASES" ]; then
    emit suspicious "최근 run 케이스 ${NCASES}건 전부 0점 — 채점기·setup·target 고장을 먼저 의심하라(에이전트 실패로 읽지 마라)" \
      "$(jq -cn --argjson c "$CUR" --argjson n "$NCASES" '{suiteScore:$c, cases:$n, extreme:"all-zero"}')"
  fi
  if [ "$NFULL" = "$NCASES" ]; then
    emit suspicious "최근 run 케이스 ${NCASES}건 전부 100점 — 골든셋이 너무 쉽다(회귀 탐지 여지 0). 난이도를 보강하라" \
      "$(jq -cn --argjson c "$CUR" --argjson n "$NCASES" '{suiteScore:$c, cases:$n, extreme:"all-full"}')"
  fi
fi

# ── required: a tagged case that is not fully green fails the gate regardless of the mean ──
REQ_FAILED=$(jq -c '
  ([ .runs[]? | select(.suiteScore != null) ] | last | .cases // [])
  | [ .[] | select((.tags // []) | index("required")) | select((.caseScore // 0) < 100) | .id ]' "$FILE" 2>/dev/null)
if [ "$(printf '%s' "$REQ_FAILED" | jq 'length')" -gt 0 ]; then
  emit regressed "required 케이스 실패: $(printf '%s' "$REQ_FAILED" | jq -r 'join(", ")') — 평균과 무관하게 차단" \
    "$(jq -cn --argjson c "$CUR" --argjson r "$REQ_FAILED" '{suiteScore:$c, requiredFailed:$r}')"
fi

if [ "$PREV" = "none" ]; then
  jq -cn --argjson c "$CUR" --arg m "$MODE" \
    '{verdict:"ok", reason:"baseline 최초 기록 — 비교 대상 없음", mode:$m, suiteScore:$c, baseline:null, delta:null}'
  echo "[carve-harness:eval-gate] ok — suite $CUR (baseline 최초 기록)" >&2
  exit 0
fi

DROP=$(awk -v c="$CUR" -v p="$PREV" 'BEGIN{ printf "%.2f", p - c }')
REGRESSED=$(awk -v d="$DROP" -v t="$DELTA" 'BEGIN{ print (d > t) ? 1 : 0 }')

if [ "$REGRESSED" -eq 1 ]; then
  jq -cn --argjson c "$CUR" --argjson p "$PREV" --argjson d "$DROP" --arg m "$MODE" --argjson t "$DELTA" \
    '{verdict:"regressed", reason:"허용 하락폭 초과", mode:$m, suiteScore:$c, baseline:$p, delta:$d, allowed:$t}'
  echo "[carve-harness:eval-gate] REGRESSION — suite ${PREV}→${CUR} (${DROP}pt 하락 > 허용 ${DELTA}pt)" >&2
  [ "$MODE" = block ] && exit 1
  exit 0
fi

jq -cn --argjson c "$CUR" --argjson p "$PREV" --argjson d "$DROP" --arg m "$MODE" --argjson t "$DELTA" \
  '{verdict:"ok", reason:"허용 범위 내", mode:$m, suiteScore:$c, baseline:$p, delta:$d, allowed:$t}'
echo "[carve-harness:eval-gate] ok — suite ${PREV}→${CUR} (허용 ${DELTA}pt 이내)" >&2
exit 0
