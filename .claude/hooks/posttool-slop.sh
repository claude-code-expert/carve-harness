#!/usr/bin/env bash
# PostToolUse: anti-ai-slop 린터 리포트 (비차단). Write/Edit로 시각 산출물을 쓴 직후
# check-slop.mjs 를 돌려 **한 줄 요약만** stderr로 내보내고, 전체 판정은 JSONL에 남긴다.
#
# 왜 별도 훅인가: posttool-format.sh 는 포맷터 stdout·stderr를 둘 다 죽인다(OBS-02/C8 —
# gradle·prettier 잡음이 트랜스크립트를 오염시킨 이력). 그 배선을 재사용하면 린터 리포트가
# 통째로 삼켜져 리포트-온리의 의미가 사라진다. 같은 이유로 여기서도 전체 리포트를 쏟지 않고
# 요약 한 줄만 낸다 — 자세히 보려면 안내된 명령을 직접 실행한다.
#
# 대상은 .html/.htm/.css/.svg 뿐이다. .md 는 의도적으로 제외한다 — 문서가 지배적인 리포에서
# 카피 톤 룰(느낌표·상투어)이 상시 발화해 신호가 잡음에 묻힌다. Markdown은 수동 실행으로.
#
# 항상 exit 0: PostToolUse 의 비영 종료는 비차단이라 오히려 헛된 훅 오류만 노출된다.
# 차단이 필요하면 게이트를 Stop 훅으로 올려야 한다(현재 설계는 리포트-온리).
input=$(cat)
f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_EVENT="$HOOKS_DIR/log-event.sh"
LINTER="$HOOKS_DIR/check-slop.mjs"

log() { bash "$LOG_EVENT" PostToolUse check-slop "$1" "${f:-}" "${2:-}"; }

# 시각 산출물이 아니면 조용히 통과 (대다수 호출이 여기서 끝난다 — 비용 0)
printf '%s' "$f" | grep -Eq '\.(html|htm|css|svg)$' || exit 0

# 도구·대상 부재는 실패가 아니라 미실행이다. 기록은 남기되 차단하지 않는다.
command -v node >/dev/null 2>&1 || { log slop-skip "node-missing"; exit 0; }
[ -f "$LINTER" ] || { log slop-skip "linter-missing"; exit 0; }
[ -f "$f" ]      || { log slop-skip "file-missing";   exit 0; }

out=$(node "$LINTER" "$f" 2>&1)
tot=$(printf '%s' "$out" | grep -oE '[0-9]+ error\(s\), [0-9]+ warning\(s\) across' | tail -1)
e=$(printf '%s' "$tot" | grep -oE '^[0-9]+')
w=$(printf '%s' "$tot" | grep -oE '[0-9]+ warning' | grep -oE '^[0-9]+')
e=${e:-0}; w=${w:-0}

if [ "$e" -gt 0 ]; then
  echo "[carve-harness:check-slop] $f — ${e} error, ${w} warn · MUST-NOT 위반이다. 고쳐라 → node .claude/hooks/check-slop.mjs $f" >&2
  log slop-error "$e"
elif [ "$w" -gt 0 ]; then
  echo "[carve-harness:check-slop] $f — 0 error, ${w} warn (판단 필요) → node .claude/hooks/check-slop.mjs $f" >&2
  log slop-warn "$w"
else
  log slop-clean ""
fi
exit 0
