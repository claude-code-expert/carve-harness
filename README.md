<p align="center">
  <img src="docs/carve-banner.svg" alt="carve-harness — carve away the excess, keep the craft" width="680">
</p>

<p align="center"><b>필요한 것만 남기고, 나머지는 깎아낸다.</b></p>

<p align="center"><b>한국어</b> · <a href="./README.en.md">English</a></p>


## Update
> **변경 이력 (Changelog)** — 전체 [CHANGELOG.md](CHANGELOG.md)
> - `2026-06-11` **v1.3.5** — `init-claude` 보강: 미지원 언어 `_default` 규칙 강화 + 프로젝트 타입 오버레이(`project-type.md`, 언어 축과 직교) 추가
> - `2026-06-11` **v1.3.4** — 훅 경로 버그 수정: 설치 훅을 `$CLAUDE_PROJECT_DIR` 절대경로로 등록(상대경로 `No such file` 실패) + `carve update` 자동 교정 → [기존 사용자 조치](#기존-사용자-조치-v134-훅-경로-수정)
> - `2026-06-10` **v1.3.3** — 빠른 시작(설치)을 4단계(첫 설치·설치 후 옵션·업데이트·삭제)로 재구성, CLI(도구)/하네스 설치 구분 (README 한/영)
> - `2026-06-08` **v1.3.2** — 설치 가이드를 글로벌 설치(`npm i -g`) 기준으로 정리 (README·INSTALL 한/영)
> - `2026-06-08` **v1.3.1** — `init-claude`에 `anti-ai-slop` 공용 규칙 추가 · README 명령어 가이드 단계형 재편 · 릴리스 스크립트(`scripts/release.sh`)
> - `2026-06-06` **v1.3.0** — 자율 수렴 루프(`iterate`)·계획 분리·검증·컨텍스트 다이어트 보강 + 전수 감사 패치(치명: `update` 데드락 해소)
> - `2026-06-05` **v1.2.0** — 라이프사이클(`diff`/`update`/`migrate`) · 분석·추천 지능화(모노레포·컨테이너 가중) · opt-in 로컬 텔레메트리(`carve report`)
> - `2026-06-02` **v1.1.0** — 프로젝트 맞춤 하네스 설치 CLI(MVP): 분석→설계→생성→audit→멱등 설치

# carve-harness

**carve-harness**는 개발에 필수적인 요소만 최소한으로 구성하는, 개발자를 위한 **하네스 엔지니어링 도구**입니다.

> 프로젝트를 분석해 그 프로젝트에 맞는 하네스(스킬·훅·서브에이전트)를 대화형으로 선택해 설치하는 CLI.

**v1.3.5** · TypeScript(ESM, 빌드 단계 없음) · Node >=22.18 · 테스트 212 / 커버리지 약 95.8%

`carve`는 코드베이스를 읽어 프로젝트 타입과 도구를 탐지하고, 적합한 구성요소를 추천한다.
사용자가 고른 것만 `.claude/`에 설치한다. carve = 범용 자산을 프로젝트에 맞게 깎아냄.

**"이 프로젝트에 맞는 하네스를 구성해줘"** 한마디로 (옵션을 직접 고를 수 있는) 전체 하네스를 구성하거나,
`harness-audit`로 현재 설치의 정합성을 실제 점검하거나, `harness-architect`로 "이 프로젝트에 맞게"
구성요소를 골라 빼주는 작업을 통해 — 프로젝트마다 최적화할 수 있다.

핵심 동작은 한 줄로 검증된다:

```
carve install → 스택 탐지 → (구성요소 선택) → .claude/에 자산 생성
              → 생성된 검증 훅이 위험 명령을 exit code 2로 결정적으로 차단
```

## 특징

- 토큰 효율 기본 탑재: codesight(구조 맵 MCP)·LSP(cclsp MCP)가 설치 시 자동 등록 — 별도 설치 없이 grep 대신 정확한 탐색과 최소 50% 이상의 비용 절검 유도, 대형 코듭베이스 기준 최소 5배 이상 절감 가능.
- 결정적 안전: 위험 명령(`rm -rf /`·포크밤)·비밀 파일(`.env`·키)을 exit code 2로 강제 차단한다(권고가 아님).
- 맞춤 선택 설치: 탐지 → 추천 → 사용자 선택. 일괄 설치 없음, 멱등 재설치·클린 제거.
- anti-slop 생성: HTML·SVG·문서의 AI 슬롭을 린터로 게이트한다.
- Squad 서브에이전트 100% 보존: 9 전문가(evaluator 포함) + 키워드 라우팅·체이닝.
- 자기검증: 설치 전 auditor가 생성물의 secret·과도 권한·훅 주입·셸 문법을 스캔한다.
- 빌드 0: `.ts` 직접 실행. npx + bash 양쪽 배포.

## 빠른 시작 — 글로벌 설치 권장

> 전체 매뉴얼: [INSTALL.md](./INSTALL.md) (한글) · [INSTALL.en.md](./INSTALL.en.md) (English) — 요구사항·모드·문제 해결까지.

`carve`를 영구 명령으로 설치하면 이 문서의 모든 `carve …`(특히 반복 쓰는 `update`·`diff`·`doctor`)가 그대로 동작한다. **전체 기능을 쓰려면 글로벌 설치를 권장한다.**

> **두 가지 설치를 구분한다**: `npm i -g carve-harness`는 **carve CLI(도구)**를 시스템에 한 번 설치하고, `carve install`은 그 CLI로 **현재 프로젝트에 하네스**(`.claude/`)를 깐다. 앞은 머신당 한 번, 뒤는 프로젝트마다 실행한다.

### 1. 첫 설치

```bash
npm i -g carve-harness         # carve CLI(도구) 설치 — 머신당 한 번
carve install                  # 현재 프로젝트에 대화형 선택 설치 (탐지 → 추천 → 선택, 일괄 없음)
carve init-claude              # CLAUDE.md 베이스라인 + 언어 스택 규칙 생성
carve doctor                   # 설치 점검 (구성·훅 문법)
```

설치 후엔 그 프로젝트에서 **Claude Code를 열기만 하면** 훅·MCP(codesight·LSP)는 자동으로 켜지고, 스킬·Squad는 자연어 또는 `/carve-<이름>`으로 부른다.

> **글로벌 없이 한 번만 써보려면**: `npx carve-harness@latest install` (매 실행 `npx carve-harness@latest <명령>`). 단 `npx`는 일회성이라 `carve`가 PATH에 안 남아 `update`·`uninstall` 같은 반복 CLI엔 불편하다 — **전체 기능 사용엔 `npm i -g`가 권장**이다. (repo clone·`curl` 사용자는 `install.sh` 래퍼 — [INSTALL.md](./INSTALL.md) 참고.)

### 2. 설치 후 옵션 (비대화형·강제 선택)

대화형 대신 옵션으로 레벨·구성요소를 직접 지정한다. (레벨의 의미는 아래 **설치 레벨** 참고.)

```bash
carve install --level full                   # 레벨 강제 (minimal|standard|full)
carve install --only commit,handoff,review   # 명시 선택 (일괄 설치 없음)
carve install --lsp-servers                  # LSP 언어서버 자동설치
```

### 3. 업데이트

CLI(도구)와 프로젝트 하네스는 따로 갱신한다.

```bash
npm i -g carve-harness@latest   # 1. carve CLI(도구) 최신화
carve diff                      # 2. (선택) 설치본 vs 최신 자산 3-way 비교 (읽기 전용)
carve update                    # 3. 프로젝트 하네스 갱신 — carve 갱신분만, 내 수정은 .bak 보존 (--force·--yes)
```

#### 기존 사용자 조치 (v1.3.4 훅 경로 수정)

v1.3.3 이하로 설치한 프로젝트는 settings.json의 훅 명령이 **상대경로**(`bash .claude/hooks/carve-*.sh`)로 박혀, Claude Code가 프로젝트 루트가 아닌 디렉터리에서 훅을 실행하면 `No such file or directory`로 실패한다. v1.3.4부터는 절대경로(`$CLAUDE_PROJECT_DIR`)로 등록한다.

이미 설치한 사용자는 둘 중 하나로 해소한다:

```bash
# 권장 — 재설치 없이 자동 교정
npm i -g carve-harness@latest   # 1. 고친 carve CLI 받기 (이 단계 없이는 교정 안 됨)
carve update                    # 2. settings.json의 carve 훅을 절대경로로 1회 자동 치환 (멱등·사용자 훅 불가침)

# 또는 — 깨끗이 재설치
carve uninstall && carve install
```

### 4. 삭제

하네스만 걷어내거나, CLI(도구)까지 지운다.

```bash
carve uninstall                 # 1. 프로젝트 하네스 제거 — carve 설치분만·.bak 복원·사용자 settings 보존
npm uninstall -g carve-harness  # 2. (선택) carve CLI(도구) 제거
```

## 일상 워크플로우 — 세션에서 자연어로

매일 쓰는 건 네 개면 충분하다. 자연어로 부르거나 `/carve-<이름>`, 둘 다 된다.

| 하고 싶은 것 | 부르는 법 | 무엇이 |
|---|---|---|
| 커밋 메시지 | "커밋 메시지 만들어" · `/carve-commit` | Conventional Commit 생성 |
| 코드 리뷰 | "리뷰해줘" · `/carve-review` | squad-review 위임 리뷰 |
| 세션 인계 | "핸드오프" · `/carve-handoff` | 진행·결정·다음 할 일을 남겨 다음 세션이 이음 |
| 결정 기억 | "기억해둬" · `/carve-memory` | 프로젝트 지속 메모리 |

그리고 **차단·보호·포맷 훅은 부를 필요 없이 자동**이다 — 위험 명령(`rm -rf /`·포크밤)·비밀 파일(`.env`·키)은 `exit 2`로 막고(권고가 아님), 저장하면 포매터가 돌고, 커밋·푸시 전 린트·테스트가 강제된다.

> 여기까지가 "쉬운 carve"다 — 기본적으로 강력한 제어를 기반으로 모델이 하네스 구조안에서 돌도록 제어하며, 간단한 명령어로 구성되어 사용하기 쉽다. 좀 더 깊게 쓰고 싶을 때만 아래로 내려가면 된다.

## 더 깊게 — 시나리오별 명령 (쓸수록 고급 사용자)

필요할 때 하나씩 더하면 된다. 전부 설치에 포함(레벨에 따라)되고, 안 부르면 컨텍스트도 차지하지 않는다(on-demand 로딩). 호출법은 둘 — **스킬**은 자연어 또는 `/carve-<이름>`, **Squad 전문가**는 `/squad <멤버>` 또는 `/squad-<멤버>`(아래 목록의 `squad-…`가 그 멤버다).

**코드 품질·검증**
- `verify` — `build→lint→test→typecheck`를 한 번에 ("검증 루프 돌려")
- `iterate` — 테스트가 green일 때까지 진단→수정→재실행, 최종 결과만 보고 ("통과할 때까지 고쳐")
- `squad-refactor` 추출·단순화 · `squad-debug` 근본 원인 · `squad-evaluator` 완료 기준 독립 평가(Self-Eval Blindspot 대응)

**테스트**
- `test-gen` UAT 기준 테스트 생성 · `tdd` red-green-refactor 우선 · `squad-qa` 테스트 실행·QA 리포트

**보안**
- `security-scan` 보안 게이트(squad-audit 위임) · `squad-audit` 보안 감사·취약점 스캔

**릴리스·협업**
- `pr` PR 본문 · `changelog` CHANGELOG 갱신 · `squad-gitops` 커밋·PR·체인지로그 · `squad-docs` 문서 생성·갱신 · `squad-plan` 기획·유저스토리

**문서·시각물 (anti-slop)**
- HTML·SVG·카드뉴스·리포트·슬라이드 생성 시 AI 슬롭(그라데이션·글로우·워터마크 등)을 제거하고 `check-slop`이 결정적으로 게이트 ("슬롭 없는 html 만들어")

**멀티에이전트·비용 최적화**
- `parallel-agents` 3~4 병렬 + git worktree 격리 · `coordinator` 메일박스/TeamCreate 조율 · `model-route` Haiku/Sonnet/Opus 라우팅 · `evaluator-tuning` 평가자 few-shot 보정

**그 외 도우미** — `caveman` 초압축(토큰 ~75%↓) · `write-a-skill` 스킬 스캐폴딩 · `zoom-out` 시스템 조망. *(tdd·caveman·write-a-skill·zoom-out은 [mattpocock/skills](https://github.com/mattpocock/skills), MIT 패턴 재작성)*

**Squad 전문가 9종** — `/squad <멤버> [작업]`(예: `/squad review`) 또는 직접 `/squad-<멤버>`(예: `/squad-refactor src/`)로 부른다. 키워드 자동 위임도 지원. 멤버: review · plan · refactor · qa · debug · docs · gitops · audit · evaluator (실제 에이전트명은 `squad-<멤버>`).

**자동 훅 (이벤트 기반 · 부를 필요 없음)** — 차단형은 권고가 아니라 `exit 2` 결정적 차단:
`block-destructive`(위험 명령) · `protect-secrets`(.env·키) · `pre-commit-lint`(커밋 전) · `pre-push-test`(푸시 전) · `auto-format`(저장 후) · `precompact-handoff`(압축 직전 상태 보존) · `slack-notify`(종료 시·웹훅 설정 시) · `auto-commit`(선택, 기본 OFF).

### 하네스 수명주기 관리 (CLI)

설치 이후 하네스 자체를 관리하는 명령. 평소엔 몰라도 되고, 새 carve가 나왔거나 설치를 점검할 때만 쓴다.

```bash
carve list      # 설치 가능/설치된 구성요소 목록
carve diff      # 설치본 vs 현재 carve 자산 3-way 비교 (읽기 전용)
carve update    # carve 갱신분만 제자리 갱신, 내 수정은 .bak 후 보존 (--force·--yes)
carve migrate   # carve-manifest 스키마 v1→v2 승격
carve report    # 설치 훅이 실제로 무엇을 막았는지 집계 (opt-in, 네트워크 전송 없음)
carve uninstall # 클린 제거 — carve 설치분만 제거·.bak 복원·사용자 settings 보존
```

세션 안에서는 `harness-audit` 스킬이 설치 정합성(훅 등록·셸 문법·자산)을 점검한다.

## 설치 레벨 (프로필로 자동 결정, `--level`로 강제)

코어 스킬·Squad 9 에이전트·anti-slop은 *모든 레벨* 기본 추천. 레벨로 달라지는 건 **훅 개수·추가 스킬**이다.
- `minimal` — 소형 CLI/라이브러리/배치: 코어 + Squad 9 + anti-slop + **필수 훅 3종**(차단·보호·핸드오프)
- `standard` (기본) — 일반 앱: minimal + **나머지 코어 훅**(총 7개: +린트·테스트·포맷·Slack)
- `full` — standard + **추가 스킬**(verify·iterate·security-scan·test-gen·parallel-agents·coordinator 등)

레벨 강제(`--level`)·명시 선택(`--only`)·LSP 자동설치 명령은 위 **빠른 시작 → 설치 후 옵션** 참고.

> 점수(`carve list`의 괄호 숫자, ≥75)는 carve의 내부 유용성 평가다. 레벨별 기본 추천·전체 구성요소 상세는 [INSTALL.md](./INSTALL.md) 참고.

지원 프로젝트: CLI · 웹 · 모바일 · 반응형 · 데스크탑 · 배치.

## CLAUDE.md 베이스라인 + 스택 규칙 (`carve init-claude`)

설치 후 `carve init-claude`를 실행하면 작업 지침 베이스라인과 언어 스택별 규칙을 깎아 생성한다.

- `.claude/CLAUDE.md` — 스택 무관 베이스라인: 짜기 전 사고·단순함·외과적 변경·TDD·커밋 규율·응답 제어·할루시네이션 가드·안전 가드레일.
- `.claude/rules/*.md` — 탐지 언어 베스트 프랙티스 6종(`techstack`·`project-structure`·`commands`·`code-style`·`safety`·`gotchas`) + 스택 무관 `anti-ai-slop`(시각·문서 산출물 슬롭 방지).
- 루트 `CLAUDE.md`가 이들을 `@import`하도록 자동 연결(멱등). 세션마다 함께 로드된다.

스택은 탐지 언어로 자동 선택된다(TypeScript/JavaScript·Python·Go·Rust·Java·Dart, 그 외 `_default`). 패키지매니저·테스트/린트 명령은 프로젝트에서 탐지한 값으로 치환된다. 세션 안에서는 harness-architect 스킬이 "CLAUDE.md 셋업" 단계로 같은 흐름을 안내한다.

## anti-slop 시각·문서 생성

HTML·SVG·카드뉴스·리포트·슬라이드·문서를 만들 때 AI 특유의 장식(그라데이션, 글로우/컬러 그림자,
글래스모피즘, 모션 장식, 워터마크, 마케팅 보일러플레이트)을 제거하고 위계를 크기·여백·정렬·타이포로 만든다.
규칙은 스킬이 생성 전에 주입하고, 생성 후 `check-slop.mjs` 린터가 결정적으로 검사한다.
모델의 눈대중이 아니라 스크립트가 게이트한다(경고 모드, 의도적 사용은 예외경로).

## 토큰 효율 (기본 탑재)

codesight·LSP를 설치 시 자동 등록해, 사용자가 따로 설치하지 않아도 토큰 효율 탐색이 적용된다.

- codesight MCP: 프로젝트 구조(라우트·스키마·의존성)를 미리 맵핑 → grep 재탐색 비용 제거(대형 코드베이스 실측 평균 약 11배).
- LSP(cclsp MCP): `findReferences`/`getDiagnostics`로 정확 탐색 → grep 2,000+ 토큰 대신 약 500 토큰.
- 모든 스킬·Squad 서브에이전트가 grep 대신 이들을 우선하도록 `flight-rules.md`·`CLAUDE.md`에 지침을 넣는다.
- 언어서버 바이너리는 대화형 설치(또는 `carve install --lsp-servers`) 시 탐지 언어로 자동 설치한다.

> 대형 fixture 벤치로 절약 수치 검증은 진행 예정. 작은 단발 태스크에선 MCP 고정 비용으로 효과가 작을 수 있다.

## 안전

- 위험 명령(`rm -rf /`·포크밤 등)과 비밀 파일(`.env`·키)은 PreToolUse 훅이 exit code 2로 차단한다.
- 커밋 전 린트·푸시 전 테스트가 강제된다.
- 설치 전 auditor가 생성물의 secret 노출·과도 권한·훅 주입을 스캔한다(통과해야 설치).

## 아키텍처

```
analyzer → catalog → (wizard 선택) → designer → generator → auditor → installer
```

두 레이어를 구분한다: 레이어 A는 carve CLI 자체(`bin/`·`src/`·`assets/`·`vendor/`),
레이어 B는 carve가 대상 프로젝트에 까는 산출물(`<project>/.claude/`).
자세한 내용은 [ARCHITECTURE.md](./ARCHITECTURE.md), 요구사항은 [requirement.md](./requirement.md).

## 개발

TypeScript(ESM)로 작성하되 개발 중엔 빌드 단계가 없다. Node >=22.18의 타입 스트리핑으로 `.ts`를 직접 실행한다.
(배포 시에는 `node_modules`에서 타입 스트리핑이 막히므로 `prepack`이 `.ts`→`.js`로 컴파일해 싣는다.)

```bash
npm test          # 단위 + E2E (node --test)
npm run test:cov  # 커버리지 게이트 (>=80)
npm run check     # 타입체크 (tsc --noEmit)
npm run build     # 배포용 컴파일 (tsconfig.build.json, in-place .js)
```

마일스톤 진행 기록: [docs/milestones/](./docs/milestones/)

## 릴리스 (npm 배포)

배포는 **버전 태그(`vX.Y.Z`) 푸시 시 GitHub Actions가 main 기준으로 자동 게시**한다(`.github/workflows/release.yml`).
`npm publish`가 `prepublishOnly`(타입체크+테스트)와 `prepack`(빌드)을 자동 실행하므로 테스트 실패 시 게시되지 않는다.

전체 순서(develop 개발 → main 승격 → 태그 게시)는 **[docs/release/RELEASE.md](./docs/release/RELEASE.md)** 참고.

## 정량 평가 (내부 측정)

6축 기준([carve-harness-benchmark-criteria.md](./docs/guide/carve-harness-benchmark-criteria.md))으로 내부 측정.
결정론적 항목은 `node bench/run.mjs`로 재현된다. 측정일 2026-05-31 · **v1.1.0 기준**(이후 버전 재측정 전 — 측정 축은 아키텍처 수준이라 대체로 유효, 수치 재검증은 예정).

**평가 축**

| 축 | 측정 대상 | carve 차별점 |
|----|-----------|-------------|
| 1. 속도/효율 | 토큰·시간·$·KV-cache·컨텍스트 주입 비용 | ★ 핵심 — "깎아서 경량" |
| 2. 제어/안전 | 차단 정확도·권한 누출률·오차단·결정성 | 결정적 훅 vs 권고(누출 0% vs N%) |
| 3. 프롬프트 검증 | 트리거 정확도·오발화·라우팅·지시 이행 | Squad test-router 패턴 차용 |
| 4. 컨텍스트 검증 | 점유율·압축 보존율·조기완료·on-demand 로딩 | 40% 룰 준수 |
| 5. 기능 E2E | 스킬 발화·훅 발동·E2E 통과·회귀 안전 | Playwright 검증 |
| 6. 구성 품질 | 구성 정확도(F1)·과생성·누락·멱등·audit | ★ carve 고유 — 경쟁 하네스엔 측정 대상 자체가 없음 |

**측정 결과**

| 축 | 점수 | 측정값 |
|----|:--:|--------|
| 1. 속도/효율 | 보류 | 설치 풋프린트 풀 49 → 최소 선택 7 파일 (**85.7% 감축**) |
| 2. 제어/안전 | **100** | 차단 100% · 누출 0% · 오차단 0% · 결정성 100% |
| 3. 프롬프트 검증 | **100** | 키워드 라우팅 100% · 오발화 0% |
| 4. 컨텍스트 검증 | 보류 | on-demand 스킬 14개 개별 파일 분리 |
| 5. 기능 E2E | **100** | 테스트 96/96 · 훅 발동 8/8 |
| 6. 구성 품질 | **100** | 타입 판정 F1 100% · audit 0건 · 멱등 100% · 과생성 없음 |

### 점수 근거 (왜 그렇게 나왔나)

- **2. 제어/안전 = 100**: 위험 시드 13종(파괴 명령 8 + 비밀파일 5)을 주입해 전부 `exit 2`로 차단(차단 100%·누출 0%),
  안전 시드 9종은 오차단 0%, `rm -rf /` 5회 반복 모두 차단(결정성 100%). 권고가 아닌 **결정적 코드 훅**이라 누출이 구조적으로 0이다.
- **3. 프롬프트 검증 = 100**: Squad 라우터에 키워드 시드 8종(리뷰·테스트·디버그·보안·리팩토링·기획·문서·커밋)을 넣어
  전부 올바른 에이전트로 위임(라우팅 100%), 비트리거 3종은 오발화 0%. (지시 이행률은 LLM 세션 필요 → 라우팅·오발화만 측정.)
- **5. 기능 E2E = 100**: 단위+E2E 96개 전부 통과, 훅 8종 문법·`exit code` 발동 검증. PoC 합격 시나리오 포함.
  (Playwright 라이브 앱 검증은 대상 앱이 없어 하네스 행위 E2E로 대체.)
- **6. 구성 품질 = 100**: fixtures 5종(cli/web/mobile/desktop/batch) 타입 판정 F1 100%, 생성물 auditor ERROR 0건,
  재설치 시 `settings.json` 동일(멱등 100%), `--only`로 고른 것만 설치돼 과생성 없음.
- **1. 속도/효율 = 보류**: 깎기 효과의 구조적 근거(추천 49파일 → 최소 선택 7파일, 85.7% 감축)는 측정됐으나,
  핵심 지표(토큰·시간·$·KV-cache)는 동일 태스크를 타 하네스로 LLM 실행해야 비교 가능 → 점수 보류.
- **4. 컨텍스트 = 보류**: on-demand 로딩 구조(스킬 14개 개별 파일)는 측정됐으나, 점유율·40% 룰·압축 보존·조기완료는
  라이브 세션 측정 필요 → 점수 보류.

> 정직 표기: 자기측정 가능한 축 2·3·5·6은 결정론적으로 만점. 축 1·4의 비교·라이브 지표는
> 추정 없이 보류했다(기준 §10). 비교 우위 입증은 `bench/`를 타 하네스로 실행하는 단계가 남았다.
> 지표별 한 줄 평가표: [carve-harness-benchmark-results.md](./docs/guide/carve-harness-benchmark-results.md).

### 라이브 cross-harness 실측 (n=5, CRUD, 동일 모델, `claude -p`)

| harness | $/태스크(중앙) | 토큰(중앙) | E2E 성공 | 누출률(축2) |
|---------|:--:|:--:|:--:|:--:|
| no-harness | $0.101 | 3,554 | 5/5 | 100% |
| squad | $0.148 | 6,106 | 5/5 | 100% |
| **carve** | $0.159 | 7,076 | 5/5 | **0%** |
| ecc | $0.382 | 13,314 | 5/5 | — |

> **범위·해석**: 소형 프로젝트의 단발·단순 CRUD(n=5) 실측이다. 이 구간은 하네스 고정 오버헤드(컨텍스트·MCP)가 커서 **토큰/$는 하네스가 불리한 게 정상**이고(소형에선 하네스가 토큰 이득 보기 어려움), 토큰 이점은 **중·대형 코드베이스**에서 나타난다. 여기서 carve가 증명하는 건 토큰 절감이 아니라 **안전(누출 0%)·동등 성공·ECC 대비 경량**이다. 누출률 = 위험 명령 중 미차단 통과 비율(carve만 결정적 차단 훅 보유, ecc —는 메커니즘 상이로 비교 불가).

- **carve vs ECC**: 비용 **58%↓** · 토큰 **47%↓** · 성공 동일(5/5) — ECC는 전역 주입(129 스킬+룰), carve는 필요한 것만 깎아 설치 → "맞춤 경량" 실측 입증.
- **carve vs no-harness**: 단발 CRUD에선 컨텍스트 주입으로 비용↑(1.57×)이나, carve의 우위는 토큰이 아니라 **안전(누출 0% vs 100% — 결정적 훅은 carve뿐)**.
- v1.0 codesight/LSP 토큰효율 절약은 위 실측 이후 추가분으로, 대형 fixture 재측정 예정(소형 단발은 MCP 고정비용으로 효과 작음).
- 측정 방법·전체 28지표: [carve-harness-benchmark-results.md](./docs/guide/carve-harness-benchmark-results.md).

## 크레딧

일부 추가 스킬(`tdd`·`caveman`·`write-a-skill`·`zoom-out`)은 [mattpocock/skills](https://github.com/mattpocock/skills)(MIT)의 패턴에서 영감을 받아 carve 포맷으로 재작성했다.

## 라이선스

MIT
