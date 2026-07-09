# Phase 1 — 게이트웨이 검증 지식 계층

> 마일스톤 v2, Phase 1 산출물 문서. 대상 요구사항 GWV-01/02/03.
> 이 문서는 규칙 파일 `.claude/rules/java-spring/gateway-testing.md`의 **개념·사용법·확장** 상세본이다.
> 규칙은 강제(무엇을), 이 문서는 교육(왜·어떻게).

---

## 0. 이 페이즈가 만든 것

| 산출물 | 역할 |
|--------|------|
| `.claude/rules/java-spring/gateway-testing.md` | 글롭 자동 로드되는 **규칙** — 게이트웨이 파일 편집 시 에이전트 컨텍스트에 주입 |
| (이 문서) | 규칙의 근거·이론·사용 예·확장 방향 |

Phase 1은 **지식 계층**만 세운다. 강제(Stop 게이트)는 Phase 2, 커밋 규율은 Phase 3, 검증 에이전트는 Phase 4다. 규칙만 있고 게이트가 없으면 "설득"에 머무는데, 그 강제는 다음 페이즈가 얹는다.

### 왜 규칙부터인가
하네스 3기둥 순서(신뢰성/노력 비율)와 같다. 검증 방법을 **먼저 규칙으로 고정**해야, Phase 2의 Stop 게이트가 "무엇을 실행해 무엇을 통과로 볼지"의 기준을 가진다. 규칙 없는 게이트는 그냥 `gradle test`일 뿐이고, 게이트 없는 규칙은 안 지켜진다.

---

## 1. 이론 — 왜 게이트웨이는 단위 테스트로 안 되는가

### 1.1 교차 관심사(cross-cutting concern)
게이트웨이의 5기능(라우팅·인증·인가·API키·레이트리미트)은 **비즈니스 로직이 아니다**. 요청이 백엔드에 닿기 전/후에 가로질러 작동하는 인프라 계층이다. 단위 테스트는 한 클래스를 격리해 검증하는데, 게이트웨이의 "실제 구동"은 **필터 체인 + 라우팅 + 실제 토큰 파싱 + 실제 Redis 카운터**가 함께 돌 때만 드러난다. 필터 하나를 Mockito로 격리 검증해봐야 "체인에 제대로 꽂혔는지"는 증명 못 한다.

**결론**: 게이트웨이를 통째로 띄우고(스프링 전체 컨텍스트) 요청을 실제로 흘려보내는 **통합 테스트**가 핵심이다.

### 1.2 테스트 더블 5종 (Meszaros / Fowler "Mocks Aren't Stubs")

| 더블 | 정의 | 게이트웨이 쓰임 |
|------|------|-----------------|
| Dummy | 자리 채우기(안 쓰임) | 필수 파라미터 채우기 |
| **Stub** | 정해진 응답 반환 | WireMock 백엔드가 200/500 반환 |
| Spy | 호출 기록 | 게이트웨이가 인증서버 호출했는지 기록 |
| **Mock** | 기대값 + **행위 검증** | "인증서버를 호출했는가"를 강제 |
| Fake | 동작하는 경량 구현 | 인메모리 DB — ⚠️ 프로덕션 부적합 |

핵심 구분: **Stub은 상태(어떤 응답)를, Mock은 행위(호출 여부)를** 검증한다. 게이트웨이 라우팅은 "stub 백엔드가 응답을 줬는가"(상태)라 주로 Stub을 쓰고, "게이트웨이가 인증서버를 호출했는가"(행위)는 Mock/Spy로 본다.

### 1.3 게이트웨이용 테스트 피라미드
```
        e2e (walking skeleton) ── 최소 1~2개, 전 구간 관통
      contract (Spring Cloud Contract/Pact) ── 스텁 = 현실 보증
    component/integration ── 게이트웨이 + WireMock + Testcontainers (가장 두껍게)
  unit ── 필터·토큰파서 (Mockito stub)
```
일반 앱 피라미드는 unit이 가장 두껍다. **게이트웨이는 다르다** — 로직이 얇고 통합 지점이 전부라, **component/integration이 가장 두꺼워야** 한다.

