# Context (DOC Intel)

> Running notes from DOC-classified sources, keyed by topic, with source attribution.
> DOCs are lowest precedence (3). Where a DOC contradicts the LOCKED ADR or a SPEC, the
> higher-precedence source wins (see INGEST-CONFLICTS.md).

---

## Topic: Project identity / two-layer model

source: /Users/codevillain/Claude-Code-Expert/carve-harness/carve-harness/CLAUDE.md

- carve = "carve general-purpose assets to fit a project" = the "constraint" pillar of the
  3-pillar harness model. The CLI analyzes an arbitrary codebase and auto-generates/installs a
  custom harness (skills, hooks, commands, subagents).
- Two layers must never be conflated: Layer A = the carve-harness repo itself (`src/`, `assets/`);
  Layer B = artifacts carve installs into a target project (`<user-project>/.claude/`). When
  coding, always be explicit about which layer is being touched. (Matches ADR D1.)
- `vendor/` (openharness, subagents) was the original analysis source and is DELETED. Required
  assets (Squad, anti-slop) were melted into `assets/` (100% melt-in). carve runs without vendor.

## Topic: Development flight-rules (repo-level)

source: CLAUDE.md

- vendor is read-only / now removed; assets are read only from `assets/`.
- Syntax verification mandatory before commit: TS `tsc --noEmit` (`npm run check`), Shell `bash -n`,
  JSON `JSON.parse`.
- Idempotency: install/generate never overwrites user-modified assets; conflicts shown as diff
  then confirmed. (Reinforces ADR D6.)
- Generated assets follow official format: SKILL.md needs `name`/`description` frontmatter +
  Progressive Disclosure; agents follow Squad pattern (single responsibility, hard tool-permission
  constraints).
- Hooks: deterministic block = PreToolUse; format/lint = PostToolUse; handoff = PreCompact +
  SessionStart.
- Commands: `/carve-*` naming, restricted `allowed-tools`.
- Behavioral guidelines: think before coding, simplicity first, surgical changes, goal-driven
  execution. CLAUDE.md kept under 200 lines (Progressive Disclosure; detail in docs/).

## Topic: Language & response policy

source: CLAUDE.md

- Internal reasoning/planning, code, comments, logs, commit messages: English.
- User-facing response: English summary → Korean conclusion (fixed order, each once).

## Topic: Milestone history (v1.x, complete)

source: /Users/codevillain/Claude-Code-Expert/carve-harness/carve-harness/docs/milestones/README.md

- MS0-MS6 + anti-slop-linter all complete (✅). MS0 skeleton, MS1 analyzer, MS2 designer+catalog,
  MS3 generator+flight-rules/eval+exit-2 hooks, MS4 installer/CLI/hooks/anti-slop/wizard, MS5
  auditor + CLAUDE.md/HARNESS-GUIDE generation, MS6 PoC E2E + README + bench scores.
- Release line: v1.1.0 (MVP done) → v1.2.0 (mattpocock skills) → v1.2.1 (catalog-asset alignment).
- NOTE: `MS*.md` are per-tick snapshots; their "remaining/next" items were that tick's TODO and are
  since resolved. Current state lives in CHANGELOG.md and benchmark-results.md.
- Planned: MS7 = v2.0 roadmap (lifecycle / analysis-intelligence / telemetry / proof-bench /
  feedback-loop), status 📋.

## Topic: Feature priority / PoC criteria (planning rationale)

source: /Users/codevillain/Claude-Code-Expert/carve-harness/carve-harness/docs/guide/carve-harness-features-priority.md
(doc version v1.1, 2026-05-31)

- PoC single success criterion: the round trip "analyze → slot design → carve → generate a
  verifiable harness" actually runs once. Deterministic analyzer + generator + verifier come before
  fancy multi-agent.
- MUST = M1-M7 (analyzer, designer, generator, evaluation-criteria, flight-rules + validation hooks,
  idempotent installer, CLI entry + natural-language trigger).
- SHOULD/COULD ranking by (impact × differentiation) ÷ difficulty: #1 Evaluator subagent, #2 Sprint
  Contract, #3 auditor, #4 deterministic hook hardening (SHOULD); #5 multi-agent parallel, #6
  Evaluator tuning loop, #7 model 3-tier routing, #8 coordinator mailbox, #9 handoff/changelog, #10
  harness-audit, #11 provider abstraction, #12 TUI (COULD).
- Designer auto-suggesting harness level by project complexity is the differentiator (single $9 vs
  full $200 harness — adjust by task importance).
- Source repos analyzed: HKUDS/OpenHarness (base, 10 subsystems), claude-code-expert/subagents
  (Squad assets, idempotent install, CLI), affaan-m/everything-claude-code (ECC meta / AgentShield),
  gsd-build/get-shit-done (Context Rot / spec-driven).

### Note: scope wording vs requirement.md (lower-precedence drift)
- features-priority.md and ARCHITECTURE.md PoC scenario #1 mention generating an `evaluator` agent;
  requirement.md R-CORE lists six core skills without `evaluator` (Evaluator is SHOULD #1, not a
  core requirement). The features-priority doc is a planning rationale (precedence 3); requirement.md
  (SPEC, precedence 1) governs the core set. Recorded in INGEST-CONFLICTS.md as auto-resolved INFO.
