---
phase: 04-self-audit-that-actually-passes-fails
plan: 01
status: complete
requirements: [AUDIT-01, AUDIT-02]
---

# Plan 04-01 Summary — Audit Core (AUDIT-01 + AUDIT-02)

## What was built
Replaced the one-line prose `/harness-audit` with `.claude/hooks/harness-audit.sh` — a mechanical PASS/FAIL that asserts AUDIT-01 (jq present, all 6 hook events registered, referenced hooks `+x`, `bash -n` clean) and AUDIT-02 (write-tool matcher coverage, Bash-write inspection present). Exits non-zero on any failure, 0 when clean. Command `.md` rewritten to invoke it.

## Self-Check: PASSED
- Live baseline: `CLAUDE_PROJECT_DIR="$PWD" bash harness-audit.sh` → **21 PASS, exit 0** (SC4).
- `harness-audit.test.sh` → **6 passed, 0 failed** (baseline + jq-absent + unregistered-hook + stripped-+x + matcher-drop + isolation).
- Full hook suite (7 files) → **0 suites failed**; `bash -n` clean; live settings.json unchanged.

## Requirements
- **AUDIT-01 (SC1):** jq-absent, unregistered `Stop`, and stripped-`+x` each make the audit exit non-zero.
- **AUDIT-02 (SC2):** dropping `NotebookEdit` from the matcher makes the audit exit non-zero.
- **SC4:** the fully-configured live harness passes with exit 0.

## Key correctness proofs
- **D-03 (testable root):** audit reads from `AUDIT_ROOT="${CLAUDE_PROJECT_DIR:-<script>/../..}"`; all negatives mutate a `cp -r` temp copy → `git diff --quiet .claude/settings.json` clean after tests.
- **Read-only:** the audit writes nothing; it only greps/jq-reads settings + hooks.
- **jq-absent handled first:** the jq check runs before any jq-dependent assertion and exits 1 — no cascade errors.
- **+x scope:** only settings-referenced hooks (4) are `+x`-checked; `bash -n` covers all 7 `hooks/*.sh` including the audit itself.

## key-files
### created
- `.claude/hooks/harness-audit.sh` — AUDIT-01/02 checks, AUDIT_ROOT-anchored, ok/no reporter + non-zero-on-fail.
- `.claude/hooks/tests/harness-audit.test.sh` — positive baseline + 4 negatives + isolation, all via temp copy.
### modified
- `.claude/commands/harness-audit.md` — rewritten from prose prompt to a thin `bash …/harness-audit.sh` invoker.

## Deviations
- Executed inline (GSD subagent spawns unreliable this session), RED→GREEN.
- jq-absent negative uses a bash-only symlink PATH dir (jq stripped) — the audit exits at the jq check using only builtins, so no other tool is needed.

## Commits
- (this plan) feat(04-01): mechanical harness-audit AUDIT-01/02 + command rewrite
