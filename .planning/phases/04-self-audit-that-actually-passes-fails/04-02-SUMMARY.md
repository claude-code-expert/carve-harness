---
phase: 04-self-audit-that-actually-passes-fails
plan: 02
status: complete
requirements: [AUDIT-03]
---

# Plan 04-02 Summary — AUDIT-03 (policy→gate map + sentinel rejection)

## What was built
Extended `harness-audit.sh` with AUDIT-03: a safety-critical policy→gate mapping (protected-path block, fail-closed jq preamble, deny list, PII masking, Stop gate) and a `[내용없음]`/`자동 수집` sentinel-handoff rejection. An orphaned safety policy or a stub handoff now turns the audit red; an absent handoff does not.

## Self-Check: PASSED
- Live baseline: `CLAUDE_PROJECT_DIR="$PWD" bash harness-audit.sh` → **27 PASS, exit 0** (AUDIT-01/02/03 all green, SC4 preserved).
- `harness-audit.test.sh` → **10 passed, 0 failed** (adds removed-deny, stripped-PROTECTED_RE, sentinel-handoff → non-zero; absent-handoff → exit 0).
- Full hook suite (7 files) → **0 suites failed**; `bash -n` clean; live settings.json + pretool-guard.sh unchanged.

## Requirements
- **AUDIT-03 (SC3):** removing a `permissions.deny` safety entry, stripping `PROTECTED_RE`, or seeding a `[내용없음]` handoff each make the audit exit non-zero.

## Key correctness proofs
- **D-09/D-12 (scope):** only safety-critical policies (safety.md + security.md) map to gates; no `rules/code-convention` enumeration — no fake mappings.
- **D-11 (sentinel):** `specs/HANDOFF.md` with a sentinel FAILs; absent HANDOFF.md passes (proven both ways).
- **SC4 preserved:** the live harness (with Phase-3's real handoff) passes AUDIT-03 → exit 0.
- **Isolation:** all negatives mutate a `cp -r` temp copy; `git diff --quiet .claude/settings.json .claude/hooks/pretool-guard.sh` clean after tests.
- **Deny-list jq check:** `.permissions.deny | index(a) and index(b) and index(c)` — a missing entry yields null → `jq -e` non-zero → FAIL.

## key-files
### modified
- `.claude/hooks/harness-audit.sh` — appended AUDIT-03 block (6 policy→gate checks + sentinel) before the tally; AUDIT-01/02 untouched.
- `.claude/hooks/tests/harness-audit.test.sh` — added 3 AUDIT-03 negatives + absent-handoff positive; isolation widened to pretool-guard.sh.

## Deviations
- protected-path + fail-closed checks appear under both AUDIT-02 (coverage framing) and AUDIT-03 (policy→gate framing) — intentional, cheap, and keeps the AUDIT-03 policy list complete.
- Executed inline (GSD subagent spawns unreliable this session).

## Commits
- (this plan) feat(04-02): AUDIT-03 policy→gate map + sentinel handoff rejection
