#!/usr/bin/env bash
# carve-block-destructive — PreToolUse(Bash) 위험 명령 결정적 차단 (exit 2).
# JSON은 node로 파싱(대상 프로젝트에 항상 존재). 차단 시 exit 2 + stderr 사유.
set -uo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String((j.tool_input&&j.tool_input.command)||""))}catch{process.stdout.write("")}})' 2>/dev/null)
[ -z "$cmd" ] && exit 0

block() { echo "[carve:block-destructive] 위험 명령 차단: $cmd" >&2; exit 2; }

# 1) 무조건 위험 (포크밤·디스크 파괴·전역 권한)
if printf '%s' "$cmd" | grep -Eq ':\(\)[[:space:]]*\{|[[:space:]]mkfs|dd[[:space:]]+if=.*of=/dev/|>[[:space:]]*/dev/sd|chmod[[:space:]]+-R[[:space:]]+777[[:space:]]+/'; then
  block
fi

# 2) rm 재귀+강제 + 위험 대상(/, ~, $HOME, *)
is_rm=$(printf '%s' "$cmd" | grep -Eq '(^|[^a-zA-Z])rm([[:space:]]|$)' && echo 1 || echo 0)
is_rf=$(printf '%s' "$cmd" | grep -Eq '[[:space:]]-[a-zA-Z]*r[a-zA-Z]*f|[[:space:]]-[a-zA-Z]*f[a-zA-Z]*r|[[:space:]]-r[[:space:]].*[[:space:]]-f' && echo 1 || echo 0)
is_tgt=$(printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])(/|~|\$HOME|/\*|\*|~/)([[:space:]]|/|$)' && echo 1 || echo 0)
if [ "$is_rm" = 1 ] && [ "$is_rf" = 1 ] && [ "$is_tgt" = 1 ]; then
  block
fi

# 3) git push --force to main/master
if printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+push[[:space:]].*(--force|-f)([[:space:]]|$)' \
   && printf '%s' "$cmd" | grep -Eq '(main|master)'; then
  block
fi

exit 0
