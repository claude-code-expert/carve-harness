# `.claude/rules/rust/` — Rust 규칙 (rust 팩)

`**/*.rs`를 열면 자동 로드. `rust` 언어팩과 함께 설치.

| 파일 | glob | 내용 |
|---|---|---|
| `patterns.md` | `**/*.rs` | rustfmt/clippy · 라이브러리 `unwrap`/`panic!` 금지 → `Result`+`?` · `unsafe` 금지 · 시크릿은 env |

## 사용방법
- 자동 로드. 게이트: `.claude/stacks/rust.sh`(cargo check·test·rustfmt). 상세본: `docs/rules/code-convention/dev-stack-rust.md`.
