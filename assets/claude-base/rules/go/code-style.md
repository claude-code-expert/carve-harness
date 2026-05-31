# Code Style — Go

> Match existing code first; these are defaults, not overrides.

## Errors
- Always check `err`. Never discard with `_` unless justified with a comment.
- Wrap with context: `fmt.Errorf("doing X: %w", err)` — preserve the chain for `errors.Is`/`As`.
- No `panic` in library code — only for truly unrecoverable startup conditions.
- Return early on error; avoid deep nesting.

## Naming & Structure
- MixedCaps: exported `PascalCase`, unexported `camelCase`. No `snake_case`, no `ALL_CAPS`.
- Avoid stutter: `http.Server`, not `http.HTTPServer`. Package name carries context.
- Accept interfaces, return concrete structs. Keep interfaces small.
- Names express intent (`shouldRetry`, not `flag2`). Keep functions single-purpose.

## Concurrency
- Pass `context.Context` as the first parameter for any cancellable / I-O work.
- Guard shared state with a mutex or channels — never rely on luck.
- Run `go test -race` on concurrent code; treat any race report as a bug.
- Don't leak goroutines — ensure each has a clear exit path.

## Secrets
- Never hardcode secrets, API keys, or tokens. Read from environment only.
- Never commit `.env*` or files containing real credentials.
