# Code Style

> TypeScript baseline. Match existing code first; these are defaults, not overrides.

## TypeScript
- `strict: true` always on. **Never use `any`** — use a precise type or `unknown` + narrowing.
- Prefer `type`/`interface` over inline shapes; export shared types from `src/domain/`.
- No non-null assertion (`!`) to silence the compiler — handle the null case.
- Validate all external input (HTTP body, env, third-party responses) with Zod at the boundary.

## Errors & Logging
- Never silently swallow errors (`.catch(() => {})`) — at minimum log with context.
- Never use `console.log` in app code — use the project logger.
- Throw typed errors; don't throw raw strings.

## Naming & Structure
- Functions/variables: `camelCase`; types/classes: `PascalCase`; constants: `UPPER_SNAKE`.
- Names express intent (`shouldRetry`, not `flag2`). Keep functions single-purpose.
- Eliminate duplication; make dependencies explicit; minimize shared mutable state.

## Async
- `async/await` over raw `.then()` chains. Always handle rejection.
- Never block on long external calls in a request path — offload / stream as needed.

## Secrets
- Never hardcode secrets, API keys, or tokens. Read from validated env only.
- Never commit `.env*` or files containing real credentials.
