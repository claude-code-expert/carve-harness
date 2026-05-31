#!/bin/bash
# helpers.sh — Test assertion helpers for squad-router tests
# Usage: source tests/lib/helpers.sh

set -uo pipefail

PASS=0
FAIL=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROUTER="$REPO_ROOT/hooks/squad-router.sh"

# Parse --quiet flag
QUIET="${QUIET:-0}"
for arg in "$@"; do
  [ "$arg" = "--quiet" ] && QUIET=1
done

# run_router <prompt> [env_vars...]
# Sets: ROUTER_OUTPUT, ROUTER_EXIT
run_router() {
  local prompt="$1"
  shift
  local json
  json=$(jq -n --arg p "$prompt" '{"prompt":$p}')
  ROUTER_OUTPUT=$(echo "$json" | env "$@" bash "$ROUTER" 2>/dev/null) || true
  ROUTER_EXIT=$?
}

# run_router_raw <raw_stdin>
# Sets: ROUTER_OUTPUT, ROUTER_EXIT
run_router_raw() {
  local raw="$1"
  ROUTER_OUTPUT=$(echo "$raw" | bash "$ROUTER" 2>/dev/null) || true
  ROUTER_EXIT=$?
}

# extract_agent — parse agent name from router output
extract_agent() {
  [ -z "$ROUTER_OUTPUT" ] && echo "" && return
  echo "$ROUTER_OUTPUT" | sed -n 's/.*the \(squad-[a-z]*\) subagent.*/\1/p'
}

# assert_routes_to <prompt> <expected_agent>
assert_routes_to() {
  local prompt="$1" expected="$2"
  run_router "$prompt"
  local actual
  actual=$(extract_agent)
  if [ "$actual" = "$expected" ]; then
    ((PASS++)) || true
    [ "$QUIET" != "1" ] && printf "  \033[32m✓\033[0m %s → %s\n" "$prompt" "$expected"
  else
    ((FAIL++)) || true
    printf "  \033[31m✗\033[0m %s → got '%s', expected '%s'\n" "$prompt" "$actual" "$expected"
  fi
}

# assert_no_output <prompt> [env_vars...]
assert_no_output() {
  local prompt="$1"
  shift
  run_router "$prompt" "$@"
  if [ -z "$ROUTER_OUTPUT" ]; then
    ((PASS++)) || true
    [ "$QUIET" != "1" ] && printf "  \033[32m✓\033[0m %s → (skip)\n" "$prompt"
  else
    ((FAIL++)) || true
    printf "  \033[31m✗\033[0m %s → expected no output, got: %s\n" "$prompt" "$ROUTER_OUTPUT"
  fi
}

# assert_no_output_raw <raw_stdin>
assert_no_output_raw() {
  local raw="$1"
  run_router_raw "$raw"
  if [ -z "$ROUTER_OUTPUT" ]; then
    ((PASS++)) || true
    [ "$QUIET" != "1" ] && printf "  \033[32m✓\033[0m (raw: %s) → (skip)\n" "${raw:0:40}"
  else
    ((FAIL++)) || true
    printf "  \033[31m✗\033[0m (raw) → expected no output, got: %s\n" "$ROUTER_OUTPUT"
  fi
}

# summary — print results and exit
summary() {
  echo ""
  if [ "$FAIL" -gt 0 ]; then
    printf "\033[31mFAILED: %d passed, %d failed, %d total\033[0m\n" "$PASS" "$FAIL" "$((PASS+FAIL))"
    exit 1
  else
    printf "\033[32mPASSED: %d passed, 0 failed, %d total\033[0m\n" "$PASS" "$PASS"
    exit 0
  fi
}
