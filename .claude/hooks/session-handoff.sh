#!/usr/bin/env bash
# SessionStart(start): 핸드오프 복원 | PreCompact/SessionEnd(save): 진행상황 저장
H="specs/HANDOFF.md"
LOG_EVENT="$(dirname "${BASH_SOURCE[0]}")/log-event.sh"
STATE=".planning/STATE.md"
DECISIONS="specs/DECISIONS.md"

# Best-effort: list items ("- ...") under an H3 heading, until the next H2/H3.
# `None`/`None yet.`/`(none)` placeholders are dropped so the section reads empty.
_section_items() {  # $1=file  $2=heading (literal, e.g. "### Pending Todos")
  awk -v h="$2" '
    index($0, h) == 1 { f = 1; next }
    /^#{2,3} /        { f = 0 }
    f && /^[[:space:]]*-[[:space:]]/ { print }
  ' "$1" 2>/dev/null | grep -viE '^[[:space:]]*-[[:space:]]*\(?none\b'
}

_emit() {  # print stdin verbatim, or "- (none)" when empty (D-12: keep header)
  local body; body=$(cat)
  if [ -n "$body" ]; then printf '%s\n' "$body"; else echo "- (none)"; fi
}

# Assemble the handoff snapshot (handoff-skill order: 진행 상황 / 미완료 / 다음 단계 / 주의점).
# Every source read is guarded so a missing/malformed file degrades to "- (none)"
# or an omitted section — never a crash (D-14).
_collect() {
  echo "# HANDOFF ($(date +%F' '%T))"
  echo
  echo "## 진행 상황"
  echo "- branch: $(git branch --show-current 2>/dev/null)"
  echo "- $(git status --porcelain 2>/dev/null | wc -l | tr -d ' ') uncommitted files"
  echo
  echo "## 미완료"
  _section_items "$STATE" "### Pending Todos" | _emit
  echo
  echo "## 다음 단계"
  {
    for p in .planning/phases/*/*-PLAN.md; do
      [ -e "$p" ] || continue                       # unmatched glob → skip
      [ -e "${p%-PLAN.md}-SUMMARY.md" ] && continue # has summary → done, not "next"
      echo "- open plan: $(basename "$p" .md)"
    done
    _section_items "$STATE" "### Blockers/Concerns"
  } | _emit
  echo
  if [ -f "$DECISIONS" ]; then                       # D-06: absent → omit section
    echo "## 주의점"
    grep -E '^[[:space:]]*-[[:space:]]' "$DECISIONS" 2>/dev/null \
      | tail -5 | cut -d'/' -f1,2 | _emit            # D-05: recent 5, date + decision
  fi
}

case "${1:-}" in
  start)
    [ -f "$H" ] && { echo "=== 이전 세션 핸드오프 ==="; cat "$H"; }
    bash "$LOG_EVENT" SessionStart handoff start ""
    ;;
  save)
    _collect > "$H" 2>/dev/null
    bash "$LOG_EVENT" PreCompact handoff save ""
    ;;
esac
exit 0
