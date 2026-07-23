#!/usr/bin/env bash
# logs-report.sh — JSONL 가드 로그 요약 + 회전 (README Dev-4).
#   logs-report.sh [days]          최근 N일(기본 7) 요약: 판정 분포·차단 상세
#   logs-report.sh --rotate <days> N일보다 오래된 로그 삭제 (유일한 쓰기 동작)
#   logs-report.sh --tokens [days] 세션별 토큰 사용량 (Claude Code 트랜스크립트 집계)
# jq는 .claude/bin(vendor 설치본) 우선 — 오프라인 동작.

DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PATH="$DIR/.claude/bin:$PATH"
LOGS="$DIR/logs"

if ! command -v jq >/dev/null 2>&1; then
  echo "[carve-harness:logs-report] jq 없음 — install.sh 실행 필요" >&2
  exit 1
fi
[ -d "$LOGS" ] || { echo "[carve-harness:logs-report] logs/ 없음 — 기록된 이벤트 없음"; exit 0; }

if [ "${1:-}" = "--rotate" ]; then
  keep="${2:?usage: logs-report.sh --rotate <keep-days>}"
  case "$keep" in *[!0-9]*|'') echo "[carve-harness:logs-report] --rotate는 정수 일수 필요" >&2; exit 1;; esac
  old=$(find "$LOGS" -name '*.jsonl' -type f -mtime +"$keep")
  if [ -n "$old" ]; then
    printf '%s\n' "$old" | while read -r f; do echo "[carve-harness:logs-report] 삭제: $f"; rm -f "$f"; done
  else
    echo "[carve-harness:logs-report] ${keep}일 초과 로그 없음"
  fi
  exit 0
fi

if [ "${1:-}" = "--tokens" ]; then
  days="${2:-7}"
  case "$days" in *[!0-9]*|'') echo "[carve-harness:logs-report] 일수는 정수" >&2; exit 1;; esac
  # Claude Code transcript dir: cwd path with / and . mangled to '-'.
  # CLAUDE_TRANSCRIPTS_DIR overrides (tests / non-standard installs).
  proj=$(printf '%s' "$DIR" | sed 's#[/.]#-#g')
  TDIR="${CLAUDE_TRANSCRIPTS_DIR:-$HOME/.claude/projects/$proj}"
  [ -d "$TDIR" ] || { echo "[carve-harness:logs-report] 트랜스크립트 없음: $TDIR"; exit 0; }
  tfiles=$(find "$TDIR" -name '*.jsonl' -type f -mtime -"$days" | sort)
  [ -n "$tfiles" ] || { echo "[carve-harness:logs-report] 최근 ${days}일 트랜스크립트 없음"; exit 0; }
  echo "== 토큰 사용량 (최근 ${days}일, API 호출 usage 합산) =="
  echo
  printf '%-38s %12s %12s %14s %14s\n' "session" "input" "output" "cache-read" "cache-create"
  total='{"in":0,"out":0,"cr":0,"cc":0}'
  while IFS= read -r f; do
    s=$(jq -s '[.[] | .message.usage? // empty]
      | {in: ([.[].input_tokens // 0] | add // 0),
         out: ([.[].output_tokens // 0] | add // 0),
         cr: ([.[].cache_read_input_tokens // 0] | add // 0),
         cc: ([.[].cache_creation_input_tokens // 0] | add // 0)}' "$f" 2>/dev/null)
    [ -n "$s" ] || continue
    name=$(basename "$f" .jsonl); name="${name:0:36}"
    printf '%-38s %12s %12s %14s %14s\n' "$name" \
      "$(printf '%s' "$s" | jq -r '.in')" "$(printf '%s' "$s" | jq -r '.out')" \
      "$(printf '%s' "$s" | jq -r '.cr')" "$(printf '%s' "$s" | jq -r '.cc')"
    total=$(jq -cn --argjson a "$total" --argjson b "$s" \
      '{in: ($a.in + $b.in), out: ($a.out + $b.out), cr: ($a.cr + $b.cr), cc: ($a.cc + $b.cc)}')
  done <<< "$tfiles"
  echo
  printf '%-38s %12s %12s %14s %14s\n' "TOTAL" \
    "$(printf '%s' "$total" | jq -r '.in')" "$(printf '%s' "$total" | jq -r '.out')" \
    "$(printf '%s' "$total" | jq -r '.cr')" "$(printf '%s' "$total" | jq -r '.cc')"
  echo
  echo "(비용 환산은 모델 단가에 따라 다름 — 단가표 없이 추정하지 않음)"
  exit 0
fi

days="${1:-7}"
case "$days" in *[!0-9]*|'') echo "[carve-harness:logs-report] 일수는 정수" >&2; exit 1;; esac

files=$(find "$LOGS" -name '*.jsonl' -type f -mtime -"$days" | sort)
[ -n "$files" ] || { echo "[carve-harness:logs-report] 최근 ${days}일 로그 없음"; exit 0; }

echo "== 하네스 로그 요약 (최근 ${days}일) =="
echo
echo "-- 이벤트 x 판정 --"
# shellcheck disable=SC2086
cat $files | jq -r '[.event, .decision] | join(" ")' | sort | uniq -c | sort -rn
echo
echo "-- 차단 상세 (도구 / 대상) --"
# shellcheck disable=SC2086
blocks=$(cat $files | jq -r 'select(.decision == "block") | [.tool, .target // "-"] | join("  ")' | sort | uniq -c | sort -rn)
if [ -n "$blocks" ]; then printf '%s\n' "$blocks"; else echo "(차단 없음)"; fi
echo
echo "-- 일자별 이벤트 수 --"
# shellcheck disable=SC2086
cat $files | jq -r '.ts[0:10]' | sort | uniq -c
exit 0
