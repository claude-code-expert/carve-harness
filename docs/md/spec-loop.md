# specloop 사용법 — 교차검증 스펙 정합성 채점 루프

> **한 줄**: "구현했다"는 주장을 믿지 않고, 항목마다 실제 코드와 대조·테스트해 **0~100점으로 채점**하고,
> 전 항목이 **95점 이상**이 될 때까지 개발↔검증 루프를 자동으로 돌리는 하네스 서브시스템.
>
> 계약 정본: [`.claude/rules/conformance.md`](../../.claude/rules/conformance.md) — 스키마·루브릭·종료기준은 그 파일이 정본이다.
> 이 문서는 **사용법**만 다룬다. 모델 무관(Claude 아니어도 동일 절차).
> 진입 커맨드: **`/carve-eval`** (발화: carve-eval · evaluator · 평가지표 · 스펙 정합성 · 구현 내역 평가).

---

## 1. 무엇을 푸는가

LLM 개발의 병목은 코드 생성이 아니라 **검증**이다. "구현 완료"라는 선언과 실제 구현 사이의 간극 —
스텁만 있고 동작 안 함, 테스트 없음, 스펙 일부 누락, 주장은 있는데 코드가 없음 — 을 **기계적으로 잡는다.**

specloop은 이 간극을 세 장치로 닫는다:

1. **전수 체크리스트** — 스펙(SC)과 실제 git diff를 교차해 "구현 주장 요소"를 하나도 빠짐없이 열거(누락·허위 동시 포착).
2. **교차검증 채점** — 항목마다 독립 2렌즈로 0~100점, 두 점수의 **min** 채택(낙관 편향 차단).
3. **95점 게이트 루프** — 하나라도 95 미만이면 미진사항을 개발로 되먹여 다시 돌린다. 전 항목 ≥95라야 종료.

---

## 2. 언제 쓰나

| 쓴다 | 안 쓴다 |
| --- | --- |
| 스펙이 명확하고 "정말 다 됐는지" 항목 단위로 보증해야 할 때 | 한 줄 수정·오타 등 자명한 변경 |
| 구현 주장이 많아 사람이 전수 확인하기 버거울 때 | 탐색·리서치처럼 정답이 없는 작업 |
| 개발→검증→수정 루프를 자동으로 수렴시키고 싶을 때 | 테스트 인프라가 아예 없는 프로토타입 (test축 0 → 95 불가) |

---

## 3. 구성 (하네스 4표면 + 계약·게이트)

| 표면 | 파일 | 역할 |
| --- | --- | --- |
| 계약 | `.claude/rules/conformance.md` | 루브릭(5축)·CHECKLIST/SCORE 스키마·95 게이트·종료기준 정본 |
| 커맨드 | `.claude/commands/carve-eval.md` (`/carve-eval`) | 진입점 + 모델무관 수동 SOP |
| 스킬 | `.claude/skills/spec-checklist/` | 주장 요소 전수 열거 → `CHECKLIST.json` |
| 에이전트 | `.claude/agents/conformance-scorer.md` | 항목별 채점(read-only), 코드 대조 + verify 실행 |
| 워크플로 | `.claude/workflows/spec-conformance-loop.js` | 코드가 보유한 루프-스테이션(build→check→score→gate→loop) |
| 훅 | `.claude/hooks/conformance-gate.sh` | active-only Stop 게이트: 미통과 항목 있으면 완료 선언 차단 |

---

## 4. 루프 흐름

```
        ┌─────────────────────────────────────────────────────────┐
        │                                                         │
        ▼                                                         │
   [Spec 분해]  ─▶  [개발/빌드]  ─▶  [체크리스트 전수 열거]  ─▶  [2렌즈 채점]        │
   /plan·SC        fable-builder    spec-checklist           conformance-scorer  │
                   (생성자)          CHECKLIST.json          code-match / test-pass│
                                                              항목점수 = min(둘)   │
                                                                    │             │
                                                                    ▼             │
                                                              [게이트 95점]        │
                                                             전 항목 ≥95 ?         │
                                                          ┌────────┴────────┐     │
                                                        아니오               예     │
                                                          │                 │     │
                                     미진사항(deficiencies) 피드백 ──────────┘      DONE
                                                          └───────────────────────┘
   가드: MAX_ITER=8 · 동일오류 3회 → [ESCALATION] · 생성자≠검증자
```

핵심: **생성자(개발)와 검증자(scorer)는 절대 같은 에이전트가 아니다** (Self-Eval Blindspot 방지).

---

## 5. 채점 루브릭 (항목별 0~100)

| 축 | 배점 | 만점 조건 |
| --- | --- | --- |
| 코드 실재 (exists) | 25 | 실제 구현 존재 — 스텁·TODO·빈 함수 아님 |
| 주장 일치 (match) | 25 | 코드가 claim과 의미적으로 일치 |
| 테스트 통과 (test) | 25 | `verify` 명령 실제 실행 → 통과 |
| 계약·경계 (contract) | 15 | 타입·에러·입력검증·인가 경계 안전, 스택 [MUST] 위반 없음 |
| 회귀 없음 (no-regress) | 10 | 기존 통과 항목·기능 퇴행 없음 |

- **pass = 항목 점수 ≥ 95** (기본값; `CONFORMANCE_THRESHOLD` 환경변수로 조정, 하한 90).
- **테스트가 없으면 구조적으로 95 불가** (test 25점 상실) → 사실상 테스트를 강제한다.

