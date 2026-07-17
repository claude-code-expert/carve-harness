#!/usr/bin/env bash
# Single-source Stop-hook forced-continuation guard (GATE-01, D-02). Sourced by
# stop-verify.sh AND conformance-gate.sh so the wedge-prevention invariant has
# exactly ONE definition — if the two Stop hooks drift here, a forced re-Stop can
# wedge the session (the very thing this guards against). Pure function, no
# top-level side effects: source it, then call. Do not redefine elsewhere.
#
#   stop_loop_yield <name> <log_event_path>
# Reads stdin (the Stop event JSON) — call before any other stdin read. On the
# second Stop pass (stop_hook_active=true) it logs a loop-yield and exit 0s the
# CALLER. jq absent → returns so the caller applies its own jq-absent policy next.
stop_loop_yield() {
  local name="$1" log="$2" input
  input=$(cat)
  if command -v jq >/dev/null 2>&1 && [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ]; then
    echo "[carve-harness:$name] 이미 재검증 continuation 상태 — 루프 방지 위해 종료 허용" >&2
    bash "$log" Stop "$name" loop-yield ""
    exit 0
  fi
}
