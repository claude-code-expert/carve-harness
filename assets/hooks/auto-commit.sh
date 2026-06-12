#!/usr/bin/env bash
# carve-auto-commit — Stop: 세션 종료 시 자동 커밋 (선택·기본 OFF, 비차단).
# 이중 옵트인: 설치돼 있어도 CARVE_AUTO_COMMIT=on 일 때만 동작한다
# (베이스라인 가드레일 "명시 요청 없는 커밋 금지"와 충돌하지 않도록).
set -uo pipefail
cat >/dev/null
[ "${CARVE_AUTO_COMMIT:-}" = "on" ] || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
# 변경이 없으면 아무것도 하지 않는다
if git diff --quiet && git diff --cached --quiet; then exit 0; fi
# tracked 파일만 스테이징(-u) — untracked(.env·빌드 산출물 등) 의도치 않은 포함 방지
git add -u >/dev/null 2>&1 || exit 0
git commit -m "chore: auto-commit (carve session end)" >/dev/null 2>&1 || true
exit 0
