# Everything Claude Code (ECC) — 검증 리포트

> **목적**: [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) 를 Run-AI 프로젝트에 도입할지 평가
> **방식**: 격리 환경에서 정적 분석 + 1샷 코딩 비교 실험
> **작성일**: 2026-04-08
> **결과 요약**: **현 시점 도입 비추천. 일부 컴포넌트만 선택적 참고 권장.**

---

## 1. ECC 개요

| 항목 | 내용 |
|------|------|
| 정체 | "Agent harness 성능 최적화 시스템" — 단순 설정팩 X |
| 범위 | Skills, Agents, Hooks, Rules, MCP, Plugins, 자체 Rust 컨트롤 플레인(`ecc2/`) |
| 대상 하네스 | Claude Code, Cursor, Codex, OpenCode, Gemini, CodeBuddy 등 |
| 라이선스 | MIT |
| 특징 | Anthropic Hackathon Winner, 지속 활발 개발 (v1.10.0 / Apr 2026) |

### Claims (README 기준)

- "10+ months of intensive daily use" 검증
- 38 agents / 156 skills / 72 commands
- "Research-first development" 원칙
- 메모리 지속, 토큰 최적화, 보안 스캐닝(AgentShield)
- 12 language ecosystems (Java, Python, Go, TS, Kotlin 등)

---

## 2. 설치 영향 분석 (Install Plan Inventory)

ECC를 Java target으로 dry-run한 결과 (`bash install.sh --dry-run --json --target claude java`):

| 디렉토리 | 추가 파일 수 | 내용 |
|----------|--------------|------|
| `~/.claude/rules/` | 89 | 언어/공통 룰 (Java, Python, Go, TS 등 + common) |
| `~/.claude/scripts/` | 88 | hooks, automation, observability 스크립트 |
| `~/.claude/commands/` | 79 | 슬래시 명령 |
| `~/.claude/skills/` | 72 | SKILL.md 형식 도메인 지식 |
| `~/.claude/.agents/` | 65 | 플러그인 marketplace 정의 |
| `~/.claude/agents/` | 47 | 스페셜리스트 sub-agent 정의 |
| `~/.claude/hooks/` | 2 | SessionStart, Stop 훅 |
| 기타 | 7 | plugin.json, marketplace.json, mcp-configs 등 |
| **합계** | **448 파일** | |

### Java/Backend 관련 핵심 자산

- **Agents**: `java-reviewer`, `java-build-resolver`, `code-architect`, `code-reviewer`, `database-reviewer`, `security-reviewer`
- **Skills**: `springboot-patterns`, `springboot-security`, `springboot-tdd`, `springboot-verification`, `java-coding-standards`, `backend-patterns`, `api-design`
- **Rules**: `rules/java/{coding-style, patterns, testing, security, hooks}.md`

이 부분은 우리 프로젝트와 직접적으로 관련 있어 보이는 자산들. 나머지 약 350개는 Run-AI에 적합하지 않거나 (다른 언어/하네스/도메인) 메타 인프라.

### 사이드이펙트

- `npm install` → 213개 노드 패키지
- 백그라운드 데몬 (observer, AgentShield)
- SQLite session state store
- 글로벌 hooks 등록 (SessionStart, Stop, etc.)
- MCP 서버 추가
- **현재 `~/.claude/`에 설치된 SuperClaude 프레임워크와 충돌 가능성 있음**

---

## 3. 1샷 비교 실험

### 실험 설계

| 항목 | 값 |
|------|-----|
| Task | `GET /api/v1/categories/roots` 엔드포인트 구현 |
| 범위 | Repository 확장 + DTO + Service + Controller + 단위 테스트 + NOTES |
| 산출물 | 6개 파일 |
| 격리 | sub-agent 각각 독립 컨텍스트 (general-purpose) |
| 양쪽 공통 | 동일한 프로젝트 컨텍스트 (Category 엔티티, ApiResponse, ErrorCode, HelloController 패턴) |
| Vanilla | 프로젝트 컨벤션만 |
| ECC | 동일 + ECC Java rules (`coding-style`, `patterns`, `testing` 약 11KB) 주입 |

### 산출물 라인 수

| 파일 | Vanilla | ECC | 차이 |
|------|---------|-----|------|
| CategoryController.java | 24 | 23 | -1 |
| CategoryRepository.java | 10 | 9 | -1 |
| CategoryResponse.java | 23 | 23 | 0 |
| CategoryService.java | 24 | 23 | -1 |
| CategoryServiceTest.java | 69 | 67 | -2 |
| NOTES.md | 9 | 8 | -1 |
| **합계** | **159** | **153** | **-6 (-3.8%)** |

