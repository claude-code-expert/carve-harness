---
description: 현재 브랜치에 Conventional Commits 규칙으로 커밋하고 푸시한다
disable-model-invocation: true
argument-hint: "[커밋 요지(선택)]"
---

현재 브랜치의 변경을 **Conventional Commits** 규칙에 맞춰 커밋하고 원격 같은 브랜치로 푸시한다. `$ARGUMENTS`가 있으면 메시지 요지로 반영한다.

## 절차

1. **브랜치 가드 (필수)**: `git branch --show-current` 확인. `main`·`master`면 **즉시 중단**하고 보고 — 기본 브랜치 직접 푸시 금지(feature/develop → PR). 그 외 브랜치만 진행한다.
2. **변경 확인·스테이징**: `git status --short`·`git diff`로 검토. 스테이징된 게 없으면 관련 tracked 변경만 `git add`한다(무관 파일·`.DS_Store`·`.env`·시크릿 제외). 어떤 파일을 담는지 1줄 고지.
3. **메시지 작성**: 변경을 요약해 제목 `type(scope)?: subject`.
   - `type ∈ {feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert}`
   - 제목은 **영어**, **50자 이하 권장·72자 하드캡**, 마침표 없음, 명령형.
   - "왜"가 자명하지 않으면 `-m` 본문에 근거를 담는다(여러 변경이면 불릿).
   - `$ARGUMENTS`가 있으면 그 요지를 제목/본문에 반영한다.
4. **커밋**: `git commit`. pre-commit(보호경로·하드코딩 시크릿·VERSION↔CHANGELOG)·commit-msg(형식·길이) 게이트가 자동 실행된다.
   - 차단되면 **원인을 고치고 재시도**한다. `--no-verify` 우회는 **절대 금지**.
   - VERSION을 바꿨다면 CHANGELOG에 해당 `[X.Y.Z]` 항목이 함께 스테이징돼야 통과한다(`/version-changelog`).
5. **푸시**: `git push origin <현재브랜치>`. `--force`·히스토리 재작성 금지.
6. **보고**: 커밋 해시·제목·푸시 결과를 보고한다. 그 브랜치의 열린 PR이 있으면 자동 반영됨을 알린다.

## 금지
- `main`/`master` 직접 커밋·푸시.
- `push --force`, `commit --no-verify`, 히스토리 재작성(`reset --hard`·rebase 후 강제 푸시).
- 무관 파일·시크릿·`.env`·`.DS_Store` 스테이징.
