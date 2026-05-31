# Commands — Go

> Canonical commands. Use these names; don't invent ad-hoc variants.

## Daily
| Task | Command |
|------|---------|
| Build all | `go build ./...` |
| Run | `go run ./cmd/<app>` |
| Tidy deps | `go mod tidy` |

## Quality (run before commit)
| Task | Command |
|------|---------|
| Vet | `go vet ./...` |
| Lint | `{{LINT_CMD}}`  (`golangci-lint run`) |
| Format | `{{FORMAT_CMD}}`  (`gofmt -w .`) |
| Unit tests | `{{TEST_CMD}}`  (`go test ./...`) |
| Race tests | `go test -race ./...` |

## Notes
- "Always run tests before committing" → `go test ./...` (add `-race` for concurrent code).
- `go vet` and the linter must be clean before commit.
- Long-running tests may be skipped locally but must pass in CI.
