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

# ── GATE-C5/C6 (adversarial-audit patches): the graded party must not be able to
# end the grading — deleting the scorecard or lowering the bar must not pass.
gd=$(mktemp -d); mkdir -p "$gd/specs"
cg() { printf '%s' '{}' | CLAUDE_PROJECT_DIR="$gd" bash "$HOOK" >/dev/null 2>&1; }

printf '%s' "$ONE_LOW" > "$gd/specs/checklist.json"; cg
[ $? -eq 2 ] && [ -f "$gd/specs/.checklist-active" ] \
  && { echo "PASS: unresolved item sets tombstone (GATE-C5)"; pass=$((pass + 1)); } \
  || { echo "FAIL: tombstone not set on block"; fail=$((fail + 1)); }

rm -f "$gd/specs/checklist.json"; cg
[ $? -eq 2 ] && { echo "PASS: deleting checklist.json still blocks (GATE-C5)"; pass=$((pass + 1)); } \
             || { echo "FAIL: checklist deletion escaped the gate"; fail=$((fail + 1)); }

printf '%s' '{"threshold":0,"items":[{"id":"c1","score":0,"pass":true}]}' > "$gd/specs/checklist.json"; cg
[ $? -eq 2 ] && { echo "PASS: lowered threshold floored at 95 (GATE-C6)"; pass=$((pass + 1)); } \
             || { echo "FAIL: threshold self-lowering escaped the gate"; fail=$((fail + 1)); }

printf '%s' '{"threshold":95,"items":[{"id":"c1","score":97,"pass":true}]}' > "$gd/specs/checklist.json"; cg
[ $? -eq 0 ] && [ ! -f "$gd/specs/.checklist-active" ] \
  && { echo "PASS: passing run clears the tombstone (GATE-C5)"; pass=$((pass + 1)); } \
  || { echo "FAIL: tombstone survived a passing run"; fail=$((fail + 1)); }

rm -f "$gd/specs/checklist.json"; cg
[ $? -eq 0 ] && { echo "PASS: no tombstone, no checklist -> no-op"; pass=$((pass + 1)); } \
             || { echo "FAIL: cleared loop should be a no-op"; fail=$((fail + 1)); }
rm -rf "$gd"

