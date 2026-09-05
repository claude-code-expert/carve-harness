---
description: 골든셋(specs/goldenset/*.json)을 재채점해 점수 추이를 남기고 baseline 대비 회귀를 판정한다
---
`carve-eval` 워크플로를 실행하라. `$ARGUMENTS`가 있으면 인자로 해석한다(`{ goldenset?: glob, threshold?: 70, delta?: 3, target?: "session"|"claude"|"exec:<cmd>" }`).

- **Phase 0 프리플라이트**: `carve-validate.sh`가 골든셋 구조를 먼저 검증한다(에이전트 0회). 실패하면 런을 시작하지 않는다 — 설정 오류가 "에이전트가 못했다"로 위장해 0점이 되는 것을 막는다.
- `specs/goldenset/*.json`의 고정 케이스(입력→루브릭)를 케이스별 k회 실행해 채점한다.
- 채점: 결정론 assert(contains·regex·부정형)는 워크플로가 순수 채점, `llm-rubric`은 evaluator가 판정. green = 전부 통과.
- `pass@k`(능력)·`pass^k`(일관성)를 분리 산출하고, `suiteScore`를 `specs/eval-score.json`에 append(추이).
- 직전 baseline 대비 `delta`(기본 3pt) 초과 하락 시 `[REGRESSION]`으로 보고한다.
- 케이스 `version`이 직전 run과 다르면 `[VERSION CHANGED]`로 알린다 — 같은 문제를 푼 점수가 아니므로 baseline 비교를 그대로 신뢰하면 안 된다.
- 채점·근거는 `eval-run.sh`가 만든다: `specs/eval-runs/run-<N>/<id>#<i>.json`에 응답 원문과 assert별 판정. 추이 append는 `eval-trend.sh`(변조 시 거부).
- 골든셋이 없으면 먼저 `eval-goldenset` 스킬로 케이스를 작성하라(실제 실패 20~50건으로 시작).
- 케이스를 새로 쓰거나 고쳤으면 `bash .claude/hooks/carve-validate.sh --red`로 "그 케이스가 실제로 무언가를 재는지"까지 확인하라.

$ARGUMENTS
