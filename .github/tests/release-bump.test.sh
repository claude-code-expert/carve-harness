#!/usr/bin/env bash
# Self-check for release-bump.sh — the money path (version correctness).
# Run: bash .github/tests/release-bump.test.sh
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
bump="$here/release-bump.sh"
fail=0

check() { # desc | expected | last-version | commit-subjects...
  local desc="$1" exp="$2" ver="$3"; shift 3
  local got; got=$(printf '%s\n' "$@" | bash "$bump" "$ver")
  if [ "$got" = "$exp" ]; then
    echo "ok: $desc"
  else
    echo "FAIL: $desc — expected '$exp' got '$got'"; fail=1
  fi
}

check "feat -> minor"            "minor 0.1.0"  0.0.13 "feat: add x"
check "fix -> patch"             "patch 0.0.14" 0.0.13 "fix: bug"
check "perf -> patch"            "patch 0.0.14" 0.0.13 "perf: faster"
check "refactor -> patch"        "patch 0.0.14" 0.0.13 "refactor: tidy"
check "bang -> major"            "major 1.0.0"  0.0.13 "feat!: drop api"
check "scoped bang -> major"     "major 1.0.0"  0.0.13 "fix(core)!: remove flag"
check "BREAKING footer -> major" "major 1.0.0"  0.0.13 "feat: x" "BREAKING CHANGE: y"
check "docs/chore only -> none"  "none 0.0.13"  0.0.13 "docs: readme" "chore: bump"
check "highest wins (feat>fix)"  "minor 0.1.0"  0.0.13 "fix: a" "feat: b" "docs: c"
check "major beats feat"         "major 1.0.0"  0.0.13 "feat: a" "feat!: b"
check "scoped feat -> minor"     "minor 0.1.0"  0.0.13 "feat(ui): x"
check "v-prefix input tolerated" "patch 0.0.14" v0.0.13 "fix: y"
check "empty history -> none"    "none 0.0.13"  0.0.13 ""

[ "$fail" = 0 ] && { echo "ALL PASS"; exit 0; } || { echo "SOME FAILED"; exit 1; }