### 1.4 스텁 괴리(stub drift)의 함정
스텁은 양날의 검이다. "스텁이 현실 백엔드를 반영 못하면, 테스트는 통과해도 프로덕션은 깨진다." 백엔드가 필드명을 바꿨는데 스텁은 옛 응답을 주면, 게이트웨이 테스트는 초록불인 채 실제 라우팅이 실패한다.
→ **계약 테스트(Contract)**: 스텁이 현실과 같은지를 주기적으로(머지 전) 검증한다. Spring Cloud Contract는 백엔드가 발행한 계약으로 stub-runner를 부트스트랩해 이 괴리를 자동 감지한다.

### 1.5 Walking Skeleton
Alistair Cockburn / James Shore 개념. **끝에서 끝까지 동작하는 가장 얇은 골격**을 먼저 만든다 — 클라이언트→게이트웨이→백엔드로 요청 1개가 관통(토큰→라우팅→200)하면, 그 뼈대에 살을 붙여간다. "전 구간이 한 번은 붙었다"를 보장하는 최소 e2e.

---

## 2. 사용 방법

### 2.1 규칙이 에이전트에 어떻게 뜨는가
`gateway-testing.md`의 프런트매터:
```yaml
paths: ["**/*Gateway*.java", "**/*Filter*.java", "**/*Auth*.java", "**/*RateLimit*.java", "**/gateway/**/*.java"]
```
게이트웨이 관련 파일을 편집·조회할 때만 이 규칙이 자동 로드된다. `**/*.java` 전역이 아니라 좁은 글롭 — **컨텍스트 비용을 아끼려는 의도적 설계**. 일반 도메인 코드 편집엔 안 뜬다.

확인:
```bash
# glob이 게이트웨이 파일에 매칭되는지 (예시)
ls gateway/src/main/java/**/*Gateway*.java 2>/dev/null
# 규칙 자체 점검
bash .claude/hooks/harness-audit.sh   # 38 PASS 유지 = 규칙 위생 OK
```

### 2.2 기능별로 무엇을 쓰는가 (규칙 GWV-01 요약)
| 기능 | 합격기준(SC) | 도구 |
|------|--------------|------|
| 라우팅 | stub A로 감 · route attr 일치 | WireMock + WebTestClient |
| 인증 | 유효=200, 무효/만료=401 | Stub 토큰 / Keycloak(Testcontainers) |
| 인가 | 권한 없음=403 | role 클레임 Stub 토큰 |
| API 키 | 발급 통과, 폐기 차단 | 발급 엔드포인트 + Testcontainers store |
| 레이트리미트 | 한도 200, 초과 429+Retry-After | Testcontainers Redis + 반복 호출 |

### 2.3 테스트 골격 (⚠️ 구조만 — 실제 SCG 버전에서 컴파일·실행 검증 필요)
```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
@AutoConfigureWireMock(port = 0)   // 백엔드 스텁
@Testcontainers                    // Redis 등 실제 컨테이너
class GatewayIntegrationTest {
  @Container static GenericContainer<?> redis =
      new GenericContainer<>("redis:7").withExposedPorts(6379);
  @Autowired WebTestClient client;

  @Test void 유효토큰_라우팅_통과() {
    stubFor(get("/api/users").willReturn(okJson("[]")));   // 스텁
    client.get().uri("/api/users")
        .header("Authorization", "Bearer " + validToken())
        .exchange().expectStatus().isOk();                 // 합격 기준
  }
  @Test void 한도초과_429() { /* 반복 호출 후 429 + Retry-After 검증 */ }
}
```
이 파일은 **대상 프로젝트**에 둔다(하네스는 규칙만 제공). Phase 2의 Stop 게이트가 이 `*GatewayIntegration*`을 게이트웨이 파일 변경 시 자동 실행한다.

### 2.4 워크플로 안에서
```
1) 게이트웨이 기능 추가 착수 → gateway-testing.md 규칙 자동 로드
2) 규칙의 SC를 실패 테스트로 먼저 작성 (Phase 4 tdd-guide가 유도 예정)
3) 구현 → WireMock 스텁 + Testcontainers로 통합 테스트 green
4) 머지 전 계약 테스트로 스텁≈현실 확인
5) (Phase 2 이후) 응답 종료 시 Stop 게이트가 게이트웨이 통합 테스트 자동 실행
```

