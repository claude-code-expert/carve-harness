#!/usr/bin/env bash
# Assertions for install.sh component selection (offline via HARNESS_SRC_DIR).
# Network never touched. Each case uses a temp target project.
# Covers: env/interactive selection, defaults, re-run union, update filter, uninstall.

REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

# (1) env single component: md only — core lands, other groups absent, exit 0.
T1=$(mktemp -d)
out=$( cd "$T1" && HARNESS_COMPONENTS=md HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" 2>&1 )
code=$?
if [ "$code" -eq 0 ] \
   && [ -f "$T1/CLAUDE.md" ] && [ -d "$T1/.claude/rules" ] && [ -d "$T1/vendor" ] \
   && [ ! -d "$T1/.claude/hooks" ] && [ ! -d "$T1/.claude/skills" ] \
   && [ ! -d "$T1/.claude/commands" ] && [ ! -d "$T1/.claude/agents" ]; then
  ok "env md-only: md+core installed, other groups absent (exit 0)"
else
  no "env md-only (exit $code)"
fi

# (2) audit is skipped without hooks group — no exit-1 crash.
printf '%s' "$out" | grep -q "audit 생략" \
  && ok "no-hooks install skips audit gracefully" || no "audit skip message"

# (3) selection recorded + gitignore covers the record file.
if grep -qx 'md' "$T1/.claude/harness-components" 2>/dev/null \
   && [ "$(wc -l < "$T1/.claude/harness-components" | tr -d ' ')" = "1" ] \
   && grep -q '.claude/harness-components' "$T1/.gitignore"; then
  ok "components record written + gitignored"
else
  no "components record"
fi

# (4) env comma list: md,orchestrator — agents/workflows/guides land, hooks still absent.
T2=$(mktemp -d)
( cd "$T2" && HARNESS_COMPONENTS=md,orchestrator HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" ) >/dev/null 2>&1
code=$?
if [ "$code" -eq 0 ] \
   && [ -d "$T2/.claude/agents" ] && [ -d "$T2/.claude/workflows" ] \
   && [ -f "$T2/docs/md/orchestration.md" ] && [ -f "$T2/docs/md/fable-team-guide.md" ] \
   && [ ! -d "$T2/.claude/hooks" ]; then
  ok "env md,orchestrator: orchestrator paths land, hooks absent"
else
  no "env comma list (exit $code)"
fi

# (5) manifest scope matches selection exactly (no unselected paths recorded).
if grep -qx '.claude/agents' "$T2/.claude/harness-manifest.txt" \
   && ! grep -qx '.claude/skills' "$T2/.claude/harness-manifest.txt" \
   && ! grep -qx '.claude/hooks' "$T2/.claude/harness-manifest.txt"; then
  ok "manifest limited to selected components"
else
  no "manifest scope"
fi

# (6) default choice (1 = auto/full) via stdin injection: full install, audit passes.
#     HARNESS_SETUP_STDIN=1 reads the prompt from stdin (never /dev/tty), so this can't
#     hang from an interactive terminal; '1' is the recommended/default setup mode.
T3=$(mktemp -d)
out=$( cd "$T3" && printf '1\n' | HARNESS_SETUP_STDIN=1 HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" 2>&1 )
code=$?
if [ "$code" -eq 0 ] \
   && printf '%s' "$out" | grep -q "구성 선택: 전체" \
   && [ -d "$T3/.claude/hooks" ] && [ -d "$T3/.claude/skills" ] \
   && [ -d "$T3/.claude/commands" ] && [ -d "$T3/.claude/agents" ] \
   && printf '%s' "$out" | grep -q "passed, 0 failed"; then
  ok "default -> full install + audit pass (exit 0)"
else
  no "default full install (exit $code)"
fi

# (7) HARNESS_COMPONENTS=all equals full selection record (5 groups).
T4=$(mktemp -d)
( cd "$T4" && HARNESS_COMPONENTS=all HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" ) >/dev/null 2>&1
[ "$(wc -l < "$T4/.claude/harness-components" | tr -d ' ')" = "5" ] \
  && ok "env all -> 5 components recorded" || no "env all"
rm -rf "$T4"

# (8) checkbox TUI: jump+space toggles hooks/skills/commands OFF -> md+orchestrator only.
#     '2\n' answers the setup-mode prompt (2=manual). Then menu keys:
#     '2'=jump hooks, SP=section off, '3' skills off, '4' commands off, EOF=confirm.
T5=$(mktemp -d)
printf '2\n2 3 4 ' \
  | ( cd "$T5" && HARNESS_SETUP_STDIN=1 HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" ) >/dev/null 2>&1
code=$?
if [ "$code" -eq 0 ] && [ -d "$T5/.claude/agents" ] && [ -f "$T5/CLAUDE.md" ] \
   && [ ! -d "$T5/.claude/hooks" ] && [ ! -d "$T5/.claude/skills" ] \
   && [ ! -d "$T5/.claude/commands" ]; then
  ok "TUI section toggles off -> md+orchestrator only"
else
  no "TUI section toggle (exit $code)"
fi

# (9) hooks-unselected NOTE shown when hooks section toggled off. '2\n'=manual mode.
out=$(printf '2\n2 ' | ( cd "$(mktemp -d)" && HARNESS_SETUP_STDIN=1 HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" ) 2>&1)
printf '%s' "$out" | grep -q "NOTE: 훅 미선택" \
  && ok "TUI: hooks-unselected NOTE shown" || no "hooks NOTE"

# (10) unknown key ignored; enter installs the default (all selected). '2\n'=manual mode.
T6=$(mktemp -d)
out=$(printf '2\n9\n' | ( cd "$T6" && HARNESS_SETUP_STDIN=1 HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" ) 2>&1)
code=$?
if [ "$code" -eq 0 ] \
   && printf '%s' "$out" | grep -q "구성 선택: 전체" \
   && [ -d "$T6/.claude/hooks" ] && [ -d "$T6/.claude/skills" ]; then
  ok "TUI unknown key ignored -> enter installs all"
else
  no "unknown key / default all (exit $code)"
fi
rm -rf "$T6"

# (10b) fine-grained pick: all off ('a'), jump skills ('3'), down ('j'), space = first skill only.
#       '2\n'=manual mode prompt first.
T7=$(mktemp -d)
FIRST_SKILL=$(ls "$REPO/.claude/skills" | sort | head -1)
out=$(printf '2\na3j \n' | ( cd "$T7" && HARNESS_SETUP_STDIN=1 HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" ) 2>&1)
code=$?
if [ "$code" -eq 0 ] \
   && [ -e "$T7/.claude/skills/$FIRST_SKILL" ] \
   && [ "$(ls "$T7/.claude/skills" | wc -l | tr -d ' ')" = "1" ] \
   && [ ! -f "$T7/CLAUDE.md" ] && [ ! -d "$T7/.claude/hooks" ] \
   && grep -qx ".claude/skills/$FIRST_SKILL" "$T7/.claude/harness-manifest.txt" \
   && grep -qx 'skills' "$T7/.claude/harness-components" \
   && [ "$(wc -l < "$T7/.claude/harness-components" | tr -d ' ')" = "1" ]; then
  ok "TUI fine-grained: single skill installed, fine manifest + skills component"
else
  no "fine-grained pick (exit $code)"
fi

# (10c) update patches fine-grained manifest entries.
SRC3=$(mktemp -d)
( cd "$REPO" && tar -c --exclude=.git --exclude=logs --exclude=.planning . ) | tar -x -C "$SRC3"
echo "9.9.8" > "$SRC3/VERSION"
echo "# FINE-MARKER" >> "$SRC3/.claude/skills/$FIRST_SKILL/SKILL.md"
( cd "$T7" && HARNESS_SRC_DIR="$SRC3" bash install.sh update ) >/dev/null 2>&1
code=$?
if [ "$code" -eq 0 ] \
   && grep -q "FINE-MARKER" "$T7/.claude/skills/$FIRST_SKILL/SKILL.md" \
   && [ "$(ls "$T7/.claude/skills" | wc -l | tr -d ' ')" = "1" ]; then
  ok "update: fine manifest entry patched, deselected skills stay absent"
else
  no "fine update (exit $code)"
fi
rm -rf "$SRC3" "$T7"

# (11) re-run adds a component: union recorded, manifest extended, no truncate loss, no dups.
( cd "$T1" && HARNESS_COMPONENTS=skills HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" ) >/dev/null 2>&1
code=$?
if [ "$code" -eq 0 ] && [ -d "$T1/.claude/skills" ] \
   && [ "$(tr '\n' ' ' < "$T1/.claude/harness-components")" = "md skills " ] \
   && grep -qx 'CLAUDE.md' "$T1/.claude/harness-manifest.txt" \
   && grep -qx '.claude/skills' "$T1/.claude/harness-manifest.txt" \
   && [ -z "$(sort "$T1/.claude/harness-manifest.txt" | uniq -d)" ]; then
  ok "re-run +skills: union record, manifest kept+extended, no dups"
else
  no "re-run union (exit $code)"
fi

# (12) update: NEW paths of unselected components are filtered, selected ones patch.
SRC2=$(mktemp -d)
( cd "$REPO" && tar -c --exclude=.git --exclude=logs --exclude=.planning . ) | tar -x -C "$SRC2"
echo "9.9.9" > "$SRC2/VERSION"
echo "# UPDATE-MARKER" >> "$SRC2/.claude/rules/common/git-workflow.md"
out=$( cd "$T2" && HARNESS_SRC_DIR="$SRC2" bash install.sh update 2>&1 )
code=$?
if [ "$code" -eq 0 ] \
   && grep -q "UPDATE-MARKER" "$T2/.claude/rules/common/git-workflow.md" \
   && [ ! -d "$T2/.claude/skills" ] && [ ! -d "$T2/.claude/hooks" ] \
   && printf '%s' "$out" | grep -q "SKIP: .claude/skills (skills 구성 미선택" \
   && [ "$(cat "$T2/.claude/harness-version")" = "9.9.9" ]; then
  ok "update: selected md patched, unselected groups filtered (exit 0)"
else
  no "update component filter (exit $code)"
fi
rm -rf "$SRC2"

# (13) uninstall --yes on partial install: manifest scope + components record removed.
echo "USER FILE" > "$T1/keep-me.txt"
( cd "$T1" && bash uninstall.sh --yes ) >/dev/null 2>&1
if [ ! -f "$T1/CLAUDE.md" ] && [ ! -e "$T1/.claude/harness-components" ] \
   && [ ! -e "$T1/.claude/harness-manifest.txt" ] \
   && grep -q "USER FILE" "$T1/keep-me.txt"; then
  ok "uninstall --yes: partial scope + components record removed, user file kept"
else
  no "uninstall partial"
fi

# (14) reinstall over a pre-existing/partial .claude/hooks restores current hooks
#      instead of a whole-dir SKIP. Regression for the fail-closed-every-commit bug:
#      a foreign or emptied hook dir made install SKIP lib-protected.sh, so the
#      pre-commit gate sourced a missing file and blocked every commit.
T8=$(mktemp -d)
( cd "$T8" && HARNESS_COMPONENTS=all HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" ) >/dev/null 2>&1
rm -f "$T8/.claude/hooks/lib-protected.sh"                        # simulate desync
printf '#stale\n' > "$T8/.claude/hooks/carve-protect-secrets.sh" # foreign leftover keeps dir present
( cd "$T8" && HARNESS_COMPONENTS=all HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" ) >/dev/null 2>&1
if [ -f "$T8/.claude/hooks/lib-protected.sh" ] && [ -f "$T8/.claude/hooks/pretool-guard.sh" ]; then
  ok "reinstall self-heals missing lib-protected.sh in existing hook dir"
else
  no "reinstall self-heal over existing hook dir (coarse-SKIP regression)"
fi

rm -rf "$T1" "$T2" "$T3" "$T5" "$T8"
printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
