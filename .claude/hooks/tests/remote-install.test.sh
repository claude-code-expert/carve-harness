#!/usr/bin/env bash
# Assertions for install.sh fetch-mode + uninstall.sh (offline via HARNESS_SRC_DIR).
# Network never touched. Each case uses a temp target project.

REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

T=$(mktemp -d)
git -C "$T" init -q

# (1) fetch-mode install from local source: exit 0, core files land, manifest written.
( cd "$T" && HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" ) >/dev/null 2>&1
code=$?
if [ "$code" -eq 0 ] && [ -f "$T/.claude/hooks/pretool-guard.sh" ] \
   && [ -f "$T/AGENTS.md" ] && [ -x "$T/.githooks/pre-commit" ] \
   && [ -f "$T/.claude/harness-manifest.txt" ]; then
  ok "fetch-mode install (exit 0, files + manifest)"
else
  no "fetch-mode install (exit $code)"
fi

# (2) post-install wiring: hooksPath set, .gitignore harness block, vendored bin staged.
if [ "$(git -C "$T" config core.hooksPath)" = ".githooks" ] \
   && grep -q '>>> harness' "$T/.gitignore" \
   && [ -x "$T/.claude/bin/jq" ]; then
  ok "wiring: hooksPath + gitignore block + .claude/bin/jq"
else
  no "wiring"
fi

# (3) existing file preserved (no clobber) and excluded from manifest.
T2=$(mktemp -d); git -C "$T2" init -q
echo "MY OWN RULES" > "$T2/CLAUDE.md"
( cd "$T2" && HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" ) >/dev/null 2>&1
if grep -q "MY OWN RULES" "$T2/CLAUDE.md" && ! grep -qx 'CLAUDE.md' "$T2/.claude/harness-manifest.txt"; then
  ok "existing CLAUDE.md preserved + not in manifest"
else
  no "no-clobber"
fi

# (3a) update, same version: no-op, exit 0, "이미 최신".
out=$( cd "$T" && HARNESS_SRC_DIR="$REPO" bash install.sh update 2>&1 )
code=$?
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q "이미 최신"; then
  ok "update same version -> no-op (exit 0)"
else
  no "update same version (exit $code)"
fi

# (3b) update, newer version: manifest files patched + backup + version stamp.
SRC2=$(mktemp -d)
( cd "$REPO" && tar -c --exclude=.git --exclude=logs --exclude=.planning . ) | tar -x -C "$SRC2"
echo "9.9.9" > "$SRC2/VERSION"
echo "# UPDATE-MARKER" >> "$SRC2/AGENTS.md"
echo "# UPDATE-MARKER" >> "$SRC2/.claude/rules/common/git-workflow.md"
OLDV=$(cat "$T/.claude/harness-version")
( cd "$T" && HARNESS_SRC_DIR="$SRC2" bash install.sh update ) >/dev/null 2>&1
code=$?
if [ "$code" -eq 0 ] \
   && grep -q "UPDATE-MARKER" "$T/AGENTS.md" \
   && grep -q "UPDATE-MARKER" "$T/.claude/rules/common/git-workflow.md" \
   && [ -e "$T/logs/harness-backup/v$OLDV/AGENTS.md" ] \
   && [ "$(cat "$T/.claude/harness-version")" = "9.9.9" ]; then
  ok "update patches manifest files + backup + stamp 9.9.9"
else
  no "update patch (exit $code)"
fi

# (3c) update never touches user files: skipped CLAUDE.md + user-added file in managed dir.
echo "# my custom rule" > "$T2/.claude/rules/my-custom.md"
( cd "$T2" && HARNESS_SRC_DIR="$SRC2" bash install.sh update ) >/dev/null 2>&1
if grep -q "MY OWN RULES" "$T2/CLAUDE.md" \
   && [ -f "$T2/.claude/rules/my-custom.md" ] \
   && ! grep -q "UPDATE-MARKER" "$T2/CLAUDE.md"; then
  ok "update preserves user CLAUDE.md + user-added rule file"
else
  no "update user-file preservation"
fi
rm -rf "$SRC2"

# (3d) rollback: previous version restored, marker gone, stamp reverted, backup consumed.
( cd "$T" && bash install.sh rollback ) >/dev/null 2>&1
code=$?
if [ "$code" -eq 0 ] \
   && ! grep -q "UPDATE-MARKER" "$T/AGENTS.md" \
   && [ "$(cat "$T/.claude/harness-version")" = "$OLDV" ] \
   && [ ! -d "$T/logs/harness-backup/v$OLDV" ]; then
  ok "rollback restores v$OLDV + consumes backup"
else
  no "rollback (exit $code)"
fi

# (3e) rollback with no backup left: clean FAIL, nothing changed.
( cd "$T" && bash install.sh rollback ) >/dev/null 2>&1
code=$?
if [ "$code" -ne 0 ] && [ "$(cat "$T/.claude/harness-version")" = "$OLDV" ]; then
  ok "rollback without backup fails cleanly (exit $code)"
else
  no "rollback-empty (exit $code)"
fi

# (3f) setup wizard: LICENSE(MIT) + protected-extra + domain rule via injected answers.
# Answer order in T (git repo + jq on PATH → q1/q2 skipped):
#   LICENSE=1(MIT), extra regex, domain rule, empty(end rules), n(GSD if npx exists)
printf '1\nvault-keys/\n주문 금액 음수 불가\n\nn\n' \
  | ( cd "$T" && HARNESS_SETUP_STDIN=1 bash install.sh setup ) >/dev/null 2>&1
code=$?
if [ "$code" -eq 0 ] \
   && grep -q "MIT License" "$T/LICENSE" 2>/dev/null \
   && grep -qx 'vault-keys/' "$T/.claude/hooks/protected-extra.regex" \
   && grep -q "주문 금액 음수 불가" "$T/CLAUDE.md"; then
  ok "setup: LICENSE(MIT) + protected-extra + domain rule (exit 0)"
else
  no "setup wizard (exit $code)"
fi

# (3g) guard honors protected-extra.regex immediately (no base-pattern overlap).
printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"vault-keys/id.txt","content":"x"}}' \
  | bash "$T/.claude/hooks/pretool-guard.sh" >/dev/null 2>&1
