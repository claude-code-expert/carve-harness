#!/usr/bin/env bash
# config-doctor.sh — CLAUDE.md / AGENTS.md 정합성 자문 검사기 (advisory, non-gate).
#
# carve-harness-create 스킬의 "설정 검증(FIX 제안)" 단계가 호출하는 결정론 검사기.
# harness-audit(차단 게이트)와 달리 여기서는 **항상 exit 0** — 발견 사항을 출력만 한다.
# 자동 수정하지 않는다(제안은 스킬이 사용자 확인 후 반영).
#
# 검사 (기계적·결정론):
#   1) 깨진 @참조   — CLAUDE.md/AGENTS.md의 @경로가 실재하지 않음
#   2) 죽은 하네스 경로 — 본문이 가리키는 .claude/{skills,commands,agents,rules,hooks}/... 부재
#
# 사용: bash .claude/hooks/config-doctor.sh [파일...]   (기본: 세 설정 파일)
set -u

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$ROOT" || exit 0

if [ "$#" -gt 0 ]; then
  FILES=("$@")
else
  FILES=(CLAUDE.md AGENTS.md .claude/CLAUDE.md)
fi

findings=0
report() { printf 'DOCTOR: %s\n' "$1"; findings=$((findings + 1)); }

for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue

  # (1) 깨진 @참조 — 경로꼴만(@., 슬래시 포함, 또는 .md 로 끝) → 이메일 등 오탐 제외
  for ref in $(grep -oE '@[.A-Za-z0-9_/-]+' "$f" 2>/dev/null | sort -u); do
    p="${ref#@}"; p="${p%.}"                 # @ 제거, 문장부호 꼬리 정리
    case "$p" in
      .*|*/*|*.md) ;;                        # 경로꼴만 검사
      *) continue ;;
    esac
    [ -e "$p" ] || report "$f: 깨진 @참조 '$ref' — 대상 없음"
  done

  # (2) 죽은 하네스 경로 — glob(*) 포함 토큰은 스킵(와일드카드는 검사 대상 아님)
  for path in $(grep -oE '\.claude/[A-Za-z0-9_./-]+' "$f" 2>/dev/null | sort -u); do
    path="${path%.}"                          # 문장부호 꼬리 정리
    case "$path" in
      *'*'*) continue ;;
    esac
    [ -e "$path" ] || report "$f: 죽은 경로 참조 '$path' — 파일/디렉터리 없음"
  done
done

if [ "$findings" -eq 0 ]; then
  echo "config-doctor: 설정 정합성 이상 없음 (@참조·하네스 경로)"
fi
exit 0
