#!/usr/bin/env bash
# Exit-code assertions for pretool-guard.sh (GUARD-01/02/03).
# Feeds synthetic hook JSON on stdin, asserts the guard's exit code.
# jq-absence is SIMULATED via an empty PATH + absolute bash — never uninstalls jq.
# block = exit 2, allow = exit 0 (per ARCHITECTURE 핵심 불변식 / MANUAL §2.2).

GUARD="$(dirname "$0")/../pretool-guard.sh"
BASH_BIN="$(command -v bash)"
fail=0
pass=0

# check <expected_exit> <label> <json>
check() {
  local expected="$1" label="$2" json="$3" got
  printf '%s' "$json" | bash "$GUARD" >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$expected" ]; then
    printf 'PASS: %s (exit %s)\n' "$label" "$got"; pass=$((pass + 1))
  else
    printf 'FAIL: %s (expected %s, got %s)\n' "$label" "$expected" "$got"; fail=$((fail + 1))
  fi
}

# check_jqabsent <expected_exit> <label> <json> — run guard with jq unreachable.
# env -i clears the environment; empty PATH means `command -v jq` (a bash builtin)
# finds nothing. Absolute bash is passed so the interpreter itself still launches.
check_jqabsent() {
  local expected="$1" label="$2" json="$3" got
  printf '%s' "$json" | env -i PATH= "$BASH_BIN" "$GUARD" >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$expected" ]; then
    printf 'PASS: %s (exit %s)\n' "$label" "$got"; pass=$((pass + 1))
  else
    printf 'FAIL: %s (expected %s, got %s)\n' "$label" "$expected" "$got"; fail=$((fail + 1))
  fi
}

# --- GUARD-01: fail-closed on degraded input (write paths) ---
check          2 "malformed JSON blocks"      'not json'
check_jqabsent 2 "jq absent blocks (D-01)"    '{"tool_name":"Write","tool_input":{"file_path":"foo.txt"}}'

# --- GUARD-01/02: write tools -> protected path blocks (exit 2) ---
check 2 "Write .env.production"       '{"tool_name":"Write","tool_input":{"file_path":"x/.env.production"}}'
check 2 "MultiEdit .env.production"   '{"tool_name":"MultiEdit","tool_input":{"file_path":"x/.env.production"}}'
check 2 "NotebookEdit notebook_path"  '{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"a/.env.production"}}'

# --- GUARD-03: Bash write operator -> protected target blocks (exit 2) ---
check 2 "Bash redirect to .env.production" '{"tool_name":"Bash","tool_input":{"command":"echo secret > x/.env.production"}}'
check 2 "Bash sed -i on migration"         '{"tool_name":"Bash","tool_input":{"command":"sed -i s/a/b/ db/migration/001.sql"}}'
check 2 "Bash cp to application-prod"       '{"tool_name":"Bash","tool_input":{"command":"cp a application-prod.yml"}}'

# --- GUARD-03: benign Bash allows (exit 0) — NO write operator targeting protected ---
check 0 "Bash npm test"                    '{"tool_name":"Bash","tool_input":{"command":"npm test"}}'
check 0 "Bash grep secret (read)"          '{"tool_name":"Bash","tool_input":{"command":"grep -ri secret ."}}'
check 0 "Bash git commit msg secret"       '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"rotate secret\""}}'
check 0 "Bash git log .env.example"        '{"tool_name":"Bash","tool_input":{"command":"git log -- .env.example"}}'
check 0 "Bash grep secret 2>/dev/null"     '{"tool_name":"Bash","tool_input":{"command":"grep -ri secret . 2>/dev/null"}}'

# --- benign write paths allow (exit 0), incl. .environment.ts false-positive guard ---
check 0 "Write foo.txt"                    '{"tool_name":"Write","tool_input":{"file_path":"foo.txt"}}'
check 0 "Write src/environment.ts"         '{"tool_name":"Write","tool_input":{"file_path":"src/environment.ts"}}'

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
