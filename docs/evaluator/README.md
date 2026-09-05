# `docs/evaluator/<lang>-example/` — LLM-judge 예시

"코드로 먼저, 필요하면 AI로" 채점을 언어별로 보여주는 실행 가능한 예시. 앱(응답 생성) · llm(호출 한 개) · judge(루브릭 채점) · 테스트(결정론 검사 → 판사 → assert) 4파일 골격.

| 예시 | 실행 |
|---|---|
| `python-example/` | `pytest -q` (JUDGE_LIVE=1 이면 실제 LLM) |
| `typescript-example/` | `node --test answers.test.ts` (Node ≥22.18) |
| `go-example/` | `go test ./...` (표준 라이브러리만) |
| `rust-example/` | `cargo test` (외부 크레이트 없음) |
| `java-example/` | JUnit + LlmJudge |

> 원칙: 규칙으로 잡히는 건 판사 없이 먼저 자르고(싸고 재현됨), 뉘앙스만 LLM에. 안전 항목 실패는 무조건 최저점.
