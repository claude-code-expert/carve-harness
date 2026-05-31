#!/bin/bash
# install.sh — Squad Agent installer (local + remote)
# Usage:
#   Local:  bash install.sh
#   Remote: curl -sL https://raw.githubusercontent.com/.../install.sh | bash
#   Remove: bash install.sh --uninstall
#   Version: bash install.sh --version
set -euo pipefail

REPO="claude-code-expert/subagents"
RELEASE_BASE="https://github.com/$REPO/releases"

# Read version from VERSION file if available (local install), else fallback
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/VERSION" ]; then
  VERSION=$(cat "$(dirname "${BASH_SOURCE[0]}")/VERSION")
else
  VERSION="1.3.1"
fi

AGENTS_DIR="$HOME/.claude/agents"
COMMANDS_DIR="$HOME/.claude/commands"
HOOKS_DIR="$HOME/.claude/hooks"

SQUAD_AGENTS=(
  squad-review squad-plan squad-refactor squad-qa
  squad-debug squad-docs squad-gitops squad-audit
)
SQUAD_COMMANDS=(
  squad squad-review squad-plan squad-refactor squad-qa
  squad-debug squad-docs squad-gitops squad-audit
)
SQUAD_HOOKS=(subagent-chain.sh squad-router.sh)

# Global temp dir for cleanup
_TMPDIR=""

# ─── Helpers ──────────────────────────────────────────

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

cleanup() { if [ -n "$_TMPDIR" ]; then rm -rf "$_TMPDIR"; fi; }
trap cleanup EXIT

banner() {
  echo ""
  bold "Squad Agent Installer v$VERSION"
  echo "================================"
  echo ""
}

# ─── Uninstall ────────────────────────────────────────

uninstall() {
  banner
  yellow "Uninstalling Squad Agent..."
  echo ""

  local removed=0

  echo "Agents:"
  for name in "${SQUAD_AGENTS[@]}"; do
    local f="$AGENTS_DIR/${name}.md"
    if [ -f "$f" ]; then
      rm -f "$f"
      green "  Removed $name.md"
      ((removed++)) || true
    fi
  done

  echo ""
  echo "Commands:"
  for name in "${SQUAD_COMMANDS[@]}"; do
    local f="$COMMANDS_DIR/${name}.md"
    if [ -f "$f" ]; then
      rm -f "$f"
      green "  Removed $name.md"
      ((removed++)) || true
    fi
  done

  echo ""
  echo "Hooks:"
  for name in "${SQUAD_HOOKS[@]}"; do
    local f="$HOOKS_DIR/$name"
    if [ -f "$f" ]; then
      rm -f "$f"
      green "  Removed $name"
      ((removed++)) || true
    fi
  done

  echo ""
  if [ "$removed" -gt 0 ]; then
    green "Uninstalled $removed file(s). Restart Claude Code."
    yellow "Note: .bak backup files were preserved."
  else
    yellow "No Squad Agent files found."
  fi
}

# ─── Detect source directory ─────────────────────────

find_source_dir() {
  local script_dir
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -d "$script_dir/agents" ] && [ -d "$script_dir/commands" ]; then
      echo "$script_dir"
      return 0
    fi
  fi
  return 1
}

# ─── Register SubagentStop hook ──────────────────────

