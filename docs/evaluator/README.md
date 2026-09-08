# `docs/evaluator/` — 채점 참조 구현

두 종류가 있다. 대체 관계가 아니라 층이 다르다.

## 1. `<lang>-example/` — LLM-judge 한 층

"코드로 먼저, 필요하면 AI로" 채점을 언어별로 보여주는 실행 가능한 예시. 앱(응답 생성) · llm(호출 한 개) · judge(루브릭 채점) · 테스트(결정론 검사 → 판사 → assert) 4파일 골격.

| 예시 | 실행 |
|---|---|
| `python-example/` | `pytest -q` (JUDGE_LIVE=1 이면 실제 LLM) |
| `typescript-example/` | `node --test answers.test.ts` (Node ≥22.18) |
| `go-example/` | `go test ./...` (표준 라이브러리만) |
| `rust-example/` | `cargo test` (외부 크레이트 없음) |
| `java-example/` | JUnit + LlmJudge |

> 원칙: 규칙으로 잡히는 건 판사 없이 먼저 자르고(싸고 재현됨), 뉘앙스만 LLM에. 안전 항목 실패는 무조건 최저점.

## 2. `deck-example/` — 채점표 전체 (결정론 채점 + 5축 루브릭 + 게이트 판정)

위 예시가 *판사 한 개*라면, 이쪽은 그 판사를 감싸는 **채점표 전체**다. 발표자료의 채점 모델을
의존성 없이 돌아가는 Java·Python 코드로 옮겼고, 테스트가 슬라이드의 숫자를 재현한다.

```bash
cd docs/evaluator/deck-example/java   && java ScoreCardTest.java    # JDK 11+
cd docs/evaluator/deck-example/python && python3 test_scorecard.py  # stdlib only
```

**이 코드를 하네스에 배선할 필요는 없다** — 같은 모델이 이미 `eval-score.sh`·`checklist-gate.sh`·
`carve-verify-loop.js`에 bash/jq/JS로 구현돼 있다. 대응표는 `deck-example/README.md` 참고.
읽고 이해하는 용도이거나, 하네스 없는 다른 에이전트·언어에 같은 모델을 옮길 때 쓴다.
