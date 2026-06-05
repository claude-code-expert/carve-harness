# Constraints (SPEC Intel)

> Technical contracts and non-functional requirements extracted from SPEC-classified docs
> (`requirement.md`, `MS7-v2-roadmap.md`). The invariant guardrails (C1-C8) are reasserted by the
> LOCKED ADR (ARCHITECTURE.md) and CLAUDE.md; the ADR is authoritative where they overlap.
> Each entry carries `source:`. Type ∈ {api-contract, schema, nfr, protocol}.

---

## Invariant guardrails (v2.0 — reasserted, ADR-locked)

source: /Users/codevillain/Claude-Code-Expert/carve-harness/carve-harness/docs/milestones/MS7-v2-roadmap.md §"불변 가드레일"
(consistent with ARCHITECTURE.md locked decisions D5-D9 and CLAUDE.md flight-rules)

### C1 — Write boundary
- type: protocol
- content: Writes are confined to `.claude/` + designated root guides + `carve-manifest.json`.
  Target source is never modified. (Matches ADR D5.)

### C2 — No network transmission
- type: nfr
- content: No network transmission anywhere. Telemetry is 100% local. Secrets are never recorded.

### C3 — Single runtime dependency
- type: nfr
- content: Runtime dependency stays `@clack/prompts` only. New features solve with the standard
  library (`node:crypto`, `node:fs`, etc.). (Matches ADR D4.)

### C4 — Idempotency + .bak once + deterministic blocking hooks
- type: protocol
- content: Idempotency, `.bak` preserved once, and deterministic exit-2 blocking hooks must not be
  weakened. (Matches ADR D6, D7.)

### C5 — Auditor gate
- type: protocol
- content: Artifacts that fail the auditor are not installed. New hooks/commands must pass the
  auditor (secret / excess permission / hook injection / shell syntax). (Matches ADR D8.)

---

## Manifest schema (M8)

source: MS7-v2-roadmap.md §"M8"

### C6 — Manifest schema v2
- type: schema
- content: `files` expands from `string[]` to `[{path, hash, assetVersion}]`; add `schemaVersion`.
  Asset content hash via `node:crypto`, computed at generation time (after Artifact creation in
  `src/generator.ts`). `migrateManifest()` lifts v1 → v2 losslessly.
- code locations: `src/manifest.ts`, `src/installer.ts`, `src/generator.ts`

### C7 — Atomic install/rollback
- type: protocol
- content: Write everything to a temp dir, pass audit, then swap. On audit failure, existing
  install is unchanged (rollback). Closes the "partial failure leaves inconsistent state" gap.
- code locations: `src/installer.ts`

---

## ProjectProfile signal contract (M9)

source: MS7-v2-roadmap.md §"M9"

### C8 — ProjectProfile signal extensions
- type: schema
- content: `ProjectProfile` extended with `workspaces[]` (monorepo: pnpm workspaces, turborepo,
  nx, lerna, cargo workspaces), `container` (Dockerfile / docker-compose), and additional signals
  (Makefile, framework refinement). designer scoring becomes signal-weighted (function split for
  testability); catalog gains weight-meta fields.
- code locations: `src/analyzer.ts`, `src/types.ts`, `src/designer.ts`, `src/catalog.ts`,
  `src/wizard.ts`

---

## Telemetry record contract (M10)

source: MS7-v2-roadmap.md §"M10"

### C9 — Metrics record format + redaction
- type: protocol
- content: `_metrics.sh` appends to `.claude/.carve-metrics.jsonl`. Each line records ONLY event
  type, timestamp, hook id. NO command body, path, or secret (redaction). Opt-in (install consent
  or `CARVE_METRICS=on`), default OFF. Emit is a side-effect only — deterministic blocking logic
  unchanged.
- code locations: `assets/hooks/_metrics.sh` (+ emit line in existing 9 hooks), `src/commands.ts`,
  `src/cli.ts`

---

## Quality / validation gates (NFR)

source: requirement.md §4, MS7-v2-roadmap.md §"전체 검증 전략"

### C10 — Coverage and verification gates
- type: nfr
- content: Coverage >= 80 gate held (currently ~95, no regression). Pre-commit gates:
  `npm run check` (tsc) · `npm test` · `bash -n` (new hooks) · `JSON.parse` (manifest v2). Each
  milestone closes with an e2e roundtrip (install → report → update → diff → uninstall).

### C11 — Explicitly deferred (out of v2.0 scope)
- type: protocol
- content: Out of scope for v2.0: plugin/custom catalog, extra stacks (C++, Kotlin, Swift, C#, PHP,
  Ruby), extra Squad agents (devops, perf, a11y). M9 catalog weight-meta and M8 asset-version
  structure are designed as future extension foundations — open the slot only, no over-design.
- source: MS7-v2-roadmap.md §"명시적 보류"
