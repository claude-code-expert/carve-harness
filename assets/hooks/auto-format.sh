#!/usr/bin/env bash
# carve-auto-format — PostToolUse(Edit/Write): 수정 파일 포맷 (비차단).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_metrics.sh" 2>/dev/null || true
input=$(cat)
path=$(printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s),t=j.tool_input||{};process.stdout.write(String(t.file_path||t.path||""))}catch{process.stdout.write("")}})' 2>/dev/null)
[ -z "$path" ] && exit 0
FMT="{{HOOK_FORMAT_CMD}}"
FMT="${CARVE_FORMAT_CMD:-$FMT}"
[ -z "$FMT" ] && exit 0
eval "$FMT \"$path\"" >/dev/null 2>&1 || true
carve_metric auto-format fire
exit 0
