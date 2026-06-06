# Requirements (PRD/SPEC Intel)

> No docs classified as PRD in this ingest set. Requirements below are extracted from the two
> SPEC-classified docs (`requirement.md`, `MS7-v2-roadmap.md`, both precedence 1). Requirement-style
> clauses are lifted as REQ-* entries; pure technical contracts live in `constraints.md`.
> Each entry carries `source:` for provenance.

---

## From requirement.md (carve-harness 요구사항) — baseline product requirements

source: /Users/codevillain/Claude-Code-Expert/carve-harness/carve-harness/requirement.md

### REQ-install-flow (R-INSTALL)
- description: Deterministic heuristics detect project type/language/tooling and recommend
  applicable components; interactive selection installs only user-chosen components.
- acceptance:
  - Detection is deterministic (no LLM calls in the CLI itself).
  - Interactive selection only; batch-install mode is NOT supported.
  - Install is idempotent; re-run never overwrites user-modified assets; conflicts shown as diff.
  - Install recorded in manifest for clean uninstall.
- scope: install pipeline

### REQ-core-components (R-CORE)
- description: Six core skills (Skill + thin command shim): handoff, memory, commit, changelog,
  review, pr. Seven required hooks + one optional hook.
- acceptance:
  - Required hooks: (1) destructive-command block PreToolUse, (2) secret-file protect PreToolUse,
    (3) pre-commit lint PreToolUse, (4) pre-push test PreToolUse, (5) auto-format PostToolUse,
    (6) Slack notify Stop/Notification, (7) PreCompact handoff PreCompact.
  - Optional hook: auto-commit, default OFF.
- scope: core skills + hooks

### REQ-squad (R-SQUAD)
- description: Squad 8 subagents (review, plan, refactor, qa, debug, docs, gitops, audit) +
  keyword router hook + chaining/notify hooks installed with 100% preservation.
- acceptance: All 8 agents + router + chaining/notify hooks installed unchanged.
- scope: subagents

### REQ-extra-components (R-EXTRA)
- description: Beyond required elements, include skills scoring >= 75 (utility/completeness) in the
  catalog, selected via score table.
- acceptance: Only components scoring >= 75 are added to the catalog.
- scope: catalog

### REQ-doc-generation (R-DOC)
- description: On install, generate a usage-guide MD and CLAUDE.md at the target project root,
  describing harness role/structure/usage.
- acceptance: Both files generated at target root.
- scope: generated docs

### REQ-lifecycle-v1 (R-LIFECYCLE)
- description: Provide `install` / `uninstall` / `list` / `doctor` commands; both install and
  uninstall must be easy and intuitive.
- acceptance: All four commands available and functional.
- scope: CLI lifecycle (v1)

### REQ-distribution (R-DIST)
- description: Provide both npx (`npx carve-harness`) and bash (`install.sh`) install paths.
- acceptance: Both distribution paths work.
- scope: distribution

### REQ-quality-gates
- description: Each harness component ships one working functional test; coverage/E2E >= 80;
  generated/modified code verified pre-commit; generated artifacts pass auditor.
- acceptance:
  - >= 1 functional test per component.
  - Coverage + E2E >= 80.
  - Pre-commit verification: tsc --noEmit / bash -n / JSON.parse.
  - auditor finds 0 (secret exposure / excess permission / hook injection).
- scope: quality

---

## From MS7-v2-roadmap.md (v2.0 milestones) — active milestone requirements

source: /Users/codevillain/Claude-Code-Expert/carve-harness/carve-harness/docs/milestones/MS7-v2-roadmap.md
status: planned (📋). Sequencing: M8 -> (M9 ∥ M10) -> M11 -> M12. M8 is the foundation.

### REQ-m8-lifecycle (M8 — lifecycle foundation)
- description: Asset versioning + `update`/`diff`/`migrate`; safely update an installed harness to
  a new carve version while preserving user edits; prevent inconsistent state on partial failure.
- acceptance:
  - Asset content hash (node:crypto) computed at generation; manifest records
    `files: [{path, hash, assetVersion}]` (expanded from current `string[]`).
  - `carve diff [dir]`: 3-way classification → unchanged / carve-updated / user-modified /
    new-recommended.
  - `carve update [dir]`: updates only user-unmodified assets in place; user-modified assets shown
    as diff for confirmation with `.bak` once; new recommended assets proposed only (never forced).
  - `carve migrate`: manifest schema v1→v2 migration, lossless.
  - Atomic install: write all to temp dir, audit, then swap (rollback on audit failure).
  - Verified by e2e roundtrip + v1→v2 migrate unit test + atomic rollback test.
- scope: manifest schema v2, lifecycle commands, atomic installer

### REQ-m9-analysis-intelligence (M9 — analysis/recommendation intelligence)
- description: Reflect real-world signals (monorepo, Docker) and replace static score with weighted
  scoring to raise recommendation accuracy.
- acceptance:
  - analyzer detects monorepo (pnpm workspaces, turborepo, nx, lerna, cargo workspaces) →
    `ProjectProfile.workspaces[]`; adds Dockerfile/docker-compose/Makefile signals.
  - designer replaces static `catalog.score` + simple level heuristic with dynamic
    signal-weighted scoring (e.g. CI+multilang → full; monorepo → parallel-agents/coordinator ↑).
  - User preference persisted (selections/deselections) in a local `.claude/` file or manifest
    field; reflected on re-run/update.
  - Verified by monorepo/Docker fixture detection tests + scoring tests + preference round-trip.
- scope: analyzer signals, designer weighted scoring, preference persistence

### REQ-m10-telemetry (M10 — local opt-in telemetry)
- description: Locally record what the harness actually did, as the data source for proof/feedback.
- acceptance:
  - Hook event emit via shared `assets/hooks/_metrics.sh`; appends to `.claude/.carve-metrics.jsonl`.
  - Opt-in (consent at install or `CARVE_METRICS=on`), default OFF.
  - Record only event type/timestamp/hook id; NO command body/path/secret (redaction). New hooks
    pass auditor.
  - `carve report [dir]`: aggregate jsonl → block counts, per-hook fire frequency, 0-fire hooks.
  - Verified by emit-format test, redaction test, opt-out no-op test, report aggregation test.
- scope: telemetry hooks, carve report

### REQ-m11-bench (M11 — comparison/proof bench) [v2.0 but outside M8-M10 focus]
- description: Complete deferred live cross-harness comparison (axes 1/4) and large-codebase
  token-efficiency re-measurement; keep honest labeling.
- acceptance: bench automation (no-harness vs carve vs others) via bench/run.mjs; large fixture;
  regenerate benchmark-results.md; no estimated numbers, reproducible (same seed → same metrics).
- scope: bench (repo-internal, outside runtime)

### REQ-m12-feedback-loop (M12 — closed-loop feedback) [v2.0 but outside M8-M10 focus]
- description: Feed M10 telemetry + M11 bench results back into designer recommendations.
- acceptance: designer reads `.carve-metrics.jsonl` (when present) into recommendation weighting;
  0-fire hooks proposed for demotion; frequently-blocked areas weighted up; suggestions only;
  100% identical to current behavior when metrics absent (backward compatible, deterministic).
- scope: designer feedback input
