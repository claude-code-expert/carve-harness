#!/usr/bin/env bash
# SessionStart(start): 핸드오프 복원 | PreCompact(save): 진행상황 저장
H="specs/HANDOFF.md"
LOG_EVENT="$(dirname "${BASH_SOURCE[0]}")/log-event.sh"
case "${1:-}" in
  start)
    [ -f "$H" ] && { echo "=== 이전 세션 핸드오프 ==="; cat "$H"; }
    bash "$LOG_EVENT" SessionStart handoff start ""
    ;;
  save)
    { echo "# HANDOFF ($(date +%F' '%T))"; echo "- branch: $(git branch --show-current 2>/dev/null)"; echo "- TODO: [자동 수집 — 내용없음]"; } > "$H"
    bash "$LOG_EVENT" PreCompact handoff save ""
    ;;
esac
exit 0
