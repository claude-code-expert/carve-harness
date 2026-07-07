#!/usr/bin/env bash
# Assertions for stop-verify.sh: stop_hook_active loop guard (GATE-01),
# jq-absent best-effort (D-02), and set -o pipefail regression (Pitfall 5).
# jq-absence simulated via env -i PATH= + absolute bash — never uninstalls jq.

HOOK="$(dirname "$0")/../stop-verify.sh"
BASH_BIN="$(command -v bash)"
fail=0
pass=0

# (1) stop_hook_active=true -> exit 0 AND stderr carries the loop-guard marker.
out=$(printf '%s' '{"stop_hook_active":true}' | bash "$HOOK" 2>&1)
code=$?
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q '루프 방지'; then
  echo "PASS: loop guard yields (exit 0 + 루프 방지 marker)"; pass=$((pass + 1))
else
  echo "FAIL: loop guard (exit $code, marker $(printf '%s' "$out" | grep -q '루프 방지' && echo present || echo absent))"; fail=$((fail + 1))
fi

# (2) jq absent + {} -> exit 0 AND stderr carries a jq-absent warning (best-effort).
out=$(printf '%s' '{}' | env -i PATH= "$BASH_BIN" "$HOOK" 2>&1)
code=$?
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q 'jq 미설치'; then
  echo "PASS: jq-absent best-effort (exit 0 + warning)"; pass=$((pass + 1))
else
  echo "FAIL: jq-absent best-effort (exit $code)"; fail=$((fail + 1))
fi

# (3) pipefail regression — the Phase 0 root fix must survive.
if grep -q 'set -o pipefail' "$HOOK"; then
  echo "PASS: set -o pipefail preserved"; pass=$((pass + 1))
else
  echo "FAIL: set -o pipefail missing"; fail=$((fail + 1))
fi

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
