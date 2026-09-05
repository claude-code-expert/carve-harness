#!/usr/bin/env bash
# go.sh — stack definition (contract: see java-spring.sh header).
STACK_ID=go
STACK_CHANGE_RE='\.go$|go\.(mod|sum)'
STACK_FORMAT_RE='\.go$'
STACK_FORMAT_TOOL=gofmt

stack_format() {
  command -v gofmt >/dev/null 2>&1 || return 2
  gofmt -w "$1"
}

# GATE-07: `go build`가 컴파일 게이트, `go vet`이 정적 게이트, `go test ./...`가 테스트 게이트.
# "no test files"만 있는 리포는 실패 아님 — 테스트 없는 프로젝트의 false fail 방지.
stack_gate() {
  [ -f go.mod ] && command -v go >/dev/null 2>&1 || return 0
  local go_out go_rc
  go build ./... 2>&1 | tail -20 || return 1
  go vet ./... 2>&1 | tail -20 || return 1
  go_out=$(go test ./... 2>&1); go_rc=$?
  printf '%s\n' "$go_out" | tail -20
  [ "$go_rc" -ne 0 ] && ! printf '%s\n' "$go_out" | grep -qi 'no test files' && return 1
  return 0
}