거의 동일한 분량.

### 실측 시간 / 토큰

| 지표 | Vanilla | ECC |
|------|---------|-----|
| 실행 시간 | 52.9s | 40.3s |
| Tool uses | 7 | 6 |
| Total tokens | 61,362 | 62,329 |

ECC가 약간 빠르고 토큰은 거의 동일. 의미있는 차이 아님.

### 산출물 비교 (semantic diff)

#### 100% 동일

- `CategoryResponse.java` (DTO record + `from(Category)` factory)
- `CategoryRepository.java` (derived query 동일: `findByParentIsNullAndIsActiveTrueOrderBySortOrderAsc`)
- `CategoryController.java` (구조/로직 동일)

#### 의미있는 차이

| 항목 | Vanilla | ECC | 평가 |
|------|---------|-----|------|
| `@Transactional` 위치 | 클래스 레벨 (`readOnly=true`) | 메서드 레벨 | **무승부**. 둘 다 유효. 클래스 레벨이 read-only 서비스에 더 일반적인 Spring 관용. |
| Mockito 주입 | `@InjectMocks` | `@BeforeEach` 수동 생성자 호출 | **무승부**. ECC는 룰에 명시된 예제 패턴을 그대로 따랐음. `@InjectMocks`도 표준. |
| BDD 주석 | `// given // when // then` 사용 | 사용 안 함 | Vanilla 약간 우세 (가독성) |
| Mock 스타일 | `BDDMockito.given().willReturn()` | `Mockito.when().thenReturn()` | 무승부 |
| `@DisplayName` 언어 | **한국어** ("루트 카테고리를...") | **영어** ("getRootCategories returns...") | **ECC 우세**. 프로젝트 룰 ("코드/주석은 영어")과 일치 |
| 테스트 명명 | `getRootCategories_returnsMappedResponses` | `getRootCategories_activeRoots_returnsMappedResponses` | ECC 우세 (`method_scenario_expected` 패턴 더 엄격) |
| import 순서 | java/javax 분리 + 빈 줄 | 알파벳순 통합 | Vanilla 우세 (Java 관용) |
| NOTES.md 구조 | 평탄 bullet | 항목별 prefix (`Repository:`, `DTO:`, ...) | ECC 약간 우세 |

#### 종합 점수

| 평가 차원 | Vanilla | ECC | 비고 |
|-----------|---------|-----|------|
| 컴파일 가능성 | ✅ | ✅ | 양쪽 다 ok |
| 프로젝트 컨벤션 준수 | 9/10 | 9.5/10 | 영어 DisplayName 차이 |
| 코드 품질 | 9/10 | 9/10 | 본질적으로 동일 |
| Over-engineering | 없음 | 없음 | 양쪽 다 절제됨 |
| 응답 길이 | 153~159 라인, 적절 | 동일 | |
| Guardrail 위반 | 없음 | 없음 | |

**결론**: ECC가 만든 차이는 **5% 미만의 코스메틱 개선**. 본질적인 코드 품질, 아키텍처 결정, 컨벤션 준수에서 의미있는 차이는 없었다.

---

## 4. 분석

### 왜 차이가 작은가?

1. **프로젝트 컨텍스트가 충분히 명확함**: Run-AI의 `CLAUDE.md` + `.claude/rules/`가 이미 핵심 컨벤션을 다 정의함. ECC가 추가로 알려줄 게 거의 없음.
2. **Task가 잘 정의됨**: 단일 read-only 엔드포인트는 결정 공간이 좁음. 어떤 도구든 비슷한 답에 수렴.
3. **모델이 동일**: 둘 다 같은 Claude 모델. ECC는 prompt engineering(룰 주입)에 불과하므로 모델 능력 자체는 안 바뀜.
4. **1샷 시나리오에선 hook/skill/memory 작동 안 함**: ECC의 자랑인 SessionStart/Stop hooks, 세션 간 메모리, skill 자동 활성화는 multi-turn에서나 의미.

### ECC가 빛날 수 있는 상황

| 시나리오 | 이유 |
|----------|------|
| **장시간 세션 / multi-turn 작업** | SessionStart/Stop 메모리 hooks, skill 진화 |
| **컨벤션이 sparse한 greenfield** | 룰북이 비어있을 때 ECC 룰이 default 채워줌 |
| **여러 언어 동시 작업** | 12개 언어 룰이 자동 활성화 |
| **보안 민감 코드** | AgentShield 자동 스캐닝 |
| **Cross-harness 협업** | Cursor/Codex/Claude 간 일관성 필요할 때 |

### ECC 비용

