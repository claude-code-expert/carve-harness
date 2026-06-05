# REQUIREMENTS.md — carve-harness v2.0

> Active milestone: **v2.0** (M8 lifecycle, M9 analysis intelligence, M10 telemetry).
> Source SPECs: `requirement.md`, `docs/milestones/MS7-v2-roadmap.md`. Guardrails: ARCHITECTURE.md (LOCKED).
> v2.0 requirements are decomposed from REQ-m8/m9/m10 into granular REQ-IDs for plan-phase traceability.

## Categories (v2.0 active)

- **LIFE** — Lifecycle: manifest v2, diff, update, migrate (M8). 6 requirements.
- **INTEL** — Analysis/recommendation intelligence: signals, weighted scoring, preferences (M9). 4 requirements.
- **TELEM** — Local opt-in telemetry: metrics helper, emit, report (M10). 4 requirements.

**Total active v2.0 requirements: 14**

---

## LIFE — Lifecycle Foundation (Phase 1 / M8)

Source: REQ-m8-lifecycle (MS7-v2-roadmap.md), constraints C6, C7.

### LIFE-01 — Asset content-hash + manifest schema v2
- description: Each generated asset gets a content hash (`node:crypto`) computed at generation time. Manifest gains `schemaVersion` and `files: [{path, hash, assetVersion}]` (expanded from `string[]`).
- acceptance: Manifest written for a fresh install validates as schema v2; every installed file has a recorded `path`, `hash`, and `assetVersion`; `JSON.parse` round-trips.
- files: `src/generator.ts`, `src/manifest.ts`, `src/installer.ts`
- traces: C6

### LIFE-02 — `carve diff` 3-way classification
- description: `carve diff [dir]` compares on-disk assets against the manifest and the current carve asset set, classifying each as **unchanged / carve-updated / user-modified / new-recommended**.
- acceptance: Given a manifest and a target `.claude/`, the command prints each asset with exactly one of the four classifications; user-edited asset surfaces as `user-modified`; a newer carve asset surfaces as `carve-updated`.
- files: `src/commands.ts`, `src/cli.ts`, `src/manifest.ts`
- traces: C6

### LIFE-03 — `carve update` preserves user edits
- description: `carve update [dir]` refreshes only carve-unmodified assets in place; user-modified assets are shown as a diff for confirmation with `.bak` preserved once; new-recommended assets are proposed only (never forced).
- acceptance: After a user edits an installed asset, `carve update` leaves that edit intact (or `.bak`-backs-up once on confirmed overwrite); carve-unmodified assets are refreshed to the new version; no new asset is installed without explicit acceptance.
- files: `src/installer.ts`, `src/commands.ts`, `src/cli.ts`
- traces: C6, D3, D6

### LIFE-04 — `carve migrate` v1→v2 (lossless)
- description: `carve migrate [dir]` lifts a v1 manifest (`files: string[]`) to v2 schema losslessly, back-filling hashes where derivable.
- acceptance: A v1 manifest migrates to v2 with no file entries dropped; a unit test asserts v1→v2 equivalence; re-running migrate on a v2 manifest is a no-op (idempotent).
- files: `src/manifest.ts`, `src/commands.ts`, `src/cli.ts`
- traces: C6

### LIFE-05 — Atomicity via pre-write audit + manifest-last
- description: Lifecycle writes are made atomic by auditing before any write and writing the manifest **last** (NOT a temp-dir swap, because `.claude/` is partially user-owned). On audit failure the existing install is unchanged.
- acceptance: An induced audit failure during `update` leaves the prior install and manifest unchanged; on success the manifest reflects exactly the assets written.
- files: `src/installer.ts`
- traces: C5, C7, D8

### LIFE-06 — Lifecycle roundtrip verified
- description: The full lifecycle roundtrip is exercised end-to-end with user-modified assets preserved.
- acceptance: e2e test `test/e2e/lifecycle.e2e.test.ts` runs install → diff → update → migrate → uninstall with a user-modified asset, and the user edit survives; `test/unit/manifest.test.ts` covers schema v2 + v1→v2 migrate + atomic rollback.
- files: `test/unit/manifest.test.ts`, `test/e2e/lifecycle.e2e.test.ts`
- traces: C10

---

## INTEL — Analysis/Recommendation Intelligence (Phase 2 / M9)

Source: REQ-m9-analysis-intelligence (MS7-v2-roadmap.md), constraint C8.

### INTEL-01 — Monorepo signal detection
- description: analyzer detects monorepo signals (`pnpm-workspace.yaml`, `turbo.json`, `nx.json`, `lerna.json`, Cargo `[workspace]`) into `ProjectProfile.workspaces[]`.
- acceptance: Given a monorepo fixture, `ProjectProfile.workspaces[]` is populated with the detected workspace tool(s); a non-monorepo fixture yields an empty array.
- files: `src/analyzer.ts`, `src/types.ts`
- traces: C8

### INTEL-02 — Container/build signal detection
- description: analyzer detects container/build signals (`Dockerfile`, `docker-compose`, `Makefile`) into `ProjectProfile`.
- acceptance: A fixture with a Dockerfile/compose/Makefile sets the corresponding `ProjectProfile.container` / build signal; absent fixtures leave them unset.
- files: `src/analyzer.ts`, `src/types.ts`
- traces: C8

