#!/usr/bin/env bash
# Assertions for checklist-gate.sh: no-op when checklist absent, block (exit 2) on
# any item under threshold or unscored, pass (exit 0) when all >= threshold,
# stop_hook_active loop guard, jq-absent best-effort, malformed-json best-effort.
# jq-absence simulated via env -i PATH= + absolute bash — never uninstalls jq.

HOOK="$(cd "$(dirname "$0")/.." && pwd)/checklist-gate.sh"
BASH_BIN="$(command -v bash)"
fail=0
pass=0

# Helper: run the hook with a project dir + optional checklist.json content.
# $1 = checklist json (empty => no file), $2 = stdin json (default '{}')
run_gate() {
  local content="$1" stdin="${2:-{}}" pd
  pd=$(mktemp -d)
  if [ -n "$content" ]; then
    mkdir -p "$pd/specs"
    printf '%s' "$content" > "$pd/specs/checklist.json"
  fi
  printf '%s' "$stdin" | CLAUDE_PROJECT_DIR="$pd" bash "$HOOK" >/dev/null 2>&1
  local code=$?
  rm -rf "$pd"
  return $code
}

# (1) no checklist.json -> no-op (exit 0). This hook only bites during a loop.
run_gate ""
[ $? -eq 0 ] && { echo "PASS: absent checklist -> no-op (exit 0)"; pass=$((pass + 1)); } \
             || { echo "FAIL: absent checklist should exit 0"; fail=$((fail + 1)); }

# (2) all items >= threshold -> pass (exit 0).
ALL_PASS='{"threshold":95,"items":[{"id":"c1","score":95,"pass":true},{"id":"c2","score":100,"pass":true}]}'
run_gate "$ALL_PASS"
[ $? -eq 0 ] && { echo "PASS: all>=95 -> allow (exit 0)"; pass=$((pass + 1)); } \
             || { echo "FAIL: all>=95 should exit 0"; fail=$((fail + 1)); }

# (3) an item below threshold -> block (exit 2).
ONE_LOW='{"threshold":95,"items":[{"id":"c1","score":95,"pass":true},{"id":"c2","score":88,"pass":false}]}'
run_gate "$ONE_LOW"
[ $? -eq 2 ] && { echo "PASS: one<95 -> block (exit 2)"; pass=$((pass + 1)); } \
             || { echo "FAIL: one<95 should exit 2"; fail=$((fail + 1)); }

# (4) an unscored item (score null) -> block (exit 2). Claim not yet graded.
UNSCORED='{"threshold":95,"items":[{"id":"c1","score":null,"pass":false}]}'
run_gate "$UNSCORED"
[ $? -eq 2 ] && { echo "PASS: unscored item -> block (exit 2)"; pass=$((pass + 1)); } \
             || { echo "FAIL: unscored should exit 2"; fail=$((fail + 1)); }

# (5) default threshold (field omitted) is 95 -> 94 blocks.
DEFAULT_TH='{"items":[{"id":"c1","score":94,"pass":false}]}'
run_gate "$DEFAULT_TH"
[ $? -eq 2 ] && { echo "PASS: default threshold 95 -> 94 blocks (exit 2)"; pass=$((pass + 1)); } \
             || { echo "FAIL: default threshold should block 94"; fail=$((fail + 1)); }

# (6) stop_hook_active=true -> loop guard yields (exit 0) even with a failing item.
run_gate "$ONE_LOW" '{"stop_hook_active":true}'
[ $? -eq 0 ] && { echo "PASS: loop guard yields (exit 0)"; pass=$((pass + 1)); } \
             || { echo "FAIL: loop guard should exit 0"; fail=$((fail + 1)); }

# (7) jq absent + failing item -> best-effort skip (exit 0, never deadlock).
pd=$(mktemp -d); mkdir -p "$pd/specs"; printf '%s' "$ONE_LOW" > "$pd/specs/checklist.json"
printf '%s' '{}' | env -i PATH= CLAUDE_PROJECT_DIR="$pd" "$BASH_BIN" "$HOOK" >/dev/null 2>&1
code=$?
rm -rf "$pd"
[ "$code" -eq 0 ] && { echo "PASS: jq-absent best-effort (exit 0)"; pass=$((pass + 1)); } \
                  || { echo "FAIL: jq-absent should exit 0 (got $code)"; fail=$((fail + 1)); }

# (8) malformed JSON -> best-effort skip (exit 0, warn only).
run_gate '{not valid json'
[ $? -eq 0 ] && { echo "PASS: malformed json best-effort (exit 0)"; pass=$((pass + 1)); } \
             || { echo "FAIL: malformed json should exit 0"; fail=$((fail + 1)); }

# (9) block path logs one line with .decision==fail (observability, matches stop-verify).
pd=$(mktemp -d); mkdir -p "$pd/specs"; printf '%s' "$ONE_LOW" > "$pd/specs/checklist.json"
L="$pd/logs/$(date -u +%F).jsonl"
printf '%s' '{}' | CLAUDE_PROJECT_DIR="$pd" bash "$HOOK" >/dev/null 2>&1
if command -v jq >/dev/null 2>&1 \
   && [ "$(tail -1 "$L" 2>/dev/null | jq -r '.event' 2>/dev/null)" = "Stop" ] \
   && [ "$(tail -1 "$L" 2>/dev/null | jq -r '.decision' 2>/dev/null)" = "fail" ]; then
  echo "PASS: block logs one line (.decision==fail)"; pass=$((pass + 1))
else
  echo "FAIL: block should log .decision==fail"; fail=$((fail + 1))
fi
rm -rf "$pd"

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
