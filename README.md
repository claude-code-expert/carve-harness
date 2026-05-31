# carve-harness

> 프로젝트를 분석해 그 프로젝트에 맞는 하네스(스킬·훅·서브에이전트)를 대화형으로 선택해 설치하는 CLI.

**v1.3.0** · TypeScript(ESM, 빌드 단계 없음) · Node >=22.18 · 테스트 104 / 커버리지 약 95%

`carve`는 코드베이스를 읽어 프로젝트 타입과 도구를 탐지하고, 적합한 구성요소를 추천한다.
사용자가 고른 것만 `.claude/`에 설치한다. carve = 범용 자산을 프로젝트에 맞게 깎아냄.

핵심 동작은 한 줄로 검증된다:

```
carve install → 스택 탐지 → (구성요소 선택) → .claude/에 자산 생성
              → 생성된 검증 훅이 위험 명령을 exit code 2로 결정적으로 차단
```

## 특징

- 결정적 안전: 위험 명령(`rm -rf /`·포크밤)·비밀 파일(`.env`·키)을 exit code 2로 강제 차단한다(권고가 아님).
- 맞춤 선택 설치: 탐지 → 추천 → 사용자 선택. 일괄 설치 없음, 멱등 재설치·클린 제거.
- anti-slop 생성: HTML·SVG·문서의 AI 슬롭을 린터로 게이트한다.
- Squad 서브에이전트 100% 보존: 8 전문가 + 키워드 라우팅·체이닝.
- 자기검증: 설치 전 auditor가 생성물의 secret·과도 권한·훅 주입을 스캔한다.
- 빌드 0: `.ts` 직접 실행. npx + bash 양쪽 배포.

## 설치 & 사용

```bash
# npx (Node >=22.18)
npx carve-harness            # 대화형으로 구성요소를 선택해 설치
npx carve-harness uninstall  # 클린 제거

# 또는 bash
bash install.sh              # 현재 디렉토리
bash install.sh --uninstall  # 제거
```

```bash
carve              # = carve install — 대화형 선택 설치
carve install --only commit,handoff,block-destructive   # 비대화형 명시 선택
carve list         # 설치 가능 구성요소
carve doctor       # 설치된 하네스 점검
carve uninstall    # 클린 제거(.bak 복원)
```

일괄 설치는 지원하지 않는다. 추천을 기본 체크로 제시하되 선택 후 설치한다.
세션 안에서는 "이 프로젝트에 맞는 하네스 구성해줘"로 harness-architect 스킬이 같은 흐름을 안내한다.

## 무엇을 설치하나

- 6 핵심 스킬: handoff · memory · commit · changelog · review · pr
- 진입 스킬: harness-architect (자연어 트리거)
- 7 필수 훅: 파괴적 명령 차단 · 비밀파일 보호 · 커밋 전 린트 · 푸시 전 테스트 · 자동 포맷 · Slack 알림 · PreCompact 핸드오프
- 1 선택 훅: 자동 커밋
- Squad 서브에이전트 9종: review · plan · refactor · qa · debug · docs · gitops · audit · evaluator(완료 기준 독립 평가)
- anti-ai-slop 팩 + 추가 스킬(점수 75↑): verify·security-scan·test-gen, 그리고 tdd·caveman·write-a-skill·zoom-out (mattpocock/skills, MIT 출처)

설치 시 `flight-rules.md`·`evaluation-criteria.md`·`sprint-contract.md`·`CLAUDE.md`·`HARNESS-GUIDE.md`를 프로젝트에 생성한다.
지원 프로젝트: CLI · 웹 · 모바일 · 반응형 · 데스크탑 · 배치.

## anti-slop 시각·문서 생성

HTML·SVG·카드뉴스·리포트·슬라이드·문서를 만들 때 AI 특유의 장식(그라데이션, 글로우/컬러 그림자,
글래스모피즘, 모션 장식, 워터마크, 마케팅 보일러플레이트)을 제거하고 위계를 크기·여백·정렬·타이포로 만든다.
규칙은 스킬이 생성 전에 주입하고, 생성 후 `check-slop.mjs` 린터가 결정적으로 검사한다.
모델의 눈대중이 아니라 스크립트가 게이트한다(경고 모드, 의도적 사용은 예외경로).

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

## 크레딧

일부 추가 스킬(`tdd`·`caveman`·`write-a-skill`·`zoom-out`)은 [mattpocock/skills](https://github.com/mattpocock/skills)(MIT)의
패턴에서 영감을 받아 carve 포맷으로 재작성했다.

## 라이선스

MIT
