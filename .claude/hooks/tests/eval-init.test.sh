#!/usr/bin/env bash
# Assertions for the /eval-init setup skill and its deterministic half.
# The interview itself is prompt-driven (untestable in bash), so this suite pins
# the parts that MUST stay mechanical: the regression gate's verdicts/exit codes,
# the CI template's shape, and the skill's wiring (frontmatter + referenced paths).

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GATE="$ROOT/.claude/hooks/eval-gate.sh"
SKILL="$ROOT/.claude/skills/eval-init/SKILL.md"
TPL="$ROOT/.claude/skills/eval-init/eval-workflow.yml.template"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

# ── skill wiring ────────────────────────────────────────────────────────────
[ -f "$SKILL" ] && ok "eval-init SKILL.md present" || no "eval-init SKILL.md missing"
grep -q '^name: eval-init' "$SKILL" 2>/dev/null && grep -q '^description:' "$SKILL" 2>/dev/null \
  && ok "skill frontmatter (name + description)" || no "skill frontmatter incomplete"
# Destructive-adjacent (writes files, wires CI) -> explicit invocation only.
grep -q '^disable-model-invocation: true' "$SKILL" 2>/dev/null \
  && ok "skill is explicit-invocation only" || no "skill missing disable-model-invocation"
# Every harness path the skill points at must exist, or the flow dead-ends mid-run.
missing=""
for p in .claude/skills/eval-goldenset/SKILL.md .claude/workflows/carve-eval.js \
         .claude/hooks/eval-state.sh .claude/hooks/eval-gate.sh \
         .claude/skills/eval-goldenset/example-harness-e2e.json; do
  grep -qF "$p" "$SKILL" 2>/dev/null && [ ! -e "$ROOT/$p" ] && missing="$missing $p"
done
[ -z "$missing" ] && ok "skill references resolve to real files" || no "dangling skill refs:$missing"
# The no-auto-confirm invariant must stay written down — it is the whole point.
grep -q '자동 확정 금지' "$SKILL" 2>/dev/null \
  && ok "skill states the no-auto-confirm invariant" || no "no-auto-confirm invariant missing"

# ── CI template ─────────────────────────────────────────────────────────────
[ -f "$TPL" ] && ok "CI workflow template present" || no "CI workflow template missing"
grep -q '__MODE__' "$TPL" 2>/dev/null && grep -q '__DELTA__' "$TPL" 2>/dev/null \
  && ok "template exposes MODE/DELTA placeholders" || no "template placeholders missing"
grep -q 'eval-gate.sh' "$TPL" 2>/dev/null \
  && ok "template calls the deterministic gate (no LLM in CI)" || no "template does not call eval-gate.sh"

# ── regression gate: verdicts + exit codes ──────────────────────────────────
[ -x "$GATE" ] && ok "eval-gate.sh executable" || no "eval-gate.sh not +x"
bash -n "$GATE" 2>/dev/null && ok "eval-gate.sh bash -n clean" || no "eval-gate.sh syntax error"

if command -v jq >/dev/null 2>&1; then
  T=$(mktemp -d); mkdir -p "$T/specs"
  TREND="$T/specs/eval-score.json"
  gate() { CLAUDE_PROJECT_DIR="$T" bash "$GATE" "$@" 2>/dev/null; }   # stdout=json, $?=exit
  verdict_of() { gate "$@" | jq -r '.verdict' 2>/dev/null; }
  exit_of() { gate "$@" >/dev/null 2>&1; echo $?; }

  # (1) no trend file: never a silent pass — report tolerates, block fails.
  [ "$(verdict_of)" = "unable" ] && [ "$(exit_of --mode report)" -eq 0 ] && [ "$(exit_of --mode block)" -eq 1 ] \
    && ok "missing trend -> unable (report 0 / block 1)" || no "missing-trend handling"

  # (2) first scored run: no baseline to compare, must pass even in block mode.
  printf '%s' '{"runs":[{"run":1,"suiteScore":82}]}' > "$TREND"
  [ "$(verdict_of --mode block)" = "ok" ] && [ "$(exit_of --mode block)" -eq 0 ] \
    && ok "first baseline -> ok (block 0)" || no "first-baseline handling"

  # (3) drop within tolerance passes; (4) beyond tolerance regresses.
  printf '%s' '{"runs":[{"run":1,"suiteScore":82},{"run":2,"suiteScore":80}]}' > "$TREND"
  [ "$(verdict_of --mode block)" = "ok" ] && [ "$(exit_of --mode block)" -eq 0 ] \
    && ok "2pt drop within 3pt tolerance -> ok" || no "in-tolerance drop"
  printf '%s' '{"runs":[{"run":1,"suiteScore":82},{"run":2,"suiteScore":70}]}' > "$TREND"
  [ "$(verdict_of --mode block)" = "regressed" ] && [ "$(exit_of --mode block)" -eq 1 ] \
    && ok "12pt drop -> regressed (block exit 1)" || no "regression not blocked"
  # (5) report mode reports the SAME verdict but never fails the build.
  [ "$(verdict_of --mode report)" = "regressed" ] && [ "$(exit_of --mode report)" -eq 0 ] \
    && ok "report mode: same verdict, exit 0" || no "report mode exit code"
  # (6) custom tolerance widens the gate.
  [ "$(exit_of --mode block --delta 20)" -eq 0 ] \
    && ok "--delta 20 tolerates the same 12pt drop" || no "--delta not honored"
  # (7) improvement is never a regression.
  printf '%s' '{"runs":[{"run":1,"suiteScore":70},{"run":2,"suiteScore":91}]}' > "$TREND"
  [ "$(verdict_of --mode block)" = "ok" ] && ok "score improvement -> ok" || no "improvement misjudged"
  # (8) unscored runs (empty goldenset) are not evidence of quality.
  printf '%s' '{"runs":[{"run":1,"suiteScore":null}]}' > "$TREND"
  [ "$(verdict_of --mode block)" = "unable" ] && [ "$(exit_of --mode block)" -eq 1 ] \
    && ok "unscored runs -> unable, not a pass" || no "unscored-run handling"
  # (9) malformed trend fails closed in block mode.
  printf 'not json' > "$TREND"
  [ "$(verdict_of --mode block)" = "unable" ] && [ "$(exit_of --mode block)" -eq 1 ] \
    && ok "malformed trend -> unable (fail-closed)" || no "malformed trend handling"
  # (10) the gate is read-only: it must never mutate the trend it grades.
  printf '%s' '{"runs":[{"run":1,"suiteScore":82},{"run":2,"suiteScore":70}]}' > "$TREND"
  before=$(cksum < "$TREND"); gate --mode block >/dev/null 2>&1; after=$(cksum < "$TREND")
  [ "$before" = "$after" ] && ok "gate does not mutate the trend file" || no "gate wrote to the trend file"
  rm -rf "$T"
else
  echo "SKIP: eval-gate verdict fixtures (jq absent)"
fi

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
