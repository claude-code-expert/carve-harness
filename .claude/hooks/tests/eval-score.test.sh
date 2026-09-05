#!/usr/bin/env bash
# Assertions for the carve-verify-loop 5-axis rubric (Stage A).
# Extracts the <score-helper> block and node-evals the REAL scoreFromAxes, proving
# the policy invariants: axes sum to 100, an untested claim (test=0) caps at 75 and
# cannot reach the 95 gate, over-max clamps, missing axes -> 0.
# It used to re-implement the clamp+sum inline ("mirrors scoreFromAxes") and so
# stayed green when the real Math.min clamp was deleted — a sham test. Never mirror
# logic under test; execute it.
# node-based (the scoring helper is inline JS in the workflow); skips if node absent.

WF="$(cd "$(dirname "$0")/../../.." && pwd)/.claude/workflows/carve-verify-loop.js"
fail=0
pass=0

# (0) workflow exists.
[ -f "$WF" ] && { echo "PASS: workflow present"; pass=$((pass + 1)); } \
             || { echo "FAIL: carve-verify-loop.js missing"; fail=$((fail + 1)); }

# (1) score-helper block extractable (marker guard — the test runs THIS code).
BLOCK="$(sed -n '/<score-helper>/,/<\/score-helper>/p' "$WF")"
if [ -n "$BLOCK" ] && printf '%s' "$BLOCK" | grep -q 'const scoreFromAxes'; then
  echo "PASS: <score-helper> block extractable"; pass=$((pass + 1))
else
  echo "FAIL: <score-helper> block missing (marker drift?)"; fail=$((fail + 1))
fi

# (2) run the REAL scoreFromAxes + AXIS_MAX and assert the rubric invariants.
if command -v node >/dev/null 2>&1; then
  if printf '%s\n%s\n' "$BLOCK" '
    const keys = Object.keys(AXIS_MAX);
    const full = Object.fromEntries(keys.map((k) => [k, AXIS_MAX[k]]));
    const noTest = Object.assign({}, full, { test: 0 });
    let ok = true;
    const A = (c, cond) => { console.log((cond ? "PASS: " : "FAIL: ") + c); if (!cond) ok = false; };
    A("5 axes sum to 100", scoreFromAxes(full) === 100);
    A("test axis worth 25 (verify=policy)", AXIS_MAX.test === 25);
    A("test omitted caps at 75 (<95 gate)", scoreFromAxes(noTest) === 75 && 75 < 95);
    A("over-max values clamp to 100", scoreFromAxes(Object.fromEntries(keys.map((k) => [k, 999]))) === 100);
    A("negative axis clamps to 0, not subtracted",
      scoreFromAxes(Object.assign({}, full, { exists: -50 })) === 75);
    A("null/empty/non-object axes -> 0",
      scoreFromAxes(null) === 0 && scoreFromAxes({}) === 0 && scoreFromAxes("nope") === 0);
    A("non-numeric axis counts as 0, never NaN",
      scoreFromAxes(Object.assign({}, full, { match: "abc" })) === 75);
    A("unknown extra axis cannot inflate the score",
      scoreFromAxes(Object.assign({}, full, { bonus: 999 })) === 100);
    process.exit(ok ? 0 : 1);
  ' | node; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
  fi
else
  echo "SKIP: node absent -> rubric math check skipped (best-effort)"
fi

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
