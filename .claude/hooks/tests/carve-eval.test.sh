#!/usr/bin/env bash
# Assertions for carve-eval.js wiring (P1a). Grading itself is exercised in
# eval-run.test.sh / eval-state.test.sh; this suite pins that the workflow delegates
# to the scripts and never lets an agent edit the trend or relay assert values:
# no in-workflow grader, eval-run.sh for setup/grade/run, eval-trend.sh for the
# trend, evidence sealed per run, target argument honoured, body compiles.

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WF="$ROOT/.claude/workflows/carve-eval.js"
EX="$ROOT/.claude/skills/eval-goldenset/example-goldenset.json"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

[ -f "$WF" ] && ok "carve-eval.js present" || no "carve-eval.js missing"

# (1) the workflow body compiles as an async function (top-level await/return are allowed there).
if command -v node >/dev/null 2>&1; then
  node -e '
    const fs = require("fs");
    const AF = Object.getPrototypeOf(async function () {}).constructor;
    new AF("args", "agent", "parallel", "pipeline", "phase", "log", fs.readFileSync(process.argv[1], "utf8").replace(/^export /m, ""));
  ' "$WF" 2>/dev/null && ok "workflow body compiles (async function wrap)" || no "workflow syntax"
else
  echo "SKIP: node absent -> syntax check skipped"
fi

# (2) no grader lives in the workflow any more — assert values never pass through an agent prompt.
! grep -q 'const gradeAssertions' "$WF" && ok "no in-workflow grader (eval-run.sh owns grading)" || no "gradeAssertions still in workflow"
! grep -q "eval-state.sh '\${dir}'" "$WF" && ok "state asserts not relayed by prompt" || no "state relay present"

# (3) delegation points: setup / grade / run / trend read / trend append / evidence seal.
for needle in "eval-run.sh setup" "eval-run.sh grade" "eval-run.sh run" "eval-trend.sh read" "eval-trend.sh append" "specs/eval-runs/run-"; do
  grep -qF "$needle" "$WF" && ok "delegates: $needle" || no "missing delegation: $needle"
done

# (4) the trend file is never opened or edited by an agent prompt.
! grep -qE 'specs/eval-score.json 을 (Read로 열어라|갱신하라)' "$WF" && ok "agent never edits specs/eval-score.json" || no "agent still edits the trend"

# (5) target argument: session default, external targets go through eval-run.sh run --target.
grep -q "ARGS.target ?? 'session'" "$WF" && grep -q -- "--target '\${TARGET}'" "$WF" \
  && ok "target: session default, external via --target" || no "target wiring"

# (6) llm-rubric: only pending ones reach the evaluator, and a pending case is never auto-green.
grep -q 'pendingRubric' "$WF" && grep -q "agentType: 'evaluator'" "$WF" \
  && ok "llm-rubric judged by evaluator only when pending" || no "rubric wiring"

# (7) shipped example golden set is valid JSON with >=1 case.
jq -e '.cases | length > 0' "$EX" >/dev/null 2>&1 && ok "example-goldenset.json valid (>=1 case)" || no "example golden set"

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