---

## 3. 확장해야 할 부분

### 3.1 다음 페이즈가 얹는 강제 (이미 계획됨)
| 페이즈 | 추가 | 이 규칙과의 연결 |
|--------|------|------------------|
| Phase 2 | 게이트웨이 타깃 Stop 게이트(GATE-04/05) | `*Gateway*/*Filter*/*Auth*/*RateLimit*.java` 변경 시 `*GatewayIntegration*`만 증분 실행 → 규칙 SC를 기계 강제 |
| Phase 2 | 감사(AUDIT-07) | 이 규칙 존재 ↔ Stop 트리거 매핑을 PASS/FAIL |
| Phase 3 | commit-msg 게이트 | 커밋 규율(규칙 무관, 병렬) |
| Phase 4 | tdd-guide·e2e-runner·pr-test-analyzer | 규칙 SC를 red→green으로 유도, walking skeleton 실행, PR 테스트 충분성 평가 |

### 3.2 이 규칙 자체의 확장 여지
- **버전 고정**: 도구 스택 버전(SCG 5.0.x·WireMock·Testcontainers)은 프로젝트 릴리스마다 변동. 규칙은 "구조"만 고정했으니, 프로젝트에서 실제 버전 확정 후 골격 컴파일 검증 필요(⚠️ 미검증 항목).
- **MVC vs Reactive**: SCG는 `spring-cloud-gateway-server-webflux`(reactive)와 `-webmvc` 두 아티팩트. 호출 도구가 갈린다(WebTestClient vs MockMvc). 프로젝트 스택 확정 시 규칙에 택1 명시 가능.
- **게이트웨이 제품**: SCG 전제. APISIX/Envoy/NGINX면 도구 스택 전면 교체(트래픽 규모 판단 — 하네스 범위 밖).

### 3.3 Deferred (v3 후보)
- **스텁 자동 생성**(문서 5-5 D): 백엔드 OpenAPI 스펙 → WireMock 매핑 자동 생성 → 계약 괴리 자동 감지. 에이전트 자동화의 정점이나 큰 별도 작업.
- **부하 파이프라인**: k6/Gatling으로 429율·Retry-After를 CI에서 검증. 로컬 훅 계층 밖(CI 소관).
- **계층 AGENTS.md**: `gateway/` 폴더 전용 AGENTS.md — 멀티모듈 확정 시.

---

## 4. 근거 · 출처

| 개념 | 출처 |
|------|------|
| 테스트 더블 5종 | Meszaros *xUnit Test Patterns* · Fowler "Mocks Aren't Stubs" |
| Walking Skeleton | Cockburn · James Shore |
| 스텁 괴리 → 계약 테스트 | Spring Cloud Contract 공식 · Pact |
| WireMock + WebTestClient · Testcontainers WireMock 모듈 | testcontainers.com 공식 가이드 |
| 5기능 SC 매핑 · 도구 스택 | `docs/harness-research.html` §5 (외부 링크 HTTP 200 검증본) |

⚠️ Java 테스트 골격은 **구조만** — 실제 SCG 버전·의존성에서 컴파일·실행 미검증. 프로젝트 적용 시 확인 필수.

---

## 5. Phase 1 완료 기준(SC) 대비 자기 점검

| SC | 상태 | 근거 |
|----|------|------|
| 1. 5기능 검증대상·더블·SC 표 | ✅ | 규칙 GWV-01 표 |
| 2. 피라미드(통합 최두껍) + 스텁괴리→계약 명문화 | ✅ | 규칙 GWV-02 |
| 3. 도구 스택 고정 + 버전 재확인 경고 | ✅ | 규칙 GWV-03 + ⚠️ 주석 |
| 4. glob 자동 로드 + audit 38 PASS | ✅ | `paths:` 프런트매터 · `harness-audit` exit 0 |

---

*Created: 2026-07-09 · Phase 1 of milestone v2 · 미커밋(사용자 검토 대기)*
