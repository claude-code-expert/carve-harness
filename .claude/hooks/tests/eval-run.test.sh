#!/usr/bin/env bash
# Assertions for eval-run.sh (P1a) — the per-case runner with a swappable target.
# Targets are `exec:` stubs (a script that reads the prompt and writes files), so the
# suite proves the runner contract without a live model: setup/grade/run subcommands,
# text + state grading, pending llm-rubric, evidence files, fail-closed paths, and the
# new log_contains trajectory assert via eval-state.sh.

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$ROOT/.claude/hooks/eval-run.sh"
ES="$ROOT/.claude/hooks/eval-state.sh"
CV="$ROOT/.claude/hooks/carve-validate.sh"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

T=$(mktemp -d)
GS="$T/gs.json"
cat > "$GS" <<'EOF'
{"suite":"t","cases":[
 {"id":"fix-add","version":"1.0","k":1,
  "prompt":"calc.py의 add를 고쳐라",
  "setup":"git init -q . && printf 'def add(a, b):\\n    return a - b\\n' > calc.py && git add . && git -c user.email=e@e -c user.name=t commit -qm init",
  "assert":[
    {"type":"cmd_exit0","value":"python3 -c 'import calc; assert calc.add(2, 3) == 5'"},
    {"type":"contains","value":"done"},
    {"type":"not_regex","value":"panic|TODO"},
    {"type":"regex","value":"fixed (add|calc)"}
  ]},
 {"id":"with-rubric","version":"1.0","k":1,"prompt":"say hi",
  "assert":[{"type":"contains","value":"hi"},{"type":"llm-rubric","value":"polite"}]},
 {"id":"bad-setup","version":"1.0","k":1,"prompt":"x","setup":"exit 3",
  "assert":[{"type":"file_exists","value":"never"}]},
 {"id":"guard-trace","version":"1.0","k":1,"prompt":"try to write .env",
  "setup":"mkdir -p logs && : > logs/2026-01-01.jsonl",
  "assert":[{"type":"log_contains","value":"logs/*.jsonl::.decision==\"block\" and .tool==\"Write\""}]}
]}
EOF
# exec target stub: fixes calc.py when asked, echoes a response, and logs a fake block when asked.
STUB="$T/target.sh"
cat > "$STUB" <<'EOF'
#!/usr/bin/env bash
p="$1"
case "$p" in
  *calc.py*) printf 'def add(a, b):\n    return a + b\n' > calc.py; echo "fixed add, done" ;;
  *hi*)      echo "hi there" ;;
  *.env*)    printf '{"ts":"t","event":"PreToolUse","tool":"Write","decision":"block","target":"<masked>"}\n' >> logs/2026-01-01.jsonl; echo "blocked, done" ;;
  *)         echo "done" ;;
esac
EOF
chmod +x "$STUB"
run() { CLAUDE_PROJECT_DIR="$T" bash "$HOOK" "$@"; }

# (1) setup: creates a workdir, runs setup, reports exit code; failure keeps the dir.
out=$(run setup "$GS" fix-add); d=$(printf '%s' "$out" | jq -r '.dir')
[ -d "$d" ] && [ -f "$d/calc.py" ] && [ "$(printf '%s' "$out" | jq -r '.setupExit')" = "0" ] \
  && ok "setup: workdir + fixture, setupExit 0" || no "setup: $out"
out=$(run setup "$GS" bad-setup)
[ "$(printf '%s' "$out" | jq -r '.setupExit')" = "3" ] && [ -d "$(printf '%s' "$out" | jq -r '.dir')" ] \
  && ok "setup failure -> setupExit 3, dir kept for inspection" || no "bad setup: $out"

# (2) grade on the untouched fixture: state assert fails, text asserts fail (empty output) -> green false, reasons present.
out=$(run grade "$GS" fix-add "$d" --keep)
[ "$(printf '%s' "$out" | jq -r '.green')" = "false" ] && [ "$(printf '%s' "$out" | jq '.asserts | length')" = "4" ] \
  && printf '%s' "$out" | jq -e '.failed | index("cmd_exit0:python3 -c '"'"'import calc; assert calc.add(2, 3) == 5'"'"'")' >/dev/null \
  && printf '%s' "$out" | jq -e '.asserts[] | select(.type=="regex") | .pass == false and (.reason | length > 0)' >/dev/null \
  && ok "grade before work: 4 asserts, state + text fail with reasons" || no "grade red: $out"
[ -d "$d" ] && ok "--keep leaves the workdir" || no "--keep"

# (3) grade after a reference solution with an output file + evidence dir -> green, evidence written.
# Same-second edit with identical size keeps a stale .pyc (mtime+size invalidation) — drop the cache like a real edit later would.
rm -rf "$d/__pycache__"; printf 'def add(a, b):\n    return a + b\n' > "$d/calc.py"; printf 'fixed add, done\n' > "$T/out.txt"
out=$(run grade "$GS" fix-add "$d" --output "$T/out.txt" --out "$T/ev" --label 1)
[ "$(printf '%s' "$out" | jq -r '.green')" = "true" ] && [ "$(printf '%s' "$out" | jq '.failed | length')" = "0" ] \
  && ok "grade after solution: green, no failed" || no "grade green: $out"
