# Project Structure — Rust

> Reference map so paths are never guessed (see CLAUDE.md "Source first").

## Layout (adjust per project)
```
.
├── src/                 # crate source
│   ├── main.rs          # binary entry point (or lib.rs for a library)
│   ├── lib.rs           # library root, re-exports public API
│   ├── domain/          # entities, types, business rules (I/O-free)
│   ├── services/        # use cases / application logic
│   └── error.rs         # crate error type (thiserror)
├── tests/               # integration tests (one file = one test crate)
├── benches/             # benchmarks
├── .claude/rules/       # project guidelines (this folder)
├── Cargo.toml
├── Cargo.lock
└── CHANGELOG.md
```

## Conventions
- One module = one responsibility. Keep modules focused and small.
- `domain/` has **no** I/O or framework imports — pure types and logic only.
- Module tree declared with `mod`; expose the public surface from `lib.rs`.
- Integration tests live in `tests/`; unit tests in a `#[cfg(test)] mod tests` block.

## Where things live
- Types/domain models: `src/domain/`.
- Config/env access: a single module (e.g. `src/config.rs`), parsed once at startup.
- Multi-crate projects: a `[workspace]` in the root `Cargo.toml`; never scatter env reads.
