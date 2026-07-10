# 개발 계획 — Java/Spring 출력 검증 Evaluator (결정적 확률)

> 출처: `docs/html/edd-complete-guide.html`(EDD 성숙도 LV2–3) × 하네스 갭 분석(판단 계층 미검증).
> Core Value: **Java/Spring 코드 출력에 대해 재현 가능한 품질 확률 `P ∈ [0,1] ± 오차`를 결정적으로 산출하는 evaluator.**
> 대상: `**/*.java` 산출물. LLM의 확률적 판정을 결정적 grader로 최대한 대체하고, 남는 정성 판정은 재현성을 측정해 오차범위와 함께 보고.

---

## 0. 문제 정의 — "결정적으로 확률이 나온다"의 의미

EDD 가이드 핵심(2장 특징1·7장): LLM 판정은 본질적으로 확률적이라 단일 assert로 못 끝낸다. 하지만 두 방법으로 **재현 가능한 수**를 만들 수 있다:

1. **결정적 grader** — 컴파일·테스트·커버리지·정적분석·아키텍처 규칙은 실행하면 **정확한 수**가 나온다(운 없음). 예: 테스트 47/50 통과 = 0.94. 이게 "결정적 확률"의 뼈대.
2. **재현성 측정된 judge** — 정성 판정(설계·Spring 관용)은 temperature=0 + 같은 프롬프트 k회(pass^k) → 평균±표준편차로 **비결정성을 제거가 아니라 정량화**. 그리고 골든셋으로 judge–human 일치율을 재 신뢰도를 보증.

→ 최종 산출: `P(quality) = Σ wᵢ·metricᵢ`, 각 metric은 결정적 grader(정확) 또는 교정된 judge(오차범위 동반). 체크리스트(가이드 10장) "모델 결정이 enum+스키마인가 / judge–human 일치율 측정하나"를 충족.

---

## v3 Requirements

### DET — 결정적 Java/Spring grader (확률의 뼈대)

- [ ] **DET-01**: 컴파일 게이트 — `gradlew compileJava` → `compile ∈ {0,1}`. 실패 시 이후 metric 0, 조기 종료.
- [ ] **DET-02**: 테스트 pass@k / pass^k — 테스트를 k회(기본 5) 실행해 `pass@k`(한 번이라도 green=능력)와 `pass^k`(전부 green=신뢰성)를 분리 산출. 플래키 테스트가 확률로 드러남(가이드 7-2).
- [ ] **DET-03**: 커버리지 — JaCoCo 라인/브랜치 `%` 추출(`build/reports/jacoco/...xml` 파싱). 핵심경로(인증·결제)는 브랜치 커버리지 우선.
- [ ] **DET-04**: 정적분석 밀도 — Checkstyle(Google) + SpotBugs + PMD 위반 수 / KLOC → `violation_density`. 0에 가까울수록 1점.
- [ ] **DET-05**: 아키텍처 규칙 — **ArchUnit**로 `java-spring/patterns.md` 규칙을 실행 테스트화: 계층 단방향, 필드주입 금지, `@ManyToOne(LAZY)`, Controller가 Entity 반환 금지, `@Transactional(readOnly)` 기본. 규칙 통과율 `archrules_pass_rate`.
- [ ] **DET-06**: N+1 탐지 — Hibernate `Statistics` 또는 datasource-proxy로 시나리오당 쿼리 수 측정, 임계 초과 = 결함. `nplus1_free ∈ {0,1}`.

### JDG — 교정된 LLM-Judge (정성 판정, 재현성 정량화)

- [ ] **JDG-01**: 구조화 출력 스키마 — evaluator는 자유 산문이 아니라 `{score: 0..1, confidence: 0..1, findings: [{rule, severity, file, line, why}]}`를 emit(가이드 예시 C 스키마 강제). JSON Schema 검증 통과 필수.
- [ ] **JDG-02**: 루브릭 기반 판정 — Spring 관용(정적 팩토리·DTO 경계·예외 계층·트랜잭션 경계 등 정적분석이 못 잡는 설계 품질)을 루브릭 문장으로 명문화, temperature=0.
- [ ] **JDG-03**: pass^k 재현성 — 같은 입력 k회 판정 → `mean ± std`. std가 임계 초과면 "판정 불안정" 플래그(루브릭 모호성 신호, 가이드 7-2).

### CAL — 골든셋 교정 (확률의 신뢰 전제)

- [ ] **CAL-01**: Java/Spring 골든셋 — 30~50 샘플: 정상 + **심은 결함**(필드주입·EAGER·Entity 반환·`@Valid` 누락·N+1·하드코딩 시크릿·삼켜진 예외·Flyway 기존파일 수정). 각 샘플에 인간 라벨(기대 verdict).
- [ ] **CAL-02**: judge–human 일치율 — evaluator 판정 vs 인간 라벨 → dimension별 agreement. 임계 미달 dimension은 judge 채점에서 제외(그 항목은 결정적 grader로만).
- [ ] **CAL-03**: guardrail recall/차단율 — 탐지형(심은 결함을 잡나) recall + 실제 "결함으로 판정" 비율 분리 측정(가이드 LV4: "달았다 ≠ 막힌다").

### CMP — 합성 스코어 + 게이트

- [ ] **CMP-01**: 가중 합성 — `P = w₁·compile + w₂·pass^k + w₃·coverage + w₄·(1−viol_density) + w₅·archrules + w₆·nplus1 + w₇·judge_score`. 가중치는 설정 파일, 오차범위는 pass^k·judge std에서 전파.
- [ ] **CMP-02**: 결정적 게이트 연동 — `P < 임계` + 오차범위 고려 시 Stop 게이트/CI에서 완료 차단(가이드 예시 D). 표본 크기 기반 허용치(가이드 7-2, 오차범위 없는 델타 금지).
- [ ] **CMP-03**: 리포트 — `{P, 오차, metric별 분해, findings, judge std}` JSON + 사람용 요약. 어떤 축이 P를 끌어내렸는지 명시.

