# RELEASE.md — 배포 절차 (자동 릴리스)

새 버전은 **`main` 머지 시 CI가 자동으로** 낸다. 버전 번호는 Conventional Commit
이력에서 유도하고, `VERSION`·`CHANGELOG.md`·`README`는 CI가 갱신한다 — 손으로 올리지
않는다. 사용자는 `curl … | bash -s -- update`로 변경분만 수신한다.

## 커밋만 규칙대로 하면 된다

작업 브랜치(feature/develop)에서 **Conventional Commits**로 커밋한다. 커밋 타입이 다음
릴리스의 버전 증가폭을 결정한다:

| 커밋 타입 | 버전 증가 |
|-----------|-----------|
| `feat:` | **MINOR** (0.0.x → 0.1.0) |
| `fix:` · `perf:` · `refactor:` | **PATCH** (0.0.13 → 0.0.14) |
| `type!:` 또는 본문 `BREAKING CHANGE` | **MAJOR** (0.x → 1.0.0) |
| `docs:` · `chore:` · `ci:` · `style:` · `test:` · `build:` 만 | **릴리스 안 함** |

여러 타입이 섞이면 **가장 높은 것**이 이긴다(feat+fix → minor).

## 절차

1. **작업 + 커밋** — feature/develop에서 Conventional Commits로. 제목이 곧 CHANGELOG 항목이 된다.
2. **회귀 검증** (배포 전 green 권장):
   ```bash
   for t in .claude/hooks/tests/*.test.sh; do bash "$t" || exit 1; done
   bash .github/tests/release-bump.test.sh
   bash .claude/hooks/harness-audit.sh
   ```
3. **PR → main 머지**:
   ```bash
   git push origin <branch>
   gh pr create --base main
   ```
   main 직접 푸시 금지 — 머지는 사용자(리뷰어)가 한다.
4. **자동 릴리스** — main 머지 즉시 `.github/workflows/release.yml`이:
   - `release-bump.sh`로 마지막 태그 이후 커밋에서 다음 SemVer를 유도(위 표),
   - `release.sh`로 `CHANGELOG.md`(커밋 제목을 Added/Fixed/Changed로 그룹핑)·`VERSION`·
     `README`(헤더 + 버전 이력 표)를 갱신,
   - `chore(release): vX.Y.Z [skip ci]` 되커밋 + 태그 `vX.Y.Z` + **GitHub Release(Latest)** 생성.
   - 되커밋은 `GITHUB_TOKEN` + `[skip ci]`라 워크플로를 **재트리거하지 않는다**(루프 방지).
   - `docs/chore/ci`만 있는 머지는 `none` → 릴리스를 만들지 않는다.
5. **수신 확인** — 대상 프로젝트에서:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash -s -- update
   ```

> **CHANGELOG 큐레이션을 원하면**: 머지 전에 해당 커밋 제목을 정제해 두면(제목이 그대로
> 릴리스 노트가 됨) 자동 생성 품질이 올라간다. `/version-changelog` 스킬은 수동 편집용으로
> 남아 있으나, 버전 증가·태그·릴리스는 이제 CI가 소유한다 — **`VERSION`을 손으로 바꾸지 말 것.**

## 잘못된 릴리스 대응

- **사용자 측**: `bash install.sh rollback` — 직전 버전 백업 복원 (README "업데이트" 절 참고).
- **레포 측**: revert 커밋(→ 다음 머지가 PATCH로 재배포). 히스토리 재작성·force push 금지 (AGENTS.md §0).

## 강제 장치

| 규칙 | 강제 수단 |
|------|-----------|
| 버전 증가는 커밋 타입에서만 유도(수동 bump 금지) | `release.yml` + `release-bump.sh` |
| 버전 결정 로직 회귀 방지 | `.github/tests/release-bump.test.sh` |
| VERSION 수동 변경 시 CHANGELOG 항목 필수 | `.githooks/pre-commit` — 로컬 커밋 차단 |
| main 직접 푸시 금지 | AGENTS.md §8 + PR 워크플로 |
| 되커밋 루프 방지 | `GITHUB_TOKEN` push + `[skip ci]` + guard 스텝 |
