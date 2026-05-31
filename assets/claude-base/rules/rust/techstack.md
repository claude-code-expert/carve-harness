# Tech Stack — Rust

> Detected stack. Trim/extend to match reality.

## Core
- **Language**: Rust (stable, 2021/2024 edition)
- **Toolchain**: rustup-managed; pin via `rust-toolchain.toml`
- **Build/package**: Cargo + `Cargo.toml` (commit `Cargo.lock` for binaries)
- **Edition**: set explicitly in `Cargo.toml` (`edition = "2021"` or `"2024"`)

## Quality Tooling
- **Lint**: Clippy — `cargo clippy --all-targets -- -D warnings`
- **Format**: rustfmt — `cargo fmt`
- **Test**: `cargo test` (unit + integration) + cargo-nextest (faster runner)
- **Validation**: serde for (de)serialization at boundaries; validate untrusted input on parse

## Async (if applicable)
- Runtime: tokio — pick one runtime and keep it consistent
- Avoid mixing async runtimes in a single binary

## Error Handling
- Libraries: thiserror for typed, structured error enums
- Binaries: anyhow for ergonomic propagation + context

## Rules
- No crate outside this stack without a stated rationale and user approval.
- Pin major versions; document any upgrade in the changelog.
