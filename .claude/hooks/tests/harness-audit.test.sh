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

# (1b) AUDIT-04 hooksPath branches. The copy needs a .git for the check to run at
# all. An absolute path activates the gate exactly as well as the relative one —
# rejecting it reported a live, working config as "unset" and blocked a Stop gate.
r=$(mkroot); git -C "$r" init -q >/dev/null 2>&1
git -C "$r" config core.hooksPath ".githooks"
CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" >/dev/null 2>&1
[ $? -eq 0 ] && ok "hooksPath relative .githooks accepted (AUDIT-04)" || no "relative hooksPath rejected"
git -C "$r" config core.hooksPath "$r/.githooks"
CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" >/dev/null 2>&1
[ $? -eq 0 ] && ok "hooksPath absolute path accepted (AUDIT-04)" || no "absolute hooksPath rejected"
git -C "$r" config core.hooksPath "/tmp/not-our-hooks"
out=$(CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'points outside .githooks' \
  && ok "hooksPath pointing elsewhere -> non-zero, named as such (AUDIT-04)" || no "foreign hooksPath ($rc)"
git -C "$r" config --unset core.hooksPath
out=$(CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'core.hooksPath unset' \
  && ok "hooksPath unset -> non-zero, reported as unset (AUDIT-04)" || no "unset hooksPath ($rc)"
rm -rf "$r"

# (1c) AUDIT-03 PII masking: the audit's own masking check had no mutation test,
# so deleting it from the audit reported PASS while log masking silently died.
r=$(mkroot)
for h in log-event.sh lib-protected.sh; do
  [ -f "$r/.claude/hooks/$h" ] && { sed 's/<masked>/<plain>/g' "$r/.claude/hooks/$h" > "$r/x" \
    && mv "$r/x" "$r/.claude/hooks/$h"; }
done
out=$(CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'PII masking' \
  && ok "PII masking removed -> non-zero (AUDIT-03)" || no "PII masking mutation ($rc)"
rm -rf "$r"

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

# (15) AUDIT-09: an installed pack with a missing path -> non-zero; complete -> zero; LSP off -> non-zero.
#      The copy gets packs/ + a harness-packs record naming python, and python's paths.
mkpackroot() {
  local r; r=$(mkroot)
  cp -r "$REPO/packs" "$r/packs"
  mkdir -p "$r/docs/rules/code-convention" "$r/docs/evaluator" "$r/specs/goldenset/starters"
  cp "$REPO/docs/rules/code-convention/dev-stack-python.md" "$REPO/docs/rules/code-convention/dev-stack-fastapi.md" "$r/docs/rules/code-convention/"
  cp -r "$REPO/docs/evaluator/python-example" "$r/docs/evaluator/python-example"
  cp "$REPO/specs/goldenset/starters/python.json" "$r/specs/goldenset/starters/python.json"
  printf 'python\n' > "$r/.claude/harness-packs"
  jq '.enabledPlugins["pyright@claude-code-lsps"] = true' "$r/.claude/settings.json" > "$r/s.tmp" && mv "$r/s.tmp" "$r/.claude/settings.json"
  printf '%s' "$r"
}
r=$(mkpackroot)
out=$(CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'pack python: every path present' \
  && ok "complete python pack -> audit passes (AUDIT-09)" || no "complete pack audit (rc $rc): $(printf '%s' "$out" | grep FAIL | head -2)"
printf '%s' "$out" | grep -q 'INFO: eval maturity LV' && ok "eval maturity readout printed (AUDIT-09)" || no "maturity readout missing"
rm -rf "$r/.claude/stacks/python.sh"
out=$(CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'pack python: missing paths' \
  && ok "pack path removed -> non-zero, names the path (AUDIT-09)" || no "missing pack path not caught ($rc)"
rm -rf "$r"
r=$(mkpackroot)
jq '.enabledPlugins["pyright@claude-code-lsps"] = false' "$r/.claude/settings.json" > "$r/s.tmp" && mv "$r/s.tmp" "$r/.claude/settings.json"
out=$(CLAUDE_PROJECT_DIR="$r" bash "$AUDIT" 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'LSP pyright@claude-code-lsps not enabled' \
  && ok "installed pack with LSP off -> non-zero (AUDIT-09)" || no "LSP mismatch not caught ($rc)"
rm -rf "$r"

# (10) isolation: live files unchanged after all mutations (hash compare — commit-independent).
if [ "$(_livesnap)" = "$PRE_SNAP" ]; then
  ok "live config unchanged by test (isolation)"
else
  no "live config mutated by test"
fi

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
