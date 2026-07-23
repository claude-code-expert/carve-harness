#!/usr/bin/env bash
# Assertions for carve-eval's deterministic grader (Stage B).
# Extracts the <grade-helper> block from carve-eval.js and node-evals the REAL
# gradeAssertions (no drift), proving: contains/regex + negations, fail-closed on
# invalid regex / unknown type, llm-rubric skipped by the deterministic grader.
# Also validates the shipped example golden set parses. node/jq absent -> skip.

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WF="$ROOT/.claude/workflows/carve-eval.js"
EX="$ROOT/.claude/skills/eval-goldenset/example-goldenset.json"
fail=0
pass=0

# (0) workflow + example present.
[ -f "$WF" ] && { echo "PASS: carve-eval.js present"; pass=$((pass + 1)); } \
             || { echo "FAIL: carve-eval.js missing"; fail=$((fail + 1)); }

# (1) grade-helper block extractable (marker guard).
BLOCK="$(sed -n '/<grade-helper>/,/<\/grade-helper>/p' "$WF")"
if [ -n "$BLOCK" ] && printf '%s' "$BLOCK" | grep -q 'const gradeAssertions'; then
  echo "PASS: <grade-helper> block extractable"; pass=$((pass + 1))
else
  echo "FAIL: <grade-helper> block missing"; fail=$((fail + 1))
fi

# (2) node-eval the real grader against a truth table.
if command -v node >/dev/null 2>&1; then
  T="$(mktemp)"; mv "$T" "$T.mjs"; T="$T.mjs"
  printf '%s\n' "$BLOCK" > "$T"
  cat >> "$T" <<'EOF'
const A = (c, cond) => { console.log((cond ? "PASS: " : "FAIL: ") + c); if (!cond) process.exitCode = 1; };
A("contains pass", gradeAssertions("has 14일 here", [{ type: "contains", value: "14일" }]).passed === true);
A("contains fail", gradeAssertions("nope", [{ type: "contains", value: "14일" }]).passed === false);
A("not_contains catches banned word", gradeAssertions("무조건 환불", [{ type: "not_contains", value: "무조건" }]).passed === false);
A("regex pass", gradeAssertions("환불 가능", [{ type: "regex", value: "환불|반품" }]).passed === true);
A("not_regex catches PII", gradeAssertions("010-1234-5678", [{ type: "not_regex", value: "010-\\d{4}-\\d{4}" }]).passed === false);
A("invalid regex is fail-closed", gradeAssertions("x", [{ type: "regex", value: "(" }]).passed === false);
A("unknown assert type is fail-closed", gradeAssertions("x", [{ type: "bogus", value: "y" }]).passed === false);
A("llm-rubric skipped by det grader", gradeAssertions("x", [{ type: "llm-rubric", value: "y" }]).passed === true);
A("state types skipped by text grader", gradeAssertions("x", [{ type: "file_exists", value: "a" }, { type: "file_contains", value: "a::b" }, { type: "cmd_exit0", value: "true" }, { type: "git_diff_contains", value: "c" }]).passed === true);
A("empty asserts pass", gradeAssertions("x", []).passed === true);
EOF
  if node "$T"; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
  rm -f "$T"
else
  echo "SKIP: node absent -> grader math check skipped (best-effort)"
fi

# (3) shipped example golden set is valid JSON with >=1 case.
if command -v jq >/dev/null 2>&1; then
  if jq -e '.cases | length > 0' "$EX" >/dev/null 2>&1; then
    echo "PASS: example-goldenset.json valid (>=1 case)"; pass=$((pass + 1))
  else
    echo "FAIL: example-goldenset.json invalid or empty"; fail=$((fail + 1))
  fi
else
  echo "SKIP: jq absent -> example json check skipped"
fi

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
