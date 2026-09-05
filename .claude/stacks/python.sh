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
