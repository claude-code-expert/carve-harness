# Roadmap: Claude 하네스 템플릿 하드닝

## Overview

The architecture is right; the enforcement leaks. This milestone closes every silent bypass in the harness before adding new capability, in reliability-per-effort order: first make the constraint and Stop gates un-bypassable (fail-closed, full write-tool coverage, no Stop-loop), then land the JSONL observability keystone that makes failures visible, then give the state pillar real handoff content, then build a `/harness-audit` that mechanically PASS/FAILs the whole thing — and finally add the additive hardening (secret content scan, incremental verify) plus the drop-in packaging (filled stubs, hygiene files). Every phase is a working end-to-end hardening slice, verified with `bash -n`, stub-invocation, and exit-code assertions.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: Fail-Closed Enforcement Core** - Guards fail closed, cover every write path, Stop can't loop or silently time out; hooks resolve from project root and critical config is airtight (completed 2026-07-07)
- [x] **Phase 2: Observability Keystone (JSONL Event Log)** - Every hook fire is structured JSONL in `logs/`; format-hook failures stop being swallowed (completed 2026-07-07)
- [x] **Phase 3: State Pillar — Real Handoff + Boundary Coverage** - Handoff captures real TODOs/next-steps/decisions and saves on normal session end, not just compaction (completed 2026-07-07)
- [ ] **Phase 4: Self-Audit That Actually Passes/Fails** - `/harness-audit` mechanically PASS/FAILs jq, hook registration, matcher coverage, rule→gate mapping, and the sentinel handoff
- [ ] **Phase 5: Additive Hardening + Drop-in Packaging** - Secret content scan, incremental Stop verify, filled stubs, and clean drop-in hygiene (gitignore/license/install/links)

## Phase Details

### Phase 1: Fail-Closed Enforcement Core
**Goal**: The constraint and Stop gates become un-bypassable — guards fail closed when `jq` is missing or JSON is malformed, cover every write path (all write tools plus Bash write commands), and the Stop gate can neither loop forever nor be silently disabled by timeout; hooks resolve from `${CLAUDE_PROJECT_DIR}`, critical rules are always-on, and the side-effect `commit` command can't be auto-invoked.
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: GUARD-01, GUARD-02, GUARD-03, GATE-01, GATE-02, CFG-01, CFG-02, CFG-03, CFG-04
**Success Criteria** (what must be TRUE):
  1. With `jq` unavailable (stripped from PATH) or malformed stdin JSON, the guard hook exits 2 (blocks) instead of allowing — feeding broken JSON to `pretool-guard.sh` asserts exit code 2.
  2. A `MultiEdit` or `NotebookEdit` write targeting a protected path (e.g. `.env.production`) is blocked with exit 2, identically to `Write`/`Edit`.
  3. A Bash write to a protected path — `echo secret > x/.env.production`, `sed -i` on an existing migration, `cp … application-prod.yml` — is blocked with exit 2 via `.tool_input.command` inspection; a benign Bash command is allowed (exit 0).
  4. On the second Stop pass (`stop_hook_active=true`) the Stop gate surfaces the failure once and yields (exit 0) instead of looping; hook commands invoke via `${CLAUDE_PROJECT_DIR}` so the guard still fires when run from a subdirectory.
  5. `commit` carries `disable-model-invocation: true`, `settings.json` validates against its declared `"$schema"`, and critical rule files have no `paths:` (always-on) — all verifiable by grep/jq assertions.
**Plans**: 4 plans
- [x] 01-01-PLAN.md — Fail-closed guard core: preamble + all write tools + Bash-write, single-source pattern (GUARD-01/02/03) [Walking Skeleton]
- [x] 01-02-PLAN.md — Stop-gate loop guard: `stop_hook_active` short-circuit + jq-absent best-effort (GATE-01)
- [x] 01-03-PLAN.md — Always-on critical rules (remove `paths:`) + `commit` no-auto-invoke (CFG-01, CFG-03)
- [x] 01-04-PLAN.md — settings.json wiring: matcher expansion, `${CLAUDE_PROJECT_DIR}`, Stop timeout, `$schema` (GUARD-02, GATE-02, CFG-02, CFG-04)

### Phase 2: Observability Keystone (JSONL Event Log)
**Goal**: Add the one missing architectural layer — a structured, zero-dependency JSONL event log — so every hook fire is recorded and format-hook failures stop vanishing into `/dev/null`. This is the keystone the real `/harness-audit` (Phase 4) and format-failure visibility (OBS-02) both depend on.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: OBS-01, OBS-02
**Success Criteria** (what must be TRUE):
  1. Every hook fire appends exactly one JSON line to `logs/*.jsonl` carrying event, tool, decision, and timestamp — triggering a hook and running `jq .` on the last line parses without error.
  2. A format-hook failure (formatter missing or non-zero exit) is written as a failure record in the JSONL log instead of being discarded — running `posttool-format.sh` with a missing formatter asserts a failure record appears.
  3. The append path uses only Bash + `jq` with no new runtime dependency — `bash -n` is clean and no non-`jq` tooling is introduced.