# (14) GATE-C7: a domain_safety item at 97 (>= threshold 95) still blocks — safety has no partial credit.
tmp=$(mktemp -d); mkdir -p "$tmp/specs"
printf '%s' '{"threshold":95,"items":[{"id":"c1","type":"domain_safety","score":97,"pass":true},{"id":"c2","score":100,"pass":true}]}' > "$tmp/specs/checklist.json"
out=$(printf '{}' | CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" 2>&1); code=$?
[ "$code" -eq 2 ] && printf '%s' "$out" | grep -q 'domain_safety' \
  && { echo "PASS: domain_safety at 97 blocks despite threshold 95 (GATE-C7)"; pass=$((pass + 1)); } \
  || { echo "FAIL: domain_safety veto (exit $code)"; fail=$((fail + 1)); }
# (15) the same item at 100 passes; an untyped 97 passes (backward compatible).
printf '%s' '{"threshold":95,"items":[{"id":"c1","type":"domain_safety","score":100,"pass":true},{"id":"c2","type":"convention","score":97,"pass":true},{"id":"c3","score":97,"pass":true}]}' > "$tmp/specs/checklist.json"
printf '{}' | CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" >/dev/null 2>&1
[ $? -eq 0 ] && { echo "PASS: domain_safety 100 + typed/untyped 97 -> pass (GATE-C7)"; pass=$((pass + 1)); } \
             || { echo "FAIL: veto misfired on a passing checklist"; fail=$((fail + 1)); }
rm -f "$tmp/specs/checklist.json" "$tmp/specs/.checklist-active"

# ── GATE-C8: score must equal the clamped 5-axis sum, and test=0 cannot reach the bar.
# The gate used to read `score` alone, so a hand-run loop could write any total it liked.
c8() { # <json> -> exit code in $code, stderr in $out
  printf '%s' "$1" > "$tmp/specs/checklist.json"
  out=$(printf '{}' | CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" 2>&1); code=$?
  rm -f "$tmp/specs/.checklist-active"
}
AX='"exists":25,"match":25,"test":25,"contract":15,"no_regress":10'

# (16) axes consistent with score -> pass.
c8 "{\"threshold\":95,\"items\":[{\"id\":\"c1\",\"score\":100,\"axes\":{$AX}}]}"
[ "$code" -eq 0 ] && { echo "PASS: score == axis sum -> allow (GATE-C8)"; pass=$((pass + 1)); } \
                  || { echo "FAIL: consistent axes blocked (exit $code): $out"; fail=$((fail + 1)); }

# (17) inflated score with honest axes -> block. This is the hole C8 closes.
c8 "{\"threshold\":95,\"items\":[{\"id\":\"c1\",\"score\":100,\"axes\":{\"exists\":25,\"match\":25,\"test\":0,\"contract\":15,\"no_regress\":10}}]}"
[ "$code" -eq 2 ] && printf '%s' "$out" | grep -q '축합' \
  && { echo "PASS: score 100 vs axis sum 75 -> block (GATE-C8)"; pass=$((pass + 1)); } \
  || { echo "FAIL: inflated score escaped (exit $code): $out"; fail=$((fail + 1)); }

# (18) axes forged so the sum matches but tests never ran -> still block.
# 5 axes cannot reach 95 with test=0 (cap 75), so a matching sum means a forged axis.
c8 "{\"threshold\":95,\"items\":[{\"id\":\"c1\",\"score\":95,\"axes\":{\"exists\":45,\"match\":25,\"test\":0,\"contract\":15,\"no_regress\":10}}]}"
[ "$code" -eq 2 ] && { echo "PASS: over-max axis clamped -> block (GATE-C8)"; pass=$((pass + 1)); } \
                  || { echo "FAIL: over-max axis escaped (exit $code): $out"; fail=$((fail + 1)); }

# (19) clamping matches carve-verify-loop.js <score-helper>: over-max clamps, missing/non-number -> 0.
c8 "{\"threshold\":95,\"items\":[{\"id\":\"c1\",\"score\":100,\"axes\":{\"exists\":99,\"match\":25,\"test\":25,\"contract\":15,\"no_regress\":10}}]}"
[ "$code" -eq 0 ] && { echo "PASS: exists 99 clamps to 25, sum 100 -> allow (GATE-C8)"; pass=$((pass + 1)); } \
                  || { echo "FAIL: clamp disagrees with score-helper (exit $code): $out"; fail=$((fail + 1)); }
c8 "{\"threshold\":95,\"items\":[{\"id\":\"c1\",\"score\":75,\"axes\":{\"match\":25,\"test\":25,\"contract\":15,\"no_regress\":10}}]}"
[ "$code" -eq 2 ] && { echo "PASS: missing axis counts as 0, not skipped (GATE-C8)"; pass=$((pass + 1)); } \
                  || { echo "FAIL: missing axis mishandled (exit $code): $out"; fail=$((fail + 1)); }

# (20) no axes field -> untouched (backward compatible with hand-written checklists).
c8 '{"threshold":95,"items":[{"id":"c1","score":97,"pass":true}]}'
[ "$code" -eq 0 ] && { echo "PASS: axes absent -> C8 no-op (backward compatible)"; pass=$((pass + 1)); } \
                  || { echo "FAIL: C8 fired without axes (exit $code): $out"; fail=$((fail + 1)); }

# (21) unscored item with axes -> the existing unresolved message wins, not an axis error.
c8 "{\"threshold\":95,\"items\":[{\"id\":\"c1\",\"score\":null,\"axes\":{$AX}}]}"
[ "$code" -eq 2 ] && printf '%s' "$out" | grep -q '미채점' \
  && { echo "PASS: score null reported as unscored, not axis mismatch"; pass=$((pass + 1)); } \
  || { echo "FAIL: null score message (exit $code): $out"; fail=$((fail + 1)); }

rm -f "$tmp/specs/checklist.json" "$tmp/specs/.checklist-active"; rm -f "$tmp"/logs/*.jsonl 2>/dev/null; rmdir "$tmp/logs" "$tmp/specs" "$tmp" 2>/dev/null

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
