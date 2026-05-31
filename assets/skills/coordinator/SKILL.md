---
name: coordinator
description: >
  멀티에이전트 직접 통신(메일박스) 패턴 가이드. 에이전트 간 핸드오프·팀 조율이 필요한 대형 작업에,
  "코디네이터", "에이전트 통신", "팀 조율" 요청에 사용. 복잡도가 높아 꼭 필요할 때만.
---
# coordinator — 에이전트 조율(메일박스)

> 복잡도가 높다. `parallel-agents`(wave/worktree)로 충분하면 그걸 먼저 쓴다.

- 에이전트 간 직접 통신이 필요할 때만 TeamCreate/메일박스 패턴을 쓴다.
- 오케스트레이터는 **목적(objective)**을 알고 서브에이전트는 query만 안다 → query에 objective context를 함께 전달한다.
- 응답을 매번 평가하고, 부족하면 follow-up(최대 3 사이클). 무한 통신 금지.
- 기본은 1입력 1출력·파일 기반 핸드오프, 직접 통신은 예외로 둔다.
