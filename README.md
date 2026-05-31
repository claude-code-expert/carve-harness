# carve-harness

> 프로젝트를 분석해 그 프로젝트에 맞는 하네스(스킬·훅·서브에이전트)를 대화형으로 선택해 설치하는 CLI.

**v2.4.0** · TypeScript(ESM, 빌드 단계 없음) · Node >=22.18 · 테스트 116 / 커버리지 약 94%

`carve`는 코드베이스를 읽어 프로젝트 타입과 도구를 탐지하고, 적합한 구성요소를 추천한다.
사용자가 고른 것만 `.claude/`에 설치한다. carve = 범용 자산을 프로젝트에 맞게 깎아냄.

핵심 동작은 한 줄로 검증된다:

```
carve install → 스택 탐지 → (구성요소 선택) → .claude/에 자산 생성
              → 생성된 검증 훅이 위험 명령을 exit code 2로 결정적으로 차단
```

## 특징

- 토큰 효율 기본 탑재: codesight(구조 맵 MCP)·LSP(cclsp MCP)가 설치 시 자동 등록 — 별도 설치 없이 grep 대신 정확 탐색.
- 결정적 안전: 위험 명령(`rm -rf /`·포크밤)·비밀 파일(`.env`·키)을 exit code 2로 강제 차단한다(권고가 아님).
- 맞춤 선택 설치: 탐지 → 추천 → 사용자 선택. 일괄 설치 없음, 멱등 재설치·클린 제거.
- anti-slop 생성: HTML·SVG·문서의 AI 슬롭을 린터로 게이트한다.
- Squad 서브에이전트 100% 보존: 9 전문가(+evaluator) + 키워드 라우팅·체이닝.
- 자기검증: 설치 전 auditor가 생성물의 secret·과도 권한·훅 주입·셸 문법을 스캔한다.
- 빌드 0: `.ts` 직접 실행. npx + bash 양쪽 배포.

## 설치 & 사용

> **전체 설치 매뉴얼**: [INSTALL.md](./INSTALL.md) (한글) · [INSTALL.en.md](./INSTALL.en.md) (English)
> — 요구사항·설치 모드·단계별 구성요소·문제 해결까지 상세.

**풀 설치 흐름 (3단계)**

```bash
npx carve-harness              # 1. 대화형 선택 설치 (탐지 → 추천 → 선택)
npx carve-harness init-claude  # 2. CLAUDE.md 베이스라인 + 언어 스택 규칙 생성
npx carve-harness doctor       # 3. 설치 점검 (구성·훅 문법)
```

bash로도 설치한다: `bash install.sh` (제거는 `bash install.sh --uninstall`).
세션 안에서는 **"이 프로젝트에 맞는 하네스 구성해줘"** 로 harness-architect 스킬이 같은 흐름을 안내한다.

**명령 레퍼런스**

```bash
carve              # = carve install — 대화형 선택 설치 (일괄 설치 없음)
carve install --level full        # 레벨 강제(minimal|standard|full). full=멀티에이전트 병렬·조율 포함
carve install --only commit,handoff,block-destructive   # 비대화형 명시 선택
carve install --lsp-servers       # LSP 언어서버 자동설치
carve init-claude  # CLAUDE.md 베이스라인 + .claude/rules/* 생성 (언어 스택 기준)
carve list         # 설치 가능/설치된 구성요소 목록
carve doctor       # 설치된 하네스 점검 (구성 + 훅 셸 문법)
carve uninstall    # 클린 제거(.bak 복원)
```

**설치 레벨** (프로필로 자동 결정, `--level`로 강제 가능):
- `minimal` — 소형 CLI/배치: 코어 스킬 + 필수 훅(차단·보호·핸드오프)
- `standard` (기본) — 일반 앱: + 7 필수 훅 + Squad 9 에이전트
- `full` — + 추가 스킬(verify 등) + **멀티에이전트 병렬(parallel-agents)·조율(coordinator)**

