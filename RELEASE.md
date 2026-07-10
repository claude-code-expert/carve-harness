# RELEASE.md — 배포 절차

새 버전을 릴리스하는 순서. 사용자는 `curl … | bash -s -- update`로 변경분만 수신한다.

## 절차

1. **변경 완료 확인** — 기능 브랜치에서 작업 완료, diff에 불필요한 변경 없음.
2. **버전 결정** — SemVer:
   - 호환 깨짐(훅 인터페이스·manifest 구조 변경) → MAJOR
   - 기능 추가(새 게이트·커맨드·스킬) → MINOR
   - 버그 수정·문서 → PATCH
3. **`/version-changelog` 스킬 실행** — 다음 3개를 함께 갱신:
   - `VERSION` → 새 버전
   - `CHANGELOG.md` → `## [X.Y.Z] - YYYY-MM-DD` 항목 (Added/Changed/Fixed/Removed)
   - `README.md` "버전 이력" 표 → 1행 요약 추가
4. **회귀 검증** — 전부 green이어야 배포:
   ```bash
   for t in .claude/hooks/tests/*.test.sh; do bash "$t" || exit 1; done
   bash .claude/hooks/harness-audit.sh
   ```
5. **커밋** — `chore(release): vX.Y.Z` (Conventional Commits).
   `.githooks/pre-commit`이 VERSION↔CHANGELOG 정합을 검사한다 — CHANGELOG 항목 없이 VERSION만 올리면 차단.
6. **태그 + 푸시 + PR**:
   ```bash
   git tag vX.Y.Z
   git push origin <branch> --tags
   gh pr create --base main
   ```
   main 머지는 사용자(리뷰어)가 한다 — main 직접 푸시 금지.
7. **머지 후 확인** — 대상 프로젝트에서 수신 테스트:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash -s -- update
   ```

## 잘못된 릴리스 대응

- **사용자 측**: `bash install.sh rollback` — 직전 버전 백업 복원 (README "업데이트" 절 참고).
- **레포 측**: revert 커밋 → PATCH 버전으로 재배포 (히스토리 재작성·force push 금지 — AGENTS.md §0).

## 강제 장치

| 규칙 | 강제 수단 |
|------|-----------|
| VERSION 변경 시 CHANGELOG 항목 필수 | `.githooks/pre-commit` (3) — 커밋 차단 |
| 배포 전 게이트 green | `stop-verify.sh` + 수동 4단계 |
| main 직접 푸시 금지 | AGENTS.md §8 + PR 워크플로 |
