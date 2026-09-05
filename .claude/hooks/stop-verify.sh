#!/usr/bin/env bash
# Stop: 스택 감지 후 빌드/타입/테스트 게이트 (실패 시 exit 2)
# 스택별 판정은 .claude/stacks/<pack>.sh 가 정의한다(언어팩 단위로 설치·제거). 이 파일은
# 공통 골격만: 루프가드 → jq → 변경 감지 → 스택 순회 → 판정 로그.
# pipefail 필수: `cmd | tail`의 종료코드는 tail(항상 0) 것이므로,
# 이게 없으면 실제 명령이 실패해도 fail이 set되지 않아 게이트가 무력화된다.
set -o pipefail

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACKS_DIR="$HOOKS_DIR/../stacks"
LOG_EVENT="$HOOKS_DIR/log-event.sh"

# GATE-01: forced-continuation guard, single-sourced with checklist-gate so the
# wedge-prevention invariant cannot drift (lib-stop-guard.sh). Reads stdin once.
source "$HOOKS_DIR/lib-stop-guard.sh"
stop_loop_yield verify "$LOG_EVENT"
# D-02: jq-absent is best-effort (non-blocking) here — asymmetric with the write guard,
# which fails closed. Hard-failing verification on a jq-less box would block completion.
if ! command -v jq >/dev/null 2>&1; then
  echo "[carve-harness:verify] jq 미설치 → 검증 스킵(best-effort)" >&2
  exit 0
fi

fail=0

# GATE-03: scope verification to changed stacks (best-effort). Not a git repo →
# verify all (never skip when change-detection is impossible).
have_git=0
command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1 && have_git=1
CHANGED=""
[ "$have_git" -eq 1 ] && CHANGED=$(git status --porcelain 2>/dev/null | sed 's/^...//')
export have_git CHANGED HOOKS_DIR

# 스택 순회 — 파일 하나 = 스택 하나. 변경 정규식이 맞을 때만(또는 git 없으면 항상) 게이트 실행.
# 각 스택은 stack_gate 를 재정의하므로 소싱 직후 바로 실행하고 다음으로 넘어간다.
for stack in "$STACKS_DIR"/*.sh; do
  [ -f "$stack" ] || continue
  unset -f stack_gate stack_format
  STACK_CHANGE_RE=''
  # shellcheck source=/dev/null
  source "$stack"
  changed=1
  if [ "$have_git" -eq 1 ]; then
    printf '%s\n' "$CHANGED" | grep -Eq "${STACK_CHANGE_RE:-^$}" && changed=1 || changed=0
  fi
  [ "$changed" -eq 1 ] || continue
  declare -f stack_gate >/dev/null 2>&1 || continue
  stack_gate || fail=1
done

# GATE-03: verification is change-scoped — only stacks whose files changed ran above.
[ "$fail" -eq 0 ] || { echo "[carve-harness:verify] 검증 실패(빌드/타입/테스트) — 완료 전 수정 필요" >&2; bash "$LOG_EVENT" Stop verify fail ""; exit 2; }
bash "$LOG_EVENT" Stop verify pass ""
exit 0
