#!/usr/bin/env bash
# java-spring.sh — stack definition (sourced by stop-verify.sh / posttool-format.sh).
# Pure definitions: variables + functions, no side effects on load.
# Contract (every .claude/stacks/*.sh):
#   STACK_ID            pack name
#   STACK_CHANGE_RE     ERE over `git status --porcelain` paths — gate runs only when it matches
#   STACK_FORMAT_RE     ERE over the written file path — PostToolUse formats when it matches ('' = none)
#   STACK_FORMAT_TOOL   name recorded in the JSONL (format-ok/fail)
#   stack_format FILE   rc 0 ok · 1 formatter error · 2 formatter missing
#   stack_gate          rc 0 pass · 1 fail. Reads $CHANGED $have_git (set by stop-verify.sh)
STACK_ID=java-spring
STACK_CHANGE_RE='\.(java|kt|gradle)'
STACK_FORMAT_RE='\.java$'
STACK_FORMAT_TOOL=spotless

# 게이트웨이 파일 판별 단일 소스 — harness-audit AUDIT-07이 이 파일에서 GatewayIntegration 트리거를 확인한다.
JAVA_GW_RE='([Gg]ateway|[Ff]ilter|[Aa]uth|[Rr]ate[Ll]imit)[^/]*\.java$|/gateway/.*\.java$'

stack_format() {
  [ -x ./gradlew ] || return 2
  ./gradlew spotlessApply -PspotlessFiles="$1" -q
}

# 컴파일 + 테스트. 커버리지 80%는 build.gradle의 jacocoTestCoverageVerification으로 강제.
# GATE-04: 게이트웨이 파일만 변경 → *GatewayIntegration* 타깃만(전체 빌드 회피).
#          다른 java가 섞이면 full test(게이트웨이 통합 테스트 포함)로 안전하게 간다.
# 기본(git 없음)은 full(java_other=1, gw off) — 회피는 변경 식별 가능할 때만.
stack_gate() {
  local GDIR="" gw_changed=0 java_other=1 gw_out gw_rc
  [ -f gradlew ] && GDIR="."
  [ -z "$GDIR" ] && [ -f backend/gradlew ] && GDIR="backend"
  [ -n "$GDIR" ] || return 0
  if [ "${have_git:-0}" -eq 1 ]; then
    printf '%s\n' "$CHANGED" | grep -Eq "$JAVA_GW_RE" && gw_changed=1 || gw_changed=0
    printf '%s\n' "$CHANGED" | grep -E '\.(java|kt|gradle)$' | grep -Ev "$JAVA_GW_RE" | grep -q . && java_other=1 || java_other=0
  fi
  if [ "$java_other" -eq 0 ] && [ "$gw_changed" -eq 1 ]; then
    gw_out=$( cd "$GDIR" && ./gradlew compileJava test --tests '*GatewayIntegration*' -q 2>&1 ); gw_rc=$?
    printf '%s\n' "$gw_out" | tail -20
    if [ "$gw_rc" -ne 0 ]; then
      # gradle는 --tests 매칭 0개면 실패 → 컨벤션 미채택 프로젝트의 false-fail 방지(best-effort skip).
      printf '%s\n' "$gw_out" | grep -qiE 'no tests found|does not match' \
        && echo "[carve-harness:verify] *GatewayIntegration* 매칭 테스트 없음 — 스킵(best-effort)" >&2 \
        || return 1
    fi
  else
    ( cd "$GDIR" && ./gradlew compileJava test -q ) 2>&1 | tail -20 || return 1
  fi
  return 0
}
