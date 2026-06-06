#!/usr/bin/env bash
# carve-precompact-handoff — PreCompact: 압축 직전 핸드오프 마커 영속화 (비차단).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_metrics.sh" 2>/dev/null || true
cat >/dev/null
dir="${CLAUDE_PROJECT_DIR:-.}"
ts=$(date -u +%FT%TZ 2>/dev/null || echo now)
{ echo "## handoff @ $ts"; echo "- PreCompact: 진행상황·결정·다음할일을 여기 정리한다(handoff 스킬 참조)."; } >> "$dir/.carve-handoff.md" 2>/dev/null || true
# 압축 발생 = 컨텍스트 압력 proxy (opt-in 텔레메트리, 라이브 점유율 측정은 불가)
carve_metric precompact-handoff compact
exit 0
