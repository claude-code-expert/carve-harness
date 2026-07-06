#!/usr/bin/env bash
# PreToolUse: 보호 파일 수정 차단 (차단은 반드시 exit 2)
f=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
case "$f" in
  *.env|*/application-prod.yml|*secret*|*/db/migration/*)
    echo "[guard] 보호 파일 수정 차단: $f" >&2; exit 2;;
esac
exit 0
