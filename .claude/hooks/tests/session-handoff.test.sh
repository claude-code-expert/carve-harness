#!/usr/bin/env bash
# Assertions for session-handoff.sh.
# Phase 2 (OBS-01/D-03): SessionStart:start and PreCompact:save each log exactly
# one JSONL line and stay exit 0; save still writes specs/HANDOFF.md; a log
# failure never changes the exit code (D-05).
# Phase 3 (STATE-01/STATE-03): the save arm collects real content (STATE.md
# todos, recent DECISIONS) — the `[자동 수집 — 내용없음]` sentinel is gone.

HOOK="$(cd "$(dirname "$0")/.." && pwd)/session-handoff.sh"
fail=0; pass=0
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }
daily() { printf '%s/logs/%s.jsonl' "$1" "$(date -u +%F)"; }

# (1) start -> one SessionStart/start line, exit 0.
cwd=$(mktemp -d); logd=$(mktemp -d); L="$(daily "$logd")"
( cd "$cwd" && CLAUDE_PROJECT_DIR="$logd" bash "$HOOK" start >/dev/null 2>&1 ); code=$?
if [ "$code" -eq 0 ] \
   && [ "$(tail -1 "$L" 2>/dev/null | jq -r '.event' 2>/dev/null)" = "SessionStart" ] \
   && [ "$(tail -1 "$L" 2>/dev/null | jq -r '.decision' 2>/dev/null)" = "start" ]; then
  ok "start logs SessionStart/start (exit 0)"
else
  bad "start log"
fi
rm -rf "$cwd" "$logd"

# (2) save -> one PreCompact/save line, writes specs/HANDOFF.md, exit 0.
cwd=$(mktemp -d); logd=$(mktemp -d); L="$(daily "$logd")"
mkdir -p "$cwd/specs"
( cd "$cwd" && CLAUDE_PROJECT_DIR="$logd" bash "$HOOK" save >/dev/null 2>&1 ); code=$?
if [ "$code" -eq 0 ] && [ -f "$cwd/specs/HANDOFF.md" ] \
   && [ "$(tail -1 "$L" 2>/dev/null | jq -r '.event' 2>/dev/null)" = "PreCompact" ] \
   && [ "$(tail -1 "$L" 2>/dev/null | jq -r '.decision' 2>/dev/null)" = "save" ]; then
  ok "save logs PreCompact/save + writes specs/HANDOFF.md (exit 0)"
else
  bad "save log / HANDOFF.md"
fi
rm -rf "$cwd" "$logd"

# (3) D-05: unwritable logs -> both start and save still exit 0.
cwd=$(mktemp -d); logd=$(mktemp -d); touch "$logd/logs"; mkdir -p "$cwd/specs"
( cd "$cwd" && CLAUDE_PROJECT_DIR="$logd" bash "$HOOK" start >/dev/null 2>&1 ); s=$?
( cd "$cwd" && CLAUDE_PROJECT_DIR="$logd" bash "$HOOK" save  >/dev/null 2>&1 ); v=$?
[ "$s" -eq 0 ] && [ "$v" -eq 0 ] && ok "unwritable logs -> start & save still exit 0" || bad "unwritable logs exit 0"
rm -rf "$cwd" "$logd"

# (4) source: log calls present; sentinel GONE + STATE.md wired (Phase 3 STATE-01); bash -n clean.
grep -q 'SessionStart handoff start' "$HOOK" && ok "start log call present" || bad "start log call"
grep -qF '${2:-PreCompact}" handoff save' "$HOOK" && ok "save log call present (label-parametrized)" || bad "save log call"
if ! grep -q '자동 수집' "$HOOK" && grep -q 'STATE.md' "$HOOK"; then
  ok "sentinel removed + STATE.md wired (STATE-01)"
else
  bad "sentinel still present or STATE.md not wired"
fi
bash -n "$HOOK" 2>/dev/null && ok "bash -n clean" || bad "bash -n"

# (5) STATE-01: a seeded Pending Todo surfaces in the written handoff (SC1).
cwd=$(mktemp -d); logd=$(mktemp -d)
mkdir -p "$cwd/specs" "$cwd/.planning"
printf '## Accumulated Context\n\n### Pending Todos\n\n- ship the widget\n\n### Blockers/Concerns\n\nNone yet.\n' > "$cwd/.planning/STATE.md"
( cd "$cwd" && CLAUDE_PROJECT_DIR="$logd" bash "$HOOK" save >/dev/null 2>&1 ); code=$?
if [ "$code" -eq 0 ] && grep -q 'ship the widget' "$cwd/specs/HANDOFF.md" 2>/dev/null; then
  ok "seeded Pending Todo appears in HANDOFF.md (STATE-01/SC1)"
