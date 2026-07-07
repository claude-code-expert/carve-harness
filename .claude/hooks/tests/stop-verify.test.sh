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

# (4) loop-yield logs exactly one line (SC1/D-03) and the exit code is unchanged.
tmp=$(mktemp -d); L="$tmp/logs/$(date -u +%F).jsonl"
out=$(printf '%s' '{"stop_hook_active":true}' | CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" 2>/dev/null)
code=$?
if [ "$code" -eq 0 ] \
   && [ "$(tail -1 "$L" 2>/dev/null | jq -r '.event' 2>/dev/null)" = "Stop" ] \
   && [ "$(tail -1 "$L" 2>/dev/null | jq -r '.decision' 2>/dev/null)" = "loop-yield" ]; then
  echo "PASS: loop-yield logs one line (exit 0 + .decision==loop-yield)"; pass=$((pass + 1))
else
  echo "FAIL: loop-yield log"; fail=$((fail + 1))
fi
rm -rf "$tmp"

# (5) D-05: log failure (unwritable logs) does not change the loop-yield exit 0.
tmp=$(mktemp -d); touch "$tmp/logs"   # regular file named logs => mkdir fails
printf '%s' '{"stop_hook_active":true}' | CLAUDE_PROJECT_DIR="$tmp" bash "$HOOK" >/dev/null 2>&1
[ $? -eq 0 ] && { echo "PASS: unwritable logs -> loop-yield still exit 0"; pass=$((pass + 1)); } \
             || { echo "FAIL: unwritable logs exit 0"; fail=$((fail + 1)); }
rm -rf "$tmp"

# (6) source: pass/fail/loop-yield log calls present (jq-absent branch stays log-free).
if grep -q 'Stop verify loop-yield' "$HOOK" \
   && grep -q 'Stop verify pass' "$HOOK" \
   && grep -q 'Stop verify fail' "$HOOK"; then
  echo "PASS: pass/fail/loop-yield log calls present"; pass=$((pass + 1))
else
  echo "FAIL: Stop log calls missing"; fail=$((fail + 1))
fi

# (7,8) GATE-03: verification is scoped to changed stacks (SC2). Uses a throwaway
# git repo with a stub gradlew that touches a marker when the gradle stack runs.
ABS_HOOK="$(cd "$(dirname "$0")/.." && pwd)/stop-verify.sh"
if command -v git >/dev/null 2>&1; then
  gd=$(mktemp -d)
  (
    cd "$gd" || exit
    git init -q
    printf '#!/usr/bin/env bash\ntouch ran-gradle\n' > gradlew; chmod +x gradlew
    echo 'plugins {}' > build.gradle
    git add -A; git -c user.email=t@t -c user.name=t commit -qm init
  )
  # (7) only a .md changed -> gradle stack skipped (no marker).
  ( cd "$gd" && echo note > notes.md && printf '%s' '{}' | CLAUDE_PROJECT_DIR="$gd" bash "$ABS_HOOK" >/dev/null 2>&1 )
  [ ! -f "$gd/ran-gradle" ] && { echo "PASS: GATE-03 untouched java -> gradle skipped (SC2)"; pass=$((pass + 1)); } \
                            || { echo "FAIL: GATE-03 skip"; fail=$((fail + 1)); }
  # (8) a .java changed -> gradle stack runs (marker created).
  ( cd "$gd" && echo 'class X {}' > X.java && printf '%s' '{}' | CLAUDE_PROJECT_DIR="$gd" bash "$ABS_HOOK" >/dev/null 2>&1 )
  [ -f "$gd/ran-gradle" ] && { echo "PASS: GATE-03 changed java -> gradle ran (SC2)"; pass=$((pass + 1)); } \
                          || { echo "FAIL: GATE-03 run"; fail=$((fail + 1)); }
  rm -rf "$gd"
else
  echo "SKIP: GATE-03 fixture (git absent)"
fi

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
