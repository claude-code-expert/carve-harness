#!/usr/bin/env bash
# release-bump.sh — derive the SemVer bump level + next version from
# Conventional Commit subjects fed on stdin (one per line).
#
#   printf '%s\n' "feat: x" "fix: y" | release-bump.sh 0.0.13   → "minor 0.1.0"
#
# Level precedence: major > minor > patch > none.
#   type!: / "BREAKING CHANGE"  → major
#   feat:                       → minor
#   fix: / perf: / refactor:    → patch
#   only docs/chore/ci/style/test/build → none (caller skips the release)
#
# Pure function: stdin + $1 in, one line out. No side effects → unit-testable.
# Self-test lives in .github/tests/release-bump.test.sh.
set -euo pipefail

last="${1:?usage: release-bump.sh <last-version>}"
last="${last#v}"
maj="${last%%.*}"; rest="${last#*.}"; min="${rest%%.*}"; pat="${rest##*.}"
case "$maj" in ''|*[!0-9]*) maj=0 ;; esac
case "$min" in ''|*[!0-9]*) min=0 ;; esac
case "$pat" in ''|*[!0-9]*) pat=0 ;; esac

rank() { case "$1" in major) echo 3 ;; minor) echo 2 ;; patch) echo 1 ;; *) echo 0 ;; esac; }

level=none
while IFS= read -r line; do
  [ -n "$line" ] || continue
  this=none
  if printf '%s' "$line" | grep -qE 'BREAKING[ -]CHANGE'; then this=major
  elif printf '%s' "$line" | grep -qE '^[a-z]+(\([^)]+\))?!:'; then this=major
  elif printf '%s' "$line" | grep -qE '^feat(\([^)]+\))?:'; then this=minor
  elif printf '%s' "$line" | grep -qE '^(fix|perf|refactor)(\([^)]+\))?:'; then this=patch
  fi
  [ "$(rank "$this")" -gt "$(rank "$level")" ] && level="$this"
done

case "$level" in
  major) maj=$((maj + 1)); min=0; pat=0 ;;
  minor) min=$((min + 1)); pat=0 ;;
  patch) pat=$((pat + 1)) ;;
  none)  printf 'none %s\n' "$last"; exit 0 ;;
esac
printf '%s %d.%d.%d\n' "$level" "$maj" "$min" "$pat"
