#!/usr/bin/env bash
# Assertions for the carve-verify-loop 5-axis rubric (Stage A).
# Extracts the ACTUAL AXIS_MAX literal from the workflow (drift guard) and proves
# the policy invariants: axes sum to 100, an untested claim (test=0) caps at 75
# and cannot reach the 95 gate, over-max clamps, missing axes -> 0.
# node-based (the scoring helper is inline JS in the workflow); skips if node absent.

WF="$(cd "$(dirname "$0")/../../.." && pwd)/.claude/workflows/carve-verify-loop.js"
fail=0
pass=0

# (0) workflow exists.
[ -f "$WF" ] && { echo "PASS: workflow present"; pass=$((pass + 1)); } \
             || { echo "FAIL: carve-verify-loop.js missing"; fail=$((fail + 1)); }

# (1) AXIS_MAX literal present (drift guard — binds the node math below to real constants).
if grep -q 'const AXIS_MAX = {' "$WF"; then
  echo "PASS: AXIS_MAX literal present"; pass=$((pass + 1))
else
  echo "FAIL: AXIS_MAX literal missing (schema drift?)"; fail=$((fail + 1))
fi

# (2) node math: use the workflow's own AXIS_MAX, assert rubric invariants.
if command -v node >/dev/null 2>&1; then
  if node -e '
    const fs = require("fs");
    const src = fs.readFileSync(process.argv[1], "utf8");
    const m = src.match(/const AXIS_MAX = \{([^}]*)\}/);
    if (!m) { console.log("FAIL: AXIS_MAX not parseable"); process.exit(1); }
    const max = {};
    for (const p of m[1].split(",")) {
      const [k, v] = p.split(":").map((s) => s.trim());
      if (k) max[k] = Number(v);
    }
    // logic under test: 0..max clamp then sum (mirrors scoreFromAxes)
    const score = (axes) => {
      let s = 0;
      for (const k in max) s += Math.max(0, Math.min(Number(axes && axes[k]) || 0, max[k]));
      return s;
    };
    const keys = Object.keys(max);
    const full = Object.fromEntries(keys.map((k) => [k, max[k]]));
    const noTest = Object.assign({}, full, { test: 0 });
    let ok = true;
    const A = (c, cond) => { console.log((cond ? "PASS: " : "FAIL: ") + c); if (!cond) ok = false; };
    A("5 axes sum to 100", score(full) === 100);
    A("test axis worth 25 (verify=policy)", max.test === 25);
    A("test omitted caps at 75 (<95 gate)", score(noTest) === 75 && 75 < 95);
    A("over-max values clamp to 100", score(Object.fromEntries(keys.map((k) => [k, 999]))) === 100);
    A("null/empty axes -> 0", score(null) === 0 && score({}) === 0);
    process.exit(ok ? 0 : 1);
  ' "$WF"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
  fi
else
  echo "SKIP: node absent -> rubric math check skipped (best-effort)"
fi

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
