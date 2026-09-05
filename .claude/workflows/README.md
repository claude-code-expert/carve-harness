# `.claude/workflows/` — 오케스트레이션 워크플로

Claude Code Workflow 도구가 실행하는 다단계 스크립트. 여러 서브에이전트를 결정적으로 조율한다. 옵트인(이름 명시 또는 `ultracode`).

| 파일 | 무엇 |
|---|---|
| `fable-team-pipeline.js` | Spec→Build+Verify→Document→Verify 4단계 멀티 에이전트 팀(생성/검증 분리) |
| `carve-verify-loop.js` | 스펙→체크리스트→5축 채점→재작업 루프, 전 항목 95(안전 100)까지 |
| `carve-eval.js` | 골든셋 k회 재채점 → pass@k/pass^k → 추이 append(`eval-trend.sh`) → 회귀 판정 |

> 채점·상태 파일 조작은 전부 `.claude/hooks/`의 결정적 스크립트에 위임한다 — 워크플로는 오케스트레이션만.
