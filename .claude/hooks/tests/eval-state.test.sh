#!/usr/bin/env bash
# Assertions for eval-state.sh (deterministic state-assert grader).
# Builds a fixture workdir + asserts file, checks pass/fail per type and the
# fail-closed contract on unusable input.

HOOK="$(dirname "$0")/../eval-state.sh"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

W=$(mktemp -d); AF=$(mktemp)
printf 'hello state world\n' > "$W/out.txt"
( cd "$W" && git init -q && git add out.txt && git -c user.email=t@t -c user.name=t commit -qm init \
  && printf 'changed line\n' >> out.txt )

# (1) all-pass set -> empty failed array
cat > "$AF" <<'EOF'
[
  {"type":"file_exists","value":"out.txt"},
  {"type":"file_contains","value":"out.txt::state world"},
  {"type":"cmd_exit0","value":"grep -q hello out.txt"},
  {"type":"git_diff_contains","value":"changed line"},
  {"type":"contains","value":"ignored text assert"},
  {"type":"llm-rubric","value":"ignored llm assert"}
]
EOF
out=$(bash "$HOOK" "$W" "$AF")
[ "$(printf '%s' "$out" | jq '.failed | length')" = "0" ] \
  && ok "all state asserts pass (non-state types ignored)" || no "all-pass set ($out)"

# (2) each type fails when the state does not match
cat > "$AF" <<'EOF'
[
  {"type":"file_exists","value":"missing.txt"},
  {"type":"file_contains","value":"out.txt::absent needle"},
  {"type":"cmd_exit0","value":"false"},
  {"type":"git_diff_contains","value":"never in diff"}
]
EOF
out=$(bash "$HOOK" "$W" "$AF")
[ "$(printf '%s' "$out" | jq '.failed | length')" = "4" ] \
  && ok "all four state types fail on mismatch" || no "fail set ($out)"
printf '%s' "$out" | jq -e '.failed[0] == "file_exists:missing.txt"' >/dev/null \
  && ok "failed entries keep type:value format" || no "failed format ($out)"

# (3) file_contains without :: separator is fail-closed
printf '[{"type":"file_contains","value":"out.txt"}]' > "$AF"
out=$(bash "$HOOK" "$W" "$AF")
[ "$(printf '%s' "$out" | jq '.failed | length')" = "1" ] \
  && ok "file_contains without separator fails closed" || no "separator guard ($out)"

# (4) unusable input (bad JSON / missing dir) -> sentinel + exit 1
printf 'not json' > "$AF"
out=$(bash "$HOOK" "$W" "$AF"); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'eval-state:unusable' \
  && ok "malformed asserts json fails closed (exit $rc)" || no "malformed json ($rc, $out)"
printf '[]' > "$AF"
out=$(bash "$HOOK" "$W/nope" "$AF"); rc=$?
[ "$rc" -ne 0 ] && ok "missing workdir fails closed" || no "missing workdir ($rc)"

# (5) cmd_exit0 runs inside the workdir (relative paths resolve there)
printf '[{"type":"cmd_exit0","value":"test -f out.txt"}]' > "$AF"
out=$(bash "$HOOK" "$W" "$AF")
[ "$(printf '%s' "$out" | jq '.failed | length')" = "0" ] \
  && ok "cmd_exit0 cwd is the workdir" || no "cmd cwd ($out)"

# (6) REGRESSION: assert values must reach bash byte-for-byte. The reader used to
# go through @tsv, which escapes backslashes — a command building a stub script
# with `\n` arrived mangled, so a case that passes when run by hand was scored as
# a failure. Found by running the harness's own golden set against itself.
STUB_CMD=$(cat <<'EOF'
mkdir -p stubdir && printf '#!/bin/sh\nexit 7\n' > stubdir/tool && chmod +x stubdir/tool && stubdir/tool; [ $? -eq 7 ]
EOF
)
jq -n --arg v "$STUB_CMD" '[{type:"cmd_exit0", value:$v}]' > "$AF"
out=$(bash "$HOOK" "$W" "$AF")
if [ "$(printf '%s' "$out" | jq '.failed | length')" = "0" ]; then
  ok "backslash escapes survive the reader (no @tsv mangling)"
