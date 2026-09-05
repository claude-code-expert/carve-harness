# `.claude/agents/` — 서브에이전트

별도 컨텍스트에서 도는 보조 AI. **생성/검증 분리**(Self-Eval Blindspot 방지)가 핵심 — 채점자는 코드를 고치지 않는다. 파일당 프런트매터(name·description·tools·model)가 로더 등록 조건이다.

## 목록
| 파일 | 역할 |
|---|---|
| `evaluator.md` | 완료 기준(SC)·타입 안전성 독립 검증(read-only), 5축 루브릭 |
| `security-reviewer.md` | 시크릿·인증/인가·인젝션 + 게이트웨이 우회 |
| `pr-test-analyzer.md` | 변경분 테스트 충분성(커버리지·SC 매핑·스텁 괴리) |
| `fable-researcher/builder/doc-writer/visualizer.md` | Fable 팀 슬롯. `fable-team-pipeline` 워크플로 전용 |

## 사용방법
- 발화로 위임: `"use the evaluator agent"` 또는 `"fable-builder로 src/api 구현"`.
- 팀 파이프라인: `fable-team-pipeline` 워크플로가 슬롯에 자동 배정.
- 새 에이전트 = `<이름>.md` + 프런트매터. **프런트매터 없는 파일(이 README 포함)은 로더가 에이전트로 등록하지 않는다.**

> 단일 관점 리뷰어 5종은 v0.6.0에서 제거(강한 모델 기준 `/review` 1회가 다관점 커버). 상세: `GUIDE.md` §5.2.
