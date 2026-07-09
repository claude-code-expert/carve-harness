# Phase 2 — 게이트웨이 타깃 Stop 게이트 + 감사

> 마일스톤 v2, Phase 2 산출물 문서. 대상 요구사항 GATE-04, GATE-05, AUDIT-07.
> Phase 1이 세운 규칙(무엇을 검증)을 이제 **결정적 게이트로 강제**한다(응답 종료 전 자동 실행).

---

## 0. 이 페이즈가 만든 것

| 산출물 | 변경 | 역할 |
|--------|------|------|
| `.claude/hooks/stop-verify.sh` | GATE-04 로직 추가 | 게이트웨이 파일 변경 시 통합 테스트를 **증분 실행** |
| `.claude/hooks/harness-audit.sh` | AUDIT-07 추가 | 게이트웨이 룰 ↔ Stop 트리거 **매핑 점검** |
| `.claude/hooks/tests/stop-verify.test.sh` | 4케이스 추가 (10–13) | 타깃팅·full·실패차단·no-test 스킵 어서션 |

**결과 지표**: 훅 테스트 110건(기존 106 + 4), audit 39 PASS(기존 38 + AUDIT-07).

Phase 1은 "설득"(규칙 md), Phase 2는 "강제"(exit 2 게이트). 이제 게이트웨이 파일을 고치고 통합 테스트가 깨진 채 응답을 끝내려 하면, Stop 훅이 완료 선언을 **차단**한다.

---

## 1. 이론 — 왜 Stop 게이트이고, 왜 증분인가

### 1.1 하네스 피드백 기둥에서 Stop의 위치
하네스 3기둥 중 **피드백**은 "나쁜 결과를 사후 반려"한다. 그 지점이 `Stop` 훅 — 에이전트가 응답을 끝내려는 순간이다. PreToolUse(제약)는 나쁜 쓰기를 사전 차단하고, Stop(피드백)은 빌드·테스트가 깨진 채 "완료했습니다"를 못 하게 막는다.

**핵심 불변식**: 차단은 `exit 2`. Stop 훅이 `exit 2`를 반환하면 에이전트는 응답을 끝내지 못하고 실패를 마주한다.

### 1.2 무한 루프 함정 (기존 GATE-01)
Stop 훅이 무조건 차단하면: 차단 → 에이전트 재시도 → 또 차단 → **무한 루프**. Claude Code는 재검증 패스에 `stop_hook_active=true`를 준다. stop-verify.sh는 이걸 확인해 2번째 패스에선 1회 보고 후 양보(exit 0)한다. GATE-04는 이 기존 루프 가드 **뒤에** 얹혔다 — 게이트웨이 검증도 같은 보호를 받는다.

### 1.3 증분 검증의 이유 (기존 GATE-03 → 확장 GATE-04)
매 응답 종료마다 전체 빌드를 돌리면 개발이 마비된다. GATE-03은 이미 "변경된 스택만" 검증한다(java 변경 → gradle, ts 변경 → tsc). GATE-04는 이걸 **게이트웨이 단위로 한 겹 더** 좁힌다:

- 필터 한 줄 고쳤는데 전체 테스트 스위트(수백 개)를 도는 건 낭비다.
- 게이트웨이 관련 파일만 바뀌었으면, `*GatewayIntegration*` 테스트만 돌면 그 변경의 리스크를 덮는다.
- 단, **다른 java가 섞여 바뀌면 full로** 간다(안전 우선) — 게이트웨이 통합 테스트는 full에도 포함되므로 누락 없음.

이건 "속도 vs 안전"의 균형이다. 순수 게이트웨이 변경 = 빠른 타깃, 혼합 변경 = 안전한 full.

