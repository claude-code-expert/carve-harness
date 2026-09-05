#!/usr/bin/env bash
# Assertions for carve-validate.sh (golden-set preflight validator).
# Each fixture injects exactly one defect; the check is that the validator names
# it and exits non-zero, so a broken golden set never reaches the expensive run.

HOOK="$(cd "$(dirname "$0")/.." && pwd)/carve-validate.sh"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

D=$(mktemp -d)
write() { cat > "$D/$1"; }   # write <name>  (heredoc on stdin)

# (1) a clean golden set validates
write good.json <<'EOF'
{"suite":"t","cases":[
  {"id":"a","version":"1.0","prompt":"p","k":2,
   "assert":[{"type":"contains","value":"x"},{"type":"not_contains","value":"y"}]},
  {"id":"b","version":"1.0","prompt":"p","setup":"true",
   "assert":[{"type":"file_exists","value":"f.txt"},{"type":"file_contains","value":"f.txt::needle"}]}
]}
EOF
out=$(bash "$HOOK" "$D/good.json"); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '0 error(s), 0 warning(s), 2 case(s)' \
  && ok "clean golden set passes (exit 0, 2 cases counted)" || no "clean set (rc=$rc) $out"

# (2) missing version — the trend comparison silently breaks without it
write nover.json <<'EOF'
{"cases":[{"id":"a","prompt":"p","assert":[{"type":"contains","value":"x"}]}]}
EOF
out=$(bash "$HOOK" "$D/nover.json"); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'missing version' \
  && ok "missing case version is an error" || no "version check (rc=$rc) $out"

# (3) unknown assert type — fail-closed at run time means a silent 0
write badtype.json <<'EOF'
{"cases":[{"id":"a","version":"1.0","prompt":"p","assert":[{"type":"containz","value":"x"}]}]}
EOF
out=$(bash "$HOOK" "$D/badtype.json"); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'unknown type' \
  && ok "unknown assert type is an error" || no "type check (rc=$rc) $out"

# (4) file_contains missing the :: separator (eval-state.sh fails it closed)
write badsep.json <<'EOF'
{"cases":[{"id":"a","version":"1.0","prompt":"p","assert":[{"type":"file_contains","value":"f.txt"}]}]}
EOF
out=$(bash "$HOOK" "$D/badsep.json"); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'file_contains needs' \
  && ok "file_contains without :: is an error" || no "separator check (rc=$rc) $out"

# (5) k outside 1..K_MAX
write badk.json <<'EOF'
{"cases":[{"id":"a","version":"1.0","prompt":"p","k":99,"assert":[{"type":"contains","value":"x"}]}]}
EOF
out=$(bash "$HOOK" "$D/badk.json"); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'k must be an integer' \
  && ok "k out of range is an error" || no "k check (rc=$rc) $out"

# (6) negative-only asserts — passes by producing nothing (reward hacking)
write negonly.json <<'EOF'
{"cases":[{"id":"a","version":"1.0","prompt":"p",
  "assert":[{"type":"not_contains","value":"x"},{"type":"not_regex","value":"y"}]}]}
EOF
out=$(bash "$HOOK" "$D/negonly.json"); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'negative asserts only' \
  && ok "negative-only case is an error" || no "positive-assert check (rc=$rc) $out"

# (7) llm-rubric only — a warning, not a blocker
write rubric.json <<'EOF'
{"cases":[{"id":"a","version":"1.0","prompt":"p","assert":[{"type":"llm-rubric","value":"good"}]}]}
EOF
out=$(bash "$HOOK" "$D/rubric.json"); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^WARN.*llm-rubric only' \
  && ok "llm-rubric-only warns but does not block" || no "rubric warn (rc=$rc) $out"

# (8) duplicate id across two files — ids key the trend
write dup1.json <<'EOF'
{"cases":[{"id":"same","version":"1.0","prompt":"p","assert":[{"type":"contains","value":"x"}]}]}
EOF
write dup2.json <<'EOF'
{"cases":[{"id":"same","version":"1.0","prompt":"p","assert":[{"type":"contains","value":"x"}]}]}
EOF
out=$(bash "$HOOK" "$D/dup1.json" "$D/dup2.json"); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'duplicate case id' \
  && ok "duplicate id across files is an error" || no "dup id check (rc=$rc) $out"

