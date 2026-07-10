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
# Includes the cross-agent entry files + .githooks so AUDIT-04 passes on the copy
# (no .git / no vendor in the copy -> hooksPath & vendor checks self-skip).
mkroot() {
  local r; r=$(mktemp -d)
  cp -r "$REPO/.claude" "$r/.claude"; mkdir -p "$r/specs"
  cp "$REPO/AGENTS.md" "$REPO/.cursorrules" "$REPO/codex.md" "$r/" 2>/dev/null
  cp -r "$REPO/.githooks" "$r/.githooks" 2>/dev/null
  printf '%s' "$r"
}

# (1) positive baseline: live harness -> exit 0.
CLAUDE_PROJECT_DIR="$REPO" bash "$AUDIT" >/dev/null 2>&1
[ $? -eq 0 ] && ok "live harness passes audit (exit 0, SC4)" || no "live baseline exit 0"

# Snapshot the live files the negatives mutate-in-copy — hash compare proves isolation
# regardless of git state (a legit uncommitted edit must not read as "test mutated it").
_livesnap() { cat "$REPO/.claude/settings.json" "$REPO/.claude/hooks/pretool-guard.sh" 2>/dev/null | cksum; }
PRE_SNAP=$(_livesnap)

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

# (6) AUDIT-03: removed safety deny entry -> non-zero (orphan policy, SC3).
r=$(mkroot)
jq '.permissions.deny |= map(select(. != "Bash(rm -rf*)"))' "$r/.claude/settings.json" > "$r/s" \
  && mv "$r/s" "$r/.claude/settings.json"
CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" >/dev/null 2>&1
[ $? -ne 0 ] && ok "removed deny entry -> non-zero (AUDIT-03/SC3)" || no "removed deny entry non-zero"
rm -rf "$r"

# (7) AUDIT-03: stripped PROTECTED_RE from the guard -> non-zero (orphan policy, SC3).
r=$(mkroot)
grep -v 'PROTECTED_RE' "$r/.claude/hooks/pretool-guard.sh" > "$r/pg" \
  && mv "$r/pg" "$r/.claude/hooks/pretool-guard.sh"
CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" >/dev/null 2>&1
[ $? -ne 0 ] && ok "stripped PROTECTED_RE -> non-zero (AUDIT-03/SC3)" || no "stripped PROTECTED_RE non-zero"
rm -rf "$r"

# (8) AUDIT-03: sentinel handoff -> non-zero (SC3).
r=$(mkroot)
printf -- '- TODO: [내용없음]\n' > "$r/specs/HANDOFF.md"
CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" >/dev/null 2>&1
[ $? -ne 0 ] && ok "sentinel handoff -> non-zero (AUDIT-03/SC3)" || no "sentinel handoff non-zero"
rm -rf "$r"

# (9) AUDIT-03: absent HANDOFF.md is NOT a failure -> exit 0 (D-11).
r=$(mkroot)   # mkroot makes an empty specs/ with no HANDOFF.md
CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" >/dev/null 2>&1
[ $? -eq 0 ] && ok "absent HANDOFF.md -> exit 0 (D-11)" || no "absent HANDOFF exit 0"
rm -rf "$r"

# (11) AUDIT-04: entry file loses its AGENTS.md pointer -> non-zero.
r=$(mkroot); echo "no pointer here" > "$r/.cursorrules"
CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" >/dev/null 2>&1
[ $? -ne 0 ] && ok "cursorrules w/o AGENTS.md pointer -> non-zero (AUDIT-04)" || no "entry pointer non-zero"
rm -rf "$r"

# (12) AUDIT-05: empty rule file -> non-zero.
r=$(mkroot); : > "$r/.claude/rules/empty-rule.md"
CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" >/dev/null 2>&1
[ $? -ne 0 ] && ok "empty rule file -> non-zero (AUDIT-05)" || no "empty rule non-zero"
rm -rf "$r"

# (13) AUDIT-05: byte-identical ' copy' duplicate -> non-zero.
r=$(mkroot); cp "$r/.claude/rules/safety.md" "$r/.claude/rules/safety copy.md"
CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" >/dev/null 2>&1
[ $? -ne 0 ] && ok "' copy' duplicate rule -> non-zero (AUDIT-05)" || no "copy dup non-zero"
rm -rf "$r"

# (14) AUDIT-06: skill without frontmatter -> non-zero.
r=$(mkroot); mkdir -p "$r/.claude/skills/broken-skill"; echo "# no frontmatter" > "$r/.claude/skills/broken-skill/SKILL.md"
CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" >/dev/null 2>&1
[ $? -ne 0 ] && ok "skill w/o frontmatter -> non-zero (AUDIT-06)" || no "skill frontmatter non-zero"
rm -rf "$r"

# (10) isolation: live files unchanged after all mutations (hash compare — commit-independent).
if [ "$(_livesnap)" = "$PRE_SNAP" ]; then
  ok "live config unchanged by test (isolation)"
else
  no "live config mutated by test"
fi

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
