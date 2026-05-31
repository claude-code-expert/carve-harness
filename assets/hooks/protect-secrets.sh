#!/usr/bin/env bash
# carve-protect-secrets — PreToolUse(Read/Edit/Write) 비밀 파일 접근 차단 (exit 2).
# .env.example 같은 안전 파일은 허용한다.
set -uo pipefail

input=$(cat)
path=$(printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s),t=j.tool_input||{};process.stdout.write(String(t.file_path||t.path||""))}catch{process.stdout.write("")}})' 2>/dev/null)
[ -z "$path" ] && exit 0

if printf '%s' "$path" | grep -Eq '(^|/)\.env$|(^|/)\.env\.(local|development|dev|production|prod|staging|test)$|\.pem$|\.key$|(^|/)id_(rsa|ed25519|dsa|ecdsa)$|(^|/)credentials\.json$|\.p12$|\.pfx$|(^|/)\.aws/credentials$|(^|/)\.netrc$|secrets?\.(ya?ml|json|toml)$'; then
  echo "[carve:protect-secrets] 비밀 파일 접근 차단: $path" >&2
  exit 2
fi
exit 0
