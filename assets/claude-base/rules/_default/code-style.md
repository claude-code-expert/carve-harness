# Code Style

> Match existing code first; these are defaults, not overrides.

## Design
- Express intent in names (`shouldRetry`, not `flag2`). Keep functions single-purpose.
- Eliminate duplication; make dependencies explicit; minimize shared mutable state.
- Validate all external input (requests, env, third-party responses) at the boundary.

## Errors & Logging
- Never silently swallow errors — at minimum log with context.
- No debug prints in application code — use the project logger.
- Raise typed/structured errors, not raw strings.

## Naming & Structure
- Follow one consistent naming convention per identifier kind and document it here.
  <!-- fill in: e.g. functions/vars, types/classes, constants -->
- Keep modules cohesive; one module = one responsibility.

## Secrets
- Never hardcode secrets, API keys, or tokens. Read from validated config/env only.
- Never commit `.env*` or files containing real credentials.
