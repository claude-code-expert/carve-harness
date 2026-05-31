# Code Style — Rust

> Match existing code first; these are defaults, not overrides.

## Errors & Results
- **Never `unwrap()`/`expect()`/`panic!`** outside tests or truly unrecoverable init — return `Result`.
- Propagate errors with `?`; don't manually match-and-rethrow.
- Handle every `Result`/`Option` explicitly — no `let _ =` to silence a real error.
- Libraries: typed errors via thiserror. Binaries: anyhow with `.context(...)`.

## Types & Safety
- Make illegal states unrepresentable — model variants with `enum`, not boolean flags.
- Prefer borrowing (`&T`, `&str`) over cloning; clone only when ownership is genuinely needed.
- **No `unsafe`** without a documented invariant comment (`// SAFETY: ...`) and review.
- Derive traits (`Debug`, `Clone`, `PartialEq`, ...) rather than hand-rolling them.
- Validate all external input (HTTP body, env, third-party responses) at the boundary with serde.

## Naming & Structure
- Functions/variables/modules: `snake_case`; types/traits/enums: `UpperCamelCase`; constants: `SCREAMING_SNAKE`.
- Names express intent (`should_retry`, not `flag2`). Keep functions single-purpose.
- Eliminate duplication; make dependencies explicit; minimize shared mutable state.

## Secrets
- Never hardcode secrets, API keys, or tokens. Read from env only.
- Never commit `.env*` or files containing real credentials.
