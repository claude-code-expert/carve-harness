# ROADMAP.md — carve-harness v2.0

> Active milestone: **v2.0**. Phases derived from MS7-v2-roadmap.md and the active prompt.
> Sequencing: M8 (foundation) → M9 → M10. M11/M12 are FUTURE backlog (not active phases).
> All phases are bound by the LOCKED ADR decisions and CLAUDE.md guardrails in PROJECT.md `<decisions>`.

## Milestone

**v2.0 — from one-shot installer to lifecycle tool.** carve can safely UPDATE an installed harness preserving user edits, recommend with real-world signal weighting, and record (locally, opt-in) what hooks actually did.

## Phases

- [ ] **Phase 1: M8 — Lifecycle Foundation** - Asset content-hash + manifest v2; `diff`/`update`/`migrate` with user edits preserved.
- [ ] **Phase 2: M9 — Analysis & Recommendation Intelligence** - Monorepo/Docker signal detection, weighted scoring, preference persistence.
- [ ] **Phase 3: M10 — Local Effect Telemetry (opt-in)** - `_metrics.sh` emit, redacted recording, `carve report` aggregation.

## Phase Details

### Phase 1: M8 — Lifecycle Foundation
**Goal**: A user can update an installed harness to a new carve version and keep their own edits — the install → diff → update → migrate → uninstall roundtrip never produces an inconsistent state.
**Depends on**: Nothing (foundation for v2.0; builds on shipped v1.x pipeline)
**Requirements**: LIFE-01, LIFE-02, LIFE-03, LIFE-04, LIFE-05, LIFE-06
**Success Criteria** (what must be TRUE):
  1. A fresh install writes a schema-v2 manifest where every installed file records `{path, hash, assetVersion}` and `schemaVersion` is present.
  2. `carve diff` classifies every on-disk asset as exactly one of unchanged / carve-updated / user-modified / new-recommended.
  3. `carve update` refreshes carve-unmodified assets in place, preserves user-modified assets (`.bak` once on confirmed overwrite), and only proposes new-recommended assets (never forces them).
  4. `carve migrate` lifts a v1 manifest to v2 losslessly and is a no-op when re-run on a v2 manifest.
  5. An induced audit failure during a lifecycle write leaves the prior install and manifest unchanged (atomicity via pre-write audit + manifest-last).
**Plans**: TBD

### Phase 2: M9 — Analysis & Recommendation Intelligence
**Goal**: carve's recommendations reflect real-world project shape — monorepo and container signals raise recommendation accuracy, and the user's own selections stick across runs.
**Depends on**: Phase 1 (manifest v2 / preference field foundation)
**Requirements**: INTEL-01, INTEL-02, INTEL-03, INTEL-04
**Success Criteria** (what must be TRUE):
  1. On a monorepo fixture (pnpm/turbo/nx/lerna/cargo workspace), `ProjectProfile.workspaces[]` is populated; a single-package fixture yields an empty array.
  2. On a fixture with Dockerfile / docker-compose / Makefile, the corresponding container/build signals appear in `ProjectProfile`.
  3. The designer recommends a measurably different (higher-coordination) slot set for a monorepo+CI project than for a single-package project, via a testable signal-weighted scoring function.
  4. A user's deselection persists to `.claude/.carve-prefs.json` and is reflected on the next run/update.
**Plans**: TBD

### Phase 3: M10 — Local Effect Telemetry (opt-in)
**Goal**: A user can see what their installed hooks actually did — locally, opt-in, with no command/path/secret ever recorded and no network traffic — and aggregate it with `carve report`.
**Depends on**: Phase 1 (installed-asset lifecycle); independent of Phase 2
**Requirements**: TELEM-01, TELEM-02, TELEM-03, TELEM-04
**Success Criteria** (what must be TRUE):
  1. With `CARVE_METRICS=on`, each instrumented hook appends one line to `.claude/.carve-metrics.jsonl`; with metrics off (default), emission is a no-op.
  2. Deterministic exit-2 blocking behavior of every instrumented hook is byte-for-byte unchanged — emit is a pure side-effect.
  3. Every recorded line contains only `{ts, hook, event}` — never a command body, path, or secret — and no network call is made.
  4. `carve report` aggregates the jsonl into per-hook fire counts, block counts, and a list of 0-fire hooks, and degrades gracefully when no metrics file exists.
**Plans**: TBD

## Future Milestones (backlog — NOT active phases)

> Sequencing after M10: M11 → M12. Listed for context; do not plan until promoted.

- **M11 — Comparison/proof bench**: live cross-harness comparison + large-codebase token-efficiency re-measurement via `bench/run.mjs`; honest labeling, reproducible (same seed → same metrics). Repo-internal, outside runtime. (REQ-m11-bench)
- **M12 — Closed feedback loop**: designer reads `.carve-metrics.jsonl` into recommendation weighting; 0-fire hooks proposed for demotion, frequently-blocked areas weighted up; suggestions only; identical behavior when metrics absent. (REQ-m12-feedback-loop)

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. M8 — Lifecycle Foundation | 0/0 | Not started | - |
| 2. M9 — Analysis & Recommendation Intelligence | 0/0 | Not started | - |
| 3. M10 — Local Effect Telemetry | 0/0 | Not started | - |

## Coverage

- 14/14 active v2.0 requirements mapped to exactly one phase. No orphans, no duplicates.
- v1.x baseline requirements are COMPLETE (not mapped).
- M11/M12 are FUTURE backlog (not active phases).
