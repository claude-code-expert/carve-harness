#!/usr/bin/env bash
# release.sh — apply an auto-release for version $1 over git range $2:
#   1. build release notes from Conventional Commit subjects in the range
#   2. prepend the CHANGELOG section, bump VERSION, sync README header + table
#   3. commit "[skip ci]", tag, push to main, create the GitHub Release
#
# Driven by .github/workflows/release.yml. The bump DECISION is release-bump.sh;
# this script only applies a decision already made.
#
# RELEASE_DRY=1  → mutate files only, skip git/tag/push/gh (local verification).
# RELEASE_TODAY  → override the date (test determinism).
set -euo pipefail

v="${1:?usage: release.sh <version> <git-range>}"
range="${2:?usage: release.sh <version> <git-range>}"
today="${RELEASE_TODAY:-$(date +%F)}"

feats=$(git log --format='%s' "$range" | grep -E '^feat(\([^)]+\))?!?:' || true)
fixes=$(git log --format='%s' "$range" | grep -E '^fix(\([^)]+\))?!?:' || true)
chgs=$(git log  --format='%s' "$range" | grep -E '^(perf|refactor)(\([^)]+\))?!?:' || true)

# ── release notes (also used verbatim as the GitHub Release body) ──
{
  echo "## [$v] - $today"
  echo
  [ -n "$feats" ] && { echo "### Added";   printf '%s\n' "$feats" | sed 's/^/- /'; echo; }
  [ -n "$fixes" ] && { echo "### Fixed";   printf '%s\n' "$fixes" | sed 's/^/- /'; echo; }
  [ -n "$chgs"  ] && { echo "### Changed"; printf '%s\n' "$chgs"  | sed 's/^/- /'; echo; }
} > notes.md

# ── prepend the section above the first existing "## [" in CHANGELOG.md ──
awk 'NR==FNR{buf=buf $0 ORS; next} !ins && /^## \[/{printf "%s", buf; ins=1} {print}' \
  notes.md CHANGELOG.md > CHANGELOG.tmp && mv CHANGELOG.tmp CHANGELOG.md

# ── VERSION ──
printf '%s\n' "$v" > VERSION

# ── README header ("현재 버전 **vX.Y.Z**" / "Current version **vX.Y.Z**") + table row ──
sum=$(printf '%s\n%s\n%s\n' "$feats" "$fixes" "$chgs" | grep -v '^$' | head -1 \
        | sed -E 's/^[a-z]+(\([^)]+\))?!?: *//')
[ -n "$sum" ] || sum="release v$v"

# Regexes stay as awk literals — passing "\|"/"\*" through -v mangles them
# (awk unescapes -v values, turning "\|" into a regex-OR that matches every line).
awk -v v="$v" -v today="$today" -v sum="$sum" '
  /현재 버전 \*\*v[0-9]/ { sub(/\*\*v[0-9]+\.[0-9]+\.[0-9]+\*\*/, "**v" v "**") }
  { print }
  prev ~ /^\| 버전 \| 날짜 \| 요약 \|$/ && /^\|[- |]+\|$/ && !done { print "| v" v " | " today " | " sum " |"; done=1 }
  { prev=$0 }
' README.md > README.md.tmp && mv README.md.tmp README.md

awk -v v="$v" -v today="$today" -v sum="$sum" '
  /Current version \*\*v[0-9]/ { sub(/\*\*v[0-9]+\.[0-9]+\.[0-9]+\*\*/, "**v" v "**") }
  { print }
  prev ~ /^\| Version \| Date \| Summary \|$/ && /^\|[- |]+\|$/ && !done { print "| v" v " | " today " | " sum " |"; done=1 }
  { prev=$0 }
' README.en.md > README.en.md.tmp && mv README.en.md.tmp README.en.md

if [ "${RELEASE_DRY:-0}" = 1 ]; then
  echo "[dry] files mutated (VERSION/CHANGELOG/README), skipping git + gh"
  exit 0
fi

# ── commit (loop-safe: [skip ci] + GITHUB_TOKEN push won't retrigger), tag, push ──
git config user.name  "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add VERSION CHANGELOG.md README.md README.en.md
git commit -m "chore(release): v$v [skip ci]"
git tag "v$v"
git push origin HEAD:main
git push origin "v$v"

gh release create "v$v" --target "$(git rev-parse HEAD)" --title "v$v" --latest --notes-file notes.md
