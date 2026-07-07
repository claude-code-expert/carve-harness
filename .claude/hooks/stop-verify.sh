#!/usr/bin/env bash
# Stop: 스택 감지 후 빌드/타입/테스트 게이트 (실패 시 exit 2)
# pipefail 필수: `cmd | tail`의 종료코드는 tail(항상 0) 것이므로,
# 이게 없으면 실제 명령이 실패해도 fail이 set되지 않아 게이트가 무력화된다.
set -o pipefail

LOG_EVENT="$(dirname "${BASH_SOURCE[0]}")/log-event.sh"

# GATE-01: read stdin once, then short-circuit a forced-continuation loop.
# On the second Stop pass (stop_hook_active=true) surface once and yield (exit 0).
input=$(cat)
if command -v jq >/dev/null 2>&1 && [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ]; then
  echo "[verify] 이미 재검증 continuation 상태 — 루프 방지 위해 종료 허용" >&2
  bash "$LOG_EVENT" Stop verify loop-yield ""
  exit 0
fi
# D-02: jq-absent is best-effort (non-blocking) here — asymmetric with the write guard,
# which fails closed. Hard-failing verification on a jq-less box would block completion.
if ! command -v jq >/dev/null 2>&1; then
  echo "[verify] jq 미설치 → 검증 스킵(best-effort)" >&2
  exit 0
fi

fail=0

# GATE-03: scope verification to changed stacks (best-effort). Not a git repo →
# verify all (never skip when change-detection is impossible).
have_git=0
command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1 && have_git=1
java_changed=1; node_changed=1
if [ "$have_git" -eq 1 ]; then
  CHANGED=$(git status --porcelain 2>/dev/null | sed 's/^...//')
  printf '%s\n' "$CHANGED" | grep -Eq '\.(java|kt|gradle)'    && java_changed=1 || java_changed=0
  printf '%s\n' "$CHANGED" | grep -Eq '\.(ts|tsx)$|package\.json' && node_changed=1 || node_changed=0
fi

# --- Java/Spring: 컴파일 + 테스트 (변경 시에만) ---
# 커버리지 80%는 build.gradle의 jacocoTestCoverageVerification으로 강제 → test 태스크가 실패한다.
if [ "$java_changed" -eq 1 ]; then
  if [ -f gradlew ]; then
    ./gradlew compileJava test -q 2>&1 | tail -20 || fail=1
  elif [ -f backend/gradlew ]; then
    ( cd backend && ./gradlew compileJava test -q ) 2>&1 | tail -20 || fail=1
  fi
fi

# --- React/Next/TS: 타입체크 + 테스트 ---
# 커버리지 80%는 vitest/jest --coverage 임계값(package.json)으로 강제.
run_node() {  # $1 = 프로젝트 디렉토리
  ( cd "$1" && pnpm exec tsc --noEmit 2>&1 | tail -20 ) || return 1
  # test 스크립트가 있을 때만 실행 (없는데 pnpm test → 오류로 false fail 방지)
  if jq -e '.scripts.test' "$1/package.json" >/dev/null 2>&1; then
    ( cd "$1" && pnpm test 2>&1 | tail -20 ) || return 1
  fi
}
if [ "$node_changed" -eq 1 ]; then
  if   [ -f package.json ];          then run_node . || fail=1
  elif [ -f frontend/package.json ]; then run_node frontend || fail=1; fi
fi

# GATE-03: verification is now change-scoped — only stacks whose files changed run above.
[ "$fail" -eq 0 ] || { echo "[verify] 검증 실패(빌드/타입/테스트) — 완료 전 수정 필요" >&2; bash "$LOG_EVENT" Stop verify fail ""; exit 2; }
bash "$LOG_EVENT" Stop verify pass ""
exit 0
