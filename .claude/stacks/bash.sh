#!/usr/bin/env bash
# bash.sh — core stack (not a language pack): the harness's own hooks and scripts.
# Contract: see java-spring.sh header. Reads $HOOKS_DIR $CHANGED $have_git from stop-verify.sh.
STACK_ID=bash
STACK_CHANGE_RE='\.sh$|^\.githooks/'
STACK_FORMAT_RE=''
STACK_FORMAT_TOOL=''

# 훅/스크립트 정적분석 + 훅 자가 테스트. 분석기는 .claude/bin(vendor) 우선 → PATH. 없으면 스킵.
# -S error만 게이트 — 경고는 비차단.
stack_gate() {
  local sh_files hooks_changed=0 SC t
  if [ "${have_git:-0}" -eq 1 ]; then
    sh_files=$(printf '%s\n' "$CHANGED" | grep -E '\.sh$|^\.githooks/' | while read -r f; do [ -f "$f" ] && echo "$f"; done)
    printf '%s\n' "$CHANGED" | grep -Eq '^\.claude/hooks/|^\.claude/stacks/|^\.githooks/' && hooks_changed=1
  else
    # git 없음 → 전체 검사 (change-detection 불가 시 skip 금지 — GATE-03과 동일 원칙)
    sh_files=$(ls .claude/hooks/*.sh .claude/stacks/*.sh .githooks/* 2>/dev/null)
    hooks_changed=1
  fi
  SC="$HOOKS_DIR/../bin/shellcheck"
  command -v "$SC" >/dev/null 2>&1 || SC=$(command -v shellcheck)
  if [ -n "$SC" ] && [ -n "$sh_files" ]; then
    # shellcheck disable=SC2086
    "$SC" -S error $sh_files 2>&1 | tail -20 || return 1
  fi
  if [ "$hooks_changed" -eq 1 ]; then
    for t in "$HOOKS_DIR"/tests/*.test.sh; do
      [ -e "$t" ] || continue
      bash "$t" >/dev/null 2>&1 || { echo "[carve-harness:verify] 훅 테스트 실패: $(basename "$t")" >&2; return 1; }
    done
  fi
  return 0
}
