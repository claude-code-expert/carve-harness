# Synthesis Summary

> Single entry point for `gsd-roadmapper`. Produced by `gsd-doc-synthesizer` from 6 classified docs.
> Mode: new (fresh bootstrap). Precedence: ADR > SPEC > PRD > DOC.
> Project: carve-harness — TypeScript ESM buildless CLI that carves/installs custom harnesses into
> target projects. Active milestone: v2.0 (M8 lifecycle, M9 analysis intelligence, M10 telemetry).

---

## Doc counts by type

- ADR: 1 — ARCHITECTURE.md (LOCKED, precedence 0)
- SPEC: 2 — requirement.md (precedence 1), MS7-v2-roadmap.md (precedence 1)
- PRD: 0
- DOC: 3 — CLAUDE.md, docs/milestones/README.md, docs/guide/carve-harness-features-priority.md
- UNKNOWN/low-confidence: 0 (all six classified `high`)

## Decisions locked (9 from 1 LOCKED ADR)

source: ARCHITECTURE.md — D1 two-layer model · D2 fixed analyze→install pipeline · D3 no batch
install (selection gate) · D4 TypeScript ESM zero-build, single runtime dep @clack/prompts · D5
writes restricted to .claude/ + root guides + manifest · D6 idempotent install + .bak once · D7
deterministic exit-2 blocking hooks · D8 auditor must pass · D9 Squad 8 subagents preserved.
Detail: `decisions.md`.

## Requirements extracted (13)

Baseline (requirement.md, SPEC): REQ-install-flow, REQ-core-components, REQ-squad,
REQ-extra-components, REQ-doc-generation, REQ-lifecycle-v1, REQ-distribution, REQ-quality-gates.

Active v2.0 (MS7-v2-roadmap.md, SPEC): REQ-m8-lifecycle, REQ-m9-analysis-intelligence,
REQ-m10-telemetry, REQ-m11-bench, REQ-m12-feedback-loop.

Sequencing (from MS7): M8 -> (M9 ∥ M10) -> M11 -> M12. M8 is the foundation; the prompt scopes the
active v2.0 focus to M8/M9/M10 (M11/M12 captured but outside the immediate focus). Detail:
`requirements.md`.

## Constraints (11)

- nfr (4): C2 no network, C3 single runtime dep, C10 coverage/verification gates, (C2/C3 reassert
  ADR D4).
- protocol (5): C1 write boundary, C4 idempotency/.bak/exit-2, C5 auditor gate, C7 atomic
  install/rollback, C9 telemetry redaction, C11 deferred scope.
- schema (2): C6 manifest schema v2, C8 ProjectProfile signal extensions.
- api-contract (0).

C1-C5 reassert the LOCKED ADR guardrails (D5-D8) and CLAUDE.md flight-rules; ADR is authoritative on
overlap. Detail: `constraints.md`.

## Context topics (5)

Project identity / two-layer model · development flight-rules · language & response policy ·
milestone history (v1.x complete) · feature priority / PoC criteria. Detail: `context.md`.

## Conflicts

- BLOCKERS: 0
- competing-variants (WARNINGS): 0
- auto-resolved (INFO): 3 — (1) requirement.md > features-priority.md on core component set
  (six-skill core, Evaluator is SHOULD not core); (2) benign cross-ref cycles among canonical docs
  (navigation see-also, not derivation — non-blocking); (3) milestone-status framing snapshot drift.
- Full detail: `.planning/INGEST-CONFLICTS.md`

## Pointers

- Decisions: `.planning/intel/decisions.md`
- Requirements: `.planning/intel/requirements.md`
- Constraints: `.planning/intel/constraints.md`
- Context: `.planning/intel/context.md`
- Conflicts report: `.planning/INGEST-CONFLICTS.md`

## Status

READY — no blockers, no competing variants. Safe to route to gsd-roadmapper.