1. **글로벌 오염**: 448 파일이 `~/.claude/`에 추가, 기존 SuperClaude와 충돌 가능
2. **노이즈 증가**: 156개 skills 중 150개+ 는 우리와 무관 → 컨텍스트 토큰 낭비 가능
3. **블랙박스 동작**: hooks/observer/AgentShield가 백그라운드에서 뭐 하는지 추적 어려움
4. **유지보수 비용**: ECC 업데이트 시 수동 sync, 우리 커스텀과 머지 충돌
5. **벤더 의존**: Anthropic 내부 도구는 아님. 외부 메인테이너 1인 의존도 높음

### Run-AI 컨벤션과 잠재 충돌

| ECC 권장 | Run-AI 컨벤션 | 충돌? |
|----------|---------------|-------|
| `record` DTO | 동일 (CLAUDE.md 명시) | ❌ |
| 생성자 주입 | 동일 | ❌ |
| `@Transactional` 서비스 레이어 | 동일 | ❌ |
| 한국어 응답 | (ECC는 코드 영어 강제, 응답 한국어는 별개) | ❌ |
| Optional 사용 규율 | 명시 안 됨 (참고 가치 있음) | ❌ |

큰 충돌은 없음. 대부분 이미 우리 룰에 포함됨.

---

## 5. 권고

### 결론: **풀 도입 비추천**

근거:
- 1샷 코딩 품질에서 측정 가능한 개선 5% 미만
- 비용(글로벌 오염, 노이즈, 유지보수) 대비 ROI 낮음
- 우리 `CLAUDE.md` + SuperClaude 조합이 이미 동등한 룰 커버

### 대신 권장: **선택적 참고 (Cherry-pick)**

다음 자산만 직접 읽고, 가치 있는 부분을 우리 `.claude/rules/` 또는 `CLAUDE.md`에 흡수:

| ECC 자산 | 흡수 가치 | 작업 |
|----------|-----------|------|
| `skills/springboot-tdd/SKILL.md` | ⭐⭐⭐ | TDD 패턴 우리 backend 룰에 추가 |
| `skills/springboot-verification/SKILL.md` | ⭐⭐⭐ | MockMvc / Testcontainers 패턴 |
| `rules/java/testing.md` | ⭐⭐⭐ | 테스트 명명/구조 룰 |
| `skills/api-design/SKILL.md` | ⭐⭐ | REST 설계 가이드 (이미 우리 컨벤션 있지만 보강 가능) |
| `agents/java-reviewer.md` | ⭐⭐ | 코드 리뷰 체크리스트 참고 |
| `skills/backend-patterns/SKILL.md` | ⭐⭐ | 일반 백엔드 패턴 사전 |

**예상 작업량**: 1~2시간 (읽고 추리고 우리 룰에 통합)
**리스크**: 0 (글로벌 환경 안 건드림)

### 만약 풀 도입을 진행한다면

전제: multi-turn 워크플로/메모리 hooks/AgentShield 같은 ECC 고유 기능을 적극 활용할 의지가 있을 때만.

조건:
1. 별도 사용자 계정 또는 Docker 컨테이너에서 운영 (현재 `~/.claude/` 절대 안 건드림)
2. SuperClaude 프레임워크와 동시 운영 시 충돌 사전 검증
3. AgentShield 등 백그라운드 데몬 활성화 여부 명시적 결정
4. ECC v1.10.0 알파(`ecc2/` Rust 컨트롤 플레인)는 회피

---

## 6. 재현 방법

```bash
# 1. 격리된 sandbox 위치
~/sandbox/ecc-eval/
├── everything-claude-code/   # ECC repo (shallow clone)
├── vanilla/output/           # Vanilla 산출물 6개
└── ecc/output/               # ECC-augmented 산출물 6개

# 2. 양쪽 비교 (이미 위 §3에 정리)
diff -u ~/sandbox/ecc-eval/vanilla/output/ ~/sandbox/ecc-eval/ecc/output/

# 3. ECC dry-run (실제 설치 없음)
cd ~/sandbox/ecc-eval/everything-claude-code
bash install.sh --dry-run --json --target claude java

# 4. 정리
rm -rf ~/sandbox/ecc-eval
```

산출물은 sandbox 안에만 존재하며 프로젝트/글로벌 환경 무오염.

---

## 7. 결론 한 문장

> **ECC는 잘 만들어진 시스템이지만, Run-AI의 현재 컨벤션 성숙도와 SuperClaude 기 도입 상태를 고려하면 풀 도입 ROI가 낮다. 대신 `springboot-tdd`, `rules/java/testing.md`, `api-design` 등 3~5개 자산을 우리 룰에 흡수하는 cherry-pick 전략이 비용/효과 최적이다.**
