#!/usr/bin/env bash
# Stop: 검증 루프 완료 게이트. specs/checklist.json 의 모든 항목이 threshold(기본 95)
# 이상으로 채점됐는지 확인, 미달/미채점이 남으면 완료 차단(exit 2).
# 관용구는 stop-verify.sh와 동일: stdin JSON 1회 소비, stop_hook_active 루프가드,
# jq-absent best-effort, log-event 서브프로세스.
set -o pipefail

LOG_EVENT="$(dirname "${BASH_SOURCE[0]}")/log-event.sh"
DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CHECKLIST="$DIR/specs/checklist.json"
# GATE-C5 tombstone: set while a loop has unresolved items, cleared only when the
# gate itself passes. Without it "delete your own scorecard" turns the gate off —
# the graded party must not be able to end the grading. The path is in
# PROTECTED_RE, so the agent can neither write nor rm it; a human ending an
# abandoned loop deletes it from their own shell.
LOCK="$DIR/specs/.checklist-active"
# GATE-C6 threshold floor: the file is agent-writable, so a lowered threshold is a
# free pass. Floor it at 95 (the documented bar); override for a genuinely
# different bar via env, which the agent does not control.
FLOOR="${CARVE_CHECKLIST_FLOOR:-95}"

# GATE-C1: forced-continuation guard, single-sourced with stop-verify so the
# wedge-prevention invariant cannot drift (lib-stop-guard.sh). Reads stdin once.
source "$(dirname "${BASH_SOURCE[0]}")/lib-stop-guard.sh"
stop_loop_yield checklist "$LOG_EVENT"

# GATE-C2: no checklist -> no-op, UNLESS a loop was already running (tombstone).
# 루프를 연 적 없는 작업은 방해받지 않고, 열린 루프는 파일을 지워도 끝나지 않는다.
if [ ! -f "$CHECKLIST" ]; then
  [ -f "$LOCK" ] || exit 0
  echo "[carve-harness:checklist] 검증 루프 진행 중인데 specs/checklist.json 이 사라졌다 — 완료 차단. 복원해 채점을 마치거나, 루프를 중단하려면 사람이 specs/.checklist-active 를 지워라" >&2
  bash "$LOG_EVENT" Stop checklist fail "checklist-missing"
  exit 2
fi

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
case "$THRESHOLD" in ''|*[!0-9]*) THRESHOLD=$FLOOR ;; esac
if [ "$THRESHOLD" -lt "$FLOOR" ]; then
  echo "[carve-harness:checklist] threshold ${THRESHOLD} < 하한 ${FLOOR} — 하한으로 채점(자가 하향 무효)" >&2
  THRESHOLD=$FLOOR
fi

# GATE-C7 유형별 거부권(블루프린트 §5.5 — domain_safety 허용 실패율 0%): `type: domain_safety` 항목은
# 100점이 아니면 총점·임계와 무관하게 차단한다. 안전 불변식은 "거의 됐다"가 없다. type 없는 항목은
# 기존 임계 규칙 그대로(하위호환). 유형은 convention | correctness | domain_safety.
SAFETY_UNRESOLVED=$(jq -r '
  [ .items[]
    | select(.type == "domain_safety")
    | select((.score == null) or (.score < 100))
    | "\(.id)(\(.score // "미채점"))"
  ] | join(", ")' "$CHECKLIST")
if [ -n "$SAFETY_UNRESOLVED" ]; then
  mkdir -p "$DIR/specs" 2>/dev/null && : > "$LOCK" 2>/dev/null
  echo "[carve-harness:checklist] domain_safety 항목 미완 (100점 필수, 임계 무관): ${SAFETY_UNRESOLVED} — 안전 불변식은 부분 점수가 없다" >&2
  bash "$LOG_EVENT" Stop checklist fail "domain_safety:${SAFETY_UNRESOLVED}"
  exit 2
fi

# 미달(=score<threshold) 또는 미채점(score==null) 항목을 "id(score)"로 나열.
# score null -> "미채점"으로 표기.
UNRESOLVED=$(jq -r --argjson th "$THRESHOLD" '
  [ .items[]
    | select((.score == null) or (.score < $th))
    | "\(.id)(\(.score // "미채점"))"
  ] | join(", ")' "$CHECKLIST")

if [ -n "$UNRESOLVED" ]; then
  COUNT=$(printf '%s' "$UNRESOLVED" | awk -F', ' '{print NF}')
  mkdir -p "$DIR/specs" 2>/dev/null && : > "$LOCK" 2>/dev/null   # tombstone on (best-effort)
  echo "[carve-harness:checklist] 미완 ${COUNT}개 (임계 ${THRESHOLD}): ${UNRESOLVED} — 루프 계속(gap 수정 후 재채점)" >&2
  bash "$LOG_EVENT" Stop checklist fail "$UNRESOLVED"
  exit 2
fi

rm -f "$LOCK" 2>/dev/null   # 정상 완료만이 tombstone을 지운다
echo "[carve-harness:checklist] 전 항목 ${THRESHOLD}점 이상 — 검증 루프 완료" >&2
bash "$LOG_EVENT" Stop checklist pass ""
exit 0
