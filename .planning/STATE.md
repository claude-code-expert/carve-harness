# STATE.md — carve-harness

> Project memory. Single source of truth for "where are we right now."
> Updated by planning/execution workflows. Read this first on session resume.

## Project Reference

- **Project**: carve-harness
- **Core value**: A deterministic CLI that carves (constrains) a general Claude Code harness to fit any target project and installs it into the target's `.claude/`.
- **Active milestone**: v2.0 — lifecycle tool (M8 lifecycle, M9 analysis intelligence, M10 telemetry).
- **Current focus**: Phase 1 — M8 Lifecycle Foundation.
- **Version**: 1.1.1 (v1.x MS0–MS6 complete; 118 tests, ~95% coverage).

## Current Position

- **Phase**: 1 — M8 Lifecycle Foundation
- **Plan**: None yet (roadmap just created; awaiting `/gsd:plan-phase 1`)
- **Status**: Roadmap created — not started
- **Progress**: `[          ] 0/3 phases`

## Performance Metrics

- **Phases complete**: 0/3
- **Active v2.0 requirements**: 0/14 delivered
- **Coverage gate**: ≥ 80 (currently ~95 — must not regress)
- **tsc**: clean (must stay clean)
- **Auditor**: passes on all generated assets (must stay green)

## Accumulated Context

### Key decisions (LOCKED — see PROJECT.md `<decisions>`)
- Two-layer model A (repo) / B (target `.claude/`) — never conflate.
- Writes restricted to `.claude/` + designated root guides + `carve-manifest.json`. Never touch target source.
- Single runtime dep `@clack/prompts`; new features use stdlib (`node:crypto`, …).
- Idempotency + `.bak` once + deterministic exit-2 blocking hooks must not weaken.
- Auditor-failed artifacts are never installed.
- No network transmission anywhere; telemetry 100% local, default OFF, records only `{ts, hook, event}`.
- **Atomicity = pre-write audit + manifest-last** (NOT temp-dir swap — `.claude/` is partially user-owned). This refines the MS7 "temp dir + swap" wording.

### Open todos
- Run `/gsd:plan-phase 1` to decompose M8 into executable plans.

### Blockers
- None.

## Session Continuity

- **Last action**: Roadmap, requirements, and project memory initialized from ingested intel (SYNTHESIS + 4 classified intel docs). 3 phases, 14 requirements, 100% coverage.
- **Next action**: `/gsd:plan-phase 1` (M8 — Lifecycle Foundation).
- **Files**:
  - `.planning/PROJECT.md` — core value, scope, LOCKED decisions.
  - `.planning/REQUIREMENTS.md` — 14 active reqs (LIFE/INTEL/TELEM) + traceability.
  - `.planning/ROADMAP.md` — 3 phases + future backlog (M11/M12).
  - `.planning/STATE.md` — this file.