### 1.4 정책↔게이트 매핑 (AUDIT-07)
하네스의 조용한 실패 모드: **규칙(md)은 배포됐는데 그걸 강제하는 훅(sh)이 빠진** 경우 — "고아 정책(orphan policy)". 규칙은 있으니 있는 줄 아는데 실제론 아무것도 안 막는다. AUDIT-07은 이걸 기계적으로 잡는다: `gateway-testing.md`가 배포되면 `stop-verify.sh`에 GATE-04 트리거(`GatewayIntegration`)가 있어야 PASS. Phase 1(규칙)과 Phase 2(게이트)가 함께여야만 통과한다.

---

## 2. 사용 방법

### 2.1 동작 — 언제 무엇이 도는가
```
응답 종료 시도
   ↓ Stop 훅 (stop-verify.sh)
   ├─ stop_hook_active=true? → 1회 보고 후 양보 (루프 방지)
   ├─ jq 없음? → best-effort 스킵
   ├─ git으로 변경 감지
   │   · 게이트웨이 파일만 변경 → ./gradlew test --tests '*GatewayIntegration*'  ← GATE-04 타깃
   │   · 게이트웨이 + 다른 java → ./gradlew test (full, 게이트웨이 포함)
   │   · java 변경 없음 → java 스택 스킵
   └─ 실패(fail=1) → exit 2 (완료 차단)  ← GATE-05
```

### 2.2 게이트웨이 파일 판별 규칙
`stop-verify.sh`의 `GW_RE`:
```
([Gg]ateway|[Ff]ilter|[Aa]uth|[Rr]ate[Ll]imit)[^/]*\.java$ | /gateway/.*\.java$
```
- 파일명에 Gateway/Filter/Auth/RateLimit이 든 `.java`, 또는 `gateway/` 디렉토리 하위 `.java`.
- 예: `ApiGateway.java`·`JwtAuthFilter.java`·`RateLimitConfig.java`·`gateway/RouteConfig.java` → 게이트웨이.
- 예: `UserService.java`·`OrderController.java` → 아님(무관 → 트리거 안 됨).

### 2.3 프로젝트가 준비할 것
GATE-04가 실제로 물려면 대상 프로젝트에:
1. `./gradlew`(또는 `backend/gradlew`)가 있어야 한다.
2. 게이트웨이 통합 테스트가 **`*GatewayIntegration*` 네이밍**을 따라야 한다(예: `GatewayIntegrationTest`, `AuthGatewayIntegrationTest`). Phase 1 규칙 GWV가 이 컨벤션을 명시한다.
3. 없으면? gradle이 "no tests found"를 뱉고, 게이트는 **best-effort 스킵**(exit 0) — 컨벤션 미채택 프로젝트를 false-fail로 막지 않는다.

### 2.4 확인 방법
```bash
# 게이트웨이 룰↔게이트 매핑 점검
bash .claude/hooks/harness-audit.sh | grep AUDIT-07
#  → PASS: policy->gate: gateway rule -> stop-verify GATE-04 trigger (AUDIT-07)

# 게이트 로직 회귀 (fake gradlew로 타깃팅·실패차단 검증)
bash .claude/hooks/tests/stop-verify.test.sh
#  → 13 passed (GATE-04 타깃, mixed full, GATE-05 exit 2, no-test 스킵 포함)
```

---

## 3. 확장해야 할 부분

### 3.1 다음 페이즈
| 페이즈 | 추가 | 이 게이트와의 관계 |
|--------|------|--------------------|
| Phase 3 | commit-msg 게이트 | 병렬(커밋 규율) — 이 게이트와 독립 |
| Phase 4 | tdd-guide 에이전트 | red(실패 테스트 먼저) → 이 게이트가 green을 기계 확인 |
| Phase 4 | pr-test-analyzer | 이 게이트가 "돌았는지"를 넘어 "충분한지"를 평가 |