### REG — 회귀·드리프트 (하네스 성격에 맞는 상한)

- [ ] **REG-01**: 골든셋 회귀 스위트 — 기존 `.claude/hooks/tests/` 패턴으로 골든셋 재실행, recall·일치율이 기준 이하로 떨어지면 실패.
- [ ] **REG-02**: 업그레이드 후 judge 재검증 — Claude Code 모델 업그레이드 후 REG-01 재실행(가이드 4장 포화·드리프트). `harness-audit`이 결정적 게이트에 하는 것을 judge에 대해 수행.

## Out of Scope

- 온라인 모니터링·드리프트 대시보드·트래픽 샘플링(가이드 LV4 운영) — 하네스는 배포 LLM 제품이 아니라 템플릿. 오프라인 골든셋 회귀로 갈음.
- 다른 스택(Node·Python) evaluator — Java/Spring 먼저(사용자 도메인). 성공 시 패턴 재사용.
- 골든셋 자동 생성 무검수 사용 — 자기강화(가이드 안티패턴2) 회피 위해 인간 검수 필수.

---

## 로드맵 (Phase)

- [ ] **Phase 1: 결정적 grader 백본** (DET-01~06) — 컴파일·pass^k·JaCoCo·정적분석·ArchUnit·N+1. **여기까지만으로도 대부분 결정적 수가 나온다** — judge 없이 절반 이상 커버.
- [ ] **Phase 2: 구조화 judge + 재현성** (JDG-01~03) — 스키마 강제·루브릭·pass^k std.
- [ ] **Phase 3: 골든셋 교정** (CAL-01~03) — 30~50 심은결함 샘플·일치율·recall. **judge를 신뢰해도 되는지 여기서 증명.**
- [ ] **Phase 4: 합성 스코어 + 게이트** (CMP-01~03) — 가중합·오차전파·리포트·Stop/CI 연동.
- [ ] **Phase 5: 회귀·드리프트** (REG-01~02) — 골든셋 회귀 + 업그레이드 재검증.

**적용 순서 근거**: 결정적 grader(정확·저비용) 먼저 최대한 커버 → 남는 정성만 judge → 골든셋으로 judge 신뢰 증명 → 합성 → 회귀. judge를 교정 없이 먼저 쓰는 것은 안티패턴2(검증 없는 Judge).

## Phase별 완료 기준(SC) 요약

| Phase | SC |
|-------|-----|
| 1 | 샘플 Java 프로젝트에서 compile·pass^k·coverage·violation·archrules·nplus1 6개 수치가 재현 가능하게 출력(같은 입력=같은 수) |
| 2 | evaluator가 스키마 검증 통과하는 `{score,confidence,findings}` emit, k회 std 리포트 |
| 3 | 30+ 골든셋에서 심은결함 recall + judge–human 일치율 산출, 임계 미달 dimension 자동 제외 |
| 4 | 단일 `P ± 오차` + metric 분해 리포트, 임계 미달 시 exit 2 |
| 5 | 골든셋 회귀가 테스트 스위트로 돌고, recall 하락 시 실패 |

---

## 도구 스택 (Java/Spring 특화)

| 목적 | 도구 | 산출 metric |
|------|------|-------------|
| 컴파일·테스트 | Gradle | compile 0/1, pass@k/pass^k |
| 커버리지 | JaCoCo | 라인·브랜치 % |
| 정적분석 | Checkstyle(Google)·SpotBugs·PMD | 위반/KLOC |
| 아키텍처 규칙 | **ArchUnit** | 규칙 통과율 (java-spring 규칙 실행화) |
| N+1 | Hibernate Statistics / datasource-proxy | 쿼리 수 |
| 통합(게이트웨이) | Testcontainers·WireMock (v2 재사용) | 통합 SC |
| judge | LLM (temp=0) + JSON Schema | score·confidence·findings |

> ArchUnit이 핵심 레버리지 — `java-spring/patterns.md`의 [MUST] 규칙(계층·주입·fetch·트랜잭션)을 **설득(md)에서 결정적 테스트로 승격**한다. 이게 "결정적 확률"의 Java 특화 심장.

---

## 위험·한계 (문서화된 천장)

- **judge는 완전 결정적이 될 수 없다** — temp=0도 완벽 재현 보장 아님. 그래서 제거가 아니라 std로 정량화하고, 결정적 grader 비중을 최대화(judge 가중치 최소).
- **골든셋 유지비** — 심은결함 샘플은 사람이 만들고 라벨링. 자동생성은 검수 필수(자기강화 회피).
- **프로젝트 의존** — ArchUnit/JaCoCo/Testcontainers는 대상 프로젝트 빌드에 의존. 없으면 해당 metric skip(best-effort, 하네스 관례) — 단 skip된 metric은 P 산출에서 제외하고 리포트에 명시(은폐 금지).
- **하네스 vs 프로젝트 경계** — evaluator 로직·골든셋은 하네스가 제공, 실제 grader 실행은 대상 프로젝트 빌드에서. 하네스는 "어떻게 재는가"를, 프로젝트는 "무엇을 재는가"를 소유.

---

*Created: 2026-07-09 · milestone v3 계획(미착수) · 근거: edd-complete-guide.html LV2–3, 하네스 판단계층 갭*
