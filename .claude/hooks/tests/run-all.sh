#!/usr/bin/env bash
# Run every hook test suite; per-suite summary + total. Non-zero exit on any failure.
# Usage: bash .claude/hooks/tests/run-all.sh   (or: npm test)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
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
