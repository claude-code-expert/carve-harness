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
java_changed=1; node_changed=1; py_changed=1; sh_changed=1
# GATE-04 defaults: git 없으면 full(java_other=1, gw off) — 회피는 변경 식별 가능할 때만.
gw_changed=0; java_other=1
# 게이트웨이 파일 판별 단일 소스 — audit(AUDIT-07)이 같은 개념을 참조.
GW_RE='([Gg]ateway|[Ff]ilter|[Aa]uth|[Rr]ate[Ll]imit)[^/]*\.java$|/gateway/.*\.java$'
if [ "$have_git" -eq 1 ]; then
  CHANGED=$(git status --porcelain 2>/dev/null | sed 's/^...//')
  printf '%s\n' "$CHANGED" | grep -Eq '\.(java|kt|gradle)'    && java_changed=1 || java_changed=0
  printf '%s\n' "$CHANGED" | grep -Eq '\.(ts|tsx)$|package\.json' && node_changed=1 || node_changed=0
  printf '%s\n' "$CHANGED" | grep -Eq '\.py$|pyproject\.toml'  && py_changed=1 || py_changed=0
  printf '%s\n' "$CHANGED" | grep -Eq '\.sh$|^\.githooks/'     && sh_changed=1 || sh_changed=0
  # GATE-04: 게이트웨이 관련 java 변경 여부 + 그 외 java 변경 여부(섞이면 full).
  printf '%s\n' "$CHANGED" | grep -Eq "$GW_RE" && gw_changed=1 || gw_changed=0
  printf '%s\n' "$CHANGED" | grep -E '\.(java|kt|gradle)$' | grep -Ev "$GW_RE" | grep -q . && java_other=1 || java_other=0
fi

# --- Java/Spring: 컴파일 + 테스트 (변경 시에만) ---
# 커버리지 80%는 build.gradle의 jacocoTestCoverageVerification으로 강제 → test 태스크가 실패한다.
# GATE-04: 게이트웨이 파일만 변경 → *GatewayIntegration* 타깃만(전체 빌드 회피).
#          다른 java가 섞이면 full test(게이트웨이 통합 테스트 포함)로 안전하게 간다.
if [ "$java_changed" -eq 1 ]; then
  GDIR=""
  [ -f gradlew ] && GDIR="."
  [ -z "$GDIR" ] && [ -f backend/gradlew ] && GDIR="backend"
  if [ -n "$GDIR" ]; then
    if [ "$java_other" -eq 0 ] && [ "$gw_changed" -eq 1 ]; then
      gw_out=$( cd "$GDIR" && ./gradlew compileJava test --tests '*GatewayIntegration*' -q 2>&1 ); gw_rc=$?
      printf '%s\n' "$gw_out" | tail -20
      if [ "$gw_rc" -ne 0 ]; then
        # gradle는 --tests 매칭 0개면 실패 → 컨벤션 미채택 프로젝트의 false-fail 방지(best-effort skip).
        printf '%s\n' "$gw_out" | grep -qiE 'no tests found|does not match' \
          && echo "[verify] *GatewayIntegration* 매칭 테스트 없음 — 스킵(best-effort)" >&2 \
          || fail=1
      fi
    else
      ( cd "$GDIR" && ./gradlew compileJava test -q ) 2>&1 | tail -20 || fail=1
    fi
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

# --- Python: 린트 + 테스트 (변경 시에만, 도구 있을 때만 — best-effort).
# pytest exit 5 = "no tests collected" — 테스트 없는 프로젝트의 false fail 방지.
if [ "$py_changed" -eq 1 ] && [ -f pyproject.toml ]; then
  if command -v ruff >/dev/null 2>&1; then
    ruff check . 2>&1 | tail -20 || fail=1
  fi
  if command -v pytest >/dev/null 2>&1; then
    py_out=$(pytest -q 2>&1); py_rc=$?
    printf '%s\n' "$py_out" | tail -20
    [ "$py_rc" -ne 0 ] && [ "$py_rc" -ne 5 ] && fail=1
  fi
fi

# --- Bash: 훅/스크립트 정적분석 + 훅 자가 테스트 (변경 시에만).
# 분석기는 .claude/bin(vendor 설치본, 오프라인) 우선 → PATH 순. 없으면 스킵(best-effort).
# -S error만 게이트 — 경고는 비차단.
if [ "$sh_changed" -eq 1 ]; then
  if [ "$have_git" -eq 1 ]; then
    sh_files=$(printf '%s\n' "$CHANGED" | grep -E '\.sh$|^\.githooks/' | while read -r f; do [ -f "$f" ] && echo "$f"; done)
    hooks_changed=0
    printf '%s\n' "$CHANGED" | grep -Eq '^\.claude/hooks/|^\.githooks/' && hooks_changed=1
  else
    # git 없음 → 전체 검사 (change-detection 불가 시 skip 금지 — GATE-03과 동일 원칙)
    sh_files=$(ls .claude/hooks/*.sh .githooks/* 2>/dev/null)
    hooks_changed=1
  fi
  SC="$(dirname "${BASH_SOURCE[0]}")/../bin/shellcheck"
  command -v "$SC" >/dev/null 2>&1 || SC=$(command -v shellcheck)
  if [ -n "$SC" ] && [ -n "$sh_files" ]; then
    # shellcheck disable=SC2086
    "$SC" -S error $sh_files 2>&1 | tail -20 || fail=1
  fi
  if [ "$hooks_changed" -eq 1 ]; then
    for t in "$(dirname "${BASH_SOURCE[0]}")"/tests/*.test.sh; do
      [ -e "$t" ] || continue
      bash "$t" >/dev/null 2>&1 || { echo "[verify] 훅 테스트 실패: $(basename "$t")" >&2; fail=1; }
    done
  fi
fi

# GATE-03: verification is now change-scoped — only stacks whose files changed run above.
[ "$fail" -eq 0 ] || { echo "[verify] 검증 실패(빌드/타입/테스트) — 완료 전 수정 필요" >&2; bash "$LOG_EVENT" Stop verify fail ""; exit 2; }
bash "$LOG_EVENT" Stop verify pass ""
exit 0
