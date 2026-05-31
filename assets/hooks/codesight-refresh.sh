#!/usr/bin/env bash
# carve-codesight-refresh — PreToolUse(Bash): git commit 시 .codesight/ 백그라운드 갱신 (비차단).
set -uo pipefail
input=$(cat)
cmd=$(printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String((j.tool_input&&j.tool_input.command)||""))}catch{process.stdout.write("")}})' 2>/dev/null)
printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+commit' || exit 0
command -v npx >/dev/null 2>&1 && (npx --yes codesight -o .codesight >/dev/null 2>&1 &)
exit 0
