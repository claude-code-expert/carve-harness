#!/usr/bin/env bash
# carve-precompact-handoff — PreCompact: 압축 직전 핸드오프 마커 영속화 (비차단).
set -uo pipefail
cat >/dev/null
dir="${CLAUDE_PROJECT_DIR:-.}"
ts=$(date -u +%FT%TZ 2>/dev/null || echo now)
{ echo "## handoff @ $ts"; echo "- PreCompact: 진행상황·결정·다음할일을 여기 정리한다(handoff 스킬 참조)."; } >> "$dir/.carve-handoff.md" 2>/dev/null || true
exit 0