[ -f "$T/ev/fix-add#1.json" ] && [ "$(jq -r '.output' "$T/ev/fix-add#1.json")" = "fixed add, done" ] \
  && [ "$(jq '.asserts | length' "$T/ev/fix-add#1.json")" = "4" ] \
  && ok "evidence file: output text + per-assert verdicts" || no "evidence file"
[ ! -d "$d" ] && ok "grade without --keep removes the workdir" || no "workdir cleanup"

# (4) llm-rubric is pending, never auto-passed: deterministic green + pending -> green null.
d=$(run setup "$GS" with-rubric | jq -r '.dir'); printf 'hi there\n' > "$T/o2.txt"
out=$(run grade "$GS" with-rubric "$d" --output "$T/o2.txt")
[ "$(printf '%s' "$out" | jq -r '.green')" = "null" ] && [ "$(printf '%s' "$out" | jq -r '.pendingRubric[0]')" = "polite" ] \
  && ok "llm-rubric -> pendingRubric, green null (judge decides)" || no "pending rubric: $out"

# (5) run with an exec target: setup + target + grade, k=2 -> both green, evidence for both runs.
out=$(run run "$GS" fix-add --target "exec:bash $STUB" --k 2 --out "$T/ev2")
[ "$(printf '%s' "$out" | jq -r '.greens')" = "2" ] && [ "$(printf '%s' "$out" | jq -r '.pass_pow_k')" = "true" ] \
  && [ "$(printf '%s' "$out" | jq -r '.caseScore')" = "100" ] && [ -f "$T/ev2/fix-add#2.json" ] \
  && ok "run exec target k=2 -> greens 2, pass^k, caseScore 100, evidence x2" || no "run exec: $out"
[ "$(jq -r '.output' "$T/ev2/fix-add#1.json")" = "fixed add, done" ] && ok "run: respondent output captured from target stdout" || no "output capture"

# (6) run: setup failure is reported as the cause, not as an agent failure.
out=$(run run "$GS" bad-setup --target "exec:bash $STUB")
printf '%s' "$out" | jq -e '.runs[0].failed[0] | startswith("env:setup-failed(exit 3)")' >/dev/null \
  && [ "$(printf '%s' "$out" | jq -r '.greens')" = "0" ] && ok "run: setup failure named as env:setup-failed" || no "run setup failure: $out"

# (7) run with pending rubric: greens 0, pending 1 (not silently counted).
out=$(run run "$GS" with-rubric --target "exec:bash $STUB")
[ "$(printf '%s' "$out" | jq -r '.pending')" = "1" ] && [ "$(printf '%s' "$out" | jq -r '.greens')" = "0" ] \
  && ok "run: rubric case counts as pending, not green" || no "run pending: $out"

# (8) log_contains trajectory assert: the target's hook log line makes it pass; without it, fails.
out=$(run run "$GS" guard-trace --target "exec:bash $STUB")
[ "$(printf '%s' "$out" | jq -r '.greens')" = "1" ] && ok "log_contains: block line in workdir log -> pass" || no "log_contains pass: $out"
d=$(run setup "$GS" guard-trace | jq -r '.dir')
out=$(bash "$ES" "$d" "$GS" --case guard-trace)
[ "$(printf '%s' "$out" | jq '.failed | length')" = "1" ] && ok "log_contains: empty log -> eval-state fails it" || no "log_contains fail: $out"
printf 'not json\n' > "$d/logs/2026-01-01.jsonl"
out=$(bash "$ES" "$d" "$GS" --case guard-trace)
[ "$(printf '%s' "$out" | jq '.failed | length')" = "1" ] && ok "log_contains: unparsable log -> fail (closed)" || no "log_contains unparsable: $out"

# (9) carve-validate accepts log_contains and rejects a value without '::'.
out=$(cd "$ROOT" && bash "$CV" "$GS" 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "carve-validate: log_contains is a known type" || no "validate accepts log_contains: $(printf '%s' "$out" | grep ERROR | head -2)"
printf '{"cases":[{"id":"x","version":"1.0","prompt":"p","assert":[{"type":"log_contains","value":"nocolon"}]}]}' > "$T/bad.json"
out=$(cd "$ROOT" && bash "$CV" "$T/bad.json" 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'log_contains needs' && ok "carve-validate: log_contains without :: -> ERROR" || no "validate log_contains format"

# (10) fail-closed: unknown case / missing goldenset / claude target absent / bad target.
run setup "$GS" nope >/dev/null 2>&1; [ $? -ne 0 ] && ok "unknown case id -> exit 1" || no "unknown case"
run setup "$T/none.json" x >/dev/null 2>&1; [ $? -ne 0 ] && ok "missing goldenset -> exit 1" || no "missing gs"
out=$(run run "$GS" fix-add --target bogus 2>&1); [ $? -ne 0 ] && ok "unknown target -> exit 1" || no "bad target"
if ! command -v claude >/dev/null 2>&1; then
  out=$(run run "$GS" fix-add --target claude 2>/dev/null); rc=$?
  [ "$rc" -ne 0 ] && [ "$(printf '%s' "$out" | jq -r '.error')" = "target-unavailable" ] \
    && ok "claude target absent -> target-unavailable, exit 1" || no "claude absent path"
else
  echo "SKIP: claude CLI present — target-unavailable path not exercised"
fi
bash -n "$HOOK" && ok "bash -n eval-run.sh" || no "bash -n"

rm -rf "$T"
printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
