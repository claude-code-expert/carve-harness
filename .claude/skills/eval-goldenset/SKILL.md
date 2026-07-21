---
name: eval-goldenset
description: 골든셋(고정 입력→루브릭 케이스)으로 산출물 품질을 정량 채점하고 점수 추이를 추적해 회귀를 잡는다. 프롬프트·에이전트·스킬·규칙을 바꾼 뒤 "더 나빠지지 않았는지"를 숫자로 확인할 때, 또는 반복 신뢰도(pass@k/pass^k)를 재고 싶을 때 발동.
---

# eval-goldenset — 골든셋 정량평가 (모델 무관 SOP)

> 권위는 도구가 아니라 이 절차에 있다. `carve-eval` 워크플로는 이 절차를 코드로 자동 실행할 뿐이다.
> 태스크당 완성도는 `checklist-loop`(항목 5축 채점)이 담당하고, 이 스킬은 **고정 케이스 집합의 품질을 시간축으로** 관리한다.

## 언제 쓰나

- 프롬프트·`CLAUDE.md`·에이전트·스킬·규칙을 바꾼 뒤 **회귀 확인** — "이 변경이 출력을 나쁘게 만들지 않았나"를 숫자로.
- 데모는 되는데 프로덕션은 무너지는지 — **pass@k(능력)** vs **pass^k(일관성)** 분리 측정.
- 안 쓰는 경우: 정답 없는 탐색·리서치, 골든셋을 유지할 사람이 없을 때(유지 안 하면 추이가 무의미).

## 골든셋 형식 (`specs/goldenset/*.json`)

```json
{
  "suite": "cs-agent",
  "cases": [
    {
      "id": "refund-policy",
      "prompt": "고객: 어제 산 제품 환불돼요? 규정대로만 답하라.",
      "k": 3,
      "assert": [
        { "type": "contains",    "value": "14일" },
        { "type": "regex",       "value": "환불|반품" },
        { "type": "not_contains","value": "무조건" },
        { "type": "llm-rubric",  "value": "규정 수치를 정확히 인용하고 규정 외 약속을 하지 않는다" }
      ]
    }
  ]
}
```

- `assert.type`: `contains` · `not_contains` · `regex` · `not_regex`(결정론, 워크플로가 순수 채점) · `llm-rubric`(정성, evaluator 위임).
- `k`: 반복 실행 횟수(기본 1, 상한 10). k>1이면 pass@k·pass^k가 의미를 가진다.
- 알 수 없는 assert 타입·잘못된 정규식은 **fail-closed**(통과로 새지 않음).

## 채점 규칙

- 한 실행이 green = **모든 결정론 assert 통과 AND 모든 llm-rubric 통과**.
- `caseScore = green/k × 100`(일관성률). `pass_at_k = green≥1`, `pass_pow_k = green==k`.
- `suiteScore = 케이스 caseScore 평균`. 임계(기본 70) 미만 케이스는 리포트에 나열.

## 회귀 게이트

- 직전 baseline(`specs/eval-score.json` 마지막 run) 대비 `suiteScore`가 **DELTA(기본 3pt) 초과 하락**하면 `regressed`.
- `specs/eval-score.json`은 append-only 추이(`{"runs":[{run, suiteScore, cases[]}]}`) — 기존 원소 수정 금지.
- 강제(CI/pre-push 차단)는 옵트인 — 팀이 골든셋을 유지할 때만 배선한다(과잉 차단 방지).

## 시작 로드맵 (덱 §5)

1. **일찍, 작게** — 실제 실패 20~50건으로 골든셋 v1. 수백 개 불필요.
2. **이미 하는 것에서** — 릴리스 전 수동 체크·버그 트래커·CS 큐가 최고 소재.
3. **모호하지 않게** — 품질 기준 = 전문가 2명이 독립적으로 같은 합/불 판정.
4. **생성 케이스는 인간 검수 필수** — Claude로 케이스를 늘리되 자기강화 방지.

## 워크플로로 자동 실행

```
/eval                       # specs/goldenset/*.json 전체 재채점 → 추이 append → 회귀 판정
```

또는 발화에 `carve-eval 실행`. 인자: `{ goldenset?: glob, threshold?: 70, delta?: 3 }`.

## 참고
- 루프 코드: `.claude/workflows/carve-eval.js`
- 예시 골든셋: `.claude/skills/eval-goldenset/example-goldenset.json`
- 태스크당 5축 채점: `.claude/skills/checklist-loop/SKILL.md`
