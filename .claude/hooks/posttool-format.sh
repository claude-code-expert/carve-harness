#!/usr/bin/env bash
# PostToolUse: 확장자로 언어 감지 후 포맷 (후처리 전용)
f=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
case "$f" in
  *.java)     [ -x ./gradlew ] && ./gradlew spotlessApply -PspotlessFiles="$f" -q 2>/dev/null ;;
  *.ts|*.tsx|*.js|*.jsx) command -v pnpm >/dev/null && pnpm exec prettier --write "$f" 2>/dev/null ;;
esac
exit 0
