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

# ── eval-score.sh 어댑터 (LP4): rc 0 ok · 1 fail · 2 도구 없음/해당 없음. stack_coverage 는 0..1 또는 skip 출력.
STACK_COVERAGE_MIN=80
STACK_TEST_CMD_HINT='go test ./...'
stack_detect()   { [ -f go.mod ]; }
stack_build()    { command -v go >/dev/null 2>&1 || return 2; go build ./... >/dev/null 2>&1; }
stack_test()     { command -v go >/dev/null 2>&1 || return 2; local out; out=$(go test ./... 2>&1); local rc=$?
                   [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'no test files' && rc=0; return $rc; }
stack_lint()     { command -v go >/dev/null 2>&1 || return 2; go vet ./... >/dev/null 2>&1; }
stack_coverage() {
  command -v go >/dev/null 2>&1 || { echo skip; return; }
  local t pct; t=$(mktemp -d)
  go test -coverprofile="$t/c.out" ./... >/dev/null 2>&1 && pct=$(go tool cover -func="$t/c.out" 2>/dev/null | awk '/^total:/{gsub("%","",$NF); print $NF}')
  rm -rf "$t"
  [ -n "$pct" ] && awk -v p="$pct" 'BEGIN{printf "%.4f", p/100}' || echo skip
}