else
  no "backslash in cmd_exit0 corrupted ($out)"
fi
# The stub must be a real 2-line script — proves \n became a newline, not literal.
[ "$(wc -l < "$W/stubdir/tool" 2>/dev/null | tr -d ' ')" = "2" ] \
  && ok "printf newline escape produced a real newline" \
  || no "stub script not written as multi-line"

# (7) a value carrying a literal tab must not split the record.
TAB_CMD=$(printf 'printf "a\tb\\n" | grep -q "b"')
jq -n --arg v "$TAB_CMD" '[{type:"cmd_exit0", value:$v}]' > "$AF"
out=$(bash "$HOOK" "$W" "$AF")
[ "$(printf '%s' "$out" | jq '.failed | length')" = "0" ] \
  && ok "tab inside an assert value survives" || no "tab in value split the record ($out)"

# ── --case mode: read asserts straight out of the golden-set file ───────────
GS=$(mktemp)
cat > "$GS" <<'EOF'
{"cases":[
  {"id":"alpha","version":"1.0","prompt":"p","assert":[
    {"type":"cmd_exit0","value":"grep -qE 'n ?\\+ ?n' code.js"},
    {"type":"file_exists","value":"out.txt"}]},
  {"id":"beta","version":"1.0","prompt":"p","assert":[
    {"type":"cmd_exit0","value":"test -f never-here.txt"}]}
]}
EOF
printf 'const double = (n) => n + n;\n' > "$W/code.js"

# (8) REGRESSION GUARD — a backslash in an assert must reach grep intact.
# Relaying assert values through an LLM prompt doubled `\+` into `\\+`, which
# matches nothing; three golden-set cases scored 0 for that reason alone.
out=$(bash "$HOOK" "$W" "$GS" --case alpha)
[ "$(printf '%s' "$out" | jq '.failed | length')" = "0" ] \
  && ok "--case: backslash in regex survives to the grader (no double-escape)" \
  || no "backslash regression ($out)"

# (9) --case selects only that case's asserts
out=$(bash "$HOOK" "$W" "$GS" --case beta)
printf '%s' "$out" | jq -e '.failed | length == 1 and (.[0] | test("never-here"))' >/dev/null \
  && ok "--case grades only the named case" || no "case selection ($out)"

# (10) unknown case id is fail-closed, never an empty pass
out=$(bash "$HOOK" "$W" "$GS" --case nope); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'eval-state:unusable' \
  && ok "unknown --case id fails closed" || no "unknown case ($rc, $out)"

# (11) a duplicated id must not silently grade the first match
cat > "$GS" <<'EOF'
{"cases":[
  {"id":"dup","version":"1.0","prompt":"p","assert":[{"type":"cmd_exit0","value":"true"}]},
  {"id":"dup","version":"1.0","prompt":"p","assert":[{"type":"cmd_exit0","value":"false"}]}
]}
EOF
out=$(bash "$HOOK" "$W" "$GS" --case dup); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'eval-state:unusable' \
  && ok "duplicated --case id fails closed" || no "duplicate case ($rc, $out)"

# (12) an empty assert value must fail, never pass. `file_exists` with "" would
# probe "$W/" — a directory that always exists — and score green for nothing.
cat > "$GS" <<'EOF'
{"cases":[{"id":"empty","version":"1.0","prompt":"p","assert":[
  {"type":"file_exists","value":""},
  {"type":"cmd_exit0","value":""}
]}]}
EOF
out=$(bash "$HOOK" "$W" "$GS" --case empty)
printf '%s' "$out" | jq -e '.failed | length == 2 and all(.[]; test("<empty>"))' >/dev/null \
  && ok "empty assert value fails closed (both types)" || no "empty value ($out)"

# same contract in the bare-array mode
printf '[{"type":"file_exists","value":""}]' > "$AF"
out=$(bash "$HOOK" "$W" "$AF")
[ "$(printf '%s' "$out" | jq '.failed | length')" = "1" ] \
  && ok "empty value fails closed in array mode too" || no "empty value array mode ($out)"

rm -f "$GS"

rm -rf "$W" "$AF"
printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
