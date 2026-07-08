#!/usr/bin/env bash
# Exit-code assertions for .githooks/pre-commit (Dev-1, agent-agnostic gate).
# Builds a throwaway git repo per case, stages fixtures, runs the hook directly.
# block = exit 1, allow = exit 0.

HOOK_SRC="$(cd "$(dirname "$0")/../../.." && pwd)/.githooks/pre-commit"
LIB_SRC="$(cd "$(dirname "$0")/.." && pwd)/lib-protected.sh"
fail=0
pass=0

# fresh_repo — new temp repo with hook + lib in place; echoes its path.
fresh_repo() {
  local r
  r=$(mktemp -d)
  git -C "$r" init -q
  git -C "$r" config user.email t@t && git -C "$r" config user.name t
  mkdir -p "$r/.claude/hooks" "$r/.githooks"
  cp "$LIB_SRC" "$r/.claude/hooks/"
  cp "$HOOK_SRC" "$r/.githooks/"
  echo "$r"
}

# check <expected_exit> <label> <repo>
check() {
  local expected="$1" label="$2" repo="$3" got
  ( cd "$repo" && bash .githooks/pre-commit ) >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$expected" ]; then
    printf 'PASS: %s (exit %s)\n' "$label" "$got"; pass=$((pass + 1))
  else
    printf 'FAIL: %s (expected %s, got %s)\n' "$label" "$expected" "$got"; fail=$((fail + 1))
  fi
  rm -rf "$repo"
}

# --- benign file allows ---
r=$(fresh_repo); echo "hello" > "$r/a.txt"; git -C "$r" add a.txt
check 0 "benign file allows" "$r"

# --- staged .env blocks ---
r=$(fresh_repo); echo "X=1" > "$r/.env"; git -C "$r" add -f .env
check 1 "staged .env blocks" "$r"

# --- NEW migration file allows (sanctioned change path) ---
r=$(fresh_repo); mkdir -p "$r/db/migration"; echo "CREATE TABLE t(id int);" > "$r/db/migration/V2__add_t.sql"
git -C "$r" add db/migration/V2__add_t.sql
check 0 "new migration allows" "$r"

# --- MODIFIED migration blocks ---
r=$(fresh_repo); mkdir -p "$r/db/migration"; echo "v1" > "$r/db/migration/V1__init.sql"
git -C "$r" add db/migration/V1__init.sql && git -C "$r" commit -qm base
echo "tampered" >> "$r/db/migration/V1__init.sql"; git -C "$r" add db/migration/V1__init.sql
check 1 "modified migration blocks" "$r"

# --- hardcoded secret content blocks (fixture split so THIS file holds no secret) ---
akia="AKIA""IOSFODNN7EXAMPLE"
r=$(fresh_repo); echo "key=$akia" > "$r/conf.txt"; git -C "$r" add conf.txt
check 1 "staged AWS key blocks" "$r"

# --- missing lib -> fail-closed block ---
r=$(fresh_repo); rm "$r/.claude/hooks/lib-protected.sh"
echo "hello" > "$r/a.txt"; git -C "$r" add a.txt
check 1 "missing lib fail-closed" "$r"

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