### 교차검증 (2렌즈 min)
- `code-match` 렌즈: 코드·타입·계약을 **정적** 대조.
- `test-pass` 렌즈: `verify` 명령을 **실제 실행**해 원문 근거로 채점.
- 항목 점수 = **min(code-match, test-pass)** — 한 렌즈만 후하게 줘도 통과 못 함.

---

## 6. 상태 산출물

한 실행(slug)당 `specs/<slug>/` 아래에 남는다:

| 파일 | 내용 |
| --- | --- |
| `CHECKLIST.json` | 구현 주장 요소 전수 목록 (`id·claim·targets·acceptance·verify`) |
| `SCORE.json` | 항목별 점수·pass + 게이트 상태(`active·threshold·iteration`) |
| `EVAL-<n>.md` | n회차 채점 근거(사람이 읽는 파일:라인·테스트 원문) |

에이전트 간 통신은 항상 이 파일들을 경유한다.

---

## 7. 사용법

### 7.1 워크플로 (권장 — 조율을 코드에 위임)

옵트인이다. 아래 중 하나로 명시해야 실행된다:
- 발화에 `ultracode` 포함
- "워크플로우로 돌려줘" / "spec-conformance-loop 실행해줘"

```
"ultracode: 주문 취소 API 정합성 루프 돌려. spec-conformance-loop 실행"
"+300k 예산으로 spec-conformance-loop 실행. goal은 결제 취소 모듈"
```

인자 형식(직접 지정 시):

```json
{
  "goal": "주문 취소 API 구현",
  "slug": "order-cancel",
  "threshold": 95,
  "tasks": [
    { "id": "api", "goal": "src/api/cancel 구현", "owns": ["src/api/**"], "acceptance": "유효 취소 200, 중복 취소 409 (테스트)" }
  ]
}
```

`tasks` 생략 시 목표를 3~5개 태스크로 자동 분해한다(owns 비중복 강제).

### 7.2 커맨드 (단일 세션·타 에이전트 — 수동 SOP)

```
/carve-eval 주문 취소 API 구현
```

`/carve-eval`(발화: carve-eval·evaluator·평가지표·스펙 정합성·구현 내역 평가)은 아래 SOP를 순서대로 구동한다(모델 무관 — Cursor·Codex 등에서도 손으로 따라 하면 동일):

```
S0. slug 확정 + specs/<slug>/ 준비 (기존 CHECKLIST/SCORE 있으면 이어서)
S1. Spec:     /plan 으로 SC 분해 → 사용자 플랜 승인
S2. 개발:     implement / fable-builder (생성자)
S3. 체크리스트: spec-checklist → CHECKLIST.json (주장 전수 열거)
S4. 채점:     conformance-scorer 2렌즈 → SCORE.json(active=true) + EVAL-<n>.md
S5. 게이트:   전 항목 ≥95 ? 예→active=false·DONE / 아니오→deficiencies로 S2 피드백
S6. 가드:     MAX_ITER=8 · 동일오류 3회 → [ESCALATION]
```

---

## 8. 게이트 훅 동작 (active-only)

`conformance-gate.sh`는 Stop(응답 종료) 시 `specs/*/SCORE.json`을 스캔한다:

| 상태 | 동작 |
| --- | --- |
| SCORE.json 없음 | 통과 (일반 세션 무영향) |
| `active:false` | 통과 (루프 종료·게이트 해제) |
| `active:true` + 전 항목 ≥threshold | 통과 |
| `active:true` + 미만 항목 존재 | **차단(exit 2)** — 완료 선언 못 함 |
| `score` 누락(malformed) | 차단 (fail-closed) |

즉 루프가 미완인 채로 "다 됐다"고 종료하는 것을 하네스가 물리적으로 막는다. 평상시(SCORE.json 없거나 inactive) 세션엔 전혀 영향 없다.

---

## 9. 종료·에스컬레이션

- **DONE**: 전 항목 ≥threshold AND 체크리스트가 spec/diff 전수 커버 → `active=false`.
- **MAX_ITERATIONS = 8**: 상한 도달 시 미달 항목과 함께 중단 보고.
- **동일 오류 3회 교착 → [ESCALATION]** 후 중단. 임의 판단 진행 금지.
- 매 재시도 전 반성 1줄: "무엇이 <95였나 / 어떤 구체 변경이 점수를 올리나 / 같은 접근 반복 중인가".
- 항상 피처 브랜치. 커밋·푸시는 명시 요청 시에만.

---

## 10. 예시 워크스루

```
목표: "쿠폰 적용 API"
회차 1:
  개발 → CHECKLIST 4항목 열거 (C1 적용, C2 중복불가, C3 만료검증, C4 응답스키마)
  채점 → C1:97 C2:70(중복검증 테스트 없음) C3:92(만료 경계 미검증) C4:100
        → SCORE.json active=true, 게이트 차단
  피드백 → C2에 "verify 테스트 추가·중복 시 409", C3에 "만료 경계 테스트" 지시
회차 2:
  개발(C2·C3만 재작업) → 재채점 → C2:96 C3:97
        → 전 항목 ≥95 → active=false → DONE
```

---

## 참고
- 계약 정본: `.claude/rules/conformance.md`
- 오케스트레이션 규칙: `docs/md/orchestration.md`
- 팀 절차: `docs/md/fable-team-guide.md`
