#!/usr/bin/env bash
# Assertions for the eval-gate.sh extensions (P1): `required` tags veto the mean,
# extreme scores are `suspicious`, and prompt changes without a trend update are
# `stale`. The pre-existing verdicts (unable / ok / regressed by delta) stay pinned
# in eval-init.test.sh — this suite must not change their behaviour.

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GATE="$ROOT/.claude/hooks/eval-gate.sh"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

T=$(mktemp -d); mkdir -p "$T/specs"; F="$T/specs/eval-score.json"
gate() { CLAUDE_PROJECT_DIR="$T" bash "$GATE" "$@" 2>/dev/null; }
verdict_of() { gate "$@" | jq -r '.verdict'; }
exit_of() { gate "$@" >/dev/null 2>&1; echo $?; }
# trend <prevSuite> <curSuite> <cases-json>
trend() { jq -cn --argjson p "$1" --argjson c "$2" --argjson cases "$3" \
  '{runs:[{run:1,suiteScore:$p,cases:[]},{run:2,suiteScore:$c,cases:$cases}]}' > "$F"; }

# (1) required case at 100 -> ok; required case at 50 -> regressed even though the mean rose.
trend 80 90 '[{"id":"a","caseScore":100,"tags":["required"]},{"id":"b","caseScore":80}]'
[ "$(verdict_of --mode block)" = "ok" ] && ok "required green + mean up -> ok" || no "required green ok"
trend 80 95 '[{"id":"a","caseScore":50,"tags":["required","category:domain_safety"]},{"id":"b","caseScore":100},{"id":"c","caseScore":100},{"id":"d","caseScore":100}]'
out=$(gate --mode block); rc=$?
[ "$rc" -eq 1 ] && [ "$(printf '%s' "$out" | jq -r '.verdict')" = "regressed" ] \
  && [ "$(printf '%s' "$out" | jq -r '.requiredFailed[0]')" = "a" ] \
  && ok "required case 50 -> regressed (block exit 1) despite mean 80->95" || no "required veto ($rc): $out"
[ "$(exit_of --mode report)" -eq 0 ] && ok "required veto in report mode -> exit 0, same verdict" || no "required report mode"
# untagged cases never trigger the veto (backward compatible with tag-less trends)
trend 80 95 '[{"id":"a","caseScore":50},{"id":"b","caseScore":100}]'
[ "$(verdict_of --mode block)" = "ok" ] && ok "untagged case at 50 with mean up -> ok (no veto)" || no "untagged veto"

# (2) suspicious: all-zero and all-full runs (>=3 cases) block; 2 cases never do.
trend 80 0 '[{"id":"a","caseScore":0},{"id":"b","caseScore":0},{"id":"c","caseScore":0}]'
out=$(gate --mode block); rc=$?
[ "$rc" -eq 1 ] && [ "$(printf '%s' "$out" | jq -r '.verdict')" = "suspicious" ] && [ "$(printf '%s' "$out" | jq -r '.extreme')" = "all-zero" ] \
  && ok "all cases 0 -> suspicious (block exit 1), named all-zero" || no "all-zero ($rc): $out"
trend 100 100 '[{"id":"a","caseScore":100},{"id":"b","caseScore":100},{"id":"c","caseScore":100}]'
[ "$(verdict_of --mode block)" = "suspicious" ] && [ "$(exit_of --mode report)" -eq 0 ] \
  && ok "all cases 100 -> suspicious (report exit 0)" || no "all-full"
trend 100 100 '[{"id":"a","caseScore":100},{"id":"b","caseScore":100}]'
[ "$(verdict_of --mode block)" = "ok" ] && ok "2 cases at 100 -> ok (extreme needs >= 3 cases)" || no "small run extreme"
trend 90 93 '[{"id":"a","caseScore":100},{"id":"b","caseScore":100},{"id":"c","caseScore":50},{"id":"d","caseScore":100}]'
[ "$(verdict_of --mode block)" = "ok" ] && ok "mixed scores -> ok" || no "mixed scores"

# (3) stale: prompt-bearing change without a trend update.
trend 90 90 '[{"id":"a","caseScore":90},{"id":"b","caseScore":90},{"id":"c","caseScore":90}]'
out=$(gate --mode block --changed $'CLAUDE.md\nsrc/app.ts'); rc=$?
[ "$rc" -eq 1 ] && [ "$(printf '%s' "$out" | jq -r '.verdict')" = "stale" ] && [ "$(printf '%s' "$out" | jq -r '.changed[0]')" = "CLAUDE.md" ] \
  && ok "CLAUDE.md changed, trend not -> stale (block exit 1)" || no "stale ($rc): $out"
[ "$(verdict_of --mode block --changed 'CLAUDE.md,specs/eval-score.json')" = "ok" ] \
  && ok "CLAUDE.md + trend both changed -> ok" || no "stale cleared by trend update"
[ "$(verdict_of --mode block --changed $'src/app.ts\nREADME.md')" = "ok" ] \
  && ok "non-prompt change -> ok" || no "non-prompt change"
[ "$(verdict_of --mode block --changed '.claude/rules/safety.md')" = "stale" ] && ok ".claude/** counts as prompt-bearing" || no ".claude stale"
[ "$(verdict_of --mode block --changed 'specs/goldenset/x.json')" = "stale" ] && ok "specs/goldenset/** counts as prompt-bearing" || no "goldenset stale"
[ "$(exit_of --mode report --changed 'CLAUDE.md')" -eq 0 ] && ok "stale in report mode -> exit 0" || no "stale report"
[ "$(verdict_of --mode block)" = "ok" ] && ok "no --changed -> stale check skipped" || no "no --changed"

# (4) ordering: stale beats everything else; required beats the delta ok.
trend 80 95 '[{"id":"a","caseScore":50,"tags":["required"]},{"id":"b","caseScore":100},{"id":"c","caseScore":100}]'
[ "$(verdict_of --mode block --changed 'CLAUDE.md')" = "stale" ] && ok "stale is judged before required" || no "ordering stale/required"

# (5) the live trend still passes report mode and stays a single JSON line.
L=$(mktemp -d); mkdir -p "$L/specs"; cp "$ROOT/specs/eval-score.json" "$L/specs/"
out=$(CLAUDE_PROJECT_DIR="$L" bash "$GATE" --mode report 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | grep -c '')" = "1" ] && printf '%s' "$out" | jq -e '.verdict' >/dev/null \
  && ok "live trend: report mode exit 0, one JSON line" || no "live trend ($rc): $out"
bash -n "$GATE" && ok "bash -n eval-gate.sh" || no "bash -n"

rm -rf "$T" "$L"
printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
