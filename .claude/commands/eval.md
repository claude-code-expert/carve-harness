---
description: 골든셋(specs/goldenset/*.json)을 재채점해 점수 추이를 남기고 baseline 대비 회귀를 판정한다
---
`carve-eval` 워크플로를 실행하라. `$ARGUMENTS`가 있으면 인자로 해석한다(`{ goldenset?: glob, threshold?: 70, delta?: 3 }`).

- `specs/goldenset/*.json`의 고정 케이스(입력→루브릭)를 케이스별 k회 실행해 채점한다.
- 채점: 결정론 assert(contains·regex·부정형)는 워크플로가 순수 채점, `llm-rubric`은 evaluator가 판정. green = 전부 통과.
- `pass@k`(능력)·`pass^k`(일관성)를 분리 산출하고, `suiteScore`를 `specs/eval-score.json`에 append(추이).
- 직전 baseline 대비 `delta`(기본 3pt) 초과 하락 시 `[REGRESSION]`으로 보고한다.
- 골든셋이 없으면 먼저 `eval-goldenset` 스킬로 케이스를 작성하라(실제 실패 20~50건으로 시작).

$ARGUMENTS
