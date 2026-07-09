# REQUIREMENTS — 게이트웨이 검증 + 커밋 규율 (v2)

> 출처: `docs/harness-research.html`(8기둥 갭 분석) × 현재 하네스 실측 대조.
> Core Value: **게이트웨이 5기능(라우팅·인증·인가·API키·레이트리미트)이 "실제 구동"으로 검증된다** — 단위 테스트가 아니라 스텁 백엔드 + 실 컨테이너 통합으로.
> 대상: Spring 게이트웨이 프로젝트(SpringGateway-WebMVC 등). 범용 하네스엔 "Java 게이트웨이 옵션"으로, 실제 검증 테스트는 프로젝트에 둔다.

## 배경 — 갭 분석 결과

문서 8기둥 중 우리 하네스 상태:
- ②③⑤⑦ + 강제 코어(fail-closed·JSONL·38체크 감사·오프라인 설치기) = **충족/우위** (문서가 우리 하드닝 이전 시점).
- ⑧ 게이트웨이 검증 = **전무** (최대 공백, 사용자 프로젝트가 바로 게이트웨이).
- ③ 커밋룰 = commitlint 없음. ④ TDD/게이트웨이 서브에이전트 없음.
- ⑥ 토큰관리(headroom·LSP) = 전역/바이너리 패치라 **Out of Scope**.

## v2 Requirements

### GWV — 게이트웨이 검증 지식 계층 (rules)

- [ ] **GWV-01**: `.claude/rules/java-spring/gateway-testing.md` 신설 — 5기능별 검증 대상·테스트 더블·합격기준(SC) 매핑 표(문서 5-2)를 규칙으로 고정. 라우팅→WireMock+WebTestClient, 인증→Stub/Keycloak(유효200/무효401), 인가→role클레임(403), API키→발급-검증-폐기, 레이트리미트→Redis+반복(429+Retry-After).
- [ ] **GWV-02**: 테스트 피라미드 규칙(문서 5-3) — unit(필터·토큰파서 Mockito) → component/integration(게이트웨이 전체 컨텍스트 + WireMock + Testcontainers, **가장 두껍게**) → contract(Spring Cloud Contract/Pact, 스텁≈현실) → e2e(Walking Skeleton 1~2개). "스텁 괴리→계약 테스트 필수" 명문화.
- [ ] **GWV-03**: 권장 도구 스택(문서 5-4)을 규칙에 고정 — WireMock(`@AutoConfigureWireMock(port=0)`)·Testcontainers(Redis/Keycloak/PostgreSQL)·WebTestClient/MockMvc·Spring Cloud Contract·RestAssured·k6. 버전은 프로젝트 SCG 릴리스에서 재확인(⚠️ 문서 골격은 구조만, 컴파일 미검증).

### GATE — 게이트웨이 타깃 검증 게이트 (hook)

- [ ] **GATE-04**: `stop-verify.sh`에 게이트웨이 증분 트리거 추가 — `*Gateway*/*Filter*/*Auth*/*RateLimit*.java` 변경 시 전체 `./gradlew test`가 아니라 `*GatewayIntegration*`만 실행(문서 5-5 B). 도구 없으면 skip 통과(기존 관례 유지).
- [ ] **GATE-05**: 게이트웨이 통합 테스트가 깨진 채 응답 종료를 차단(`exit 2`)한다 — GATE-04 실패가 Stop 게이트로 전파되는지 어서션.

### COMMIT — 커밋 규율 강제 (③ 갭)

- [ ] **COMMIT-01**: Conventional Commits 형식을 커밋 시점에 기계 검증 — `.githooks/commit-msg`(또는 pre-commit 확장)로 제목 `type(scope): subject` 패턴·50자 검사. jq 불필요(bash+git), 에이전트 무관. `--no-verify` 금지는 기존 규약 유지.

### TESTAGENT — TDD/게이트웨이 서브에이전트 (④ 갭)

- [ ] **TESTAGENT-01**: `tdd-guide` 에이전트 — 기능별 합격기준 명세 → 실패 테스트(red) 먼저 → 구현 → green 유도. GSD `<verify><done>` 슬롯과 연결(문서 5-5 A·4장 연결 포인트).
- [ ] **TESTAGENT-02**: `e2e-runner`(walking skeleton 실행) + `pr-test-analyzer`(PR 테스트 충분성 평가) 신설. 인증/인가 누락 탐지는 기존 `security-reviewer` 확장으로 커버(신규 에이전트 불필요).

### AUDIT — 자가 감사 확장

- [ ] **AUDIT-07**: `/harness-audit`가 게이트웨이 룰(GWV-01)과 게이트웨이 Stop 트리거(GATE-04) 존재를 PASS/FAIL로 점검 — 룰만 있고 훅 미반영인 "정책↔게이트 미매핑"을 잡는다.

## v3 / Deferred

- **계층 AGENTS.md** (①): 멀티모듈일 때만 `backend/`·`frontend/`·`gateway/` 폴더별 배치. 단일 모듈이면 YAGNI — 실제 프로젝트 구조 확정 후 판단.
- **스텁 자동 생성**(문서 5-5 D): OpenAPI→WireMock 매핑 자동 생성 + 계약 괴리 자동 감지. 큰 별도 작업.

## Out of Scope

- **토큰관리 headroom·LSP**(⑥): 전역 pip·Claude Code 바이너리 패치라 위험/전역. caveman+codesight+superpowers로 충분.
- **실제 게이트웨이 테스트 코드 작성**: 하네스는 규칙·게이트·에이전트(강제 계층)만 제공. 실 테스트(`GatewayIntegrationTest.java`)는 대상 프로젝트 소관.
- **게이트웨이 제품 선택**(SCG vs APISIX/Envoy): 트래픽 규모 판단 — 하네스 범위 밖.
- **k6/Gatling 부하 파이프라인**: 로컬 훅 계층 밖(CI 소관).

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| GWV-01 | Phase 1 | Complete |
| GWV-02 | Phase 1 | Complete |
| GWV-03 | Phase 1 | Complete |
| GATE-04 | Phase 2 | Complete |
| GATE-05 | Phase 2 | Complete |
| AUDIT-07 | Phase 2 | Complete |
| COMMIT-01 | Phase 3 | Complete |
| TESTAGENT-01 | Phase 4 | Complete |
| TESTAGENT-02 | Phase 4 | Complete |

**Coverage:** 9/9 v2 requirements mapped — no orphans.

---
*Created: 2026-07-09 from harness-research.html gap analysis*
