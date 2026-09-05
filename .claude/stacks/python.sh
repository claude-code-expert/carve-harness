#!/usr/bin/env bash
# python.sh — stack definition (contract: see java-spring.sh header).
STACK_ID=python
# GATE-06: 프로젝트 판별은 pyproject.toml 하나가 아니다 — requirements.txt/setup.py만
# 쓰는 프로젝트가 통째로 스킵되던 갭(적대적 감사 G7)을 막는다.
STACK_CHANGE_RE='\.py$|pyproject\.toml|requirements[^/]*\.txt|setup\.(py|cfg)'
STACK_FORMAT_RE='\.py$'
STACK_FORMAT_TOOL=ruff

stack_format() {
  command -v ruff >/dev/null 2>&1 || return 2
  ruff format "$1"
}

# 린트 + 테스트 (도구 있을 때만 — best-effort). pytest exit 5 = "no tests collected".
stack_gate() {
  { [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f setup.py ] || [ -f setup.cfg ]; } || return 0
  local py_out py_rc
  if command -v ruff >/dev/null 2>&1; then
    ruff check . 2>&1 | tail -20 || return 1
  fi
  if command -v pytest >/dev/null 2>&1; then
    py_out=$(pytest -q 2>&1); py_rc=$?
    printf '%s\n' "$py_out" | tail -20
    [ "$py_rc" -ne 0 ] && [ "$py_rc" -ne 5 ] && return 1
  fi
  return 0
}

# ── eval-score.sh 어댑터 (LP4): rc 0 ok · 1 fail · 2 도구 없음/해당 없음. stack_coverage 는 0..1 또는 skip 출력.
STACK_COVERAGE_MIN=80
STACK_TEST_CMD_HINT='pytest -q'
stack_detect()   { [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f setup.py ] || [ -f setup.cfg ]; }
stack_build()    { python3 -m compileall -q . >/dev/null 2>&1; }   # 컴파일 단계 = 문법 검사
stack_test()     { command -v pytest >/dev/null 2>&1 || return 2; pytest -q >/dev/null 2>&1; local rc=$?; [ "$rc" -eq 5 ] && rc=0; return $rc; }
stack_lint()     { command -v ruff >/dev/null 2>&1 || return 2; ruff check . >/dev/null 2>&1; }
stack_coverage() {
  command -v pytest >/dev/null 2>&1 && python3 -c 'import pytest_cov' >/dev/null 2>&1 || { echo skip; return; }
  local t; t=$(mktemp -d)
  pytest -q --cov=. --cov-report="json:$t/cov.json" >/dev/null 2>&1
  [ -f "$t/cov.json" ] && jq -r '(.totals.percent_covered // empty) / 100' "$t/cov.json" 2>/dev/null || echo skip
  rm -rf "$t"
}
