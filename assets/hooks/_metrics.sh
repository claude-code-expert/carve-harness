#!/usr/bin/env bash
# carve-metrics — opt-in 로컬 텔레메트리 emit 헬퍼 (source 전용, 차단 로직 영향 없음).
# 기본 OFF: CARVE_METRICS=on 또는 .claude/.carve-metrics.enabled 있을 때만 한 줄 append.
# 기록은 {ts,hook,event}뿐 — 명령/경로/비밀 절대 기록 안 함. 네트워크 없음. 항상 return 0.
set -uo pipefail

carve_metric() {
  local hook="$1" event="$2"
  # 프로젝트 디렉토리 기준 — 형제 훅과 동일($CLAUDE_PROJECT_DIR, 미설정 시 CWD)
  local dir="${CLAUDE_PROJECT_DIR:-.}"
  # opt-in 게이트 먼저 — 기본 OFF
  if [ "${CARVE_METRICS:-}" = "on" ] || [ -f "$dir/.claude/.carve-metrics.enabled" ]; then
    local ts
    ts=$(date +%s 2>/dev/null) || ts=0
    mkdir -p "$dir/.claude" 2>/dev/null
    printf '{"ts":%s,"hook":"%s","event":"%s"}\n' "$ts" "$hook" "$event" >> "$dir/.claude/.carve-metrics.jsonl" 2>/dev/null
  fi
  return 0
}
