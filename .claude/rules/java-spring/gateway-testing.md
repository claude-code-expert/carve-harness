---
paths: ["**/*Gateway*.java", "**/*Filter*.java", "**/*Auth*.java", "**/*RateLimit*.java", "**/gateway/**/*.java"]
---
# 게이트웨이 검증 규칙 (자동 로드 · GWV)

> 게이트웨이 5기능(라우팅·인증·인가·API키·레이트리미트)은 비즈니스 로직이 아니라 **교차 관심사**라, 단위 테스트로는 "실제 구동"을 증명 못 한다. 스텁 백엔드 + 실 컨테이너로 게이트웨이를 통째로 띄워 요청을 흘려보내는 **통합 테스트가 핵심**이다.
> 개념·근거·코드 골격·확장 방향: `.planning/milestones/v2-gateway-verification/phase-1-gateway-testing.md`
> ⚠️ 도구 버전은 프로젝트의 Spring Cloud Gateway 릴리스에서 재확인(아래 스택은 구조 기준).

## GWV-01 · 기능별 검증 + 합격기준(SC)
- [MUST] 5기능 각각은 아래 합격기준으로 통합 테스트한다. 단위 테스트 통과만으로 "검증됨" 선언 금지.

| 기능 | 검증 대상 | 테스트 더블 | 합격기준(SC) |
|------|-----------|-------------|--------------|
| 라우팅 | 경로·헤더 → 올바른 백엔드 | WireMock 스텁 + WebTestClient | 요청이 stub A로 감 · route attr 일치 |
| 인증 | 유효/만료/위조 토큰 | Stub 토큰 또는 Testcontainers Keycloak | 유효=200, 무효/만료=401 |
| 인가 | 역할·스코프 | role 클레임 담긴 Stub 토큰 | 권한 없음=403 |
| API 키 | 발급→검증→폐기 | 발급 엔드포인트 + Testcontainers store | 발급 키 통과, 폐기 키 차단 |
| 레이트리미트 | N회 초과 차단 | Testcontainers Redis + 반복 호출 | 한도 내 200, 초과 429 + Retry-After |
| Walking Skeleton | 전 구간 관통 | 위 전부를 얇게 1시나리오 | 토큰→라우팅→백엔드 200 1회 |

## GWV-02 · 테스트 피라미드
- [MUST] component/integration(게이트웨이 전체 컨텍스트 + WireMock + Testcontainers)을 **가장 두껍게** 둔다. 단위(필터·토큰파서 Mockito)는 얇게, e2e(Walking Skeleton)는 1~2개.
- [MUST] **스텁 괴리 방지**: 스텁이 현실을 반영 못하면 통과해도 실제 깨진다 → 계약 테스트(Spring Cloud Contract/Pact)로 "스텁≈현실"을 머지 전 검증.
- [SHOULD] 라우팅 검증은 `GATEWAY_ROUTE_ATTR`를 응답 헤더로 노출해 대상 route를 단언한다.

## GWV-03 · 도구 스택 (Java/Spring)
- [MUST] 백엔드 스텁 = WireMock(`@AutoConfigureWireMock(port=0)` 또는 Testcontainers WireMock 모듈).
- [MUST] 인프라 의존성 = Testcontainers — Redis(레이트리미트)·Keycloak(인증)·PostgreSQL(API키 저장). 인메모리 Fake로 대체 금지(프로덕션 괴리).
- [SHOULD] 호출 = WebTestClient(reactive SCG)/MockMvc(MVC) · 계약 = `spring-cloud-starter-contract-stub-runner` 또는 Pact · e2e = RestAssured · 부하(429율) = k6/Gatling.

> 실제 테스트 코드(`GatewayIntegrationTest.java` 등)는 이 프로젝트 소관 — 하네스는 규칙·게이트만 제공.
