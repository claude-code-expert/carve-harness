# P2 — `domain_safety` 거부권(GATE-C7) + SUCCESS-CRITERIA

> 브랜치 `feat/eval-p2-veto-criteria`(P1 위) · 계획 `specs/eval-generalization-plan.md` §3 P2 · 블루프린트 §5.5(유형별 허용 실패율), §6.1(프롬프트=Eval), §6.8 Q1
> 결과: 체크리스트 항목 `type`, `domain_safety`는 100점 필수(Stop 게이트 차단). `specs/SUCCESS-CRITERIA.md` 실물 6항목 + 템플릿 + `/eval-init` Q3-b + 감사 검사. 전체 29 스위트 489건·감사 70 PASS.

## 1. 구성

| 요소 | 변경 |
|---|---|
| `checklist-gate.sh` GATE-C7 | `type: domain_safety` 항목이 `score < 100`(미채점 포함)이면 임계·총점 무관 exit 2, tombstone on. 기존 임계 규칙 앞에 판정. type 없는 항목은 불변 |
| `carve-verify-loop.js` | 체크리스트 스키마 `type: convention\|correctness\|domain_safety`(선택), 분해 프롬프트가 도메인 불변식 항목에 `domain_safety`를 붙이도록 지시, `pass` 계산이 게이트와 같은 규칙(안전은 100) |
| `checklist-loop` SKILL | `type` 필드 규약 |
| `specs/SUCCESS-CRITERIA.md` | 이 리포 실물 6항목(SC-01~06) — 기준/지시문/검사문/강제 네 줄, 골든셋 suite와 1:1 |
| `.claude/skills/eval-init/SUCCESS-CRITERIA.template.md` + SKILL Q3-b | Q1(크리티컬 경로)·Q3(불변식) 답에서 3줄 초안 → 확인 1회 → append. S5에서 CLAUDE.md 도메인 규칙과 같은 문장으로 기록 |
| `harness-audit.sh` AUDIT-09 | 파일이 있으면 3줄 형식 검사(PASS/FAIL), 없으면 INFO(성숙도 안내). 70체크 |
| `tests/checklist-gate.test.sh` +2 | 97점 domain_safety 차단 · 100점 + typed/untyped 97 통과 |

## 2. 왜 이 형태인가

- 블루프린트 §5.5는 convention 5% · correctness 3% · domain_safety 0%. 단일 임계(95) 위에 비율 게이트를 얹으면 "몇 건 중 몇 건"을 세야 해서 항목 수가 적은 검증 루프에선 의미가 약하다. **0%인 domain_safety만 거부권으로 구현**하고 나머지는 기존 95 임계로 둔다(계획 D-리스크 표와 todo #2 `[~]`에 명시).
- SUCCESS-CRITERIA는 "성공 기준 한 문장 = 지시문 = 채점 기준"을 파일로 묶는다. 이 리포에서는 골든셋 suite(guard·craft·hard·carve-harness)와 대응시켜 각 케이스가 어느 기준을 재는지 역추적 가능.

## 3. 사용방법

```jsonc
// specs/checklist.json 항목
{ "id": "amount-nonnegative", "type": "domain_safety", "claim": "...", "acceptance": "...", "owns": ["src/orders/**"], "score": null }
```
- 97점이어도 Stop이 막힌다: `[carve-harness:checklist] domain_safety 항목 미완 (100점 필수, 임계 무관)`.
- `/verify-loop`가 분해할 때 CLAUDE.md 도메인 규칙과 닿는 항목에 자동으로 `domain_safety`를 붙인다(프롬프트 지시). 손으로 돌릴 땐 `checklist-loop` SOP대로 직접 붙인다.
- `/eval-init` → Q3-b가 `specs/SUCCESS-CRITERIA.md` 초안을 만든다. 손으로: 템플릿 복사 후 항목당 4줄.

## 4. 완료 기준(SC) 검증

| SC | 증명 | 결과 |
|---|---|---|
| ① `type: domain_safety` 항목 score 94(97) → 총점 무관 exit 2 | `checklist-gate.test.sh` (14) | PASS |
| ② `type` 없는 기존 checklist.json 동작 불변 | (15) + 기존 13건 무수정 green | PASS |
| ③ 템플릿에 기준/지시문/검사문 3줄 형식 | 템플릿 파일 | PASS |
| ④ 이 리포 실물 ≥5항목(골든셋 suite 대응) | SC-01~06 | PASS |
| ⑤ audit "Q1 성공 기준 문장" PASS | `harness-audit` 70/70, AUDIT-09 줄 | PASS |
| 회귀 | `npm test` 29 스위트 489건 | PASS |

## 5. 한계

- convention/correctness 비율 게이트는 없다(단일 임계 95). 필요해지면 항목 수가 충분한 대형 체크리스트에서 `CARVE_CHECKLIST_FLOOR`와 별개 env로 도입.
- SUCCESS-CRITERIA와 골든셋 `llm-rubric` 문장의 **자동 대조**는 없다 — 감사는 형식만 본다. 문장 일치는 `/eval-init` 절차와 리뷰가 지킨다.
