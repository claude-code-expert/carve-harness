---
description: 스펙→개발→체크리스트→채점 루프를 돌려 모든 구현 항목이 95점 이상이 될 때까지 검증한다
---
`carve-verify-loop` 워크플로를 실행하라. `$ARGUMENTS`를 목표(goal)로 전달한다.

- 항목(tasks)을 직접 주지 않으면 P1에서 리서치 기반으로 3~7개 체크리스트 항목(claim·acceptance·owns 비중복)으로 자동 분해한다.
- 각 항목을 evaluator가 코드 대조로 0~100 채점하고, 95 미만 항목만 gap을 되먹여 재작업→재채점(항목당 최대 3회).
- 진행 상태는 `specs/checklist.json`에 기록되며, 미달 항목이 남으면 `checklist-gate` 훅이 완료(Stop)를 차단한다.
- 워크플로 없이(타 에이전트·일반 세션) 같은 루프를 손으로 돌릴 때는 `checklist-loop` 스킬의 SOP를 따른다.

$ARGUMENTS
