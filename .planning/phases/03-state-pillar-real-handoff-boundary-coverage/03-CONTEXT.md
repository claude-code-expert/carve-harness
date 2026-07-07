# Phase 3: State Pillar — Real Handoff + Boundary Coverage - Context

**Gathered:** 2026-07-07
**Status:** Ready for planning
**Source:** Default-proposal review (discuss Q&A skipped per user preference)

<domain>
## Phase Boundary

Make the state pillar real, not theater. The compaction-survival mechanism (`session-handoff.sh` + PreCompact/SessionStart hooks) already works; this phase fills it with genuine content and closes the boundary gap:

- **STATE-01:** the `save` path collects real unfinished TODOs / next steps / decisions from project state — the hardcoded `[자동 수집 — 내용없음]` sentinel is removed (C7).
- **STATE-02:** a new `SessionEnd` hook saves a handoff on ordinary session exit, not only on `PreCompact`.
- **STATE-03:** entries logged in `specs/DECISIONS.md` surface in the saved handoff output.

**In scope:** editing `session-handoff.sh` (collection logic + SessionEnd), registering the `SessionEnd` hook in `settings.json`, and tests proving each SC. **Out of scope:** code `TODO|FIXME` scanning, DECISIONS.md auto-creation, secret-content scanning (all Phase 5 candidates).

</domain>

<decisions>
## Implementation Decisions

### TODO / next-step collection sources (STATE-01)
- **D-01:** Collect from `.planning/STATE.md` — the `## Pending Todos` and `## Blockers/Concerns` sections are the canonical source (SC1: "collected from project state"). Parse their list items; when a section says `None`/`None yet`, treat as empty.
- **D-02:** Derive "next steps" from incomplete plans — any `.planning/phases/*/*-PLAN.md` with no matching `*-SUMMARY.md` is an open plan; list its id/objective as a next step.
- **D-03:** Include a `git status` summary as a **count only** (e.g. "N uncommitted files") — never file paths (avoids leaking protected/PII paths into the handoff; consistent with Phase 2 masking posture).
- **D-04:** Do NOT scan code for `TODO`/`FIXME` — noise and out of scope (Phase 5 candidate).

