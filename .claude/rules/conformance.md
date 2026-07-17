# conformance.md — Spec-Conformance Loop-Station 계약 (specloop)

> 스펙 정합성 채점 루프의 **공유 계약**. 모든 조각(스킬·에이전트·커맨드·워크플로·훅)이 이 파일의
> 스키마·루브릭·종료기준을 정본으로 참조한다. 모델 무관(Claude 아니어도 동일 절차).
> 위치 규약: 전역 적용이라 frontmatter 생략 (orchestration.md와 동일).

---

## 0. 루프 개요

```
Spec 분석 → 개발 → 체크리스트(주장 요소 전수 열거) → Evaluator 채점(항목별 코드대조+테스트)
    → 게이트: 전 항목 ≥95 AND 전수 커버  ─── 예 ──▶ DONE
    └── 아니오: 미진사항·수정지시 수집 → 개발 피드백 → 루프
```

- 채점은 **주장(claim) vs 실제 코드**를 항목 단위로 대조한다. 코드가 주장을 실증하지 못하면 감점.
- 생성자(개발)와 검증자(scorer)는 **절대 동일 에이전트가 아니다** (Self-Eval Blindspot 방지, AGENTS.md 6절).
- 완료 선언은 SCORE.json이 전 항목 pass일 때만. 명령 성공 ≠ 구현 정확(CLAUDE.md 4절).

---

## 1. 상태 산출물 (파일 기반 통신)

한 실행(run)의 slug 하나당 `specs/<slug>/` 아래:

| 파일 | 생성 주체 | 내용 |
| --- | --- | --- |
| `CHECKLIST.json` | spec-checklist 스킬 | 구현 주장 요소 전수 목록 |
| `SCORE.json` | conformance-scorer 집계 | 항목별 점수·pass + 게이트 상태 |
| `EVAL-<n>.md` | conformance-scorer | n회차 채점 리포트(사람이 읽는 근거) |

에이전트 간 통신은 항상 이 파일들을 경유한다. 직접 메모리 공유 없음.

---

## 2. CHECKLIST.json 스키마

```json
{
  "slug": "order-cancel",
  "goal": "주문 취소 API 구현",
  "source": "spec+diff",
  "items": [
    {
      "id": "C1",
      "claim": "POST /orders/{id}/cancel — 취소 엔드포인트 구현",
      "targets": ["src/api/cancel.ts"],
      "acceptance": "유효 주문 → 200 + status=CANCELLED, 이미 취소 → 409 (테스트 어서션)",
      "verify": "vitest run cancel.test.ts"
    }
  ]
}
```

- `claim`: "구현했다"고 주장하는 단일 요소. 한 항목 = 한 검증 단위.
- `targets`: 주장을 실증할 실제 파일/심볼. 비면 채점 시 0점 후보.
- `acceptance`: 검증 가능한 완료 기준(SC). 검증 방법이 안 떠오르면 SC가 아니다.
- `verify`: 재현 가능한 명령(테스트·grep). scorer가 실제 실행한다.
- **전수(exhaustive)**: spec의 SC + 실제 git diff를 교차해 누락·허위(주장은 있으나 코드 없음) 둘 다 항목화한다.

---

## 3. 채점 루브릭 (0~100, 항목별)

scorer는 항목마다 아래 5축을 합산한다. **증거(파일:라인, 테스트 원문) 없는 가점 금지.**

| 축 | 배점 | 만점 조건 |
| --- | --- | --- |
| 코드 실재 (exists) | 25 | `targets`에 주장 기능의 실제 구현이 있다(스텁·TODO·빈 함수 아님) |
| 주장 일치 (match) | 25 | 코드가 `claim`과 의미적으로 일치(부분 구현·다른 동작이면 비례 감점) |
| 테스트 통과 (test) | 25 | `verify` 명령 실제 실행 → 통과. 테스트 없음/실패 → 0 |
| 계약·경계 (contract) | 15 | 타입·에러·입력검증·인가 등 경계 안전(스택 rules의 [MUST] 위반 없음) |
| 회귀 없음 (no-regress) | 10 | 이 항목이 기존 통과 항목·기능을 퇴행시키지 않음 |

- **pass 기준: 항목 점수 ≥ 95** (기본 임계값; `CONFORMANCE_THRESHOLD` 환경변수로 조정 가능, 하한 90).
- 95는 "테스트 통과(25) + 코드 실재·일치 완전(50) + 계약 만점(15) + 회귀 5/10" 수준 — **테스트가 없으면 구조상 95 불가**(test 25 상실) → 사실상 테스트 강제.
- 교차검증: scorer를 **2렌즈로 독립 실행**한다 — `code-match`(코드·계약 정적 대조)와 `test-pass`(verify 실제 실행). 두 렌즈 점수의 **min**을 항목 점수로 채택(낙관 편향 차단).

---

## 4. SCORE.json 스키마 (게이트 정본)

```json
{
  "slug": "order-cancel",
  "active": true,
  "threshold": 95,
  "iteration": 2,
  "items": [
    { "id": "C1", "score": 97, "pass": true,  "deficiencies": [] },
    { "id": "C2", "score": 80, "pass": false, "deficiencies": ["verify 명령 없음", "입력검증 누락"] }
  ]
}
```

- `active`: 루프 진행 중이면 true. 완료·중단 시 false로 내려 게이트 해제.
- 게이트 통과 = `active==false` 또는 (모든 item.score ≥ threshold).
- `deficiencies`: <95 항목의 구체 미진사항 — 다음 루프의 개발 피드백 입력.

---

## 5. 루프 종료 기준 (orchestration.md 5절 준수)

- **DONE**: 전 항목 score ≥ threshold AND 체크리스트가 spec/diff를 전수 커버. → `active=false`.
- **MAX_ITERATIONS = 8**: 상한 도달 시 중단 후 미달 항목과 함께 보고.
- **동일 오류 3회 교착 → [ESCALATION]** 후 중단. 임의 판단 진행 금지.
- 각 재시도 전 반성: "무엇이 <95였나 / 어떤 구체 변경이 점수를 올리나 / 같은 접근 반복 중인가".
- 항상 피처 브랜치. 커밋·푸시는 명시 요청 시에만.

---

## 6. 모델 라우팅 (orchestration.md 1절 정합)

| 역할 | 모델 | 비고 |
| --- | --- | --- |
| 오케스트레이터(루프 조율) | opus · high | carve-eval 커맨드 / spec-conformance-loop 워크플로 구동 |
| 개발(빌더) | sonnet · high | implement / fable-builder |
| conformance-scorer | sonnet · high | read-only, 채점·근거만 |
| 체크리스트 생성 | sonnet | spec+diff 열거 |

생성자·검증자 분리 불변. scorer는 코드를 고치지 않는다 — 지적만.
