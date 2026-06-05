#!/usr/bin/env bash
# carve-pre-commit-lint — PreToolUse(Bash): git commit 전 린트. 실패 시 exit 2.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_metrics.sh" 2>/dev/null || true
input=$(cat)
cmd=$(printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String((j.tool_input&&j.tool_input.command)||""))}catch{process.stdout.write("")}})' 2>/dev/null)
printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+commit' || exit 0
LINT="{{HOOK_LINT_CMD}}"
LINT="${CARVE_LINT_CMD:-$LINT}"
[ -z "$LINT" ] && exit 0
if ! eval "$LINT" >/dev/null 2>&1; then
  echo "[carve:pre-commit-lint] 린트 실패 — 커밋 차단: $LINT" >&2
  carve_metric pre-commit-lint block
  exit 2
fi
carve_metric pre-commit-lint pass
exit 0