### DECISIONS.md reflection (STATE-03)
- **D-05:** Surface the **most recent 5** entries from `specs/DECISIONS.md`, each as a one-line summary (date + decision). Recency over completeness — the full log stays in DECISIONS.md.
- **D-06:** If `specs/DECISIONS.md` does not exist, omit the decisions section gracefully (no auto-creation — that is the `changelog` skill's job). Absence is not an error.

### SessionEnd behavior + registration (STATE-02)
- **D-07:** Save on **every** SessionEnd `reason` (clear / logout / prompt_input_exit / other) — a normal exit always leaves a handoff. Do not branch on reason.
- **D-08:** Reuse the existing `session-handoff.sh save` arm — SessionEnd calls the same save path (no new arm, single collection implementation).
- **D-09:** Register `SessionEnd` in `settings.json` as `bash ${CLAUDE_PROJECT_DIR}/.claude/hooks/session-handoff.sh save`. ⚠️ **SAFETY GATE:** `settings.json` changes require explicit user approval (`.claude/rules/safety.md`) — the plan MUST surface this as an approval checkpoint (`autonomous: false` for that task).
- **D-10:** `PreCompact` and `SessionEnd` both call `save` and overwrite the same `specs/HANDOFF.md` — **last-wins is intentional** (the handoff is a current snapshot; the newest wins). SessionEnd also logs one JSONL line via `log-event.sh SessionEnd handoff save` (extends Phase 2 observability to this 6th entry point).

### Empty-result fallback + write semantics (sentinel removal)
- **D-11:** Replace the `[자동 수집 — 내용없음]` sentinel with the real collected block (C7 resolved).
- **D-12:** When a collected section is genuinely empty, emit an explicit `- (none)` line — keep the section header (auditable), never silently drop it.
- **D-13:** Keep overwrite (`>`) write semantics — the handoff is a point-in-time snapshot, not append-only. (Append-only lives in `specs/DECISIONS.md`, which the handoff only reads.)

### Claude's Discretion
- Exact handoff section layout/order (follow the `handoff` skill's format: 진행 상황 / 미완료 / 다음 단계 / 주의점).
- Parsing approach for STATE.md sections (awk/sed/grep) and jq usage for JSONL — implementer's choice, must stay `bash -n` clean and Bash+jq+coreutils only.
- Test fixture design (mirror Phase 1/2 harness style).

### Cross-cutting
- **D-14:** TDD (RED→GREEN) per the Phase 1/2 test-harness style; Bash + jq + coreutils only; no new runtime dependency; `bash -n` clean; save path must never crash the hook (keep final `exit 0`, best-effort collection).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` §"Phase 3: State Pillar" — goal, 3 success criteria, `Mode: mvp`.
- `.planning/REQUIREMENTS.md` — STATE-01, STATE-02, STATE-03 wording.

### Files being modified / read
- `.claude/hooks/session-handoff.sh` — current start/save arms + `[자동 수집 — 내용없음]` sentinel (the file this phase makes real).
- `.claude/settings.json` — hook registration block (add `SessionEnd`; SAFETY-gated).
- `.planning/STATE.md` — `## Pending Todos` / `## Blockers/Concerns` sections (collection source, D-01).
- `.claude/hooks/log-event.sh` — Phase 2 helper reused for the SessionEnd log line (D-10).

### Output format contracts (project skills)
- `.claude/skills/handoff/SKILL.md` — HANDOFF.md format: 진행 상황 / 미완료 / 다음 단계 / 주의점.
- `.claude/skills/changelog/SKILL.md` — DECISIONS.md entry format: 날짜 / 결정 / 이유 / 대안 / 영향 (append-only).

### Safety
- `.claude/rules/safety.md` §"Require Explicit User Approval" — `settings.json` changes need approval (D-09).
- `.claude/rules/common/security.md` §PII — no PII/paths in logs or handoff (D-03).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `session-handoff.sh save` arm: already writes `specs/HANDOFF.md` and (Phase 2) logs `PreCompact handoff save`. SessionEnd reuses it verbatim (D-08).
- `log-event.sh`: best-effort JSONL helper — call `bash "$LOG_EVENT" SessionEnd handoff save ""` for D-10.
- Phase 1/2 test harnesses (`.claude/hooks/tests/*.test.sh`): `pass`/`fail` counters, `mktemp` CLAUDE_PROJECT_DIR, `env -i PATH=` for jq-absent — mirror for STATE tests.

### Established Patterns
- Hooks stay `exit 0` best-effort (handoff is non-blocking); collection failures must not crash the hook.
- settings.json hook commands use `${CLAUDE_PROJECT_DIR}` prefix (Phase 1 CFG-02) — SessionEnd must match.
- Single-source + surgical edits (Phase 1/2): edit save arm in place; don't rewrite the file.

### Integration Points
- `settings.json` gains a 6th hook event (`SessionEnd`) → session-handoff.sh save.
- Handoff `save` now READS `.planning/STATE.md` and `specs/DECISIONS.md`; WRITES `specs/HANDOFF.md` and one JSONL line.

</code_context>

<specifics>
## Specific Ideas

- Handoff must contain a real open TODO when STATE.md has one (SC1 test asserts it appears).
- Invoking the SessionEnd path must write the handoff file (SC2 test asserts existence).
- Seeding a decision in DECISIONS.md then running save must surface it in HANDOFF.md (SC3 test asserts it).

</specifics>

<deferred>
## Deferred Ideas

- Code `TODO`/`FIXME` scanning across the repo → Phase 5 (additive hardening).
- Auto-creating/seeding `specs/DECISIONS.md` → belongs to the `changelog` skill, not this phase.
- Secret-content scanning of collected text → GUARD-04 / Phase 5.

*None of these block Phase 3 — discussion stayed within scope.*

</deferred>

---

*Phase: 03-state-pillar-real-handoff-boundary-coverage*
*Context gathered: 2026-07-07*
