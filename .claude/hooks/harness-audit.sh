#!/usr/bin/env bash
# /harness-audit — mechanical PASS/FAIL of the harness gates (Phases 1–4).
# Read-only report: audits the harness rooted at AUDIT_ROOT, writes nothing,
# and exits NON-ZERO on any failed check (0 only when fully configured).
# Root resolves from CLAUDE_PROJECT_DIR (like log-event.sh) so tests can retarget
# it at a temp copy of .claude/ without touching the live config.
#   AUDIT-01: jq present · all hook events registered · hooks +x · bash -n clean
#   AUDIT-02: write-tool matcher coverage · Bash-write inspection present
#   AUDIT-03: safety-critical policy→gate mapping · [내용없음] handoff rejected

AUDIT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
S="$AUDIT_ROOT/.claude/settings.json"
HOOKS_DIR="$AUDIT_ROOT/.claude/hooks"

fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

# ── AUDIT-01 ────────────────────────────────────────────────────────────────
# jq present (checked first; every settings assertion below needs it).
if ! command -v jq >/dev/null 2>&1; then
  no "jq present (AUDIT-01)"
  printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
  exit 1
fi
ok "jq present (AUDIT-01)"

# settings.json parses.
if jq empty "$S" >/dev/null 2>&1; then
  ok "settings.json parses"
else
  no "settings.json parse (AUDIT-01)"
  printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
  exit 1
fi

# All 6 hook events registered.
for evt in PreToolUse PostToolUse Stop SessionStart PreCompact SessionEnd; do
  if jq -e --arg e "$evt" '.hooks[$e]' "$S" >/dev/null 2>&1; then
    ok "event $evt registered (AUDIT-01)"
  else
    no "event $evt UNREGISTERED (AUDIT-01)"
  fi
done

# Every hook script referenced by settings exists and is executable.
while read -r sh; do
  [ -n "$sh" ] || continue
  f="$HOOKS_DIR/$sh"
  if [ -f "$f" ] && [ -x "$f" ]; then
    ok "$sh exists +x (AUDIT-01)"
  else
    no "$sh missing or not +x (AUDIT-01)"
  fi
done < <(jq -r '.hooks | to_entries[] | .value[].hooks[].command // empty' "$S" \
           | grep -oE '[A-Za-z0-9._-]+\.sh' | sort -u)

# bash -n clean on every hook script.
for f in "$HOOKS_DIR"/*.sh; do
  [ -e "$f" ] || continue
  if bash -n "$f" 2>/dev/null; then
    ok "bash -n $(basename "$f") (AUDIT-01)"
  else
    no "bash -n $(basename "$f") FAILED (AUDIT-01)"
  fi
done

# ── AUDIT-02 ────────────────────────────────────────────────────────────────
# Write-tool matcher covers all write tools + Bash.
m=$(jq -r '.hooks.PreToolUse[0].matcher // empty' "$S")
if [ "$m" = "Write|Edit|MultiEdit|NotebookEdit|Bash" ]; then
  ok "PreToolUse matcher covers write tools + Bash (AUDIT-02)"
else
  no "PreToolUse matcher missing a write tool (AUDIT-02): '$m'"
fi

# Bash-write inspection present in the guard.
PG="$HOOKS_DIR/pretool-guard.sh"
if grep -q 'tool_input.command' "$PG" 2>/dev/null && grep -q 'PROTECTED_RE' "$PG" 2>/dev/null; then
  ok "Bash-write inspection present in pretool-guard.sh (AUDIT-02)"
else
  no "Bash-write inspection missing in pretool-guard.sh (AUDIT-02)"
fi

# ── AUDIT-03 ────────────────────────────────────────────────────────────────
# Each safety-critical policy must map to an enforcing gate (safety-critical scope
# only; code-convention style guides are LLM guidance, not hook-gated — D-09/D-12).
grep -q 'PROTECTED_RE' "$PG" 2>/dev/null \
  && ok "policy->gate: protected-path block (safety.md -> PROTECTED_RE) (AUDIT-03)" \
  || no "orphan policy: protected-path block has no gate (AUDIT-03)"

grep -q 'command -v jq' "$PG" 2>/dev/null && grep -q 'exit 2' "$PG" 2>/dev/null \
  && ok "policy->gate: fail-closed jq preamble (safety.md) (AUDIT-03)" \
  || no "orphan policy: fail-closed guard missing (AUDIT-03)"

if jq -e '.permissions.deny
          | index("Read(./**/.env*)") and index("Bash(rm -rf*)") and index("Bash(git push*--force*)")' \
     "$S" >/dev/null 2>&1; then
  ok "policy->gate: deny list (secret-read / rm-rf / force-push) (AUDIT-03)"
else
  no "orphan policy: deny list missing an entry (AUDIT-03)"
fi

if grep -q '<masked>' "$HOOKS_DIR/log-event.sh" 2>/dev/null \
   || grep -q '<masked>' "$HOOKS_DIR/lib-protected.sh" 2>/dev/null; then
  ok "policy->gate: PII masking in logs (security.md -> <masked>) (AUDIT-03)"
else
  no "orphan policy: PII masking missing (AUDIT-03)"
fi

jq -e '.hooks.Stop' "$S" >/dev/null 2>&1 \
  && ok "policy->gate: Stop verification gate registered (AUDIT-03)" \
  || no "orphan policy: Stop gate unregistered (AUDIT-03)"

