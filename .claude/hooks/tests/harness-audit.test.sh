#!/usr/bin/env bash
# Tests for harness-audit.sh.
# AUDIT-01/02: the live harness passes (exit 0, SC4), and each broken condition
# makes the audit exit non-zero (SC1/SC2). Every negative mutates a `cp -r` copy
# of .claude/ under a mktemp root — the live config is never touched (D-03).

REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
AUDIT="$REPO/.claude/hooks/harness-audit.sh"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

# Fresh temp copy of the harness (+ empty specs/); echoes the root path.
mkroot() { local r; r=$(mktemp -d); cp -r "$REPO/.claude" "$r/.claude"; mkdir -p "$r/specs"; printf '%s' "$r"; }

# (1) positive baseline: live harness -> exit 0.
CLAUDE_PROJECT_DIR="$REPO" bash "$AUDIT" >/dev/null 2>&1
[ $? -eq 0 ] && ok "live harness passes audit (exit 0, SC4)" || no "live baseline exit 0"

# (2) jq absent -> non-zero (PATH holds bash but not jq).
r=$(mkroot); nob=$(mktemp -d); ln -s "$(command -v bash)" "$nob/bash"
( PATH="$nob" CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" ) >/dev/null 2>&1
[ $? -ne 0 ] && ok "jq absent -> non-zero (AUDIT-01/SC1)" || no "jq absent non-zero"
rm -rf "$r" "$nob"

# (3) unregistered hook event -> non-zero.
r=$(mkroot); jq 'del(.hooks.Stop)' "$r/.claude/settings.json" > "$r/s" && mv "$r/s" "$r/.claude/settings.json"
CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" >/dev/null 2>&1
[ $? -ne 0 ] && ok "unregistered Stop -> non-zero (AUDIT-01/SC1)" || no "unregistered hook non-zero"
rm -rf "$r"

# (4) hook stripped of +x -> non-zero.
r=$(mkroot); chmod -x "$r/.claude/hooks/stop-verify.sh"
CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" >/dev/null 2>&1
[ $? -ne 0 ] && ok "stripped +x -> non-zero (AUDIT-01/SC1)" || no "stripped +x non-zero"
rm -rf "$r"

# (5) matcher drops NotebookEdit -> non-zero.
r=$(mkroot)
jq '.hooks.PreToolUse[0].matcher="Write|Edit|MultiEdit|Bash"' "$r/.claude/settings.json" > "$r/s" && mv "$r/s" "$r/.claude/settings.json"
CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" >/dev/null 2>&1
[ $? -ne 0 ] && ok "matcher drops NotebookEdit -> non-zero (AUDIT-02/SC2)" || no "matcher drop non-zero"
rm -rf "$r"

# (6) isolation: live settings.json unchanged after all mutations.
if git -C "$REPO" diff --quiet .claude/settings.json 2>/dev/null; then
  ok "live settings.json unchanged (isolation)"
else
  no "live settings.json mutated by test"
fi

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
