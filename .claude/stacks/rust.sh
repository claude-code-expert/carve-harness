#!/usr/bin/env bash
# rust.sh — stack definition (contract: see java-spring.sh header).
STACK_ID=rust
STACK_CHANGE_RE='\.rs$|Cargo\.(toml|lock)'
STACK_FORMAT_RE='\.rs$'
STACK_FORMAT_TOOL=rustfmt

stack_format() {
  command -v rustfmt >/dev/null 2>&1 || return 2
  rustfmt "$1"
}

# cargo check(=컴파일) + test. check는 코드 생성 없이 타입·차용 검사만 — 게이트 목적엔 build보다 빠르고 충분.
stack_gate() {
  [ -f Cargo.toml ] && command -v cargo >/dev/null 2>&1 || return 0
  cargo check --quiet 2>&1 | tail -20 || return 1
  cargo test --quiet 2>&1 | tail -20 || return 1
  return 0
}

# ── eval-score.sh 어댑터 (LP4): rc 0 ok · 1 fail · 2 도구 없음/해당 없음. stack_coverage 는 0..1 또는 skip 출력.
STACK_COVERAGE_MIN=80
STACK_TEST_CMD_HINT='cargo test -q'
stack_detect()   { [ -f Cargo.toml ]; }
stack_build()    { command -v cargo >/dev/null 2>&1 || return 2; cargo check -q >/dev/null 2>&1; }
stack_test()     { command -v cargo >/dev/null 2>&1 || return 2; cargo test -q >/dev/null 2>&1; }
stack_lint()     { cargo clippy --version >/dev/null 2>&1 || return 2; cargo clippy -q -- -D warnings >/dev/null 2>&1; }
stack_coverage() {
  cargo llvm-cov --version >/dev/null 2>&1 || { echo skip; return; }
  cargo llvm-cov --summary-only --json 2>/dev/null | jq -r '(.data[0].totals.lines.percent // empty) / 100' 2>/dev/null || echo skip
}
