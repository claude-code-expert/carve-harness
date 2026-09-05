#!/usr/bin/env bash
# typescript.sh — stack definition (contract: see java-spring.sh header).
STACK_ID=typescript
STACK_CHANGE_RE='\.(ts|tsx)$|package\.json'
STACK_FORMAT_RE='\.(ts|tsx|js|jsx)$'
STACK_FORMAT_TOOL=prettier

stack_format() {
  command -v pnpm >/dev/null 2>&1 || return 2
  pnpm exec prettier --write "$1"
}

# 타입체크 + 린트 + 테스트. 커버리지 80%는 vitest/jest --coverage 임계값(package.json)으로 강제.
ts_verify_dir() {  # $1 = 프로젝트 디렉토리
  local PM=pnpm; command -v pnpm >/dev/null 2>&1 || PM=npm   # 단일 PM 감지(tsc·lint·test 공유)
  # package.json 존재 ≠ TS 프로젝트 — tsconfig 있을 때만 타입체크 (셸 전용 리포 false fail 방지)
  if [ -f "$1/tsconfig.json" ]; then
    ( cd "$1" && "$PM" exec tsc --noEmit 2>&1 | tail -20 ) || return 1
  fi
  # lint 스크립트가 있을 때만 — CI의 `npm run lint`를 로컬 Stop으로 앞당긴다(shift-left).
  if jq -e '.scripts.lint' "$1/package.json" >/dev/null 2>&1; then
    ( cd "$1" && "$PM" run lint 2>&1 | tail -20 ) || return 1
  fi
  # test 스크립트가 있을 때만 (없는데 test → 오류로 false fail 방지)
  if jq -e '.scripts.test' "$1/package.json" >/dev/null 2>&1; then
    ( cd "$1" && "$PM" test 2>&1 | tail -20 ) || return 1
  fi
  return 0
}

stack_gate() {
  if   [ -f package.json ];          then ts_verify_dir . || return 1
  elif [ -f frontend/package.json ]; then ts_verify_dir frontend || return 1; fi
  return 0
}

# ── eval-score.sh 어댑터 (LP4): rc 0 ok · 1 fail · 2 도구 없음/해당 없음. stack_coverage 는 0..1 또는 skip 출력.
STACK_COVERAGE_MIN=80
STACK_TEST_CMD_HINT='npm test'
ts_pm() { command -v pnpm >/dev/null 2>&1 && echo pnpm || echo npm; }
stack_detect()   { [ -f package.json ]; }
stack_build()    { [ -f tsconfig.json ] || return 2; "$(ts_pm)" exec tsc --noEmit >/dev/null 2>&1; }
stack_test()     { jq -e '.scripts.test' package.json >/dev/null 2>&1 || return 2; "$(ts_pm)" test >/dev/null 2>&1; }
stack_lint()     { jq -e '.scripts.lint' package.json >/dev/null 2>&1 || return 2; "$(ts_pm)" run lint >/dev/null 2>&1; }
# 커버리지는 직접 돌리지 않는다(설정 의존·느림) — 프로젝트가 남긴 summary 리포트가 있을 때만 읽는다.
stack_coverage() { [ -f coverage/coverage-summary.json ] && jq -r '(.total.lines.pct // empty) / 100' coverage/coverage-summary.json 2>/dev/null || echo skip; }