# Sentinel handoff rejection (D-11): a [내용없음]/자동 수집 stub is "not implemented".
# Absent HANDOFF.md is NOT a failure (nothing to reject).
H="$AUDIT_ROOT/specs/HANDOFF.md"
if [ -f "$H" ] && grep -Eq '내용없음|자동 수집' "$H" 2>/dev/null; then
  no "sentinel handoff not implemented ([내용없음]) (AUDIT-03)"
else
  ok "handoff free of [내용없음] sentinel (AUDIT-03)"
fi

# ── AUDIT-04 ────────────────────────────────────────────────────────────────
# Cross-agent + offline readiness (README Dev-1/3/6). Entry files for non-Claude
# agents must reach AGENTS.md; the git-level gate must exist; vendored binaries,
# when shipped, must match their recorded checksums (tamper/corruption detection).
[ -f "$AUDIT_ROOT/AGENTS.md" ] \
  && ok "AGENTS.md present (AUDIT-04)" \
  || no "AGENTS.md missing (AUDIT-04)"

for ef in .cursorrules codex.md; do
  if [ -f "$AUDIT_ROOT/$ef" ] && grep -q 'AGENTS.md' "$AUDIT_ROOT/$ef" 2>/dev/null; then
    ok "$ef points at AGENTS.md (AUDIT-04)"
  else
    no "$ef missing or lacks AGENTS.md pointer (AUDIT-04)"
  fi
done

PC="$AUDIT_ROOT/.githooks/pre-commit"
if [ -f "$PC" ] && [ -x "$PC" ] && grep -q 'PROTECTED_RE' "$PC" 2>/dev/null; then
  ok "agent-agnostic pre-commit gate present +x (AUDIT-04)"
else
  no "pre-commit gate missing/not +x/no PROTECTED_RE (AUDIT-04)"
fi

# hooksPath is per-clone install state — only checkable inside a git repo.
if [ -d "$AUDIT_ROOT/.git" ] && command -v git >/dev/null 2>&1; then
  hp=$(git -C "$AUDIT_ROOT" config core.hooksPath 2>/dev/null)
  [ "$hp" = ".githooks" ] \
    && ok "core.hooksPath=.githooks (AUDIT-04)" \
    || no "core.hooksPath unset — run install.sh (AUDIT-04)"
fi

# Vendored offline binaries: verify only when shipped (absence is a valid,
# online-only deployment; install.sh hard-fails offline without them).
if [ -f "$AUDIT_ROOT/vendor/bin/SHA256SUMS" ]; then
  if ( cd "$AUDIT_ROOT/vendor/bin" && sha256sum -c SHA256SUMS ) >/dev/null 2>&1; then
    ok "vendor binaries match SHA256SUMS (AUDIT-04)"
  else
    no "vendor binary checksum MISMATCH (AUDIT-04)"
  fi
fi

# ── AUDIT-05 ────────────────────────────────────────────────────────────────
# Rules hygiene (README Dev-5): empty rule files and duplicate copies load into
# every session as dead/conflicting context.
rules_bad=0
while IFS= read -r f; do
  if [ ! -s "$f" ]; then
    no "empty rule file: $(basename "$f") (AUDIT-05)"; rules_bad=1
  fi
  case "$(basename "$f")" in
    *" copy"*) no "' copy' duplicate filename: $(basename "$f") (AUDIT-05)"; rules_bad=1 ;;
  esac
done < <(find "$AUDIT_ROOT/.claude/rules" -name '*.md' -type f 2>/dev/null)
[ "$rules_bad" -eq 0 ] && ok "rules hygiene: no empty / ' copy' files (AUDIT-05)"

dups=$(find "$AUDIT_ROOT/.claude/rules" -name '*.md' -type f -exec md5sum {} + 2>/dev/null \
         | sort | awk '{print $1}' | uniq -d)
[ -z "$dups" ] \
  && ok "rules hygiene: no byte-identical duplicates (AUDIT-05)" \
  || no "byte-identical duplicate rule files (AUDIT-05)"

# ── AUDIT-06 ────────────────────────────────────────────────────────────────
# Skills wiring (README Dev-7): every skill needs discoverable frontmatter; a
# repo skill shadowing a global (~/.claude/skills) name makes triggers ambiguous.
sk_bad=0
for sk in "$AUDIT_ROOT/.claude/skills"/*/; do
  [ -e "$sk" ] || continue
  if [ ! -f "$sk/SKILL.md" ] || ! grep -q '^name:' "$sk/SKILL.md" 2>/dev/null \
     || ! grep -q '^description:' "$sk/SKILL.md" 2>/dev/null; then
    no "skill frontmatter missing: $(basename "$sk") (AUDIT-06)"; sk_bad=1
  fi
done
[ "$sk_bad" -eq 0 ] && ok "skills frontmatter valid (AUDIT-06)"

if [ -d "$HOME/.claude/skills" ]; then
  coll=$(comm -12 <(ls "$AUDIT_ROOT/.claude/skills" 2>/dev/null | sort) \
                  <(ls "$HOME/.claude/skills" 2>/dev/null | sort))
  [ -z "$coll" ] \
    && ok "no repo<->global skill name collision (AUDIT-06)" \
    || no "skill name collision with ~/.claude/skills: $(printf '%s' "$coll" | tr '\n' ' ') (AUDIT-06)"
fi

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
