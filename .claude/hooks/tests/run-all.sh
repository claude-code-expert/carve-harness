#!/usr/bin/env bash
# Run every hook test suite; per-suite summary + total. Non-zero exit on any failure.
# Usage: bash .claude/hooks/tests/run-all.sh   (or: npm test)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"

# Test runs must not write into the repo's own logs/. Hooks resolve their log dir
# from CLAUDE_PROJECT_DIR (falling back to the repo root), so a suite that invokes
# a hook without it appends synthetic verdicts to the real observability log — and
# then trace mining reads its own fixtures instead of real sessions. Suites that
# need a specific root still set CLAUDE_PROJECT_DIR per case; this is only the
# default for the ones that don't.
export CARVE_TEST_LOGDIR="${CARVE_TEST_LOGDIR:-$(mktemp -d)}"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$CARVE_TEST_LOGDIR}"
trap 'rm -rf "$CARVE_TEST_LOGDIR"' EXIT

total_fail=0
for f in "$HERE"/*.test.sh; do
  out=$(bash "$f" 2>&1); rc=$?
  printf '%-38s %s\n' "$(basename "$f")" "$(printf '%s' "$out" | tail -1)"
  if [ "$rc" -ne 0 ]; then
    total_fail=$((total_fail + 1))
    printf '%s\n' "$out" | grep '^FAIL' | sed 's/^/  /'
  fi
done
printf -- '---\n'
if [ "$total_fail" -eq 0 ]; then
  echo "ALL SUITES PASSED"
else
  echo "$total_fail suite(s) FAILED"
  exit 1
fi
