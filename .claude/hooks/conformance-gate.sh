#!/usr/bin/env bash
# Stop: spec-conformance gate (active-only). Blocks a "done" declaration while any
# specs/*/SCORE.json is active with an item below its threshold — or malformed.
# Contract: .claude/rules/conformance.md §4·§5. Usage doc: docs/md/spec-loop.md §8.
#
# This is a GATE, not the loop driver. It mirrors stop-verify's loop guard so a
# forced re-Stop cannot wedge the session: block once, and if Claude stops again
# without resolving, yield. The convergence loop is /carve-eval or the workflow.
set -o pipefail

LOG_EVENT="$(dirname "${BASH_SOURCE[0]}")/log-event.sh"
DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# GATE-01: forced-continuation guard, single-sourced with stop-verify so the
# wedge-prevention invariant cannot drift (lib-stop-guard.sh). Reads stdin once.
source "$(dirname "${BASH_SOURCE[0]}")/lib-stop-guard.sh"
stop_loop_yield conformance "$LOG_EVENT"

# jq-absent → best-effort skip (D-02, consistent with stop-verify/log-event). The
# loop is JSON-driven; a jq-less box can't run or evaluate SCORE.json meaningfully.
if ! command -v jq >/dev/null 2>&1; then
  echo "[carve-harness:conformance] jq 미설치 → 정합성 게이트 스킵(best-effort)" >&2
  exit 0
fi

# active-only: no SCORE.json anywhere → ordinary session, pass silently.
shopt -s nullglob
scores=( "$DIR"/specs/*/SCORE.json )
[ ${#scores[@]} -eq 0 ] && exit 0

blocked=0
report=""
for f in "${scores[@]}"; do
  slug=$(basename "$(dirname "$f")")
  # malformed JSON → fail-closed (contract §8): cannot prove pass → block.
  if ! jq empty "$f" >/dev/null 2>&1; then
    report="${report}\n  - ${slug}: SCORE.json 파싱 불가(malformed) → fail-closed"
    blocked=1; continue
  fi
  [ "$(jq -r '.active // false' "$f")" != "true" ] && continue   # inactive slug → gate released
  threshold=$(jq -r 'if (.threshold|type)=="number" then .threshold else 95 end' "$f")
  n=$(jq -r '(.items // []) | length' "$f")
  # active loop with nothing enumerated is itself suspect → fail-closed.
  if [ "$n" -eq 0 ]; then
    report="${report}\n  - ${slug}: items 비어 있음(전수 열거 안 됨) → fail-closed"
    blocked=1; continue
  fi
  # any item missing a numeric score, or scoring below threshold → block.
  bad=$(jq -r --argjson th "$threshold" '
    (.items // [])
    | map(select((.score | type) != "number" or .score < $th))
    | map((.id // "?") + "=" + ((.score // "null") | tostring))
    | join(", ")
  ' "$f")
  if [ -n "$bad" ]; then
    report="${report}\n  - ${slug}: 미달 항목 [${bad}] (threshold ${threshold})"
    blocked=1
  fi
done

if [ "$blocked" -eq 1 ]; then
  echo "[carve-harness:conformance] 정합성 게이트 미통과 — 완료 선언 차단:" >&2
  printf '%b\n' "$report" >&2
  echo "  → 미달 항목을 수정하고 conformance-scorer로 재채점하라 (해제: 전 항목 ≥threshold → SCORE.json active=false)." >&2
  bash "$LOG_EVENT" Stop conformance block ""
  exit 2
fi

bash "$LOG_EVENT" Stop conformance pass ""
exit 0
