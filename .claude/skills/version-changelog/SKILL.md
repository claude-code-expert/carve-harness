---
name: version-changelog
description: 릴리스 버전이 바뀔 때 VERSION·CHANGELOG.md·README 버전 이력을 함께 갱신한다. 버전 업/릴리스 준비 시 반드시 사용 — VERSION만 바꾸면 pre-commit이 커밋을 차단한다.
---

# version-changelog (버전 변경 기록)

`VERSION`이 바뀌는 모든 커밋에는 `CHANGELOG.md`의 해당 버전 항목이 함께 스테이징되어야 한다.
`.githooks/pre-commit` (3)이 기계적으로 강제한다 — 이 스킬은 그 정합을 한 번에 맞춘다.

## 절차

1. **새 버전 결정** — SemVer: 호환 깨짐=MAJOR / 기능 추가=MINOR / 수정·문서=PATCH.
2. **`VERSION` 교체** — 새 버전 문자열만 (예: `0.0.3`).
3. **`CHANGELOG.md` 항목 추가** — 헤더 설명문 바로 아래, 기존 항목 위에:

   ```markdown
   ## [X.Y.Z] - YYYY-MM-DD

   ### Added / Changed / Fixed / Removed  (해당 섹션만)
   - 변경 요약 — 사용자 관점, 파일·기능 명시
   ```

   - 변경 내역은 직전 버전 이후 커밋에서 수집: `git log --oneline <이전버전 태그 또는 릴리스 커밋>..HEAD`
   - 기존 항목은 수정하지 않는다 (append-only).
4. **`README.md` "버전 이력" 표** — 최상단에 같은 내용 1행 요약 추가.
5. **검증** — `bash .claude/hooks/harness-audit.sh` exit 0 확인 후, `RELEASE.md` 절차로 배포.

## 완료 기준 (SC)

- `VERSION` 내용 = CHANGELOG 최신 항목 버전 = README 버전 이력 최상단 행.
- `git add VERSION CHANGELOG.md README.md` 후 pre-commit 통과.
