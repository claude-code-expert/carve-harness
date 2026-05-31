# Commands — Rust

> Canonical commands. Use these names; don't invent ad-hoc variants. Keep in sync with `Cargo.toml`.

## Daily
| Task | Command |
|------|---------|
| Build | `cargo build` |
| Build (optimized) | `cargo build --release` |
| Run | `cargo run` |
| Type/borrow check (fast) | `cargo check` |

## Quality (run before commit)
| Task | Command |
|------|---------|
| Lint | `{{LINT_CMD}}`  (`cargo clippy --all-targets -- -D warnings`) |
| Format | `{{FORMAT_CMD}}`  (`cargo fmt`) |
| Tests | `{{TEST_CMD}}`  (`cargo test`) |
| All checks | `cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test` |

## Notes
- "Always run tests before committing" → run the full check.
- `cargo check` is the fast inner loop; `cargo build` only when you need an artifact.
- Long-running tests may be skipped locally but must pass in CI.
