# Tech Stack — Go

> Detected stack. Trim/extend to match reality.

## Core
- **Language**: Go 1.22+ (modern toolchain, generics available)
- **Modules**: Go modules (`go.mod` + `go.sum`, both committed)
- **Toolchain**: standard `go` toolchain (build, test, vet, mod) — built in
- **Layout**: standard project layout (`cmd/`, `internal/`, `pkg/`)

## Quality Tooling
- **Lint**: golangci-lint (aggregates govet, staticcheck, errcheck, etc.)
- **Format**: gofmt + goimports (run on save / in CI; no unformatted code lands)
- **Test**: `go test` with table-driven tests; coverage via `go test -cover`
- **Race**: `go test -race` for any concurrent code

## Backend (if applicable)
- HTTP: net/http (standard library) or a thin router (chi / echo) — pick one, stay consistent
- DB access: `database/sql` + sqlc, or pgx — **no string-concatenated SQL** in app code
- Config: read from environment, parsed once into a typed struct at startup
- Auth: JWT (stateless) or session — document the choice

## Rules
- No library outside this stack without a stated rationale and user approval.
- Pin versions in `go.mod`; document any upgrade in the changelog.
- Prefer the standard library; add a dependency only when it earns its weight.
