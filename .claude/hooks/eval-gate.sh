#!/usr/bin/env bash
# eval-gate.sh — deterministic regression gate over the golden-set score trend.
# Reads specs/eval-score.json (written by the carve-eval workflow) and compares the
# latest run against the previous one. NO LLM, no scoring — carve-eval scores and
# appends, this only enforces, so CI never depends on a model to decide pass/fail.
#
#   bash eval-gate.sh [--mode report|block] [--delta N] [--file PATH]
#     --mode block    regression -> exit 1 (CI gate). default: report (always exit 0)
#     --delta N       allowed drop vs the previous run, in points (default 3)
#     --file PATH     trend file (default $CLAUDE_PROJECT_DIR/specs/eval-score.json)
#
# Verdicts (one JSON line on stdout, human summary on stderr):
#   ok         no regression (or first run / no baseline yet)
#   regressed  suiteScore dropped more than --delta below the previous run
#   unable     no trend file, unusable JSON, or no scored run -> NEVER a silent pass;
#              exits 1 in block mode (a missing score is not evidence of quality).
set -o pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
MODE=report
DELTA=3
FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --mode)  MODE="${2:-report}"; shift 2 ;;
    --delta) DELTA="${2:-3}"; shift 2 ;;
    --file)  FILE="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
case "$MODE" in report|block) ;; *) MODE=report ;; esac
case "$DELTA" in ''|*[!0-9]*) DELTA=3 ;; esac
[ -n "$FILE" ] || FILE="$ROOT/specs/eval-score.json"

emit() {  # $1=verdict $2=reason ; exit code decided by mode
  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg v "$1" --arg r "$2" --arg m "$MODE" \
      '{verdict:$v, reason:$r, mode:$m, suiteScore:null, baseline:null, delta:null}'
  else
    printf '{"verdict":"%s","reason":"%s","mode":"%s"}\n' "$1" "$2" "$MODE"
  fi
  echo "[carve-harness:eval-gate] $1 — $2" >&2
  { [ "$1" = "ok" ] || [ "$MODE" = report ]; } && exit 0
  exit 1
}

command -v jq >/dev/null 2>&1 || emit unable "jq 미설치 — 추이 파싱 불가"
[ -f "$FILE" ] || emit unable "추이 파일 없음: ${FILE#"$ROOT"/} (먼저 /eval 로 baseline을 남겨라)"
jq -e . "$FILE" >/dev/null 2>&1 || emit unable "추이 JSON 파싱 실패: ${FILE#"$ROOT"/}"

# Last two SCORED runs (suiteScore null = empty goldenset run, not a measurement).
read -r CUR PREV < <(jq -r '
  [ .runs[]? | select(.suiteScore != null) ] as $s
  | [ ($s[-1].suiteScore // "none"), ($s[-2].suiteScore // "none") ] | @tsv' "$FILE" 2>/dev/null)

[ "$CUR" = "none" ] || [ -z "$CUR" ] && emit unable "채점된 run이 없다 — 골든셋이 비었거나 /eval 미실행"

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
