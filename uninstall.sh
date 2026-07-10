#!/usr/bin/env bash
# uninstall.sh — 하네스 제거. 프로젝트 루트에서 실행.
#   bash uninstall.sh          드라이런: 삭제될 목록만 출력 (기본, 아무것도 안 지움)
#   bash uninstall.sh --yes    실제 삭제 + core.hooksPath 해제 + .gitignore 블록 제거
#
# 삭제 범위는 설치 시 기록된 .claude/harness-manifest.txt 로 한정한다 —
# 설치 때 SKIP된(원래 있던) 파일은 목록에 없으므로 건드리지 않는다.
# logs/ 와 specs/HANDOFF.md 등 런타임 산출물은 사용자 데이터로 보고 남긴다.
set -u

HERE="$PWD"
MANIFEST="$HERE/.claude/harness-manifest.txt"
say() { printf '%s\n' "$*"; }

[ -f "$MANIFEST" ] || {
  printf 'FAIL: %s 없음 — install.sh를 한 번 실행하면 생성된다 (제거 범위의 기록).\n' "$MANIFEST" >&2
  exit 1
}
if [ -f "$HERE/.planning/PROJECT.md" ] && grep -qi 'harness' "$HERE/.planning/PROJECT.md" 2>/dev/null; then
  say "WARN: 여기가 하네스 원본 레포로 보임 — 정말 여기서 제거할 건지 확인."
fi

APPLY=0
[ "${1:-}" = "--yes" ] && APPLY=1
[ "$APPLY" -eq 0 ] && say "[드라이런] 실제 삭제는 --yes. 삭제 예정 목록:"

while IFS= read -r p; do
  [ -n "$p" ] || continue
  case "$p" in /*|*..*) say "SKIP: 비정상 경로 무시: $p"; continue ;; esac
  t="$HERE/$p"
  [ -e "$t" ] || continue
  if [ "$APPLY" -eq 1 ]; then
    rm -rf "$t" && say "removed: $p"
  else
    say "  $p"
  fi
done < "$MANIFEST"

# 생성물 + 설정 원복
for extra in .claude/bin; do
  if [ -e "$HERE/$extra" ]; then
    if [ "$APPLY" -eq 1 ]; then rm -rf "${HERE:?}/$extra" && say "removed: $extra"; else say "  $extra"; fi
  fi
done

if [ "$APPLY" -eq 1 ]; then
  git -C "$HERE" config --unset core.hooksPath 2>/dev/null && say "OK: core.hooksPath 해제"
  if grep -q '>>> harness' "$HERE/.gitignore" 2>/dev/null; then
    # -i.hbak: BSD sed needs a suffix (bare -i is GNU-only); backup removed right after
    sed -i.hbak '/# >>> harness (managed by install.sh) >>>/,/# <<< harness <<</d' "$HERE/.gitignore" \
      && rm -f "$HERE/.gitignore.hbak"
    say "OK: .gitignore 하네스 블록 제거"
  fi
  rm -f "$MANIFEST" "$HERE/.claude/harness-version" "$HERE/.claude/harness-components"
  rmdir "$HERE/.claude" "$HERE/specs" "$HERE/.githooks" 2>/dev/null
  say "제거 완료. 남긴 것: logs/ (감사 기록), specs/ 산출물 — 필요 없으면 직접 삭제."
else
  say "  .gitignore 하네스 블록 · core.hooksPath · $MANIFEST"
fi
exit 0
