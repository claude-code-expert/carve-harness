#!/usr/bin/env bash
# /harness-audit — mechanical PASS/FAIL of the harness gates (Phases 1–4).
# Read-only report: audits the harness rooted at AUDIT_ROOT, writes nothing,
# and exits NON-ZERO on any failed check (0 only when fully configured).
# Root resolves from CLAUDE_PROJECT_DIR (like log-event.sh) so tests can retarget
# it at a temp copy of .claude/ without touching the live config.
#   AUDIT-01: jq present · all hook events registered · hooks +x · bash -n clean
#   AUDIT-02: write-tool matcher coverage · Bash-write inspection present
#   AUDIT-03: safety-critical policy→gate mapping · [내용없음] handoff rejected

AUDIT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
S="$AUDIT_ROOT/.claude/settings.json"
HOOKS_DIR="$AUDIT_ROOT/.claude/hooks"

fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

# ── AUDIT-01 ────────────────────────────────────────────────────────────────
# jq present (checked first; every settings assertion below needs it).
if ! command -v jq >/dev/null 2>&1; then
  no "jq present (AUDIT-01)"
  printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
  exit 1
fi
ok "jq present (AUDIT-01)"

# settings.json parses.
if jq empty "$S" >/dev/null 2>&1; then
  ok "settings.json parses"
else
  no "settings.json parse (AUDIT-01)"
  printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
  exit 1
fi

# All 6 hook events registered.
for evt in PreToolUse PostToolUse Stop SessionStart PreCompact SessionEnd; do
  if jq -e --arg e "$evt" '.hooks[$e]' "$S" >/dev/null 2>&1; then
    ok "event $evt registered (AUDIT-01)"
  else
    no "event $evt UNREGISTERED (AUDIT-01)"
  fi
done

# Every hook script referenced by settings exists and is executable.
while read -r sh; do
  [ -n "$sh" ] || continue
  f="$HOOKS_DIR/$sh"
  if [ -f "$f" ] && [ -x "$f" ]; then
    ok "$sh exists +x (AUDIT-01)"
  else
    no "$sh missing or not +x (AUDIT-01)"
  fi
done < <(jq -r '.hooks | to_entries[] | .value[].hooks[].command // empty' "$S" \
           | grep -oE '[A-Za-z0-9._-]+\.sh' | sort -u)

# bash -n clean on every hook script.
for f in "$HOOKS_DIR"/*.sh; do
  [ -e "$f" ] || continue
  if bash -n "$f" 2>/dev/null; then
    ok "bash -n $(basename "$f") (AUDIT-01)"
  else
    no "bash -n $(basename "$f") FAILED (AUDIT-01)"
  fi
done

# ── AUDIT-02 ────────────────────────────────────────────────────────────────
# Write-tool matcher covers all write tools + Bash.
m=$(jq -r '.hooks.PreToolUse[0].matcher // empty' "$S")
if [ "$m" = "Write|Edit|MultiEdit|NotebookEdit|Bash" ]; then
  ok "PreToolUse matcher covers write tools + Bash (AUDIT-02)"
else
  no "PreToolUse matcher missing a write tool (AUDIT-02): '$m'"
fi

# Bash-write inspection present in the guard.
PG="$HOOKS_DIR/pretool-guard.sh"
if grep -q 'tool_input.command' "$PG" 2>/dev/null && grep -q 'PROTECTED_RE' "$PG" 2>/dev/null; then
  ok "Bash-write inspection present in pretool-guard.sh (AUDIT-02)"
else
  no "Bash-write inspection missing in pretool-guard.sh (AUDIT-02)"
fi

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
