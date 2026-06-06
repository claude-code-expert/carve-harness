#!/usr/bin/env bash
# carve-anti-slop — PostToolUse(Write/Edit) 시각·문서 슬롭 경고 (차단 아님).
# check-slop.mjs로 검사해 ERROR가 있으면 stderr로 경고만 한다(exit 0).
# 의도적 디자인 시스템 경로(presentation/slides)는 예외.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_metrics.sh" 2>/dev/null || true

input=$(cat)
path=$(printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s),t=j.tool_input||{};process.stdout.write(String(t.file_path||t.path||""))}catch{process.stdout.write("")}})' 2>/dev/null)
[ -z "$path" ] && exit 0

case "$path" in
  *.html|*.htm|*.css|*.svg|*.md|*.markdown) ;;
  *) exit 0 ;;
esac
# 예외: 의도적 디자인 시스템
case "$path" in
  */presentation/*|*/slides/*) exit 0 ;;
esac

script="${CLAUDE_PROJECT_DIR:-.}/.claude/skills/clean-html/scripts/check-slop.mjs"
[ -f "$script" ] || exit 0

out=$(node "$script" "$path" 2>&1) || true
if printf '%s' "$out" | grep -q 'ERROR'; then
  echo "[carve:anti-slop] AI 슬롭 경고 (차단 아님 — 의도적이면 무시):" >&2
  printf '%s\n' "$out" >&2
  carve_metric anti-slop warn
fi
exit 0
