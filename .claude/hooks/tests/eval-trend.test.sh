#!/usr/bin/env bash
# Assertions for eval-trend.sh — deterministic read/append of specs/eval-score.json.
# Pins: run ordinal and version come from the script (caller values ignored),
# append-only integrity via prevHash (tampering an earlier run blocks the next
# append), fail-closed on unusable input, atomicity, and the live trend's shape.

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$ROOT/.claude/hooks/eval-trend.sh"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

T=$(mktemp -d); mkdir -p "$T/specs"; printf '1.2.3\n' > "$T/VERSION"
F="$T/specs/eval-score.json"
run() { CLAUDE_PROJECT_DIR="$T" bash "$HOOK" "$@"; }
entry() { # <score> [caseVersion] -> path of an entry file (with wrong run/version to prove they are overridden)
  local p; p=$(mktemp)
  jq -cn --argjson s "$1" --arg cv "${2:-1.0}" '{run: 999, version: "9.9.9", config: "t", suiteScore: $s, threshold: 70,
    cases: [{id: "c1", caseVersion: $cv, caseScore: $s, k: 1}]}' > "$p"; printf '%s' "$p"
}

# (1) read on a missing file -> runs 0, version from VERSION.
out=$(run read)
[ "$(printf '%s' "$out" | jq -r '.runs')" = "0" ] && [ "$(printf '%s' "$out" | jq -r '.version')" = "1.2.3" ] \
  && ok "read: missing file -> runs 0, version 1.2.3" || no "read missing: $out"

# (2) first append creates the file; run=1, version from VERSION, caller's run/version ignored.
out=$(run append "$(entry 80)")
[ "$(jq -r '.runs | length' "$F")" = "1" ] && [ "$(jq -r '.runs[0].run' "$F")" = "1" ] \
  && [ "$(jq -r '.runs[0].version' "$F")" = "1.2.3" ] && [ "$(jq -r '.runs[0].suiteScore' "$F")" = "80" ] \
  && ok "append #1: creates file, run=1, version from VERSION (caller 999/9.9.9 ignored)" || no "append #1: $(cat "$F")"

# (3) second append: run=2, prevHash present and equal to the canonical hash of runs[:-1].
run append "$(entry 90 1.1)" >/dev/null
h_stored=$(jq -r '.runs[1].prevHash' "$F")
h_expect=$(jq -cS '.runs[:-1]' "$F" | { command -v sha256sum >/dev/null 2>&1 && sha256sum || shasum -a 256; } | awk '{print $1}')
[ "$(jq -r '.runs | length' "$F")" = "2" ] && [ "$(jq -r '.runs[1].run' "$F")" = "2" ] && [ "$h_stored" = "$h_expect" ] \
  && ok "append #2: run=2, prevHash chains to prior runs" || no "append #2 chain (stored=$h_stored expect=$h_expect)"

# (4) read reflects the last run.
out=$(run read)
[ "$(printf '%s' "$out" | jq -r '.runs')" = "2" ] && [ "$(printf '%s' "$out" | jq -r '.lastSuiteScore')" = "90" ] \
  && [ "$(printf '%s' "$out" | jq -r '.lastCaseVersions[0].caseVersion')" = "1.1" ] \
  && ok "read: runs 2, lastSuiteScore 90, lastCaseVersions from the last run" || no "read after appends: $out"

# (5) tampering: change one byte of run 1 -> next append refuses, file unchanged.
before=$(cat "$F")
jq '.runs[0].suiteScore = 81' "$F" > "$T/x" && mv "$T/x" "$F"
tampered=$(cat "$F")
run append "$(entry 70)" >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && [ "$(cat "$F")" = "$tampered" ] && [ "$(jq -r '.runs | length' "$F")" = "2" ] \
  && ok "tampered earlier run -> append exit 1, file untouched" || no "tamper guard (rc $rc)"
printf '%s\n' "$before" > "$F"
run append "$(entry 70)" >/dev/null 2>&1 && [ "$(jq -r '.runs | length' "$F")" = "3" ] \
  && ok "restored trend -> append proceeds (run 3)" || no "append after restore"

# (6) existing runs are never rewritten by an append (byte-compare runs[:-1]).
pre=$(jq -cS '.runs' "$F")
run append "$(entry 60)" >/dev/null
post=$(jq -cS '.runs[:-1]' "$F")
[ "$pre" = "$post" ] && ok "append leaves prior runs byte-identical" || no "prior runs changed by append"

# (7) fail-closed: malformed trend / malformed entry / missing entry.
printf 'not json' > "$T/bad.json"
run append "$(entry 50)" --file "$T/bad.json" >/dev/null 2>&1; [ $? -ne 0 ] && [ "$(cat "$T/bad.json")" = "not json" ] \
  && ok "malformed trend -> exit 1, untouched" || no "malformed trend"
run read --file "$T/bad.json" >/dev/null 2>&1; [ $? -ne 0 ] && ok "read malformed -> exit 1" || no "read malformed"
printf '{"suiteScore": 1}' > "$T/e.json"
run append "$T/e.json" >/dev/null 2>&1; [ $? -ne 0 ] && ok "entry without cases[] -> exit 1" || no "entry validation"
run append "$T/nope.json" >/dev/null 2>&1; [ $? -ne 0 ] && ok "missing entry file -> exit 1" || no "missing entry"
run bogus >/dev/null 2>&1; [ $? -ne 0 ] && ok "unknown command -> exit 1" || no "unknown command"

# (8) the live trend reads cleanly and appending to a COPY yields run 5 with the repo VERSION.
L=$(mktemp -d); mkdir -p "$L/specs"; cp "$ROOT/specs/eval-score.json" "$L/specs/"; cp "$ROOT/VERSION" "$L/VERSION"
out=$(CLAUDE_PROJECT_DIR="$L" bash "$HOOK" read)
[ "$(printf '%s' "$out" | jq -r '.runs')" = "4" ] && ok "live trend: 4 runs readable" || no "live trend read: $out"
CLAUDE_PROJECT_DIR="$L" bash "$HOOK" append "$(entry 95)" >/dev/null 2>&1
[ "$(jq -r '.runs[-1].run' "$L/specs/eval-score.json")" = "5" ] && [ "$(jq -r '.runs[-1].version' "$L/specs/eval-score.json")" = "$(tr -d '[:space:]' < "$ROOT/VERSION")" ] \
  && ok "live copy: append -> run 5 tagged with repo VERSION" || no "live copy append"
bash -n "$HOOK" && ok "bash -n eval-trend.sh" || no "bash -n"

rm -rf "$T" "$L"
printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
