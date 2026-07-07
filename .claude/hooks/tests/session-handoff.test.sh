#!/usr/bin/env bash
# Assertions for session-handoff.sh (OBS-01/D-03): SessionStart:start and
# PreCompact:save each log exactly one JSONL line and stay exit 0; save still
# writes specs/HANDOFF.md. A log failure never changes the exit code (D-05).

HOOK="$(cd "$(dirname "$0")/.." && pwd)/session-handoff.sh"
fail=0; pass=0
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }
daily() { printf '%s/logs/%s.jsonl' "$1" "$(date -u +%F)"; }

# (1) start -> one SessionStart/start line, exit 0.
cwd=$(mktemp -d); logd=$(mktemp -d); L="$(daily "$logd")"
( cd "$cwd" && CLAUDE_PROJECT_DIR="$logd" bash "$HOOK" start >/dev/null 2>&1 ); code=$?
if [ "$code" -eq 0 ] \
   && [ "$(tail -1 "$L" 2>/dev/null | jq -r '.event' 2>/dev/null)" = "SessionStart" ] \
   && [ "$(tail -1 "$L" 2>/dev/null | jq -r '.decision' 2>/dev/null)" = "start" ]; then
  ok "start logs SessionStart/start (exit 0)"
else
  bad "start log"
fi
rm -rf "$cwd" "$logd"

# (2) save -> one PreCompact/save line, writes specs/HANDOFF.md, exit 0.
cwd=$(mktemp -d); logd=$(mktemp -d); L="$(daily "$logd")"
mkdir -p "$cwd/specs"
( cd "$cwd" && CLAUDE_PROJECT_DIR="$logd" bash "$HOOK" save >/dev/null 2>&1 ); code=$?
if [ "$code" -eq 0 ] && [ -f "$cwd/specs/HANDOFF.md" ] \
   && [ "$(tail -1 "$L" 2>/dev/null | jq -r '.event' 2>/dev/null)" = "PreCompact" ] \
   && [ "$(tail -1 "$L" 2>/dev/null | jq -r '.decision' 2>/dev/null)" = "save" ]; then
  ok "save logs PreCompact/save + writes specs/HANDOFF.md (exit 0)"
else
  bad "save log / HANDOFF.md"
fi
rm -rf "$cwd" "$logd"

# (3) D-05: unwritable logs -> both start and save still exit 0.
cwd=$(mktemp -d); logd=$(mktemp -d); touch "$logd/logs"; mkdir -p "$cwd/specs"
( cd "$cwd" && CLAUDE_PROJECT_DIR="$logd" bash "$HOOK" start >/dev/null 2>&1 ); s=$?
( cd "$cwd" && CLAUDE_PROJECT_DIR="$logd" bash "$HOOK" save  >/dev/null 2>&1 ); v=$?
[ "$s" -eq 0 ] && [ "$v" -eq 0 ] && ok "unwritable logs -> start & save still exit 0" || bad "unwritable logs exit 0"
rm -rf "$cwd" "$logd"

# (4) source: both log calls present; HANDOFF placeholder untouched (Phase 3 scope); bash -n clean.
grep -q 'SessionStart handoff start' "$HOOK" && ok "start log call present" || bad "start log call"
grep -q 'PreCompact handoff save' "$HOOK" && ok "save log call present" || bad "save log call"
grep -q '자동 수집' "$HOOK" && ok "HANDOFF placeholder preserved (STATE-01/Phase 3)" || bad "placeholder removed"
bash -n "$HOOK" 2>/dev/null && ok "bash -n clean" || bad "bash -n"

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
