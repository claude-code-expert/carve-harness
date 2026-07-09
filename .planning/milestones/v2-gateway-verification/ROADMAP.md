# Roadmap: 게이트웨이 검증 + 커밋 규율 (Milestone v2)

## Overview

v1이 강제 코어(fail-closed·관측·상태·자가감사)를 완성했다. v2는 그 위에 **도메인 검증 계층**을 얹는다 — 게이트웨이 5기능을 "실제 구동"으로 검증하는 규칙·게이트·에이전트. 순서는 v1과 동일한 원칙(신뢰성/노력 비율): 먼저 지식 계층(규칙)을 세우고 → 결정적 게이트(Stop 훅)로 강제하고 → 커밋 규율을 닫고 → 검증 자동화(에이전트)로 마무리. 문서(`harness-research.html`)의 ⑧·③·④를 흡수하되, 실제 테스트 코드는 대상 프로젝트에 남기고 하네스는 강제 계층만 제공한다.

**적용 순서 근거** (문서 6장 "한 번에 다 하지 말 것"): 규칙 → 훅 → 커밋 → 에이전트. 각 페이즈는 독립적으로 가치가 있고 순서대로 쌓인다.

## Phases

- [ ] **Phase 1: 게이트웨이 검증 지식 계층** — 5기능 SC 매핑 · 테스트 피라미드 · 도구 스택을 `rules/java-spring/`에 규칙으로 고정 (GWV-01/02/03)
- [ ] **Phase 2: 게이트웨이 타깃 Stop 게이트 + 감사** — 게이트웨이 파일 변경 시 통합 테스트만 증분 실행, 실패 시 완료 차단, 감사가 룰↔게이트 매핑 점검 (GATE-04/05, AUDIT-07)
- [ ] **Phase 3: 커밋 규율** — Conventional Commits 형식 커밋 시점 기계 검증 (COMMIT-01)
- [ ] **Phase 4: TDD/게이트웨이 서브에이전트** — tdd-guide · e2e-runner · pr-test-analyzer, security-reviewer 확장 (TESTAGENT-01/02)

## Phase Details

### Phase 1: 게이트웨이 검증 지식 계층
**Goal**: 게이트웨이 5기능(라우팅·인증·인가·API키·레이트리미트)을 어떻게 "실제 구동"으로 검증하는지가 규칙으로 고정돼, 에이전트가 단위 테스트로 때우지 못한다.
**Mode:** mvp
**Depends on**: Nothing (v2 첫 페이즈)
**Requirements**: GWV-01, GWV-02, GWV-03
**Success Criteria**:
  1. `.claude/rules/java-spring/gateway-testing.md`가 5기능 각각의 검증대상·테스트더블·합격기준(SC)을 표로 명시한다 — 예: 인증 유효=200/무효=401, 레이트리미트 초과=429+Retry-After.
  2. 테스트 피라미드 규칙이 component/integration(WireMock+Testcontainers)을 "가장 두껍게"로 지정하고, "스텁 괴리→계약 테스트 필수"를 명문화한다.
  3. 도구 스택(WireMock·Testcontainers·WebTestClient·Spring Cloud Contract·RestAssured)이 규칙에 고정되고, 버전 재확인 경고가 붙는다.
  4. `paths: ["**/*.java"]` glob으로 자동 로드되고 `/harness-audit` 38 PASS를 깨지 않는다.
**Plans**: 1 plan (규칙 md — 코드 없음, 저위험)

### Phase 2: 게이트웨이 타깃 Stop 게이트 + 감사
**Goal**: 게이트웨이/필터/인증/레이트리미트 파일을 고치면, 응답 종료 전에 관련 통합 테스트만 자동으로 돌고, 깨져 있으면 완료가 차단된다. 감사가 이 매핑을 검증한다.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: GATE-04, GATE-05, AUDIT-07
**Success Criteria**:
  1. `stop-verify.sh`가 `*Gateway*/*Filter*/*Auth*/*RateLimit*.java` 변경 감지 시 `*GatewayIntegration*` 테스트만 실행한다(전체 빌드 회피); 무관 파일 변경엔 트리거 안 됨.
  2. 게이트웨이 통합 테스트 실패가 `exit 2`로 완료 선언을 차단한다 — 깨진 테스트 픽스처로 exit 2 어서션.
  3. 게이트웨이 도구(gradle/테스트) 부재 시 skip 통과(기존 관례). `bash -n` clean.
  4. `/harness-audit`가 GWV-01 룰과 GATE-04 트리거의 존재·매핑을 PASS/FAIL로 점검(AUDIT-07).
**Plans**: 2 plans (훅 case + 테스트 / 감사 체크 + 테스트)

### Phase 3: 커밋 규율
**Goal**: 형식 위반 커밋 메시지가 커밋 시점에 차단된다 — Claude·타 에이전트·사람 무관.
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: COMMIT-01
**Success Criteria**:
  1. `.githooks/commit-msg`(또는 pre-commit 확장)가 제목을 `type(scope): subject` + 50자 이하로 검사, 위반 시 비영 종료.
  2. jq 불필요(bash+git만), 오프라인 안전. 정상 형식은 통과.
  3. `pre-commit.test.sh`류 어서션으로 차단/통과 케이스 검증.
**Plans**: 1 plan

### Phase 4: TDD/게이트웨이 서브에이전트
**Goal**: 테스트 우선 루프와 walking-skeleton·PR 테스트 충분성 평가가 에이전트로 자동화된다.
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: TESTAGENT-01, TESTAGENT-02
**Success Criteria**:
  1. `tdd-guide` 에이전트가 red→green 루프를 유도하고 GSD `<verify><done>` 슬롯 연결을 안내한다.
  2. `e2e-runner`·`pr-test-analyzer` 에이전트가 `.claude/agents/`에 valid 프런트매터로 추가된다.
  3. 인증/인가 누락 탐지는 `security-reviewer` 확장으로 커버(신규 중복 에이전트 없음).
  4. `/harness-audit` 스킬/에이전트 프런트매터 검증(AUDIT-06) 통과.
**Plans**: 1 plan

## Progress

**Execution Order:** 1 → 2 → 3 → 4

| Phase | Plans | Status |
|-------|-------|--------|
| 1. 게이트웨이 검증 지식 계층 | 0/1 | Pending |
| 2. 게이트웨이 Stop 게이트 + 감사 | 0/2 | Pending |
| 3. 커밋 규율 | 0/1 | Pending |
| 4. TDD/게이트웨이 서브에이전트 | 0/1 | Pending |

---
*Created: 2026-07-09 — milestone v2, derived from harness-research.html gap analysis*
