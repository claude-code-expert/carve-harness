# Phase 4 — TDD/게이트웨이 서브에이전트

> 마일스톤 v2, Phase 4 산출물. 대상 요구사항 TESTAGENT-01, TESTAGENT-02.
> 갭 분석 3순위: 테스트 우선·walking skeleton·테스트 충분성 평가를 담당하는 서브에이전트가 없었다.

---

## 0. 이 페이즈가 만든 것

| 산출물 | 역할 | 축(생성/검증) |
|--------|------|----------------|
| `.claude/agents/tdd-guide.md` | red→green 루프 유도, GSD `<verify><done>` 연결 | 계약 수립 |
| `.claude/agents/e2e-runner.md` | Walking Skeleton 세우고 실행 | 실행 |
| `.claude/agents/pr-test-analyzer.md` | 변경분 테스트 충분성 평가 | **검증(Evaluator)** |
| `.claude/agents/security-reviewer.md` (확장) | 게이트웨이 인증/인가/레이트리미트 우회 점검 추가 | 검증 |

**지표**: 에이전트 16종(기존 13 + 3), audit 40 PASS(프런트매터 검증 통과).

인증/인가 누락은 사용자 지시대로 **신규 에이전트를 만들지 않고** 기존 `security-reviewer`를 확장했다(중복 회피, YAGNI).

---

## 1. 이론 — 왜 에이전트로 나누는가

### 1.1 생성/검증 분리 (Self-Eval Blindspot)
`AGENTS.md §6`: 생성(Generator)과 검증(Evaluator)은 분리한다. 자기가 짠 코드를 자기가 채점하면 맹점을 못 본다. Phase 4의 에이전트는 이 분리를 실체화한다:
- **tdd-guide**: 테스트 계약을 세운다(구현 안 함).
- **e2e-runner**: 뼈대를 돌려 관통을 증명한다.
- **pr-test-analyzer**: 결과물의 테스트 충분성을 **독립적으로** 판정한다.
구현은 주 세션(생성)이, 검증은 이 에이전트들이 — 축이 갈린다.

### 1.2 게이트(훅)와 에이전트의 역할 차이
- **훅(GATE-04)**: 기계적·결정적. "게이트웨이 테스트가 **돌았고 통과했는가**"를 exit 2로 강제. 판단 없음.
- **에이전트(pr-test-analyzer)**: 판단적. "테스트가 **충분한가**, SC를 실제로 방어하는가"를 평가. 
훅은 존재/통과를, 에이전트는 품질/충분성을 본다. GATE-04의 best-effort 스킵(no-test)이 조용히 넘긴 누락을 pr-test-analyzer가 드러낸다 — 둘이 상보적이다.

### 1.3 TDD 루프와 게이트의 연결
```
tdd-guide: SC → 실패 테스트(red) 먼저
   ↓ 구현(주 세션)
GATE-04(훅): 응답 종료 시 *GatewayIntegration* 실행 → green 기계 확인
   ↓
pr-test-analyzer: "이 테스트가 SC를 충분히 덮는가" 독립 평가
```
red는 에이전트가 유도, green은 훅이 확인, 충분성은 에이전트가 판정 — 각 단계에 담당이 있다.

---

## 2. 사용 방법

### 2.1 에이전트 호출
description 자동 위임 또는 명시 호출:
```
"use the tdd-guide agent to set up tests for the rate-limit filter"
"use the e2e-runner agent to run the walking skeleton"
"use the pr-test-analyzer agent on this diff"
"use the security-reviewer agent"   # 게이트웨이 인증/인가 포함
```

### 2.2 각 에이전트가 하는 일
| 에이전트 | 입력 | 출력 |
|----------|------|------|
| tdd-guide | 대상 기능·SC | 실패 테스트 계약(구현 X), red 확인, GSD 슬롯 연결 |
| e2e-runner | 시나리오 1개 | 관통 PASS/FAIL + 실패 구간 특정 + 다음 슬라이스 |
| pr-test-analyzer | 변경분(diff/PR) | 심각도별 테스트 갭 목록(커버리지·SC매핑·스텁괴리·더블오용·피라미드) |
| security-reviewer | 게이트웨이 코드 | 인증누락·토큰검증구멍·인가누락·레이트리미트우회·시크릿노출 |

