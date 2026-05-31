# Project Structure — Go

> Reference map so paths are never guessed (see CLAUDE.md "Source first").

## Layout (adjust per project)
```
.
├── cmd/
│   └── <app>/main.go    # entry point(s) — one dir per binary
├── internal/            # private packages (not importable externally)
│   ├── domain/          # entities, business rules (framework-/I-O-free)
│   ├── service/         # use cases / application logic
│   └── http/            # handlers, routing, transport
├── pkg/                 # only if genuinely reusable by external projects
├── .claude/rules/       # project guidelines (this folder)
├── go.mod
├── go.sum
└── CHANGELOG.md
```

## Conventions
- One package = one responsibility. Keep packages small and cohesive.
- `internal/domain/` has **no** framework or I/O imports — pure types and logic only.
- Test files live alongside source as `_test.go` (`service/x.go` → `service/x_test.go`).
- Use `internal/` to enforce package privacy; only promote to `pkg/` when truly reusable.

## Where things live
- Types/domain rules: `internal/domain/`.
- Config/env access: a single typed module parsed once at startup.
- Never scatter `os.Getenv` reads across the codebase.
