#!/usr/bin/env bash
# carve-harness 설치 래퍼 — npx 우선, 로컬 소스면 node 직접.
# 사용법:
#   curl -fsSL <url>/install.sh | bash            # 현재 디렉토리에 설치
#   bash install.sh /path/to/project              # 지정 디렉토리
#   bash install.sh --uninstall [dir]             # 제거
set -euo pipefail

ACTION="install"
if [ "${1:-}" = "--uninstall" ]; then ACTION="uninstall"; shift; fi
DIR="${1:-$(pwd)}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
LOCAL_BIN="$HERE/bin/carve.ts"

if [ -f "$LOCAL_BIN" ] && command -v node >/dev/null 2>&1; then
  exec node "$LOCAL_BIN" "$ACTION" "$DIR"
elif command -v npx >/dev/null 2>&1; then
  exec npx carve-harness@latest "$ACTION" "$DIR"
else
  echo "carve-harness: Node.js(>=22.18) 또는 npx가 필요합니다." >&2
  exit 1
fi