### 3.2 이 게이트 자체의 한계·확장 여지 (문서화된 천장)
- **네이밍 결합**: `*GatewayIntegration*` 문자열 컨벤션에 묶여 있다. 프로젝트가 다른 네이밍(`*GatewayIT*` 등)을 쓰면 `GW_RE`와 gradle 필터를 함께 조정해야 한다. 단일 소스(`GW_RE`)로 뒀으니 한 곳만 고치면 된다.
- **혼합 변경 = full**: 게이트웨이 + 무관 java가 섞이면 full로 간다. 대형 모노리스에선 여전히 무거울 수 있다 — 모듈 단위(gradle subproject) 타깃까지 좁히려면 `--tests` 대신 `:gateway:test` 같은 프로젝트 경로 타깃이 필요(프로젝트 구조 의존, v3 후보).
- **MVC/Reactive 무관**: 게이트는 테스트 네이밍만 보므로 SCG webflux/webmvc 어느 쪽이든 동작. 실제 테스트 도구(WebTestClient vs MockMvc)는 프로젝트 소관.
- **best-effort 스킵의 양날**: "no tests found"를 스킵하는 건 미채택 프로젝트 보호용이나, 오타로 테스트가 실제로 안 잡히는 경우도 조용히 통과시킨다. AUDIT-07은 "룰↔게이트 매핑"만 보지 "테스트 실재"는 안 본다 → Phase 4 pr-test-analyzer가 "게이트웨이 통합 테스트가 실제로 존재하는가"를 보완.

### 3.3 Deferred (v3 후보)
- **PostToolUse 즉시 피드백**: 문서 5-5 B는 게이트웨이 파일 저장 시(PostToolUse) 즉시 타깃 테스트를 돌린다. 우리는 Stop에만 뒀다(응답 단위). 편집 단위 피드백을 원하면 PostToolUse 훅 추가 — 단 매 편집 테스트는 무거우니 신중히.
- **gradle subproject 타깃**: 멀티모듈에서 `:gateway:integrationTest`로 좁히기.

---

## 4. 설계 결정 기록

| 결정 | 근거 |
|------|------|
| GATE-04를 Stop에 (PostToolUse 아님) | 하네스는 검증을 Stop에 모은다(posttool은 포맷 전용, 비차단). 응답 단위 검증이 편집 단위보다 가볍다. |
| 혼합 변경 시 full | 안전 우선 — 게이트웨이만 타깃하면 함께 바뀐 서비스 코드의 회귀를 놓친다. full은 게이트웨이 테스트도 포함하므로 누락 없음. |
| "no tests found" → 스킵 | 컨벤션 미채택 프로젝트를 false-fail로 막지 않는다(하네스 best-effort 철학, py exit 5·shellcheck 부재와 동일). |
| `GW_RE` 단일 소스 | 파일 판별 정규식을 훅 안 한 곳에 정의 → 네이밍 변경 시 한 곳만 수정(AUDIT-07은 같은 개념 참조). |
| AUDIT-07 조건부 | 게이트웨이 룰이 없는 하네스(비-게이트웨이 프로젝트)에선 점검 스킵 — 범용 하네스가 게이트웨이를 강요하지 않는다. |

---

## 5. Phase 2 완료 기준(SC) 대비 자기 점검

| SC | 상태 | 근거 |
|----|------|------|
| 1. 게이트웨이 파일만 변경 → `*GatewayIntegration*`만; 무관 변경 미트리거 | ✅ | 테스트 (10)(11) PASS · `GW_RE` + `java_other` 분기 |
| 2. 게이트웨이 통합 테스트 실패 → exit 2 | ✅ | 테스트 (12) PASS (GATE-05) |
| 3. 도구 부재 시 skip 통과 · `bash -n` clean | ✅ | 테스트 (13) no-tests 스킵 · syntax + shellcheck clean |
| 4. audit가 GWV↔GATE-04 매핑 점검 | ✅ | AUDIT-07 PASS (39 total) |

전체: 훅 테스트 **110 passed / 0 failed**, `harness-audit` **39 PASS / exit 0**, shellcheck `-S error` clean.

---

*Created: 2026-07-09 · Phase 2 of milestone v2 · 미커밋(사용자 검토 대기)*
