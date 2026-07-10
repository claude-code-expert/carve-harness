#!/usr/bin/env bash
# Assertions for log-event.sh (OBS-01): append-count delta==1, JSON validity,
# PROTECTED_RE masking, injection safety, and guard exit-code preservation under
# a log failure (D-05). jq-absence simulated via env -i PATH= + absolute bash —
# never uninstalls jq. Every case uses a fresh mktemp CLAUDE_PROJECT_DIR so the
# repo's real logs/ is never touched.

DIR_HERE="$(cd "$(dirname "$0")/.." && pwd)"      # .claude/hooks
LOG_EVENT="$DIR_HERE/log-event.sh"
LIB="$DIR_HERE/lib-protected.sh"
GUARD="$DIR_HERE/pretool-guard.sh"
GITIGNORE="$(cd "$DIR_HERE/../.." && pwd)/.gitignore"
BASH_BIN="$(command -v bash)"
fail=0
pass=0

ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

daily() { printf '%s/logs/%s.jsonl' "$1" "$(date -u +%F)"; }
lines() { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }

# (1) Direct append: protected target -> one line, parses, target masked.
tmp=$(mktemp -d); L="$(daily "$tmp")"
before=$(lines "$L")
CLAUDE_PROJECT_DIR="$tmp" bash "$LOG_EVENT" PreToolUse Write block "x/.env.production"
after=$(lines "$L")
if [ "$((after - before))" -eq 1 ] && tail -1 "$L" 2>/dev/null | jq . >/dev/null 2>&1 \
   && [ "$(tail -1 "$L" | jq -r '.event')" = "PreToolUse" ] \
   && [ "$(tail -1 "$L" | jq -r '.decision')" = "block" ] \
   && [ "$(tail -1 "$L" | jq -r '.target')" = "<masked>" ]; then
  ok "direct append: delta==1, jq . parses, protected target masked"
else
  bad "direct append / masking"
fi
rm -rf "$tmp"

# (2) Non-protected target logged as-is (not masked).
tmp=$(mktemp -d); L="$(daily "$tmp")"
CLAUDE_PROJECT_DIR="$tmp" bash "$LOG_EVENT" PreToolUse Write allow foo.txt
if [ "$(tail -1 "$L" 2>/dev/null | jq -r '.target' 2>/dev/null)" = "foo.txt" ]; then
  ok "non-protected target logged as-is"
else
  bad "non-protected target"
fi
rm -rf "$tmp"

# (3) Injection: hostile target (quote + newline + fake JSON) -> delta==1, parses.
tmp=$(mktemp -d); L="$(daily "$tmp")"
hostile=$'a"b\n{"fake":"line"}c'
before=$(lines "$L")
CLAUDE_PROJECT_DIR="$tmp" bash "$LOG_EVENT" PreToolUse Write allow "$hostile"
after=$(lines "$L")
if [ "$((after - before))" -eq 1 ] && tail -1 "$L" 2>/dev/null | jq . >/dev/null 2>&1; then
  ok "injection: hostile target -> one line, parses as one object"
else
  bad "injection safety"
fi
rm -rf "$tmp"

# (4) D-05: jq present but logs UNWRITABLE (logs is a FILE) -> guard exit code unchanged.
tmp=$(mktemp -d); touch "$tmp/logs"   # regular file named logs => mkdir -p logs fails
printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"x/.env.production"}}' \
  | CLAUDE_PROJECT_DIR="$tmp" bash "$GUARD" >/dev/null 2>&1
[ $? -eq 2 ] && ok "unwritable logs: protected-write still blocks (exit 2)" || bad "unwritable logs block (exit 2)"
printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"foo.txt"}}' \
  | CLAUDE_PROJECT_DIR="$tmp" bash "$GUARD" >/dev/null 2>&1
[ $? -eq 0 ] && ok "unwritable logs: benign-write still allows (exit 0)" || bad "unwritable logs allow (exit 0)"
rm -rf "$tmp"

# (5) D-05 / Pitfall 3: jq absent -> protected-write blocks (exit 2), no log line.
printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"x/.env.production"}}' \
  | env -i PATH= "$BASH_BIN" "$GUARD" >/dev/null 2>&1
[ $? -eq 2 ] && ok "jq-absent: protected-write blocks (exit 2)" || bad "jq-absent block (exit 2)"

# (6) Guard integration: protected-write appends one masked block line.
tmp=$(mktemp -d); L="$(daily "$tmp")"
before=$(lines "$L")
printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"x/.env.production"}}' \
  | CLAUDE_PROJECT_DIR="$tmp" bash "$GUARD" >/dev/null 2>&1
after=$(lines "$L")
if [ "$((after - before))" -eq 1 ] \
   && [ "$(tail -1 "$L" | jq -r '.decision')" = "block" ] \
   && [ "$(tail -1 "$L" | jq -r '.tool')" = "Write" ] \
   && [ "$(tail -1 "$L" | jq -r '.target')" = "<masked>" ]; then
  ok "guard integration: protected-write logs one masked block line"
else
  bad "guard integration masked block line"
fi
rm -rf "$tmp"

# (7) Regression: .gitignore has logs/, Phase 1 guard test still green, bash -n clean.
grep -q '^logs/$' "$GITIGNORE" 2>/dev/null && ok ".gitignore contains logs/" || bad ".gitignore logs/"
if bash "$DIR_HERE/tests/pretool-guard.test.sh" >/dev/null 2>&1; then
  ok "pretool-guard.test.sh regression exits 0"
else
  bad "pretool-guard.test.sh regression"
fi
if bash -n "$LOG_EVENT" 2>/dev/null && bash -n "$LIB" 2>/dev/null && bash -n "$GUARD" 2>/dev/null; then
  ok "bash -n clean (log-event, lib-protected, guard)"
else
  bad "bash -n (log-event / lib-protected / guard)"
fi

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