**Plans**: 3 plans
- [x] 02-01-PLAN.md — OBS-01 keystone: log-event.sh helper + lib-protected + .gitignore + pretool-guard wiring (fail-safe append, D-05 exit-code proof)
- [x] 02-02-PLAN.md — OBS-02: posttool-format failure visibility (missing/error/ok/skip records, hook stays exit 0)
- [x] 02-03-PLAN.md — OBS-01 completion: stop-verify + session-handoff logging (all 5 hook entry points, D-03)

### Phase 3: State Pillar — Real Handoff + Boundary Coverage
**Goal**: Make the state pillar real, not theater. The compaction-survival mechanism already works; this fills it with genuine content (unfinished TODOs, next steps, logged decisions — no more `[내용없음]` sentinel) and adds `SessionEnd` so ordinary session exits also save state.
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: STATE-01, STATE-02, STATE-03
**Success Criteria** (what must be TRUE):
  1. A saved handoff contains real unfinished TODOs and next steps collected from project state (no `[내용없음]` sentinel) — running the save path in a fixture with a known open TODO asserts it appears in the output.
  2. Ending a session normally fires the `SessionEnd` hook and writes a handoff, not only `PreCompact` — invoking the `SessionEnd` path asserts the handoff file is written.
  3. Decisions logged in `specs/DECISIONS.md` appear in the handoff output — seeding a decision and running save asserts it surfaces in the saved handoff.
**Plans**: 2 plans
- [x] 03-01-PLAN.md — Real save collection: STATE.md TODOs, open plans, git count, DECISIONS recent-5; sentinel removed (STATE-01, STATE-03)
- [x] 03-02-PLAN.md — SessionEnd boundary: event-label reuse of save arm + settings.json registration (SAFETY-gated) (STATE-02)

### Phase 4: Self-Audit That Actually Passes/Fails
**Goal**: Turn `/harness-audit` from a prose prompt into a mechanical PASS/FAIL that asserts every fix from Phases 1–3 exists — the single highest-leverage piece, re-runnable after every Claude Code upgrade to prove the gates still work.
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: AUDIT-01, AUDIT-02, AUDIT-03
**Success Criteria** (what must be TRUE):
  1. `/harness-audit` exits non-zero when any hook is unregistered, a hook script lacks `+x`, `jq` is absent, or `bash -n` fails on a script — breaking one condition asserts a non-zero exit.
  2. The audit FAILs when the write-tool matcher omits a write-capable tool or the Bash-write check is missing — removing `NotebookEdit` from the matcher asserts FAIL.
  3. The audit flags a `rules/*` policy with no enforcing gate and rejects a `[내용없음]` handoff as "not implemented" — pointing it at an orphaned rule or sentinel handoff asserts FAIL.
  4. A fully-configured harness passes the audit with exit 0 — the positive baseline holds.
**Plans**: TBD

### Phase 5: Additive Hardening + Drop-in Packaging
**Goal**: With the core trustworthy, add the two additive enforcement capabilities (secret content scan, incremental Stop verify) and finish the template as a clean drop-in: fill remaining generic stubs and add the hygiene files (`.gitignore` with root `.env*` block, `LICENSE`, `install.md`, corrected doc links).
**Mode:** mvp
**Depends on**: Phase 4
**Requirements**: GUARD-04, GATE-03, CFG-05, HYG-01, HYG-02, HYG-03
**Success Criteria** (what must be TRUE):
  1. Writing a file whose content contains a hardcoded secret (`AKIA…`, `sk-…`, `ghp_…`, PEM/JWT pattern) is blocked with exit 2, complementing the path-based guard; benign content is allowed (no false positive).
  2. Stop verification runs only against changed modules instead of the full build every turn — staging a change in one module asserts the untouched module's build/test is skipped.
  3. Remaining stubs (`specs/README`, stack-rule `[추가 규칙]`, skill bodies) carry usable generic defaults — no `[내용없음]` sentinel remains where content is expected.
  4. `.gitignore` blocks root `.env*`, `LICENSE` exists, `install.md` has real steps (or is removed), and manual links point to `code.claude.com` — all verifiable by grep assertions.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Fail-Closed Enforcement Core | 4/4 | Complete   | 2026-07-07 |
| 2. Observability Keystone | 3/3 | Complete   | 2026-07-07 |
| 3. State Pillar | 2/2 | Complete   | 2026-07-07 |
| 4. Self-Audit | 0/TBD | Not started | - |
| 5. Additive Hardening + Packaging | 0/TBD | Not started | - |
