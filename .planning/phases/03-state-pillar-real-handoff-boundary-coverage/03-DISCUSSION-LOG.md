# Phase 3: State Pillar — Real Handoff + Boundary Coverage - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-07
**Phase:** 3-state-pillar-real-handoff-boundary-coverage
**Mode:** Default-proposal review — user opted out of interactive Q&A; Claude proposed defaults for all 4 gray areas, user approved as-is.
**Areas discussed:** TODO collection sources, DECISIONS.md reflection, SessionEnd behavior/registration, empty-result fallback & write semantics

---

## TODO / next-step collection sources (STATE-01)

| Option | Description | Selected |
|--------|-------------|----------|
| STATE.md Pending Todos + Blockers/Concerns | Canonical structured project state | ✓ |
| Incomplete plans (PLAN without SUMMARY) → next steps | Natural next-work derivation | ✓ |
| git status — count only | Snapshot signal, no paths (PII-safe) | ✓ |
| Code TODO/FIXME grep | Repo-wide scan | ✗ (deferred to Phase 5) |

**User's choice:** Approved default (STATE.md sections + incomplete plans + git count; no code grep).
**Notes:** git status reported as count only to avoid leaking protected/PII paths.

## DECISIONS.md reflection (STATE-03)

| Option | Description | Selected |
|--------|-------------|----------|
| Recent 5, one-line summary | Recency over completeness | ✓ |
| Full log inline | Bloats handoff | ✗ |
| Auto-create DECISIONS.md if missing | Out of scope | ✗ (graceful omit instead) |

**User's choice:** Approved default (recent 5 one-liners; omit gracefully if file absent).

## SessionEnd behavior + registration (STATE-02)

| Option | Description | Selected |
|--------|-------------|----------|
| Save on every reason | Normal exit always hands off | ✓ |
| Branch per reason (logout only, etc.) | Selective | ✗ |
| Reuse save arm vs new arm | Single collection impl | ✓ reuse |

**User's choice:** Approved default (all reasons; reuse `save`; register in settings.json under SAFETY approval gate; log one JSONL line; last-wins overwrite with PreCompact).
**Notes:** settings.json change flagged as approval-gated (`.claude/rules/safety.md`).

## Empty-result fallback + write semantics (sentinel removal)

| Option | Description | Selected |
|--------|-------------|----------|
| Replace sentinel with real block | C7 fix | ✓ |
| Empty section → `- (none)` explicit | Auditable | ✓ |
| Overwrite (`>`) snapshot vs append | Handoff = current snapshot | ✓ overwrite |

**User's choice:** Approved default.

## Claude's Discretion

- Handoff section layout/order (follow handoff skill format).
- STATE.md parsing approach (awk/sed/grep) and jq usage.
- Test fixture design (mirror Phase 1/2 harness).

## Deferred Ideas

- Code TODO/FIXME scanning → Phase 5.
- DECISIONS.md auto-creation → changelog skill.
- Secret-content scanning of collected text → GUARD-04 / Phase 5.
