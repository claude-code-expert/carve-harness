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
