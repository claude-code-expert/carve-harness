#!/usr/bin/env bash
# Stop: 검증 루프 완료 게이트. specs/checklist.json 의 모든 항목이 threshold(기본 95)
# 이상으로 채점됐는지 확인, 미달/미채점이 남으면 완료 차단(exit 2).
# 관용구는 stop-verify.sh와 동일: stdin JSON 1회 소비, stop_hook_active 루프가드,
# jq-absent best-effort, log-event 서브프로세스.
set -o pipefail

LOG_EVENT="$(dirname "${BASH_SOURCE[0]}")/log-event.sh"
DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CHECKLIST="$DIR/specs/checklist.json"

# GATE-C1: read stdin once; on forced-continuation 2nd pass, yield to avoid a loop.
input=$(cat)
if command -v jq >/dev/null 2>&1 && [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ]; then
  echo "[carve-harness:checklist] 이미 재검증 continuation 상태 — 루프 방지 위해 종료 허용" >&2
  bash "$LOG_EVENT" Stop checklist loop-yield ""
  exit 0
fi

# GATE-C2: no checklist -> no-op. This hook only has teeth during an active loop.
[ -f "$CHECKLIST" ] || exit 0

# GATE-C3: jq-absent best-effort (non-blocking) — symmetric with stop-verify (D-02).
# 채점 파일을 파싱 못 하면 완료를 막지 않는다(jq 없는 박스에서 교착 방지).
if ! command -v jq >/dev/null 2>&1; then
  echo "[carve-harness:checklist] jq 미설치 → 체크리스트 게이트 스킵(best-effort)" >&2
  exit 0
fi

# GATE-C4: malformed JSON -> best-effort skip (막지 않음, 경고만).
if ! jq -e . "$CHECKLIST" >/dev/null 2>&1; then
  echo "[carve-harness:checklist] checklist.json 파싱 실패 → 스킵(best-effort)" >&2
  exit 0
fi

THRESHOLD=$(jq -r '.threshold // 95' "$CHECKLIST")

# 미달(=score<threshold) 또는 미채점(score==null) 항목을 "id(score)"로 나열.
# score null -> "미채점"으로 표기.
UNRESOLVED=$(jq -r --argjson th "$THRESHOLD" '
  [ .items[]
    | select((.score == null) or (.score < $th))
    | "\(.id)(\(.score // "미채점"))"
  ] | join(", ")' "$CHECKLIST")

if [ -n "$UNRESOLVED" ]; then
  COUNT=$(printf '%s' "$UNRESOLVED" | awk -F', ' '{print NF}')
  echo "[carve-harness:checklist] 미완 ${COUNT}개 (임계 ${THRESHOLD}): ${UNRESOLVED} — 루프 계속(gap 수정 후 재채점)" >&2
  bash "$LOG_EVENT" Stop checklist fail "$UNRESOLVED"
  exit 2
fi

echo "[carve-harness:checklist] 전 항목 ${THRESHOLD}점 이상 — 검증 루프 완료" >&2
bash "$LOG_EVENT" Stop checklist pass ""
exit 0
