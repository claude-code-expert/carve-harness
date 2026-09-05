#!/usr/bin/env bash
# PostToolUse: 확장자로 언어 감지 후 포맷 (후처리 전용).
# OBS-02/C8: every fire records exactly one outcome (format-ok/fail/skip) in the
# JSONL; the formatter's own stdout AND stderr stay silenced (>/dev/null 2>&1 —
# stderr alone let gradle/prettier chatter into the transcript). Stays exit 0 —
# a PostToolUse non-zero exit is non-blocking, so a format miss must not surface
# a spurious hook error.
input=$(cat)
f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
LOG_EVENT="$(dirname "${BASH_SOURCE[0]}")/log-event.sh"
case "$f" in
  *.java)
    if [ ! -x ./gradlew ]; then
      bash "$LOG_EVENT" PostToolUse spotless format-fail "$f" missing
    elif ! ./gradlew spotlessApply -PspotlessFiles="$f" -q >/dev/null 2>&1; then
      bash "$LOG_EVENT" PostToolUse spotless format-fail "$f" error
    else
      bash "$LOG_EVENT" PostToolUse spotless format-ok "$f"
    fi
    ;;
  *.ts|*.tsx|*.js|*.jsx)
    if ! command -v pnpm >/dev/null 2>&1; then
      bash "$LOG_EVENT" PostToolUse prettier format-fail "$f" missing
    elif ! pnpm exec prettier --write "$f" >/dev/null 2>&1; then
      bash "$LOG_EVENT" PostToolUse prettier format-fail "$f" error
    else
      bash "$LOG_EVENT" PostToolUse prettier format-ok "$f"
    fi
    ;;
  *)
    bash "$LOG_EVENT" PostToolUse none format-skip "$f"
    ;;
esac
exit 0
