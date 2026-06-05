#!/usr/bin/env bash
# carve-pre-push-test — PreToolUse(Bash): git push 전 테스트. 실패 시 exit 2.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_metrics.sh" 2>/dev/null || true
input=$(cat)
cmd=$(printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String((j.tool_input&&j.tool_input.command)||""))}catch{process.stdout.write("")}})' 2>/dev/null)
printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+push' || exit 0
TEST="{{HOOK_TEST_CMD}}"
TEST="${CARVE_TEST_CMD:-$TEST}"
[ -z "$TEST" ] && exit 0
if ! eval "$TEST" >/dev/null 2>&1; then
  echo "[carve:pre-push-test] 테스트 실패 — 푸시 차단: $TEST" >&2
  carve_metric pre-push-test block
  exit 2
fi
carve_metric pre-push-test pass
exit 0