### INTEL-03 — Signal-weighted designer scoring
- description: designer replaces the static `catalog.score` + simple level heuristic with dynamic signal-weighted scoring (e.g. CI+multilang → fuller harness; monorepo → parallel-agents/coordinator weighted up). catalog gains weight-meta fields (extension slot only).
- acceptance: For a monorepo+CI fixture the designer recommends a measurably different (higher-coordination) slot set than for a single-package fixture; scoring is a testable pure function.
- files: `src/designer.ts`, `src/catalog.ts`
- traces: C8

### INTEL-04 — User preference persistence
- description: wizard persists user selections/deselections to `.claude/.carve-prefs.json`; preferences are reflected on re-run/update.
- acceptance: After a user deselects a component, the choice is written to `.claude/.carve-prefs.json`; a re-run reflects the persisted preference (round-trip test passes).
- files: `src/wizard.ts`, `src/types.ts`
- traces: C8, D5

---

## TELEM — Local Opt-in Telemetry (Phase 3 / M10)

Source: REQ-m10-telemetry (MS7-v2-roadmap.md), constraints C2, C9.

### TELEM-01 — Metrics emit helper (`_metrics.sh`)
- description: `assets/hooks/_metrics.sh` provides a shared emit helper; opt-in via `CARVE_METRICS=on` (default OFF); appends one line to `.claude/.carve-metrics.jsonl`.
- acceptance: With `CARVE_METRICS=on`, the helper appends a JSONL line; with metrics off (default), it is a no-op; the helper passes `bash -n` and the auditor.
- files: `assets/hooks/_metrics.sh`, `src/generator.ts`
- traces: C9, D8

### TELEM-02 — Existing hooks emit (blocking unchanged)
- description: Existing hooks each emit one metrics line via the helper. Deterministic blocking logic (exit-2) is unchanged — emit is a side-effect only.
- acceptance: Each instrumented hook still blocks/passes exactly as before; an emit line is produced only when metrics are on; exit-2 behavior is byte-for-byte preserved.
- files: `assets/hooks/*.sh`, `src/generator.ts`
- traces: C9, D7

### TELEM-03 — Record redaction
- description: Each recorded line contains ONLY `{ts, hook, event}`. No command body, path, or secret. No network transmission.
- acceptance: A redaction test asserts emitted lines contain only the three allowed fields and never a command/path/secret; no network call is made anywhere.
- files: `assets/hooks/_metrics.sh`
- traces: C2, C9

### TELEM-04 — `carve report` aggregation
- description: `carve report [dir]` aggregates `.claude/.carve-metrics.jsonl` into block counts, per-hook fire frequency, and 0-fire hooks.
- acceptance: Given a sample jsonl, `carve report` prints per-hook fire counts and lists hooks that never fired; with no metrics file it degrades gracefully (no crash).
- files: `src/commands.ts`, `src/cli.ts`
- traces: C9

---

## Baseline (v1.x — COMPLETE, not in active scope)

> Shipped in MS0–MS6 at 1.1.1. Listed for context; not mapped to v2.0 phases.

- REQ-install-flow, REQ-core-components, REQ-squad, REQ-extra-components, REQ-doc-generation,
  REQ-lifecycle-v1 (install/uninstall/list/doctor), REQ-distribution, REQ-quality-gates.

## Future Backlog (v2.0-future — NOT active phases)

> Captured but outside the active M8–M10 focus. Sequencing: M8 → (M9 ∥ M10) → **M11 → M12**.

- **REQ-m11-bench (M11 — comparison/proof bench)**: live cross-harness comparison + large-codebase token-efficiency re-measurement via `bench/run.mjs`; honest labeling, reproducible.
- **REQ-m12-feedback-loop (M12 — closed feedback loop)**: designer reads `.carve-metrics.jsonl` into recommendation weighting; 0-fire hooks proposed for demotion; suggestions only; identical behavior when metrics absent.

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| LIFE-01 | Phase 1 | Pending |
| LIFE-02 | Phase 1 | Pending |
| LIFE-03 | Phase 1 | Pending |
| LIFE-04 | Phase 1 | Pending |
| LIFE-05 | Phase 1 | Pending |
| LIFE-06 | Phase 1 | Pending |
| INTEL-01 | Phase 2 | Pending |
| INTEL-02 | Phase 2 | Pending |
| INTEL-03 | Phase 2 | Pending |
| INTEL-04 | Phase 2 | Pending |
| TELEM-01 | Phase 3 | Pending |
| TELEM-02 | Phase 3 | Pending |
| TELEM-03 | Phase 3 | Pending |
| TELEM-04 | Phase 3 | Pending |

**Coverage: 14/14 active v2.0 requirements mapped. No orphans.**

| Future Requirement | Milestone | Status |
|--------------------|-----------|--------|
| REQ-m11-bench | M11 (future) | Backlog |
| REQ-m12-feedback-loop | M12 (future) | Backlog |
