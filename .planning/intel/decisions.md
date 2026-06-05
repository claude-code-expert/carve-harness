# Decisions (ADR Intel)

> Extracted from classified ADR docs. One entry per decision. Decisions from a LOCKED ADR
> cannot be auto-overridden by any lower-precedence source. Provenance preserved via `source:`.

---

## ADR: carve-harness Architecture

- source: /Users/codevillain/Claude-Code-Expert/carve-harness/carve-harness/ARCHITECTURE.md
- status: LOCKED (manifest_override=true, locked=true)
- precedence: 0 (highest)
- scope: carve CLI architecture, two-layer model, pipeline, stack, MUST components, milestones

The following decisions are LOCKED and constrain all downstream planning.

### D1 — Two-layer model (A/B), never conflated
- decision: Layer A = the carve-harness CLI itself (`bin/`, `src/`, `assets/`). Layer B = artifacts
  carve installs into a target project (`<user-project>/.claude/`). Code must always be explicit
  about which layer it touches.
- scope: project structure / mental model
- source: ARCHITECTURE.md §"두 레이어"

### D2 — Fixed analyze→install pipeline
- decision: `carve install` runs a fixed pipeline: analyzer (read-only scan → ProjectProfile) →
  catalog (component registry) → wizard (interactive selection, @clack/prompts) → designer (slot
  design) → generator (carve assets + var substitution) → auditor (self-verify) → installer
  (idempotent install + manifest record).
- scope: install pipeline
- source: ARCHITECTURE.md §"파이프라인"

### D3 — No batch install; user selection gate is mandatory
- decision: Natural-language trigger is NOT an automatic batch install. After analyze→design, a
  selection gate is required before generate. The user decides; there is no bulk-install mode.
- scope: install UX / contract
- source: ARCHITECTURE.md §"MUST 구성요소" note, §"파이프라인" (wizard "일괄 없음")

### D4 — TypeScript ESM, zero-build runtime
- decision: TypeScript (ESM) with zero build — Node ≥22.18 type-stripping runs `.ts` directly.
  Relative imports must use explicit extensions. Single runtime dependency: `@clack/prompts`.
  Dev deps: `typescript` (tsc --noEmit), `@types/node`. Tests: `node --test` + built-in coverage.
- scope: tech stack
- source: ARCHITECTURE.md §"기술 스택"

### D5 — Writes restricted to .claude/ + root guides + manifest
- decision: Installation outputs are confined to `<user-project>/.claude/` plus designated root
  guides (CLAUDE.md, HARNESS-GUIDE.md) plus `carve-manifest.json`. Target source code is never
  modified.
- scope: safety / write boundary
- source: ARCHITECTURE.md §"설치 산출물 (레이어 B)"

### D6 — Idempotent installation with .bak preservation
- decision: Installation is idempotent. Re-running never overwrites user-modified assets; conflicts
  are shown as a diff for confirmation; originals are preserved as `.bak` once. settings.json is
  merged safely (jq-based). Manifest records installs for clean uninstall.
- scope: installer contract
- source: ARCHITECTURE.md §"디렉토리" (installer 멱등성 필수), §"MUST 구성요소" M6

### D7 — Deterministic blocking hooks via exit code 2
- decision: Validation hooks enforce flight-rules with PreToolUse deterministic blocking via exit
  code 2 (the only deterministic block mechanism). This must not be weakened.
- scope: hooks / safety
- source: ARCHITECTURE.md §"PoC 성공 기준", §"MUST 구성요소" M5

### D8 — Auditor must pass before install
- decision: Generated artifacts are self-verified by the auditor (secret exposure, excess
  permissions, hook injection, shell syntax). Artifacts that fail the auditor are not installed.
- scope: quality gate
- source: ARCHITECTURE.md §"파이프라인" (auditor), §"PoC 성공 기준" ④

### D9 — Squad 8 subagents preserved 100%
- decision: Squad subagents (8 agents) + router/chaining hooks are preserved on install (melt-in,
  vendor-independent under `assets/squad/`).
- scope: subagents
- source: ARCHITECTURE.md §"디렉토리" (assets/squad/)