register_hook() {
  local settings="$HOME/.claude/settings.json"
  local hook_cmd="zsh ~/.claude/hooks/subagent-chain.sh"
  local new_hook='[{"matcher":"","hooks":[{"type":"command","command":"'"$hook_cmd"'"}]}]'

  # If jq is not available, print manual instructions
  if ! command -v jq &>/dev/null; then
    yellow "Note: jq not found — cannot auto-register hooks."
    yellow "Add SubagentStart, SubagentStop, and UserPromptSubmit hooks manually to $settings"
    return 0
  fi

  # If settings.json doesn't exist, create minimal one
  if [ ! -f "$settings" ]; then
    echo '{}' > "$settings"
  fi

  local registered=0

  # Register SubagentStart hook
  if jq -e '.hooks.SubagentStart' "$settings" &>/dev/null; then
    green "  SubagentStart hook already registered."
  else
    local tmp
    tmp=$(mktemp)
    if jq --argjson hook "$new_hook" '.hooks.SubagentStart = $hook' "$settings" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$settings"
      green "  SubagentStart hook registered"
      ((registered++)) || true
    else
      rm -f "$tmp"
    fi
  fi

  # Register SubagentStop hook
  if jq -e '.hooks.SubagentStop' "$settings" &>/dev/null; then
    green "  SubagentStop hook already registered."
  else
    local tmp
    tmp=$(mktemp)
    if jq --argjson hook "$new_hook" '.hooks.SubagentStop = $hook' "$settings" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$settings"
      green "  SubagentStop hook registered"
      ((registered++)) || true
    else
      rm -f "$tmp"
    fi
  fi

  # Register UserPromptSubmit hook (squad-router)
  local router_cmd="bash ~/.claude/hooks/squad-router.sh"
  local router_hook='[{"matcher":"","hooks":[{"type":"command","command":"'"$router_cmd"'"}]}]'

  if jq -e '.hooks.UserPromptSubmit' "$settings" &>/dev/null; then
    green "  UserPromptSubmit hook already registered."
  else
    local tmp
    tmp=$(mktemp)
    if jq --argjson hook "$router_hook" '.hooks.UserPromptSubmit = $hook' "$settings" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$settings"
      green "  UserPromptSubmit hook registered (squad-router)"
      ((registered++)) || true
    else
      rm -f "$tmp"
    fi
  fi

  if [ "$registered" -eq 0 ]; then
    return 0
  fi
}

# ─── Install from source directory ───────────────────

