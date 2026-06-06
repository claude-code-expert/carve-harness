# PROJECT.md — carve-harness

> Project memory for planning. Core value, scope, and LOCKED architectural decisions.
> Higher-precedence sources: ARCHITECTURE.md (ADR, LOCKED) > requirement.md / MS7-v2-roadmap.md (SPEC) > docs (DOC).

## Core Value

`carve` is a TypeScript ESM CLI that analyzes an arbitrary codebase and **carves** (constrains) a general-purpose Claude Code harness — skills, hooks, commands, subagents — to fit that specific project, then installs it into the target's `.claude/`.

The name encodes the thesis: **carve = constrain a general asset to fit a project** = the "constraint" pillar of the 3-pillar harness model. Detection is deterministic (no LLM in the CLI); the user always selects what gets installed.

## Current Focus

**Active milestone: v2.0** — turn carve from a one-shot installer into a **lifecycle tool**.

v1.x (MS0–MS6) is COMPLETE: the analyze → design → generate → audit → install pipeline ships at 1.1.1 with 118 tests and ~95% coverage. v2.0 adds three capabilities:

1. **M8 — Lifecycle foundation**: safely UPDATE an installed harness across carve versions, preserving user edits (install → diff → update → migrate → report → uninstall roundtrip).
2. **M9 — Analysis/recommendation intelligence**: detect monorepo/Docker signals; replace static scoring with profile-signal weighted scoring; persist user preferences.
3. **M10 — Local effect telemetry (opt-in)**: record what hooks actually did, 100% local, default OFF.

## Developer-Facing Success Metric (v2.0)

1. `carve update` preserves user-modified assets: the **install → diff → update → migrate → report → uninstall** roundtrip passes with user-edited assets intact.
2. analyzer detects monorepo/Docker signals and designer produces **weighted** recommendations.
3. opt-in local telemetry records hook effects, **100% local, no network**.

**Quality gate:** coverage stays ≥ 80 (currently ~95), `tsc --noEmit` clean, auditor passes on all generated assets.

## Scope

### In Scope (v2.0 active)
- Manifest schema v2 (asset content-hash, `files: [{path, hash, assetVersion}]`, `schemaVersion`).
- New commands: `carve diff`, `carve update`, `carve migrate`, `carve report`.
- analyzer monorepo/container signals → `ProjectProfile`.
- designer signal-weighted scoring; wizard preference persistence (`.claude/.carve-prefs.json`).
- opt-in telemetry: `assets/hooks/_metrics.sh`, hook emit lines, `.carve-metrics.jsonl`.

### Out of Scope (deferred / future)
- **M11 (comparison/proof bench)** and **M12 (closed feedback loop)** — captured as FUTURE backlog, not active phases.
- plugin/custom catalog; extra stacks (C++, Kotlin, Swift, C#, PHP, Ruby); extra Squad agents (devops, perf, a11y).
- v1.x baseline (install/uninstall/list/doctor, six core skills, Squad 8, doc generation) — already shipped.

> M9 catalog weight-meta and M8 asset-version structure are designed as **future extension foundations** — open the slot only, no over-design (constraint C11).

## Decisions (LOCKED)

> From ARCHITECTURE.md (ADR, precedence 0) and CLAUDE.md flight-rules. These cannot be overridden by downstream planning. Every phase plan must respect them.

<decisions>

### D1 — Two-layer model (A/B), never conflated
Layer A = the carve-harness repo itself (`bin/`, `src/`, `assets/`). Layer B = artifacts carve installs into a target (`<user-project>/.claude/`). Every change must be explicit about which layer it touches.

### D2 — Fixed analyze→install pipeline
`carve install` runs a fixed pipeline: analyzer → catalog → wizard → designer → generator → auditor → installer. v2.0 commands (`diff`/`update`/`migrate`/`report`) extend this without breaking the order.

### D3 — No batch install; user selection gate mandatory
After analyze→design there is a required selection gate before generate. No bulk-install mode. New-recommended assets in `update` are **proposed only, never forced**.

### D4 — TypeScript ESM, zero-build runtime
Node ≥22.18 type-stripping runs `.ts` directly; relative imports use explicit extensions. **Single runtime dependency: `@clack/prompts`.** New features use the standard library (`node:crypto`, `node:fs`, …). No new runtime deps.

### D5 — Writes restricted to .claude/ + root guides + manifest
Installation outputs are confined to `<user-project>/.claude/` plus designated root guides (CLAUDE.md, HARNESS-GUIDE.md) plus `carve-manifest.json`. **Target source code is never modified.** Telemetry writes only `.claude/.carve-metrics.jsonl`; preferences only `.claude/.carve-prefs.json`.

### D6 — Idempotent installation with .bak preservation
Re-running never overwrites user-modified assets; conflicts are shown as a diff for confirmation; originals preserved as `.bak` **once**. settings.json merged safely. `update` honors this exactly.

### D7 — Deterministic blocking hooks via exit code 2
PreToolUse deterministic blocking via exit code 2 is the only deterministic block mechanism and **must not be weakened**. Telemetry emit is a side-effect only — blocking logic is unchanged.

### D8 — Auditor must pass before install
Generated artifacts are self-verified (secret exposure, excess permissions, hook injection, shell syntax). **Artifacts that fail the auditor are not installed.** New hooks/commands (`_metrics.sh`) and `update` writes are auditor-gated.

### D9 — Squad 8 subagents preserved 100%
Squad subagents (8) + router/chaining hooks are preserved on install (melt-in, vendor-independent under `assets/squad/`).

### C2 — No network transmission
No network anywhere. Telemetry is 100% local. Secrets are never recorded.

### C7 — Atomicity (manifest-last, NOT temp-dir swap)
`.claude/` is partially owned by the user, so atomicity is achieved by **pre-write audit + manifest-written-last**, not a temp-dir swap. On audit failure the existing install is unchanged.

> Note: MS7-v2-roadmap.md originally framed atomicity as "temp dir + swap". The active prompt refines this to manifest-last because `.claude/` is partially user-owned. The refinement governs; the intent (no inconsistent state on partial failure) is identical.

### C9 — Telemetry redaction
Each `.carve-metrics.jsonl` line records ONLY `{ts, hook, event}`. NO command body, path, or secret. Opt-in (install consent or `CARVE_METRICS=on`), default OFF.

</decisions>

## Constraints (verification gates)

- **C10**: coverage ≥ 80 held (currently ~95, no regression). Pre-commit: `npm run check` (tsc) · `npm test` · `bash -n` (new hooks) · `JSON.parse` (manifest v2). Each milestone closes with an e2e roundtrip.
- **C3**: runtime dep stays `@clack/prompts` only.
- **C5**: auditor-failed artifacts are never installed.

## Tech Stack

TypeScript (ESM), Node ≥22.18, buildless dev (type-stripping; prepack compiles `.ts`→`.js` for npm). Distributed via npm. Tests: `node --test` + built-in coverage. Single runtime dep `@clack/prompts`.
