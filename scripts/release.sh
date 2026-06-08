#!/usr/bin/env bash
# release.sh — carve-harness 릴리스 트리거 (레이어 A 개발 도구).
# main의 package.json 버전으로 vX.Y.Z 태그를 만들어 push → GitHub Actions가 npm 게시.
# 게시 트리거는 '태그 push'다 (main 머지만으론 안 돈다). 배경·전체 흐름: docs/release/RELEASE.md
# 사용: bash scripts/release.sh [--dry-run] [--yes]
#   --dry-run  검사·게이트만 돌리고 태그/푸시는 생략
#   --yes      확인 프롬프트 생략(자동화용)
# 주의: 이 스크립트는 develop→main 승격(PR)은 하지 않는다. 머지된 main에서 '태그 트리거'만 담당한다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DRY_RUN=0; ASSUME_YES=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    -y|--yes)  ASSUME_YES=1 ;;
    -h|--help) echo "usage: bash scripts/release.sh [--dry-run] [--yes]"; exit 0 ;;
    *) echo "알 수 없는 인자: $a (--dry-run | --yes)"; exit 1 ;;
  esac
done

die(){  printf '\033[31m❌ %s\033[0m\n' "$1" >&2; exit 1; }
info(){ printf '\033[36m▶ %s\033[0m\n'  "$1"; }

# 1. 필수 도구
command -v git  >/dev/null || die "git 필요"
command -v node >/dev/null || die "node 필요"
command -v npm  >/dev/null || die "npm 필요"

# 2. main 브랜치 + 클린 트리 (main 직접 작업 금지 규율상, 릴리스 태그만 main에서)
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" = "main" ] || die "릴리스는 main에서만 (현재: $BRANCH). 'git switch main && git pull origin main' 후 재실행."
[ -z "$(git status --porcelain)" ] || die "작업 트리가 더럽습니다. 커밋/정리 후 재실행."

# 3. 원격 동기 확인 (원격 태그도 함께 가져온다)
info "origin/main + 태그 fetch"
git fetch --quiet origin main --tags
[ "$(git rev-parse @)" = "$(git rev-parse origin/main)" ] || die "로컬 main이 origin/main과 다릅니다. 'git pull origin main' 후 재실행."

# 4. 버전 = package.json 단일 출처
VER="$(node -p "require('./package.json').version")"
TAG="v$VER"
info "릴리스 대상: $TAG (package.json)"

# 5. 태그 중복 (fetch --tags로 원격 태그도 로컬 동기화됨)
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  die "태그 $TAG 이미 존재. package.json 버전을 올리세요(npm version patch --no-git-tag-version → develop→main 승격)."
fi

# 6. npm 중복 게시 (이미 게시된 버전이면 CI가 403)
if npm view "carve-harness@$VER" version >/dev/null 2>&1; then
  die "npm에 carve-harness@$VER 이미 게시됨. 버전을 올리세요."
fi

# 7. 로컬 게이트 (CI prepublishOnly와 동일 — 먼저 깨지면 태그를 만들지 않는다)
info "npm run check"; npm run check
info "npm test";      npm test
command -v shellcheck >/dev/null || printf '\033[33m⚠ shellcheck 미설치 — CI(ubuntu)에서만 잡히는 셸 문제 가능 (brew install shellcheck)\033[0m\n'

# 8. 확인 후 태그 push (게시 트리거)
echo
echo "수행 예정: git tag -a $TAG → git push origin $TAG → GitHub Actions release → npm 게시"
if [ "$DRY_RUN" = 1 ]; then echo "[dry-run] 여기까지. 태그/푸시 생략."; exit 0; fi
if [ "$ASSUME_YES" != 1 ]; then
  printf "계속할까요? npm 게시는 되돌릴 수 없습니다 [y/N] "
  read -r ans
  case "$ans" in y|Y|yes) ;; *) echo "취소."; exit 0 ;; esac
fi

git tag -a "$TAG" -m "release $TAG"
git push origin "$TAG"
printf '\033[32m✅ %s push 완료.\033[0m GitHub → Actions의 release 워크플로를 확인하세요.\n' "$TAG"
echo "   게시 확인: npm view carve-harness version   # → $VER"
