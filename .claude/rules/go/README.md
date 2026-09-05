# `.claude/rules/go/` — Go 규칙 (go 팩)

`**/*.go`를 열면 자동 로드. `go` 언어팩과 함께 설치.

| 파일 | glob | 내용 |
|---|---|---|
| `patterns.md` | `**/*.go` | gofmt/vet · 오류 반환 `%w` · ctx 첫 인자 · 고루틴 종료 조건 · 시크릿은 env |

## 사용방법
- 자동 로드. 게이트: `.claude/stacks/go.sh`(build·vet·test·gofmt). 상세본: `docs/rules/code-convention/dev-stack-go.md`.
