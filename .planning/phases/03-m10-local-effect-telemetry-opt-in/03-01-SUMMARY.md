---
phase: 03-m10-local-effect-telemetry-opt-in
plan: 01
subsystem: hooks
tags: [telemetry, hooks, opt-in, security]
requires: []
provides: [carve_metric, opt-in-telemetry, metrics-jsonl]
affects: [assets/hooks]
tech-stack:
  added: []
  patterns: [sourced-bash-helper, opt-in-gate, redaction-by-construction]
key-files:
  created:
    - assets/hooks/_metrics.sh
    - test/unit/metrics.test.ts
  modified:
    - assets/hooks/block-destructive.sh
    - assets/hooks/protect-secrets.sh
    - assets/hooks/pre-commit-lint.sh
    - assets/hooks/pre-push-test.sh
    - assets/hooks/auto-format.sh
    - assets/hooks/anti-slop.sh
decisions:
  - "Telemetry is opt-in (default OFF) gated by CARVE_METRICS=on OR .claude/.carve-metrics.enabled"
  - "Emit records only {ts,hook,event} — redaction by construction, never interpolates command/path/secret"
  - "carve_metric always returns 0 so it can never alter a hook's exit code (blocking logic byte-for-byte unchanged)"
  - "No network anywhere: append-only to .claude/.carve-metrics.jsonl"
metrics:
  duration: ~12m
  completed: 2026-06-05
---

# Phase 03 Plan 01: Local Effect Telemetry (opt-in) Summary

Opt-in local telemetry emit helper (`_metrics.sh`) sourced by six effect hooks; records only `{ts,hook,event}` to `.claude/.carve-metrics.jsonl` when enabled, default OFF, no network, blocking logic byte-for-byte unchanged.

## What Was Built

- **`assets/hooks/_metrics.sh`** (TELEM-01): single `carve_metric <hook> <event>` function. Opt-in gate first (`CARVE_METRICS=on` OR `.claude/.carve-metrics.enabled` exists), otherwise immediate `return 0`. When enabled: `ts=$(date +%s)` with `0` fallback, defensive `mkdir -p .claude`, appends exactly one JSON line via `printf` to `.claude/.carve-metrics.jsonl`, swallows all errors, always `return 0`. No `curl`/`wget`/`nc`. No template tokens (ships verbatim).
- **Six instrumented hooks** (TELEM-02): each gets one `source` line after `set -uo pipefail` (`|| true` keeps `set -u` happy) plus `carve_metric` calls placed BEFORE existing exits:
  - block-destructive.sh: inside `block()` before `exit 2` (covers all 3 block paths).
  - protect-secrets.sh: before its `exit 2`.
  - pre-commit-lint.sh / pre-push-test.sh: `block` before fail `exit 2`, `pass` before final `exit 0`.
  - auto-format.sh: `fire` before final `exit 0`.
  - anti-slop.sh: `warn` inside the slop-detected (`grep -q 'ERROR'`) branch.
- **`test/unit/metrics.test.ts`** (TELEM-03): opt-out no-op (exit 2 + no jsonl), opt-in emit (exit 2 + one redacted `{ts,hook,event}` line, asserts line excludes `rm -rf`), no-network scan across helper + 6 hooks, `bash -n` on all 7 files.

## Verification Results

- `git diff` confirms every `grep`/threshold/`exit` line byte-for-byte unchanged — only `source` + `carve_metric` lines added.
- `node --test test/unit/hooks.test.ts`: 21/21 pass UNCHANGED (default-OFF emit is a no-op).
- `node --test test/unit/metrics.test.ts`: 10/10 pass.
- `npm run check` (tsc --noEmit): clean.
- `npm test`: 183/183 pass.
- Manual `grep -rEn 'curl|wget'` across helper + 6 hooks: nothing found.

## Deviations from Plan

None — plan executed exactly as written. One in-test typing fix (captured `lines[0]` into a checked `const line` with `assert.ok(line)` instead of a non-null `!`) to satisfy strict `tsc` per CLAUDE.md (no non-null assertions); this is a test-only correctness adjustment, not a plan deviation.

## Threat Mitigations Applied

- T-03-01 (info disclosure): line records only `{ts,hook,event}`; test asserts redaction + exact key set.
- T-03-02 (info disclosure): no network calls; test asserts absence across all 7 files.
- T-03-03 (tampering): emit additive + always returns 0; hooks.test.ts exit-code assertions re-run green.
- T-03-04 (auditor): write target is the data file `.claude/.carve-metrics.jsonl`, not settings.json or a hook file — `hook-injection` rule does not trip.

## Self-Check: PASSED

- assets/hooks/_metrics.sh — FOUND
- test/unit/metrics.test.ts — FOUND
- 6 instrumented hooks — FOUND (git diff shows additive-only changes)
