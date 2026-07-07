---
phase: 02-observability-keystone-jsonl-event-log
verified: 2026-07-07T00:00:00Z
status: passed
score: 3/3 plans, all must-haves verified
overrides_applied: 0
---

# Phase 2: Observability Keystone (JSONL Event Log) — Verification Report

**Phase Goal:** Every hook decision is recorded as one structured JSON line in `logs/`, so an operator can audit what each of the 5 hook entry points blocked/allowed/formatted — without that record ever weakening the fail-closed guards.

**Verified:** 2026-07-07
**Status:** passed
**Re-verification:** No — initial verification

**Method:** Independent execution, not SUMMARY-trust. All 6 hook test harnesses were run directly. Beyond the harnesses, a live end-to-end smoke fired all 5 entry points into one temp `CLAUDE_PROJECT_DIR` with fresh payloads (not harness fixtures) and asserted the resulting daily JSONL with `jq -e .` — confirming each fire leaves exactly one valid line, protected paths mask, empty keys omit, and `logs/` is git-ignored.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Each of the 5 hook entry points appends exactly one valid JSON line per fire (SC1, D-03) | VERIFIED | Live smoke: 5 fires → 5 lines, `jq -e . logs/<day>.jsonl` = ALL LINES PARSE. Distinct events: PreToolUse, PostToolUse, Stop, SessionStart (PreCompact:save covered in `session-handoff.test.sh`). |
| 2 | A log failure NEVER changes a guard's exit code (D-05, load-bearing) | VERIFIED | `logs` a regular FILE (mkdir fails): protected-write → guard exit 2, benign → exit 0; `env -i PATH=` (jq absent) → exit 2. stop-verify loop-yield and session-handoff start/save stay exit 0 under unwritable logs. |
| 3 | Injection-safe: hostile target (quote + newline + `{"fake":...}`) → one line, parses | VERIFIED | `log-event.test.sh` case 3: line-count delta == 1 and `tail -1 \| jq .` parses. Construction is `jq -cn --arg` only (no string interpolation). |
| 4 | Protected paths masked; raw Bash commands not logged (T-02-03/T-02-04) | VERIFIED | Live smoke: `x/.env.production` block → `.target` == `<masked>`. Bash allow line carries no `target` key (empty omitted); raw command never logged. |
| 5 | posttool-format records missing/error/ok/skip; stays exit 0 (SC2, C8) | VERIFIED | `posttool-format.test.sh`: gradlew-less CWD → `format-fail`/`reason:missing`; stub gradlew exit 1 → `error`; exit 0 → `ok`; unknown ext → `skip`; every case exit 0, delta==1. |
| 6 | No new runtime dependency; `bash -n` clean (SC3) | VERIFIED | `bash -n` clean on all 6 hooks. Bash + jq (1.8.1) + coreutils only; timestamp via `date -u +%Y-%m-%dT%H:%M:%SZ` (portable). |
| 7 | Phase 1 fail-closed behavior unregressed | VERIFIED | `pretool-guard.test.sh` 15/15, `stop-verify.test.sh` 6/6 (pipefail + loop-guard + jq-absent intact), `settings.test.sh` 6/6. |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `.claude/hooks/log-event.sh` | VERIFIED | Best-effort subprocess helper: `jq -cn`, `date -u +%Y-%m-%dT%H:%M:%SZ`, single-source masking, no `set -e`, last statement literal `exit 0`. |
| `.claude/hooks/lib-protected.sh` | VERIFIED | Single-source `PROTECTED_RE` (D-04); sourced by guard + helper; no inline redefinition remains in the guard. |
| `.gitignore` | VERIFIED | Contains `logs/` (only); `git check-ignore logs/` → ignored. `.env*` correctly NOT added (Phase 5 scope). |
| `.claude/hooks/pretool-guard.sh` | VERIFIED | Sources lib-protected; log call before each of 4 exit points; fail-closed preamble byte-for-byte preserved. |
| `.claude/hooks/posttool-format.sh` | VERIFIED | if/elif/else per arm + `format-skip` catch-all; formatter stdout still `2>/dev/null`; ends on literal `exit 0`, no `exit 2` statement. |
| `.claude/hooks/stop-verify.sh` | VERIFIED | Log calls at loop-yield/pass/fail before existing exits; pipefail/loop-guard/jq-absent/stack-detect unchanged; no log in jq-absent branch. |
| `.claude/hooks/session-handoff.sh` | VERIFIED | Log calls in start/save arms; HANDOFF.md write + `[자동 수집 — 내용없음]` placeholder preserved (Phase 3 scope). |
| Test harnesses (4 new + 1 extended) | VERIFIED | Full suite: 51 assertions, 0 failed across 6 files. |

## Deviations & Notes
- Executed inline (GSD subagent spawns unreliable this session), RED→GREEN, atomic commits per task.
- PreCompact:save event not exercised in the aggregate live smoke (only SessionStart:start fired there); it is proven independently in `session-handoff.test.sh`.
- Accepted ceilings carried forward (documented, not defects): concurrent-append `flock` (T-02-05), jq-absent leaves no line (T-02-06), secret-value scanning inside Bash commands (T-02-04) → GUARD-04/Phase 5.

**Verdict:** PASSED — Phase 2 goal achieved. The keystone JSONL trail is live across all 5 hook entry points and provably cannot weaken the fail-closed guards. Ready for OBS-02 consumers and Phase 4 `/harness-audit`.
