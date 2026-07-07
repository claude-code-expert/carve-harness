#!/usr/bin/env bash
# OBS-01 best-effort JSONL append helper (D-04): the single source for schema,
# timestamp, and PROTECTED_RE masking. Called as a SUBPROCESS with positional
# args (NEVER stdin) so a failure here can never change the caller's exit code
# (D-05). ALWAYS exits 0. No `set -e`.
#   log-event.sh <event> <tool> <decision> [target] [reason]
# Writes one compact JSON line to $DIR/logs/$(date -u +%F).jsonl; empty
# target/reason keys are omitted. Never echo/interpolate the line — jq -cn only.

command -v jq >/dev/null 2>&1 || exit 0

DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

event="$1"; tool="$2"; decision="$3"; target="$4"; reason="$5"

# Single-source protected-path pattern. Fail-safe: if lib-protected.sh cannot
# load, mask any non-empty target unconditionally rather than risk logging a
# protected path in clear.
if source "$(dirname "${BASH_SOURCE[0]}")/lib-protected.sh" 2>/dev/null; then
  if [ -n "$target" ] && printf '%s' "$target" | grep -Eq "$PROTECTED_RE"; then
    target='<masked>'
  fi
elif [ -n "$target" ]; then
  target='<masked>'
fi

mkdir -p "$DIR/logs" 2>/dev/null || exit 0
LOG="$DIR/logs/$(date -u +%F).jsonl"

{
  jq -cn \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg event "$event" \
    --arg tool "$tool" \
    --arg decision "$decision" \
    --arg target "$target" \
    --arg reason "$reason" \
    '{ts:$ts, event:$event, tool:$tool, decision:$decision}
      + (if $target != "" then {target:$target} else {} end)
      + (if $reason != "" then {reason:$reason} else {} end)' >> "$LOG"
} 2>/dev/null || exit 0

exit 0
