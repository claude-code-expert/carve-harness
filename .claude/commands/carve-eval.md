---
description: 스펙 정합성 채점 루프(carve-eval) — 구현 "주장"을 실제 코드·테스트와 2렌즈로 대조해 항목별 0~100점 채점하고, 전 항목 95점 게이트를 통과할 때까지 개발↔검증 루프를 돈다. 발화 트리거: carve-eval · evaluator · 평가지표 · 스펙 정합성 · 구현 내역 평가.
---

인자로 받은 목표(`$ARGUMENTS`)의 **구현 정합성**을 채점하고 게이트를 통과시킨다. "구현했다"는 선언을 믿지 않고 항목마다 코드·테스트로 실증한다. 계약 정본은 `.claude/rules/conformance.md`, 상세 사용법은 `docs/md/spec-loop.md`. 모델 무관 — 아래 SOP를 순서대로 구동한다(Cursor·Codex 등에서도 손으로 따라 하면 동일).

## 핵심 불변
- **생성자(개발) ≠ 검증자(conformance-scorer).** 절대 같은 에이전트가 채점하지 않는다(Self-Eval Blindspot 방지).
- 완료 선언은 `SCORE.json`이 전 항목 pass일 때만. 명령 성공 ≠ 구현 정확.
- 상태는 `specs/<slug>/`의 파일(CHECKLIST/SCORE/EVAL)로만 통신한다.

## SOP
```
S0. slug 확정 + specs/<slug>/ 준비 (기존 CHECKLIST/SCORE 있으면 이어서)
S1. Spec:      /plan 으로 완료기준(SC) 분해 → 사용자 플랜 승인
S2. 개발:      implement / fable-builder (생성자) — 코드 + 테스트
S3. 체크리스트: spec-checklist 스킬 → CHECKLIST.json (스펙 SC × git diff 전수 열거)
S4. 채점:      conformance-scorer (검증자, read-only) 2렌즈 → SCORE.json(active=true) + EVAL-<n>.md
               항목점수 = min(code-match 정적대조, test-pass verify 실제실행)
S5. 게이트:    전 항목 ≥ threshold(기본 95) ?
                 예   → SCORE.json active=false → DONE
                 아니오 → 각 항목 deficiencies를 개발(S2)로 되먹여 재작업 → S3
S6. 가드:      MAX_ITER=8 · 동일 오류 3회 → [ESCALATION] 후 중단(임의 판단 진행 금지)
```

## 채점 루브릭 (항목별 0~100)
| 축 | 배점 | 만점 조건 |
| --- | --- | --- |
| 코드 실재 (exists) | 25 | 실제 구현 존재 — 스텁·TODO·빈 함수 아님 |
| 주장 일치 (match) | 25 | 코드가 claim과 의미적으로 일치 |
| 테스트 통과 (test) | 25 | `verify` 명령 실제 실행 → 통과 |
| 계약·경계 (contract) | 15 | 타입·에러·입력검증·인가 경계 안전, 스택 [MUST] 위반 없음 |
| 회귀 없음 (no-regress) | 10 | 기존 통과 항목·기능 퇴행 없음 |

- **pass = 항목 점수 ≥ threshold.** 테스트 없으면 test 25축 상실 → 구조상 95 불가(사실상 테스트 강제).

## 게이트 훅
루프가 도는 동안 `specs/*/SCORE.json`은 `active=true`다. Stop 시 `conformance-gate.sh`가 미달 항목이 있으면 완료 선언을 **물리적으로 차단**(exit 2)한다. 전 항목 통과로 `active=false`가 되면 해제. 평상시(SCORE.json 없음) 세션엔 무영향.

## 자동화(옵트인)
조율을 코드에 위임하려면 워크플로를 명시적으로 실행한다:
```
"ultracode: <목표> 정합성 루프 돌려. spec-conformance-loop 실행"
```
인자: `{ "goal": "...", "slug": "...", "threshold": 95, "tasks": [...] }` (`tasks` 생략 시 3~5개로 자동 분해).

## 재시도 전 반성 (매 회차 1줄)
"무엇이 <threshold였나 / 어떤 구체 변경이 점수를 올리나 / 같은 접근을 반복 중인가."
항상 피처 브랜치. 커밋·푸시는 명시 요청 시에만.
