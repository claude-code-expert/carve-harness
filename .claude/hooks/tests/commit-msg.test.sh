#!/usr/bin/env bash
# Exit-code assertions for .githooks/commit-msg (COMMIT-01, Conventional Commits).
# Writes a message to a temp file, runs the hook with it as $1. block=1, allow=0.

HOOK="$(cd "$(dirname "$0")/../../.." && pwd)/.githooks/commit-msg"
fail=0; pass=0
tmp=$(mktemp -d)

# check <expected_exit> <label> <message...>
check() {
  local expected="$1" label="$2" msg="$3" got
  printf '%s\n' "$msg" > "$tmp/MSG"
  bash "$HOOK" "$tmp/MSG" >/dev/null 2>&1; got=$?
  if [ "$got" -eq "$expected" ]; then
    printf 'PASS: %s (exit %s)\n' "$label" "$got"; pass=$((pass + 1))
  else
    printf 'FAIL: %s (expected %s, got %s)\n' "$label" "$expected" "$got"; fail=$((fail + 1))
  fi
}

# --- valid Conventional Commits allow ---
check 0 "feat: allows"             "feat: add login form"
check 0 "fix(scope): allows"       "fix(auth): null guard on empty body"
check 0 "docs allows"              "docs: update README"
check 0 "breaking ! allows"        "feat(api)!: drop v1 endpoint"
check 0 "chore/deep-scope allows"  "chore(ci/deploy): bump runner"

# --- invalid format blocks ---
check 1 "unknown type blocks"      "wip: messing around"
check 1 "no type blocks"           "just some changes"
check 1 "missing colon blocks"     "feat add thing"
check 1 "empty subject blocks"     "feat: "

# --- length: >72 blocks, ≤72 allows ---
check 1 "overlong subject blocks"  "feat: $(printf 'x%.0s' {1..80})"
check 0 "72-char boundary allows"  "feat: $(printf 'x%.0s' {1..66})"   # 'feat: '=6 +66 =72

# --- exempt formats allow ---
check 0 "merge commit exempt"      "Merge branch 'develop' into main"
check 0 "revert commit exempt"     "Revert \"feat: add login form\""
check 0 "fixup exempt"             "fixup! feat: add login form"

# --- comment/empty handling: comments skipped, real subject validated ---
printf '# a comment\n\nfeat: real subject\n' > "$tmp/MSG"
bash "$HOOK" "$tmp/MSG" >/dev/null 2>&1
[ $? -eq 0 ] && { echo "PASS: comment lines skipped, subject validated (exit 0)"; pass=$((pass + 1)); } \
             || { echo "FAIL: comment skip"; fail=$((fail + 1)); }

rm -rf "$tmp"
printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