code=$?
[ "$code" -eq 2 ] && ok "guard blocks extra-regex path (exit 2)" || no "extra-regex guard (exit $code)"

# (3h) setup with no input: all questions skipped, exit 0, nothing created.
( cd "$T2" && HARNESS_SETUP_STDIN=1 bash install.sh setup ) </dev/null >/dev/null 2>&1
code=$?
if [ "$code" -eq 0 ] && [ ! -e "$T2/LICENSE" ] && [ ! -e "$T2/.claude/hooks/protected-extra.regex" ]; then
  ok "setup empty-input -> all skip, no side effects (exit 0)"
else
  no "setup non-interactive safety (exit $code)"
fi

# (4) uninstall dry-run removes nothing.
( cd "$T2" && bash uninstall.sh ) >/dev/null 2>&1
[ -f "$T2/AGENTS.md" ] && [ -f "$T2/.claude/settings.json" ] \
  && ok "uninstall dry-run removes nothing" || no "dry-run"

# (5) uninstall --yes: manifest files gone, preserved file kept, wiring reverted.
( cd "$T2" && bash uninstall.sh --yes ) >/dev/null 2>&1
if [ ! -f "$T2/AGENTS.md" ] && [ ! -d "$T2/.claude" ] \
   && grep -q "MY OWN RULES" "$T2/CLAUDE.md" \
   && [ -z "$(git -C "$T2" config core.hooksPath 2>/dev/null)" ] \
   && ! grep -q '>>> harness' "$T2/.gitignore" 2>/dev/null; then
  ok "uninstall --yes removes manifest scope only, reverts wiring"
else
  no "uninstall --yes"
fi

rm -rf "$T" "$T2"
printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
