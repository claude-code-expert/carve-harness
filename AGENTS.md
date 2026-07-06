# AGENTS.md — 에이전트 표준

## 공통 규약
- 아키텍처 변경·반복 실패·스펙 충돌·비가역 작업은 자율 판단 금지 → `[ESCALATION]` 보고
- 생성(Generator)과 검증(Evaluator)은 분리 (Self-Eval Blindspot 방지)
- 출력은 완료 기준(SC) 대비 자기 점검 후 제출

## 역할
- Planner: 작업 분해·SC 정의 / Generator: 구현 / Evaluator: 타입·보안·예외·상태 검증

## 에스컬레이션 포맷
```
[ESCALATION]
- 상황: / 막힌 지점: / 시도한 것: / 필요한 결정:
```