do_install() {
  local src="$1"

  mkdir -p "$AGENTS_DIR" "$COMMANDS_DIR" "$HOOKS_DIR"

  echo "Agents (${#SQUAD_AGENTS[@]}):"
  for f in "$src"/agents/*.md; do
    [ -f "$f" ] || continue
    local n
    n=$(basename "$f")
    if [ -f "$AGENTS_DIR/$n" ]; then
      cp "$AGENTS_DIR/$n" "$AGENTS_DIR/${n}.bak"
      yellow "  Backed up $n"
    fi
    cp "$f" "$AGENTS_DIR/$n"
    green "  Installed $n"
  done

  echo ""
  echo "Commands (${#SQUAD_COMMANDS[@]}):"
  for f in "$src"/commands/*.md; do
    [ -f "$f" ] || continue
    local n
    n=$(basename "$f")
    if [ -f "$COMMANDS_DIR/$n" ]; then
      cp "$COMMANDS_DIR/$n" "$COMMANDS_DIR/${n}.bak"
    fi
    cp "$f" "$COMMANDS_DIR/$n"
    local cmd_name="${n%.md}"
    green "  Installed /$cmd_name"
  done

  echo ""
  echo "Hooks:"
  for f in "$src"/hooks/*.sh; do
    [ -f "$f" ] || continue
    local n
    n=$(basename "$f")
    if [ -f "$HOOKS_DIR/$n" ]; then
      cp "$HOOKS_DIR/$n" "$HOOKS_DIR/${n}.bak"
    fi
    cp "$f" "$HOOKS_DIR/$n"
    chmod +x "$HOOKS_DIR/$n"
    green "  Installed $n"
  done

  # Auto-register SubagentStop hook in settings.json
  register_hook

  cat << 'DONE'

================================

  Squad Agent installed!

  Next steps:
    1. Restart Claude Code
    2. Run /agents to verify
    3. Try /squad-review to start

================================

  Commands:
    /squad-review          Code review
    /squad-plan <feature>  Planning + wireframes
    /squad-refactor [scope] Refactoring
    /squad-qa              Testing + QA
    /squad-debug <error>   Debugging
    /squad-docs <type>     Documentation
    /squad-gitops <type>   Commit / PR
    /squad-audit           Security audit
    /squad <member>        Universal invoke

DONE
}

# ─── Register pre-commit hook (dev mode) ─────────────

register_precommit() {
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    yellow "Not in a git repository — skipping pre-commit hook."
    return 0
  }

  local hook_file="$repo_root/.git/hooks/pre-commit"

  if [ -f "$hook_file" ] && grep -q "test-router.sh" "$hook_file" 2>/dev/null; then
    green "  Pre-commit hook already registered."
    return 0
  fi

  mkdir -p "$repo_root/.git/hooks"
  cat > "$hook_file" << 'HOOK'
#!/bin/bash
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"
echo "Running squad-router tests..."
bash "$REPO_ROOT/tests/test-router.sh" --quiet || exit 1
bash "$REPO_ROOT/tests/test-files.sh" --quiet || exit 1
echo "All tests passed."
HOOK
  chmod +x "$hook_file"
  green "  Pre-commit hook installed at .git/hooks/pre-commit"
}

# ─── Main ─────────────────────────────────────────────

main() {
  case "${1:-}" in
    --uninstall|-u)
      uninstall
      ;;
    --version|-v)
      echo "Squad Agent v$VERSION"
      ;;
    --dev)
      banner
      echo "Developer mode: registering pre-commit hook..."
      register_precommit
      ;;
    --help|-h)
      echo "Usage: bash install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  (no args)      Install Squad Agent"
      echo "  --uninstall    Remove Squad Agent files"
      echo "  --dev          Register pre-commit test hook (contributors)"
      echo "  --version      Show version"
      echo "  --help         Show this help"
      ;;
    *)
      banner

      # Try local source first
      local src=""
      src=$(find_source_dir) || true

      if [ -n "$src" ]; then
        do_install "$src"
      else
        # Remote install: download latest release
        yellow "No local source found. Downloading latest release..."
        echo ""

        _TMPDIR=$(mktemp -d)

        local latest_tag
        latest_tag=$(curl -sI "$RELEASE_BASE/latest" 2>/dev/null | grep -i '^location:' | sed 's|.*/||' | tr -d '\r\n') || true

        if [ -z "$latest_tag" ]; then
          red "Error: Could not determine latest release."
          red "Please install manually: git clone https://github.com/$REPO.git && cd subagents && bash install.sh"
          exit 1
        fi

        # Validate tag format (vX.Y.Z)
        if [[ ! "$latest_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          red "Error: Invalid release tag format: $latest_tag"
          red "Expected format: vX.Y.Z (e.g., v1.1.0)"
          exit 1
        fi

        green "Latest version: $latest_tag"

        local archive_url="$RELEASE_BASE/download/$latest_tag/squad-agents-${latest_tag}.tar.gz"
        local checksum_url="$RELEASE_BASE/download/$latest_tag/squad-agents-${latest_tag}.tar.gz.sha256"
        echo "Downloading $archive_url ..."

        if ! curl -sL "$archive_url" -o "$_TMPDIR/squad.tar.gz"; then
          red "Error: Download failed."
          exit 1
        fi

        # Verify checksum if available
        if curl -sL "$checksum_url" -o "$_TMPDIR/squad.tar.gz.sha256" 2>/dev/null; then
          if command -v shasum &>/dev/null; then
            local expected actual
            expected=$(awk '{print $1}' < "$_TMPDIR/squad.tar.gz.sha256")
            actual=$(shasum -a 256 "$_TMPDIR/squad.tar.gz" | awk '{print $1}')
            if [ "$expected" != "$actual" ]; then
              red "Error: Checksum verification failed!"
              red "  Expected: $expected"
              red "  Actual:   $actual"
              red "The downloaded file may be corrupted or tampered with."
              exit 1
            fi
            green "Checksum verified."
          else
            yellow "Warning: shasum not found — skipping checksum verification."
          fi
        else
          yellow "Warning: No checksum file found — skipping verification."
        fi

        tar xzf "$_TMPDIR/squad.tar.gz" -C "$_TMPDIR"

        local extracted
        extracted=$(find "$_TMPDIR" -name "agents" -type d -maxdepth 2 | head -1) || true
        if [ -z "$extracted" ]; then
          red "Error: Invalid archive — agents/ not found."
          exit 1
        fi

        do_install "$(dirname "$extracted")"
      fi
      ;;
  esac
}

# Wrap in main() so curl|bash downloads the entire script before executing
main "$@"
