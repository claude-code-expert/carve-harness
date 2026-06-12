#!/usr/bin/env bash
# carve-protect-secrets — PreToolUse(Read/Edit/Write) 비밀 파일 접근 차단 (exit 2).
# .env.example 같은 안전 파일은 허용한다.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_metrics.sh" 2>/dev/null || true

input=$(cat)
path=$(printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s),t=j.tool_input||{};process.stdout.write(String(t.file_path||t.path||""))}catch{process.stdout.write("")}})' 2>/dev/null)
[ -z "$path" ] && exit 0

# 안전 파일 허용 (.env.example 등 — 차단 패턴보다 먼저, 대소문자 무시)
if printf '%s' "$path" | grep -Eqi '\.(example|sample|template|dist)$'; then
  exit 0
fi

# 차단: 대소문자 무시(-i, .ENV 우회 방지) + .env 변형은 구분자 무관(.env.local·.env-local·.env_ci)
if printf '%s' "$path" | grep -Eqi '(^|/)\.env([._-][A-Za-z0-9._-]+)?$|\.pem$|\.key$|(^|/)id_(rsa|ed25519|dsa|ecdsa)$|(^|/)credentials\.json$|\.p12$|\.pfx$|(^|/)\.aws/credentials$|(^|/)\.netrc$|secrets?\.(ya?ml|json|toml)$'; then
  echo "[carve:protect-secrets] 비밀 파일 접근 차단: $path" >&2
  carve_metric protect-secrets block
  exit 2
fi
exit 0
