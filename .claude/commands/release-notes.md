---
name: release-notes
description: 새 버전의 변경사항을 검증하고 README "What's New" 섹션 + CHANGELOG + package.json 버전을 한 번에 갱신한다 (carve-harness 릴리스 노트 루틴)
argument-hint: "<version> [요약할 변경 맥락/마일스톤]"
allowed-tools:
  - Read
  - Edit
  - Bash
  - Glob
  - Grep
---

# release-notes — carve-harness 릴리스 노트 루틴

`$ARGUMENTS`의 첫 토큰을 **버전**(예: `1.2.2`)으로, 나머지를 **요약 맥락**(어떤 기능/마일스톤이 추가됐는지)으로 해석한다.
이 작업은 매 릴리스마다 반복되므로 절차를 고정한다. 출력은 **English 요약 → 한글 결론** 순서(프로젝트 응답 규약).

## 절차 (단계 → 검증)

### 1. 테스트 전체 통과 확인 (실패 시 패치)
```bash
npm run check    # tsc --noEmit
npm test         # node --test 전체
```
- 실패가 있으면 **먼저 고친다**(재현 → 수정 → 재실행). 통과 없이 다음 단계로 가지 않는다.
- 셸 자산을 건드렸으면 `bash -n`도 확인.

### 2. 버전 인상
- `package.json`의 `"version"`을 인자 버전으로 변경(예: `1.2.0` → `1.2.1`).
- 하드코딩된 옛 버전 참조가 있는지 점검: `grep -rn "<옛버전>" src/ test/ bin/` (없어야 정상 — `CARVE_VERSION`은 package.json에서 동적 로드).

### 3. 변경사항 파악
- `git log --oneline <직전_태그_또는_커밋>..HEAD` 와 `git diff --stat` 으로 이번 버전의 실제 변경을 확인한다.
- 인자의 요약 맥락 + 커밋 메시지(Conventional Commits의 `feat`/`fix`)에서 **사용자에게 의미 있는** 변경만 추린다. 내부 리팩터·계획 문서 커밋은 제외.
- 추측 금지 — 코드/커밋으로 확인되는 것만 적는다(할루시네이션 가드).

### 4. README "What's New" 갱신 (핵심 산출물)
- README.md의 `<!-- changelog:start -->` … `<!-- changelog:end -->` 마커 **사이 맨 위**에 새 버전 블록을 **prepend**한다(이전 버전 블록은 아래로 보존).
- 각 주요 기능마다 다음 3요소를 짧게:
  - **핵심**: 사용자가 얻는 것 한 줄.
  - **원리**: 어떻게 동작하는지 1~2문장(내부 메커니즘을 평이하게).
  - **예시**: 실제 명령(코드블록) 또는 구체 시나리오 한 줄.
- 형식 예:
  ```markdown
  ### v<버전> — <한 줄 제목> (<YYYY-MM-DD>)

  <한 문단 개요. 상세: [CHANGELOG](CHANGELOG.md)>

  **1. <기능명> — `<명령>`**
  - **핵심**: …
  - **원리**: …
  - 예) …
  ```
- README 상단 버전 배지 줄(`**vX.Y.Z** · TypeScript … · 테스트 N / 커버리지 ~M%`)의 버전·테스트 수·커버리지도 현재값으로 갱신한다. 테스트 수는 `npm test`의 `tests N`, 커버리지는 `npm run test:cov`의 `all files` 라인에서 가져온다.
- **날짜는 추측하지 말 것** — `date +%Y-%m-%d`로 확인해 넣는다.

### 5. CHANGELOG.md 갱신
- `[Unreleased]` 아래에 `## [<버전>] — <YYYY-MM-DD>` 섹션을 추가하고 `### Added`/`### Changed`/`### Fixed`/`### Notes`로 분류한다(Keep a Changelog).
- `### Notes`에 테스트 수·커버리지·가드레일 준수(의존성 불변 등)를 적는다.

### 6. 게이트 재확인
```bash
npm run check && npm test
```
- 버전 변경 후에도 그린인지 확인.

### 7. 보고 (커밋은 하지 않음 — 안전 규칙)
- 변경 파일(README.md·CHANGELOG.md·package.json 등)을 요약한다.
- **명시 요청 없이는 커밋/푸시하지 않는다**(`.claude/rules/safety.md`). 릴리스 태그·`npm publish`는 CI(태그 push) 경로이며 이 커맨드 범위 밖이다.

## 가드레일
- 두 레이어 구분: 이 커맨드는 **레이어 A(carve-harness 리포 자체)** 문서/버전만 만진다. 대상 프로젝트(`.claude/` 산출물)와 무관.
- 의존성 추가 금지. 표준 도구(`git`·`npm`·`grep`)만 사용.
- 추정 수치/날짜 금지 — 측정·확인값만 기재.
