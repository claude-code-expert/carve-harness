#!/usr/bin/env bash
# PostToolUse: 확장자로 스택 감지 후 포맷 (후처리 전용). 포맷터는 .claude/stacks/<pack>.sh 의
# STACK_FORMAT_RE / stack_format 이 정의한다 — 언어팩 단위로 설치·제거.
# OBS-02/C8: every fire records exactly one outcome (format-ok/fail/skip) in the
# JSONL; the formatter's own stdout AND stderr stay silenced (>/dev/null 2>&1 —
# stderr alone let gradle/prettier chatter into the transcript). Stays exit 0 —
# a PostToolUse non-zero exit is non-blocking, so a format miss must not surface
# a spurious hook error.
input=$(cat)
f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACKS_DIR="$HOOKS_DIR/../stacks"
LOG_EVENT="$HOOKS_DIR/log-event.sh"
handled=0
for stack in "$STACKS_DIR"/*.sh; do
  [ -f "$stack" ] || continue
  unset -f stack_gate stack_format
  STACK_FORMAT_RE=''; STACK_FORMAT_TOOL=''
  # shellcheck source=/dev/null
  source "$stack"
  [ -n "$STACK_FORMAT_RE" ] && [ -n "$f" ] || continue
  printf '%s' "$f" | grep -Eq "$STACK_FORMAT_RE" || continue
  declare -f stack_format >/dev/null 2>&1 || continue
  stack_format "$f" >/dev/null 2>&1; rc=$?
  case "$rc" in
    0) bash "$LOG_EVENT" PostToolUse "$STACK_FORMAT_TOOL" format-ok "$f" ;;
    2) bash "$LOG_EVENT" PostToolUse "$STACK_FORMAT_TOOL" format-fail "$f" missing ;;
    *) bash "$LOG_EVENT" PostToolUse "$STACK_FORMAT_TOOL" format-fail "$f" error ;;
  esac
  handled=1; break
done
[ "$handled" -eq 1 ] || bash "$LOG_EVENT" PostToolUse none format-skip "$f"
exit 0
