---
name: evaluator-tuning
description: >
  Evaluator 튜닝 루프 — squad-evaluator의 오판(통과시켰어야/막았어야 한 것)을 모아 few-shot으로 보정한다.
  "평가자 튜닝", "오판 보정", "evaluator 개선" 요청에 사용. 1~2주 운영 도구.
---
# evaluator-tuning — 평가자 보정 루프

1. squad-evaluator 판정 로그에서 **오판 사례**를 수집한다(false pass / false fail).
2. 각 오판을 "입력 → 기대 판정 → 근거"로 정리한다.
3. `evaluation-criteria.md` 또는 평가자 프롬프트에 **few-shot 예시**로 추가한다.
4. 같은 케이스를 재평가해 교정을 확인한다. 1~2주에 걸쳐 반복하며 정확도를 올린다.

원칙: 기준은 사람이 정의하고, 평가자는 그 기준에 수렴시킨다(주관 금지).
