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

# 설치 인벤토리 — carve-harness가 세션에서 호출하는 훅·스킬·커맨드·에이전트·문서 전부 표시.
# 매 SessionStart에 실행되는 핫패스 — 포크 최소화(파라미터 확장, 라벨당 awk 1회).
_inv() { # $1=라벨 — stdin 줄당 1항목을 세고 " · "로 조인. 빈 입력(미설치 구성)은 생략.
  awk -v L="$1" 'NF { n++; s = s (n > 1 ? " · " : "") $0 } END { if (n) printf "   %s(%d): %s\n", L, n, s }'
}
_ls() { # $1=glob (unquoted 확장) $2=제거할 접미사 → 줄당 이름 1개
  local f n
  for f in $1; do
    [ -e "$f" ] || continue
    n="${f##*/}"; [ -n "$2" ] && n="${n%"$2"}"
    printf '%s\n' "$n"
  done
}

case "${1:-}" in
  start)
    cat <<'BANNER'
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
   ⟦ CARVE-HARNESS ⟧ ACTIVE — 3기둥 게이트 ON
     제약 가드(차단 exit 2) · 피드백 증분검증 · 상태 핸드오프
     점검: /harness-audit   ·   로그: logs/*.jsonl
   ── carve-harness 로드 구성 (전 항목) ──
BANNER
    _ls '.claude/hooks/*.sh' .sh | _inv "훅"
    { [ -d vendor/ponytail ] && echo 'ponytail'; } | _inv "모드"
    _ls '.githooks/*' '' | _inv "git훅"
    _ls '.claude/skills/*' '' | _inv "스킬"
    _ls '.claude/commands/*.md' .md | _inv "커맨드"
    _ls '.claude/agents/*.md' .md | _inv "에이전트"
    _ls '.claude/workflows/*' '' | _inv "워크플로"
    for d in CLAUDE.md AGENTS.md RULES.md codex.md .cursorrules .claude/CLAUDE.md specs/README.md; do
      [ -e "$d" ] && printf '%s\n' "$d"   # install.sh MD_PATHS와 동기 유지
    done | _inv "문서"
    find .claude/rules -name '*.md' 2>/dev/null \
      | sed -e 's|^\.claude/rules/||' -e 's|\.md$||' | sort | _inv "규칙"
    echo "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"
    [ -f "$H" ] && { echo "=== 이전 세션 핸드오프 (carve-harness) ==="; cat "$H"; }
    bash "$LOG_EVENT" SessionStart handoff start ""
    ;;
  save)
    _collect > "$H" 2>/dev/null
    bash "$LOG_EVENT" "${2:-PreCompact}" handoff save ""
    ;;
esac
exit 0
