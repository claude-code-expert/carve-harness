#!/bin/bash
# run-all.sh — Run all Squad Agent tests
# Usage: bash tests/run-all.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=0

echo "╔══════════════════════════════════════════╗"
echo "║     Squad Agent — Full Test Suite        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

bash "$SCRIPT_DIR/test-router.sh" || FAILED=1
echo ""
echo "──────────────────────────────────────────"
echo ""
bash "$SCRIPT_DIR/test-files.sh" || FAILED=1

echo ""
echo "══════════════════════════════════════════"
if [ "$FAILED" -ne 0 ]; then
  printf "\033[31m FINAL: SOME TESTS FAILED\033[0m\n"
  exit 1
else
  printf "\033[32m FINAL: ALL TESTS PASSED\033[0m\n"
  exit 0
fi
