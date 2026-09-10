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
if [ -n "$BLOCK" ] && printf '%s' "$BLOCK" | grep -q 'const scoreFromAxes' && printf '%s' "$BLOCK" | grep -q 'const testAxis'; then
  echo "PASS: <score-helper> block extractable"; pass=$((pass + 1))
else
  echo "FAIL: <score-helper> block missing (marker drift?)"; fail=$((fail + 1))
fi

# (1b) the evaluator must not be able to report the test axis at all — it reports a run.
# If `test` reappears in the axes schema the derivation is bypassable, so guard the schema.
if grep -A12 'const SCORE_SCHEMA' "$WF" | grep -q "required: \['exists', 'match', 'contract', 'no_regress'\]" \
   && grep -q "required: \['ran', 'passed', 'failed', 'command', 'output'\]" "$WF"; then
  echo "PASS: SCORE_SCHEMA asks for a test RUN, not a test score"; pass=$((pass + 1))
else
  echo "FAIL: SCORE_SCHEMA drifted — evaluator can self-report the test axis"; fail=$((fail + 1))
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

    // test axis is DERIVED from a run, never reported. This is what makes
    // "an untested claim cannot pass" arithmetic instead of prose.
    const four = { exists: 25, match: 25, contract: 15, no_regress: 10 };
    A("tests not run -> test axis 0", testAxis({ ran: false, passed: 9, failed: 0 }) === 0);
    A("no tests object -> test axis 0", testAxis(null) === 0 && testAxis(undefined) === 0);
    A("ran with nothing collected -> 0 (claiming a run is not a run)",
      testAxis({ ran: true, passed: 0, failed: 0 }) === 0);
    A("all green -> full 25", testAxis({ ran: true, passed: 4, failed: 0 }) === 25);
    A("one failure -> 0 (red is not done, no partial credit)",
      testAxis({ ran: true, passed: 3, failed: 1 }) === 0);
    A("99 green + 1 red -> still 0 (a ratio would let 4/5 land exactly on 95)",
      testAxis({ ran: true, passed: 99, failed: 1 }) === 0);
    A("negative failed does not count as zero failures -> 0 (matches jq tx())",
      testAxis({ ran: true, passed: 5, failed: -3 }) === 0);
    A("truthy non-boolean ran does not count as a run", testAxis({ ran: "yes", passed: 4, failed: 0 }) === 0);
    A("untested claim with four perfect axes caps at 75 < 95",
      scoreFromAxes(axesWithTest(four, { ran: false, passed: 0, failed: 0 })) === 75);
    A("same claim with a green run reaches 100",
      scoreFromAxes(axesWithTest(four, { ran: true, passed: 2, failed: 0 })) === 100);
    A("axesWithTest overwrites a self-reported test axis",
      axesWithTest({ ...four, test: 25 }, { ran: false, passed: 0, failed: 0 }).test === 0);
    process.exit(ok ? 0 : 1);
  ' | node; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
  fi
else
  echo "SKIP: node absent -> rubric math check skipped (best-effort)"
fi

# (3) the jq clamp in checklist-gate.sh GATE-C8 must agree with scoreFromAxes.
# Two implementations of one rule: if they drift, the workflow path and the hand-run
# path judge the same checklist.json differently. Compare them on the same inputs.
GATE="$(cd "$(dirname "$0")/../../.." && pwd)/.claude/hooks/checklist-gate.sh"
if command -v node >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  CASES='[{"exists":25,"match":25,"test":25,"contract":15,"no_regress":10},
          {"exists":99,"match":25,"test":25,"contract":15,"no_regress":10},
          {"exists":-50,"match":25,"test":25,"contract":15,"no_regress":10},
          {"exists":25,"match":"abc","test":25,"contract":15,"no_regress":10},
          {"match":25,"test":25,"contract":15,"no_regress":10},
          {"exists":25,"match":25,"test":0,"contract":15,"no_regress":10}]'
  JS=$(printf '%s\n%s\n' "$BLOCK" "
    const cases = $CASES;
    console.log(cases.map(scoreFromAxes).join(','));
  " | node)
  # 게이트의 cl() 정의를 훅에서 그대로 뽑아 같은 입력에 먹인다(재구현 금지 — 위장 테스트 방지).
  CL=$(grep -m1 '  def cl(' "$GATE")
  JQ=$(printf '%s' "$CASES" | jq -r "$CL
    [ .[] | cl(.exists; 25) + cl(.match; 25) + cl(.test; 25) + cl(.contract; 15) + cl(.no_regress; 10) ]
    | join(\",\")")
  if [ -n "$JS" ] && [ "$JS" = "$JQ" ]; then
    echo "PASS: GATE-C8 jq clamp agrees with scoreFromAxes ($JS)"; pass=$((pass + 1))
  else
    echo "FAIL: clamp drift — js=[$JS] jq=[$JQ]"; fail=$((fail + 1))
  fi
  # Same for the test-axis derivation: jq tx() vs JS testAxis on one input set.
  TCASES='[{"ran":true,"passed":4,"failed":0},{"ran":true,"passed":3,"failed":1},{"ran":false,"passed":9,"failed":0},
           {"ran":true,"passed":0,"failed":0},{"ran":"yes","passed":4,"failed":0},{"ran":true},
           {"ran":true,"passed":-1,"failed":0},{"ran":true,"passed":5,"failed":-3},"nope",null]'
  JS=$(printf '%s\n%s\n' "$BLOCK" "console.log(($TCASES).map(testAxis).join(','));" | node)
  TX=$(grep -m1 '  def num(' "$GATE"; grep -m1 '  def tx(' "$GATE")
  JQ=$(printf '%s' "$TCASES" | jq -r "$TX [ .[] | tx(.) ] | join(\",\")")
  if [ -n "$JS" ] && [ "$JS" = "$JQ" ]; then
    echo "PASS: GATE-C8 jq tx() agrees with testAxis ($JS)"; pass=$((pass + 1))
  else
    echo "FAIL: test-axis derivation drift — js=[$JS] jq=[$JQ]"; fail=$((fail + 1))
  fi
else
  echo "SKIP: node or jq absent -> clamp cross-check skipped"
fi

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
