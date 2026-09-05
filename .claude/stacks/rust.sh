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
