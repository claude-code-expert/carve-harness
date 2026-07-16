#!/usr/bin/env bash
# Assertions for config-doctor.sh — the advisory checker /carve-harness-create drives.
# Deterministic: temp files with known-broken refs; live repo config never depended on.

REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
DOCTOR="$REPO/.claude/hooks/config-doctor.sh"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

T=$(mktemp -d)
mkdir -p "$T/.claude/skills/real-skill"          # a path that DOES exist
: > "$T/AGENTS.md"                                 # @AGENTS.md target exists

# clean file — real @ref + real path → no findings
cat > "$T/CLAUDE.md" <<'EOF'
See @AGENTS.md and .claude/skills/real-skill for details.
EOF
out=$( CLAUDE_PROJECT_DIR="$T" bash "$DOCTOR" CLAUDE.md )
printf '%s' "$out" | grep -q '이상 없음' \
  && ok "clean config -> 이상 없음" || no "clean config flagged: $out"

# broken @ref + dead .claude path → two findings, still exit 0
cat > "$T/CLAUDE.md" <<'EOF'
Broken ref @.claude/rules/ghost/ and dead .claude/skills/frontend-design here.
Real ones: @AGENTS.md .claude/skills/real-skill stay clean.
EOF
out=$( CLAUDE_PROJECT_DIR="$T" bash "$DOCTOR" CLAUDE.md ); code=$?
printf '%s' "$out" | grep -q "깨진 @참조 '@.claude/rules/ghost/'" \
  && ok "detects broken @ref" || no "missed broken @ref: $out"
printf '%s' "$out" | grep -q "죽은 경로 참조 '.claude/skills/frontend-design'" \
  && ok "detects dead .claude path" || no "missed dead path: $out"
printf '%s' "$out" | grep -q 'real-skill' \
  && no "false-positive on existing path" || ok "no false-positive on existing path"
[ "$code" -eq 0 ] && ok "advisory: exit 0 despite findings" || no "doctor exited non-zero ($code)"

# email must not false-positive as a broken @ref
cat > "$T/CLAUDE.md" <<'EOF'
Contact user@example.com for access.
EOF
out=$( CLAUDE_PROJECT_DIR="$T" bash "$DOCTOR" CLAUDE.md )
printf '%s' "$out" | grep -q '이상 없음' \
  && ok "email is not treated as @ref" || no "email false-positive: $out"

rm -rf "$T"
printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
