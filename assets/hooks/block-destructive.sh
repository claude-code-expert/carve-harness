#!/usr/bin/env bash
# carve-block-destructive — PreToolUse(Bash) 위험 명령 결정적 차단 (exit 2).
# JSON은 node로 파싱(대상 프로젝트에 항상 존재). 차단 시 exit 2 + stderr 사유.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_metrics.sh" 2>/dev/null || true

input=$(cat)
cmd=$(printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String((j.tool_input&&j.tool_input.command)||""))}catch{process.stdout.write("")}})' 2>/dev/null)
[ -z "$cmd" ] && exit 0

block() { echo "[carve:block-destructive] 위험 명령 차단: $cmd" >&2; carve_metric block-destructive block; exit 2; }

# 인용부호 제거 정규화 — rm -rf "/" 처럼 위험 인자에 인용부호를 섞은 우회를 막는다(권한 777 변형 포함).
# 트레이드오프: 문자열에 위험 명령을 담은 명령(예: git commit -m "rm -rf /")도 과차단된다.
# 결정적 안전 훅이므로 fail-closed를 택한다.
norm=$(printf '%s' "$cmd" | tr -d "\"'")

# 1) 무조건 위험 (포크밤·디스크 파괴·전역 권한 — chmod는 0777·멀티플래그·플래그없음 변형 포함)
if printf '%s' "$norm" | grep -Eq ':\(\)[[:space:]]*\{|[[:space:]]mkfs|dd[[:space:]]+if=.*of=/dev/|>[[:space:]]*/dev/sd|chmod[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*0?777[[:space:]]+/([[:space:]]|$)'; then
  block
fi

# 2) rm 재귀+강제 + 위험 대상(/, ~, $HOME, *)
is_rm=$(printf '%s' "$norm" | grep -Eq '(^|[^a-zA-Z])rm([[:space:]]|$)' && echo 1 || echo 0)
is_rf=$(printf '%s' "$norm" | grep -Eq '[[:space:]]-[a-zA-Z]*r[a-zA-Z]*f|[[:space:]]-[a-zA-Z]*f[a-zA-Z]*r|[[:space:]]-r[[:space:]].*[[:space:]]-f' && echo 1 || echo 0)
is_tgt=$(printf '%s' "$norm" | grep -Eq '(^|[[:space:]])(/|~|\$HOME|/\*|\*|~/)([[:space:]]|/|$)' && echo 1 || echo 0)
if [ "$is_rm" = 1 ] && [ "$is_rf" = 1 ] && [ "$is_tgt" = 1 ]; then
  block
fi

# 3) git push --force to main/master
if printf '%s' "$norm" | grep -Eq 'git[[:space:]]+push[[:space:]].*(--force|-f)([[:space:]]|$)' \
   && printf '%s' "$norm" | grep -Eq '(main|master)'; then
  block
fi

exit 0
