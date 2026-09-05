# `.claude/rules/` — 자동 로드 규칙

`paths` glob이 맞는 파일을 열면 세션에 자동 로드되는 규칙. 짧게 유지(길수록 덜 지켜진다) — 상세본은 `docs/rules/code-convention/`.

| 경로 | glob | 내용 |
|---|---|---|
| `common/` | 항상 | security(시크릿·PII) · testing(red→green·커버리지 80) · git-workflow |
| `safety.md` | 항상 | 위험 동작(DB 파괴·git·프로덕션) 승인 게이트 |
| `database.md` | 항상 | id/타임스탬프·soft delete·N+1·마이그레이션 |
| `java-spring/` | `**/*.java` | 계층·주입·트랜잭션 + `gateway-testing.md`(GATE-04) + `archunit/`(규칙-as-테스트 템플릿) |
| `react-next/` | `**/*.ts,tsx` | Hooks·key·서버상태 분리 |
| `python/` `go/` `rust/` | `**/*.py` `.go` `.rs` | 스택별 슬림 규칙(언어팩과 함께 설치) |

> 스택 규칙은 언어팩 단위로 설치·제거된다. 빈 파일·중복은 감사 AUDIT-05가 잡는다.
