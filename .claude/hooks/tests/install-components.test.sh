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

# (6) default (no env, no tty): full install, audit runs and passes.
T3=$(mktemp -d)
out=$( cd "$T3" && HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" </dev/null 2>&1 )
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

# (8) interactive numbered pick "1 5": md+orchestrator only.
T5=$(mktemp -d)
printf '1 5\n' \
  | ( cd "$T5" && HARNESS_SETUP_STDIN=1 HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" ) >/dev/null 2>&1
code=$?
if [ "$code" -eq 0 ] && [ -d "$T5/.claude/agents" ] && [ -f "$T5/CLAUDE.md" ] \
   && [ ! -d "$T5/.claude/hooks" ] && [ ! -d "$T5/.claude/skills" ]; then
  ok "interactive '1 5' -> md+orchestrator only"
else
  no "interactive pick (exit $code)"
fi

# (9) hooks-unselected warning shown in interactive mode.
out=$(printf '1\n' | ( cd "$(mktemp -d)" && HARNESS_SETUP_STDIN=1 HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" ) 2>&1)
printf '%s' "$out" | grep -q "NOTE: 훅 미선택" \
  && ok "interactive: hooks-unselected NOTE shown" || no "hooks NOTE"

# (10) interactive invalid input "9": warned + falls back to full install.
T6=$(mktemp -d)
out=$(printf '9\n' | ( cd "$T6" && HARNESS_SETUP_STDIN=1 HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" ) 2>&1)
code=$?
if [ "$code" -eq 0 ] \
   && printf '%s' "$out" | grep -q "WARN: 무시된 입력: 9" \
   && printf '%s' "$out" | grep -q "유효 선택 없음 → 전체 설치" \
   && [ -d "$T6/.claude/hooks" ]; then
  ok "interactive invalid -> WARN + full fallback"
else
  no "invalid input fallback (exit $code)"
fi
rm -rf "$T6"

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

rm -rf "$T1" "$T2" "$T3" "$T5"
printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
