---
name: release-notes
description: >
  carve-harness 리포 자체(레이어 A)의 변경 이력을 정리한다. CHANGELOG.md 갱신 →
  README의 Update 영역에 한 줄 추가(한/영 동시)를 고정 순서로 수행한다. "체인지로그
  갱신", "changelog", "릴리스 노트", "오늘 변경 README에 정리", "Update 영역 추가",
  "변경 이력 업데이트" 요청에 사용. What's New 섹션은 폐지됐다 — Update 한 줄 + CHANGELOG로 충분.
---

# release-notes — CHANGELOG + README Update 루틴 (레이어 A 전용)

이 리포(carve-harness)의 **변경 이력 문서**를 갱신하는 반복 루틴이다. 대상은 레이어 A 문서뿐
(`CHANGELOG.md`·`README.md`·`README.en.md`·`package.json`). carve가 *대상 프로젝트*에 까는
산출물(`.claude/` 템플릿)과는 무관하다.

> **What's New 폐지**: 과거의 `## What's New`(`<!-- changelog:start -->` 마커 포함)는 더 쓰지 않는다.
> 버전 요약은 **README Update 영역의 한 줄**, 상세는 **CHANGELOG.md** — 두 곳이면 충분하다.
> What's New 섹션이나 `#whats-new` 앵커가 남아 있으면 **제거하고 링크를 CHANGELOG로 돌린다**.

## 고정 순서 (반드시 이 순서)

1. **CHANGELOG.md 작성** → 2. **README Update 한 줄 추가(한글)** → 3. **README.en.md Update 한 줄 추가(영문, 동일 내용)**

한/영은 **락스텝**으로 간다: 같은 날짜·같은 버전·같은 의미의 요약을 두 README에 동시에 넣는다.
하나만 고치고 끝내지 않는다.

## 절차 (단계 → 검증)

### 0. 변경 파악 (추측 금지)
```bash
git log --oneline <직전_태그_또는_커밋>..HEAD   # 이번 버전의 실제 커밋
git diff --stat                                  # 변경 규모
date +%Y-%m-%d                                   # 날짜는 추측하지 말고 확인
node -p "require('./package.json').version"      # 현재 버전
```
- 커밋 메시지의 `feat`/`fix` 중 **사용자에게 의미 있는** 변경만 추린다. 내부 리팩터·계획 문서(`docs(plan)`)·체이닝 잡일은 제외.
- 코드/커밋으로 확인되는 것만 적는다(할루시네이션 가드). 불확실하면 "needs verification"로 표시하고 묻는다.

### 1. CHANGELOG.md 갱신 (Keep a Changelog)
- `## [Unreleased]` 아래에 `## [<버전>] — <YYYY-MM-DD>` 섹션을 추가한다(이미 있으면 내용 보강).
- 한 줄 개요 + `### Added` / `### Changed` / `### Fixed` / `### Removed` / `### Notes`로 분류.
- `### Notes`에 테스트 수·커버리지·가드레일 준수(런타임 의존성 불변 등)를 적는다. 수치는 측정값만.
- SemVer 라벨·날짜 형식을 기존 항목과 정확히 맞춘다.

### 2. README.md(한글) Update 영역 한 줄 추가 — 핵심 산출물
- `## Update` 아래 blockquote 목록 **맨 위**에 한 줄을 prepend한다(이전 버전 줄은 아래로 보존):
  ```markdown
  > - `<YYYY-MM-DD>` **v<버전>** — <커밋에서 추린 한 줄 요약(주요 기능·치명 수정 위주)>
  ```
- 상단 버전 배지 줄도 갱신: `**v<버전>** · TypeScript(ESM, 빌드 단계 없음) · Node >=22.18 · 테스트 <N> / 커버리지 약 <M>%`.
  - 테스트 수 N = `npm test`의 `tests N`, 커버리지 M = `npm run test:cov`의 `all files` 라인. (문서만 바꿨다면 직전 측정값 유지.)
- `#whats-new`로 가는 죽은 링크가 보이면 그 자리에서 제거하거나 `[CHANGELOG](CHANGELOG.md)`로 교체한다.

### 3. README.en.md(영문) Update 영역 한 줄 추가 — 한글과 동일
- 영문 README의 `## Update` blockquote 목록 맨 위에 **2번과 같은 줄을 영어로** prepend한다(날짜·버전 동일):
  ```markdown
  > - `<YYYY-MM-DD>` **v<버전>** — <same summary, in English>
  ```
- 상단 버전 배지 줄도 동일하게 갱신: `**v<버전>** · TypeScript (ESM, no build step) · Node >=22.18 · <N> tests / ~<M>% coverage`.
- 한글 README와 **구조가 평행**하도록 유지한다(`## Update` 헤더 + `> **Changelog** — full history in [CHANGELOG.md](CHANGELOG.md)` blockquote). What's New 섹션이 남아 있으면 삭제한다.

### 4. 게이트 (코드가 바뀐 릴리스일 때만)
```bash
npm run check && npm test
```
- 코드 변경을 동반한 버전 인상이면 그린 확인 후 마무리. **문서만 바뀐 경우(이 루틴의 흔한 경우)는 생략 가능** — 이유를 보고에 명시.

### 5. 보고 (커밋·푸시 금지)
- 바꾼 파일(CHANGELOG.md·README.md·README.en.md·필요 시 package.json)을 요약한다.
- **명시 요청 없이는 커밋/푸시하지 않는다**(`.claude/rules/safety.md`). 릴리스 태그·`npm publish`는 CI(태그 push) 경로이며 이 루틴 밖이다.

## 가드레일
- 레이어 A 문서/버전만 만진다. 대상 프로젝트 산출물·소스와 무관.
- 의존성 추가 금지. 표준 도구(`git`·`npm`·`grep`)만.
- 추정 수치·날짜 금지 — 측정·확인값만 기재.
- 한/영 둘 다 갱신했는지 마무리 전에 `grep -n "v<버전>" README.md README.en.md`로 확인한다.
