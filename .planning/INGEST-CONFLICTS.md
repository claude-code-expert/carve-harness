## Conflict Detection Report

### BLOCKERS (0)

(none)

No LOCKED-vs-LOCKED contradiction: only one LOCKED ADR is present
(ARCHITECTURE.md). No UNKNOWN/low-confidence docs (all six classified `high`). Mode is `new`, so no
existing-CONTEXT.md locked-decision checks apply. No cross-ref cycle blocks synthesis (see INFO).

### WARNINGS (0)

(none)

No PRD-classified docs in this ingest set, so there are no competing acceptance variants to resolve.

### INFO (3)

[INFO] Auto-resolved: requirement.md (SPEC) > features-priority.md (DOC) on core component set
  Found: docs/guide/carve-harness-features-priority.md and ARCHITECTURE.md PoC scenario #1 describe
    generating an `evaluator` agent as part of the bootstrap.
  Note: requirement.md (SPEC, precedence 1) R-CORE lists exactly six core skills
    (handoff, memory, commit, changelog, review, pr) and places Evaluator as SHOULD #1, not a core
    requirement. requirement.md (higher precedence than the DOC) wins; the six-skill core set is
    authoritative in synthesized intel. Recorded as drift, not a contradiction of any LOCKED
    decision.
  source: requirement.md §2.2, docs/guide/carve-harness-features-priority.md §3 (#1),
    ARCHITECTURE.md §"PoC 성공 기준" scenario ①

[INFO] Benign cross-ref cycles among canonical docs (not blocking)
  Found: ARCHITECTURE.md ↔ requirement.md and ARCHITECTURE.md ↔ CLAUDE.md form directed cycles in
    the cross_refs graph (each "see also" links the others).
  Note: These are navigation "참고 / see also" references, not derivation/transclusion dependencies.
    Each document's content is self-contained prose, so synthesis does not loop. Traversal depth
    well under the 50 cap. Surfaced for transparency; synthesis proceeded on the full set.
  source: ARCHITECTURE.md cross_refs (./requirement.md, ./CLAUDE.md), requirement.md cross_refs
    (./ARCHITECTURE.md, ./CLAUDE.md), CLAUDE.md cross_refs (ARCHITECTURE.md, requirement.md)

[INFO] Milestone-status framing differs between docs (stale snapshot, no action)
  Found: docs/milestones/README.md is titled "전부 완료 — v1.2.x" while MS7-v2-roadmap.md states
    "현재 v1.1.1" as the baseline before v2.0.
  Note: README.md explicitly labels MS*.md as per-tick snapshots and points to CHANGELOG.md /
    benchmark-results.md for current state. The discrepancy is a versioning snapshot, not a
    requirement conflict. No synthesized intel depends on the exact patch version. Recorded only.
  source: docs/milestones/README.md (title, note block), docs/milestones/MS7-v2-roadmap.md §Context
