#!/usr/bin/env bash
# SessionStart(start): 핸드오프 복원 | PreCompact(save): 진행상황 저장
H="specs/HANDOFF.md"
case "${1:-}" in
  start) [ -f "$H" ] && { echo "=== 이전 세션 핸드오프 ==="; cat "$H"; } ;;
  save)  { echo "# HANDOFF ($(date +%F' '%T))"; echo "- branch: $(git branch --show-current 2>/dev/null)"; echo "- TODO: [자동 수집 — 내용없음]"; } > "$H" ;;
esac
exit 0
