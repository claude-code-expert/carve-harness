#!/usr/bin/env bash
# Assertions for `install.sh prune` — the mode /carve-harness-create drives.
# Offline (HARNESS_SRC_DIR), temp targets, network never touched.
# Covers: keep-list prune, stack pruning, dependency edges (eval-java↔archunit,
# squad cmd↔agent), PROTECTED core, manifest/audit/rollback, dry-run, guards.

REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

# One full install; copy it per destructive case (cp is cheap vs re-install).
BASE=$(mktemp -d)
( cd "$BASE" && HARNESS_COMPONENTS=all HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" ) >/dev/null 2>&1
if [ -f "$BASE/.claude/harness-manifest.txt" ] && [ -d "$BASE/.claude/rules/java-spring" ]; then
  ok "baseline full install lands (manifest + java-spring present)"
else
  no "baseline full install"
fi

# KEEP set for a Python/FastAPI project: always-keep (non-protected) + python stack
# + review's reviewer agents. Everything else (java, react, squad, fable, misc) prunes.
mkkeep() {
  cat <<'EOF'
.claude/skills/handoff
.claude/skills/changelog
.claude/skills/version-changelog
.claude/skills/anti-ai-slop
.claude/skills/carve-harness-create
.claude/commands/harness-audit.md
.claude/commands/commit.md
.claude/commands/plan.md
.claude/commands/review.md
.claude/commands/verify.md
.claude/agents/security-reviewer.md
docs/rules/code-convention/dev-stack-python.md
docs/rules/code-convention/dev-stack-fastapi.md
docs/rules/code-convention/dev-stack-orm.md
.claude/rules/database.md
EOF
}

# ── keep-list prune on a copy ────────────────────────────────────────────────
TA=$(mktemp -d); cp -R "$BASE/." "$TA/"
KEEP="$TA/keep.list"; mkkeep > "$KEEP"
( cd "$TA" && bash install.sh prune --keep-list "$KEEP" ) >/dev/null 2>&1; code=$?

# (1) prune exits 0 (audit passed on fall-through)
[ "$code" -eq 0 ] && ok "keep-list prune exits 0" || no "keep-list prune exit ($code)"

# (2) java-spring rules pruned
[ ! -e "$TA/.claude/rules/java-spring" ] && ok "java-spring pruned" || no "java-spring still present"

# (3) python rules kept
[ -f "$TA/docs/rules/code-convention/dev-stack-python.md" ] \
  && ok "python rules kept" || no "python rules pruned"

# (4) core hooks + git-hooks + settings intact (constraint/feedback pillar)
[ -f "$TA/.claude/hooks/pretool-guard.sh" ] && [ -f "$TA/.githooks/pre-commit" ] \
  && [ -f "$TA/.claude/settings.json" ] \
  && ok "core hooks + git-hooks + settings intact" || no "core damaged by prune"

# (5) always-keep survive: safety/security (protected) + handoff/version-changelog (in keep)
[ -f "$TA/.claude/rules/safety.md" ] && [ -f "$TA/.claude/rules/common/security.md" ] \
  && [ -d "$TA/.claude/skills/handoff" ] && [ -d "$TA/.claude/skills/version-changelog" ] \
  && ok "always-keep core survives prune" || no "always-keep pruned"

# (6) edge: eval-java pruned => archunit pruned together (no orphan, AUDIT-08 safe)
if [ ! -e "$TA/.claude/hooks/eval-java.sh" ]; then
  [ ! -e "$TA/.claude/rules/java-spring/archunit" ] \
    && ok "edge: eval-java + archunit pruned together" || no "orphan archunit after eval-java prune"
else
  no "eval-java.sh should have been pruned (not in keep-list)"
fi

# (7) manifest rewritten to keep-set
! grep -q 'java-spring' "$TA/.claude/harness-manifest.txt" \
  && grep -q 'dev-stack-python' "$TA/.claude/harness-manifest.txt" \
  && ok "manifest reflects keep-set" || no "manifest not updated"

# (8) audit still passes after prune
aout=$( cd "$TA" && CLAUDE_PROJECT_DIR="$TA" bash .claude/hooks/harness-audit.sh 2>&1 )
printf '%s' "$aout" | grep -q "0 failed" && ok "harness-audit passes post-prune" || no "audit FAIL post-prune"

# (10) rollback restores pruned components (prune is reversible)
( cd "$TA" && bash install.sh rollback ) >/dev/null 2>&1
[ -e "$TA/.claude/rules/java-spring" ] && [ -e "$TA/.claude/hooks/eval-java.sh" ] \
  && ok "rollback restores pruned components" || no "rollback did not restore"

# ── dry-run must not mutate, and must report the would-remove COUNT ───────────
#    (regression: the `continue` in the dry branch skipped `removed++` → the summary
#     always said "0 개 제거 예정" even when files were detected.)
TC=$(mktemp -d); cp -R "$BASE/." "$TC/"
dout=$( cd "$TC" && bash install.sh prune --remove-file .claude/rules/java-spring --dry-run 2>&1 )
if [ -e "$TC/.claude/rules/java-spring" ] && grep -qx '.claude/rules' "$TC/.claude/harness-manifest.txt"; then
  ok "dry-run mutates nothing (files + coarse manifest intact)"
else
  no "dry-run mutated state"
fi
printf '%s' "$dout" | grep -qE 'dry-run: [1-9][0-9]* 개 제거 예정' \
  && ok "dry-run reports would-remove count (>0)" \
  || no "dry-run count 0/absent: $(printf '%s' "$dout" | grep -o 'dry-run:.*예정')"

# ── empty keep-list guard (prevent full wipe) ────────────────────────────────
TD=$(mktemp -d); cp -R "$BASE/." "$TD/"
: > "$TD/empty.list"
( cd "$TD" && bash install.sh prune --keep-list empty.list ) >/dev/null 2>&1; ecode=$?
[ "$ecode" -ne 0 ] && [ -d "$TD/.claude/hooks" ] \
  && ok "empty keep-list rejected (no wipe)" || no "empty keep-list not guarded"

# ── PROTECTED core refusal (trust boundary) ──────────────────────────────────
TE=$(mktemp -d); cp -R "$BASE/." "$TE/"
( cd "$TE" && bash install.sh prune --remove-file CLAUDE.md --remove-file .claude/settings.json ) >/dev/null 2>&1
[ -f "$TE/CLAUDE.md" ] && [ -f "$TE/.claude/settings.json" ] \
  && ok "PROTECTED core refuses removal" || no "PROTECTED core removed"

# ── out-of-manifest path is a structural no-op (only manifest paths ever removed) ──
TF=$(mktemp -d); cp -R "$BASE/." "$TF/"
( cd "$TF" && bash install.sh prune --remove-file ../../../../etc/passwd ) >/dev/null 2>&1
[ -f "$TF/CLAUDE.md" ] && [ -f "$TF/.claude/hooks/pretool-guard.sh" ] \
  && ok "out-of-manifest remove path is a no-op (core intact)" || no "out-of-manifest path affected core"

rm -rf "$BASE" "$TA" "$TC" "$TD" "$TE" "$TF"
printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
