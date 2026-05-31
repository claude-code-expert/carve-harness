#!/bin/bash
# test-files.sh — Validate agent/command file integrity
# Usage: bash tests/test-files.sh [--quiet]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
QUIET=0
for arg in "$@"; do
  [ "$arg" = "--quiet" ] && QUIET=1
done

pass() {
  ((PASS++)) || true
  [ "$QUIET" != "1" ] && printf "  \033[32m✓\033[0m %s\n" "$1"
}

fail() {
  ((FAIL++)) || true
  printf "  \033[31m✗\033[0m %s\n" "$1"
}

echo "Squad File Integrity Tests"
echo "=========================="

# ─── 1. Extract routed agents from squad-router.sh ──────
echo ""
echo "1. Router-to-file consistency"

ROUTED_AGENTS=$(grep -o 'AGENT="squad-[a-z]*"' "$REPO_ROOT/hooks/squad-router.sh" | \
  sed 's/AGENT="//;s/"//' | sort -u)

for agent in $ROUTED_AGENTS; do
  # Check agent definition exists
  if [ -f "$REPO_ROOT/agents/${agent}.md" ]; then
    pass "$agent → agents/${agent}.md exists"
  else
    fail "$agent → agents/${agent}.md MISSING"
  fi

  # Check command definition exists
  if [ -f "$REPO_ROOT/commands/${agent}.md" ]; then
    pass "$agent → commands/${agent}.md exists"
  else
    fail "$agent → commands/${agent}.md MISSING"
  fi
done

# ─── 2. Agent frontmatter validation ───────────────────
echo ""
echo "2. Agent frontmatter"

for f in "$REPO_ROOT"/agents/squad-*.md; do
  [ -f "$f" ] || continue
  local_name=$(basename "$f" .md)

  # Check starts with ---
  if head -1 "$f" | grep -q '^---$'; then
    pass "$local_name: frontmatter open"
  else
    fail "$local_name: missing opening ---"
    continue
  fi

  # Check has closing ---
  if sed -n '2,$p' "$f" | grep -q '^---$'; then
    pass "$local_name: frontmatter close"
  else
    fail "$local_name: missing closing ---"
    continue
  fi

  # Check name field matches filename
  fm_name=$(awk '/^---$/{n++; next} n==1 && /^name:/{sub(/^name:[[:space:]]*/, ""); print; exit}' "$f")
  if [ "$fm_name" = "$local_name" ]; then
    pass "$local_name: name field matches"
  else
    fail "$local_name: name='$fm_name' expected='$local_name'"
  fi

  # Check has model field
  if sed -n '/^---$/,/^---$/p' "$f" | grep -q '^model:'; then
    pass "$local_name: has model field"
  else
    fail "$local_name: missing model field"
  fi

  # Check has tools field
  if sed -n '/^---$/,/^---$/p' "$f" | grep -q '^tools:'; then
    pass "$local_name: has tools field"
  else
    fail "$local_name: missing tools field"
  fi
done

# ─── 3. Command frontmatter validation ─────────────────
echo ""
echo "3. Command frontmatter"

for f in "$REPO_ROOT"/commands/squad*.md; do
  [ -f "$f" ] || continue
  local_name=$(basename "$f" .md)

  if head -1 "$f" | grep -q '^---$'; then
    pass "$local_name: frontmatter open"
  else
    fail "$local_name: missing opening ---"
  fi

  if sed -n '2,$p' "$f" | grep -q '^---$'; then
    pass "$local_name: frontmatter close"
  else
    fail "$local_name: missing closing ---"
  fi
done

# ─── 4. install.sh agent list consistency ───────────────
echo ""
echo "4. install.sh consistency"

INSTALL_AGENTS=$(grep -A1 'SQUAD_AGENTS=' "$REPO_ROOT/install.sh" | \
  grep -o 'squad-[a-z]*' | sort -u)

for agent in $INSTALL_AGENTS; do
  if [ -f "$REPO_ROOT/agents/${agent}.md" ]; then
    pass "install.sh: $agent has agent file"
  else
    fail "install.sh: $agent listed but agents/${agent}.md missing"
  fi
done

# ─── Summary ────────────────────────────────────────────
echo ""
if [ "$FAIL" -gt 0 ]; then
  printf "\033[31mFAILED: %d passed, %d failed, %d total\033[0m\n" "$PASS" "$FAIL" "$((PASS+FAIL))"
  exit 1
else
  printf "\033[32mPASSED: %d passed, 0 failed, %d total\033[0m\n" "$PASS" "$PASS"
  exit 0
fi