**제거**: `carve uninstall` (= `bash install.sh --uninstall`). `carve-manifest.json` 기준으로 carve 설치 파일만 제거하고
`.bak`가 있으면 원본을 복원한다. `settings.json`의 carve 훅·MCP 항목만 정확히 제거(사용자 항목 보존). 자세히는 [INSTALL.md](./INSTALL.md#11-제거-uninstall).

## 무엇을 설치하나

- 토큰 효율(기본 탑재): codesight(구조 맵 MCP) · lsp(cclsp MCP) — settings.json에 자동 등록 + git commit 시 `.codesight/` 갱신
- 6 핵심 스킬: handoff · memory · commit · changelog · review · pr
- 진입 스킬: harness-architect (자연어 트리거)
- 7 필수 훅: 파괴적 명령 차단 · 비밀파일 보호 · 커밋 전 린트 · 푸시 전 테스트 · 자동 포맷 · Slack 알림 · PreCompact 핸드오프
- 1 선택 훅: 자동 커밋
- Squad 서브에이전트 9종: review · plan · refactor · qa · debug · docs · gitops · audit · evaluator(완료 기준 독립 평가)
- anti-ai-slop 팩 + 추가 스킬(점수 75↑): verify·security-scan·test-gen, 그리고 tdd·caveman·write-a-skill·zoom-out (mattpocock/skills, MIT 출처)

설치 시 `flight-rules.md`·`evaluation-criteria.md`·`sprint-contract.md`·`CLAUDE.md`·`HARNESS-GUIDE.md`를 프로젝트에 생성한다.
지원 프로젝트: CLI · 웹 · 모바일 · 반응형 · 데스크탑 · 배치.

## CLAUDE.md 베이스라인 + 스택 규칙 (`carve init-claude`)

설치 후 `carve init-claude`를 실행하면 작업 지침 베이스라인과 언어 스택별 규칙을 깎아 생성한다.

- `.claude/CLAUDE.md` — 스택 무관 베이스라인: 짜기 전 사고·단순함·외과적 변경·TDD·커밋 규율·응답 제어·할루시네이션 가드·안전 가드레일.
- `.claude/rules/*.md` — 탐지 언어의 베스트 프랙티스 6종: `techstack`·`project-structure`·`commands`·`code-style`·`safety`·`gotchas`.
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

TypeScript(ESM)로 작성하되 빌드 단계가 없다. Node >=22.18의 타입 스트리핑으로 `.ts`를 직접 실행한다.

```bash
npm test          # 단위 + E2E (node --test)
npm run test:cov  # 커버리지 게이트 (>=80)
npm run check     # 타입체크 (tsc --noEmit)
```

마일스톤 진행 기록: [docs/milestones/](./docs/milestones/)

## 정량 평가 (내부 측정)

6축 기준([carve-harness-benchmark-criteria.md](./docs/guide/carve-harness-benchmark-criteria.md))으로 내부 측정.
결정론적 항목은 `node bench/run.mjs`로 재현된다. 측정일 2026-05-31 · v1.1.0.

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

- **carve vs ECC**: 비용 **58%↓** · 토큰 **47%↓** · 성공 동일(5/5) — ECC는 전역 주입(129 스킬+룰), carve는 필요한 것만 깎아 설치 → "맞춤 경량" 실측 입증.
- **carve vs no-harness**: 단발 CRUD에선 컨텍스트 주입으로 비용↑(1.57×)이나, carve의 우위는 토큰이 아니라 **안전(누출 0% vs 100% — 결정적 훅은 carve뿐)**.
- v2.1 codesight/LSP 토큰효율 절약은 위 실측 이후 추가분으로, 대형 fixture 재측정 예정(소형 단발은 MCP 고정비용으로 효과 작음).
- 측정 방법·전체 28지표: [carve-harness-benchmark-results.md](./docs/guide/carve-harness-benchmark-results.md).

## 크레딧

일부 추가 스킬(`tdd`·`caveman`·`write-a-skill`·`zoom-out`)은 [mattpocock/skills](https://github.com/mattpocock/skills)(MIT)의
패턴에서 영감을 받아 carve 포맷으로 재작성했다.

## 라이선스

MIT