### 2.3 워크플로 통합
```
1) /plan 또는 tdd-guide → 게이트웨이 기능 SC를 실패 테스트로
2) 구현
3) 응답 종료 → GATE-04(훅)가 *GatewayIntegration* 자동 실행 (green 강제)
4) e2e-runner → walking skeleton 관통 확인
5) pr-test-analyzer + security-reviewer → 충분성·보안 독립 검증 (생성≠검증)
6) /verify → SC 대조
```

### 2.4 확인
```bash
ls .claude/agents/{tdd-guide,e2e-runner,pr-test-analyzer}.md   # 존재
bash .claude/hooks/harness-audit.sh | grep -i "frontmatter\|passed"
#  → skills frontmatter valid · 40 passed (에이전트도 name/description 필수)
```

---

## 3. 확장해야 할 부분

### 3.1 조정·확장
- **모델 라우팅**: 현재 전부 `sonnet`. pr-test-analyzer 같은 대형 검증은 상위 모델로 올릴 수 있다(`model:` 필드).
- **tools 최소화**: 각 에이전트 `tools`를 필요 최소로 뒀다(tdd-guide/pr-test-analyzer는 Read·Grep·Bash). 쓰기 필요 없으면 Write 미부여(최소 권한).
- **도메인 확장**: 게이트웨이 외 백엔드 도메인(결제·주문)용 tdd-guide 프롬프트 특화가 필요하면 별도 에이전트보다 규칙(rules/) 추가가 가볍다.

### 3.2 안 한 것 (의도적)
- **자동 테스트 생성 에이전트**: 테스트를 자동으로 써주는 에이전트는 만들지 않았다 — tdd-guide는 계약을 세우고 구현/작성은 주 세션이. 자동 생성은 검증 없는 테스트를 양산할 위험.
- **인증/인가 전용 신규 에이전트**: security-reviewer 확장으로 충분(사용자 지시). 중복 에이전트 = 트리거 모호.

### 3.3 한계
- 에이전트는 **판단**이라 결정적이지 않다 — 훅(GATE-04)이 못 잡는 "충분성"을 보지만, 놓칠 수도 있다. 그래서 훅(결정적 하한선) + 에이전트(판단적 상한선) 둘 다 둔다.
- 게이트웨이 서브에이전트 불안정(메모리): 무거운 병렬/worktree 실행은 stall 이력. 단일 포그라운드 read-only 실행(리뷰·평가)은 정상 — 이 에이전트들은 대부분 read-only라 안전.

---

## 4. Phase 4 완료 기준(SC) 대비 자기 점검

| SC | 상태 | 근거 |
|----|------|------|
| 1. tdd-guide red→green + GSD 슬롯 연결 안내 | ✅ | `tdd-guide.md` 절차 5단계 |
| 2. e2e-runner·pr-test-analyzer valid 프런트매터로 추가 | ✅ | 에이전트 16종 · name/description 검증 |
| 3. 인증/인가는 security-reviewer 확장(신규 중복 없음) | ✅ | `security-reviewer.md` 게이트웨이 섹션 |
| 4. `/harness-audit` 프런트매터 검증 통과 | ✅ | AUDIT-06 · 40 PASS |

---

## 5. 마일스톤 v2 전체 요약 (Phase 1–4)

| Phase | 산출물 | 강제 계층 |
|-------|--------|-----------|
| 1 | gateway-testing.md 규칙 | 지식(설득) |
| 2 | GATE-04/05 Stop 게이트 + AUDIT-07 | 결정적 게이트(exit 2) |
| 3 | commit-msg 게이트 | 커밋 규율(비영 종료) |
| 4 | tdd-guide·e2e-runner·pr-test-analyzer + security-reviewer 확장 | 판단적 검증(생성≠검증) |

**최종 지표**: 훅 테스트 **125 passed**, `harness-audit` **40 PASS**, 에이전트 16·스킬 23·규칙 18·테스트 11 스위트.

**남은 것(별도 판단)**: 4순위 계층 AGENTS.md(멀티모듈일 때만 — 프로젝트 구조 확정 후), 선택 토큰관리(Out of Scope). v3 후보: 스텁 자동 생성, PostToolUse 즉시 피드백, gradle subproject 타깃.

---

*Created: 2026-07-09 · Phase 4 of milestone v2 · 미커밋(사용자 검토 대기)*