else
  bad "STATE-01 todo collection"
fi
rm -rf "$cwd" "$logd"

# (6) D-12: empty Pending Todos keeps the 미완료 header with an explicit "- (none)".
cwd=$(mktemp -d); logd=$(mktemp -d)
mkdir -p "$cwd/specs" "$cwd/.planning"
printf '### Pending Todos\n\nNone yet.\n' > "$cwd/.planning/STATE.md"
( cd "$cwd" && CLAUDE_PROJECT_DIR="$logd" bash "$HOOK" save >/dev/null 2>&1 )
if grep -q '## 미완료' "$cwd/specs/HANDOFF.md" 2>/dev/null && grep -q '(none)' "$cwd/specs/HANDOFF.md" 2>/dev/null; then
  ok "empty todos -> 미완료 header + (none) (D-12)"
else
  bad "D-12 empty section"
fi
rm -rf "$cwd" "$logd"

# (7) STATE-03: a seeded DECISIONS.md entry surfaces in the handoff (SC3).
cwd=$(mktemp -d); logd=$(mktemp -d)
mkdir -p "$cwd/specs" "$cwd/.planning"
printf -- '- 2026-07-07 / use jq for JSONL / alt printf / logging\n' > "$cwd/specs/DECISIONS.md"
( cd "$cwd" && CLAUDE_PROJECT_DIR="$logd" bash "$HOOK" save >/dev/null 2>&1 ); code=$?
if [ "$code" -eq 0 ] && grep -q 'use jq' "$cwd/specs/HANDOFF.md" 2>/dev/null; then
  ok "seeded DECISIONS entry surfaces in handoff (STATE-03/SC3)"
else
  bad "STATE-03 decision reflection"
fi
rm -rf "$cwd" "$logd"

# (7b) D-06: no DECISIONS.md -> save exit 0, handoff written, no 주의점 section.
cwd=$(mktemp -d); logd=$(mktemp -d); mkdir -p "$cwd/specs" "$cwd/.planning"
( cd "$cwd" && CLAUDE_PROJECT_DIR="$logd" bash "$HOOK" save >/dev/null 2>&1 ); code=$?
if [ "$code" -eq 0 ] && [ -f "$cwd/specs/HANDOFF.md" ] && ! grep -q '주의점' "$cwd/specs/HANDOFF.md" 2>/dev/null; then
  ok "absent DECISIONS.md -> graceful omit, exit 0 (D-06)"
else
  bad "D-06 graceful omit"
fi
rm -rf "$cwd" "$logd"

# (8) D-14: no .planning/STATE.md at all -> save exits 0 and still writes the handoff.
cwd=$(mktemp -d); logd=$(mktemp -d); mkdir -p "$cwd/specs"
( cd "$cwd" && CLAUDE_PROJECT_DIR="$logd" bash "$HOOK" save >/dev/null 2>&1 ); code=$?
[ "$code" -eq 0 ] && [ -f "$cwd/specs/HANDOFF.md" ] && ok "no STATE.md -> exit 0 + handoff written (D-14)" || bad "D-14 best-effort"
rm -rf "$cwd" "$logd"

# (9) STATE-02: `save SessionEnd` reuses the save path, writes HANDOFF.md, logs .event==SessionEnd (SC2/D-10).
cwd=$(mktemp -d); logd=$(mktemp -d); L="$(daily "$logd")"; mkdir -p "$cwd/specs"
( cd "$cwd" && CLAUDE_PROJECT_DIR="$logd" bash "$HOOK" save SessionEnd >/dev/null 2>&1 ); code=$?
if [ "$code" -eq 0 ] && [ -f "$cwd/specs/HANDOFF.md" ] \
   && [ "$(tail -1 "$L" 2>/dev/null | jq -r '.event' 2>/dev/null)" = "SessionEnd" ] \
   && [ "$(tail -1 "$L" 2>/dev/null | jq -r '.decision' 2>/dev/null)" = "save" ]; then
  ok "save SessionEnd -> SessionEnd/save log + HANDOFF.md (exit 0) (STATE-02/SC2)"
else
  bad "STATE-02 SessionEnd label"
fi
rm -rf "$cwd" "$logd"

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