# (9) malformed JSON is reported, not swallowed
printf 'not json at all' > "$D/broken.json"
out=$(bash "$HOOK" "$D/broken.json"); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'invalid JSON' \
  && ok "malformed JSON is an error" || no "json check (rc=$rc) $out"

# (10) missing .cases key
write nocases.json <<'EOF'
{"suite":"t"}
EOF
out=$(bash "$HOOK" "$D/nocases.json"); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q '.cases is missing' \
  && ok ".cases missing is an error" || no "cases key check (rc=$rc) $out"

# (11) no files matched — running an empty golden set is never intended
out=$(bash "$HOOK" "$D/absent-*.json"); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'no golden-set files matched\|file not found' \
  && ok "no matching files is an error" || no "empty match (rc=$rc) $out"

# (12) invalid regex — JS semantics, so the check is node-gated and never silent
write badre.json <<'EOF'
{"cases":[{"id":"a","version":"1.0","prompt":"p","assert":[{"type":"regex","value":"([unclosed"}]}]}
EOF
out=$(bash "$HOOK" "$D/badre.json"); rc=$?
if command -v node >/dev/null 2>&1; then
  [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'invalid regex' \
    && ok "uncompilable regex is an error (node present)" || no "regex check (rc=$rc) $out"
else
  printf '%s' "$out" | grep -q '^SKIP.*regex compile' \
    && ok "regex check skip is reported, not silent (node absent)" || no "regex skip notice ($out)"
fi

# (13) --red flags a case that is already green before the agent does anything
write nosignal.json <<'EOF'
{"cases":[{"id":"a","version":"1.0","prompt":"p","setup":"printf x > f.txt",
  "assert":[{"type":"file_exists","value":"f.txt"},{"type":"cmd_exit0","value":"true"}]}]}
EOF
out=$(bash "$HOOK" --red "$D/nosignal.json"); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'NO-SIGNAL' \
  && ok "--red flags a case that passes with no agent work" || no "no-signal check (rc=$rc) $out"

# (14) --red reports a broken setup instead of letting the case run empty
write badsetup.json <<'EOF'
{"cases":[{"id":"a","version":"1.0","prompt":"p","setup":"exit 3",
  "assert":[{"type":"cmd_exit0","value":"test -f never.txt"}]}]}
EOF
out=$(bash "$HOOK" --red "$D/badsetup.json"); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'setup script failed' \
  && ok "--red catches a failing setup script" || no "setup check (rc=$rc) $out"

# (15) --red flags a setup that writes under a protected path. Running it from a
# shell never trips PreToolUse, but carve-eval hands it to an agent as a literal
# command, so the guard blocks it and the fixture is never built.
write protsetup.json <<'EOF'
{"cases":[{"id":"a","version":"1.0","prompt":"p",
  "setup":"mkdir -p db/migration && printf 'x' > db/migration/V1__init.sql",
  "assert":[{"type":"cmd_exit0","value":"test -f never.txt"}]}]}
EOF
out=$(bash "$HOOK" --red "$D/protsetup.json"); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'setup writes under a protected path' \
  && ok "--red flags a fixture the guard would block" || no "protected setup (rc=$rc) $out"

# (16) --red passes a case whose asserts are red before the work
write signal.json <<'EOF'
{"cases":[{"id":"a","version":"1.0","prompt":"p","setup":"printf x > f.txt",
  "assert":[{"type":"file_exists","value":"f.txt"},{"type":"cmd_exit0","value":"test -f done.txt"}]}]}
EOF
out=$(bash "$HOOK" --red "$D/signal.json"); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^RED.*사전통과 1/2' \
  && ok "--red passes a case with real signal" || no "signal case (rc=$rc) $out"

# (16) the repo's own golden set validates — the shipped cases are not decorative
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
if [ -d "$REPO/specs/goldenset" ]; then
  out=$(cd "$REPO" && bash "$HOOK"); rc=$?
  [ "$rc" -eq 0 ] && ok "repo specs/goldenset/*.json validates" || no "repo golden set invalid: $out"
  out=$(cd "$REPO" && bash "$HOOK" --red); rc=$?
  [ "$rc" -eq 0 ] && ok "repo golden set has signal in every case (--red)" || no "repo golden set NO-SIGNAL: $out"
fi

rm -rf "$D"
printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
