# Phase 4: Self-Audit That Actually Passes/Fails - Context

**Gathered:** 2026-07-07
**Status:** Ready for planning
**Source:** Default-proposal review (discuss Q&A skipped per user preference; AUDIT-03 scope confirmed via one approval question)

<domain>
## Phase Boundary

Turn `/harness-audit` from a one-line prose prompt (`.claude/commands/harness-audit.md:4`) into a **mechanical PASS/FAIL** bash script that asserts every fix from Phases 1–3 still exists. Re-runnable after each Claude Code upgrade to prove the gates hold.

- **AUDIT-01:** jq present · all registered hook events wired · every `hooks/*.sh` has `+x` · `bash -n` clean on each → any miss exits non-zero.
- **AUDIT-02:** the write-tool matcher covers all write tools + Bash, and the Bash-write inspection exists → a missing tool FAILs.
- **AUDIT-03:** each **safety-critical** `rules/*` policy maps to an enforcing gate (orphan → FAIL), and a `[내용없음]`/`자동 수집` sentinel handoff is rejected as "not implemented" → FAIL.

**In scope:** a new `.claude/hooks/harness-audit.sh`, its test `.claude/hooks/tests/harness-audit.test.sh`, and rewriting `.claude/commands/harness-audit.md` to invoke the script. **Out of scope:** auditing code-convention style guides (LLM guidance, not hook-gated), new enforcement capability (Phase 5), CI integration.

</domain>

<decisions>
## Implementation Decisions

### Audit shape + location (A-01)
- **D-01:** Audit logic lives in `.claude/hooks/harness-audit.sh` (Bash + jq + coreutils only — mirrors the Phase 1/2 hook style). The slash command `.claude/commands/harness-audit.md` is rewritten to a thin invoker that runs `bash ${CLAUDE_PROJECT_DIR}/.claude/hooks/harness-audit.sh`.
- **D-02:** Exit semantics — the script exits **non-zero (1)** on any hard FAIL and **0** only when the harness is fully configured (SC4 positive baseline). Each check prints `PASS: …` / `FAIL: …` (mirror the `*.test.sh` reporter), with a final tally + `[ "$fail" -eq 0 ]`.
- **D-03:** Target root resolves from `AUDIT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"` (same pattern as `log-event.sh`). This is load-bearing for testability: negative tests copy `.claude/` into a temp dir, mutate the copy, set `CLAUDE_PROJECT_DIR`, and run — never touching the live config.

### AUDIT-01 checks (A-02)
- **D-04:** jq present (`command -v jq`) → else FAIL.
- **D-05:** every hook event in `settings.json .hooks` whose command references a `hooks/*.sh` resolves to an existing, `+x` script; and each of the 6 registered events (PreToolUse, PostToolUse, Stop, SessionStart, PreCompact, SessionEnd) is present. Missing registration or missing `+x` → FAIL.
- **D-06:** `bash -n` clean on every `.claude/hooks/*.sh` (including libs) → any syntax error FAILs.

### AUDIT-02 checks (A-03)
- **D-07:** `settings.json .hooks.PreToolUse[0].matcher` == `Write|Edit|MultiEdit|NotebookEdit|Bash` exactly — a dropped tool (e.g. `NotebookEdit`) FAILs.
- **D-08:** the Bash-write inspection exists in `pretool-guard.sh` — assert `grep -q 'tool_input.command'` AND the `PROTECTED_RE` write-operator checks are present. Missing → FAIL.

### AUDIT-03 policy→gate mapping + sentinel (A-04, A-05) — **scope: safety-critical only** (user-confirmed)
- **D-09:** Only enforceable **safety-critical** policies map to gates; code-convention style guides (`rules/code-convention/*`, naming/fetch/style) are EXEMPT — they are LLM guidance no hook can gate. The mapping is an in-script table (policy label → presence-grep on the gate artifact). Any mapped policy whose gate artifact is absent → **FAIL** (orphan).
- **D-10:** The safety-critical map (each row = a policy and the gate that must exist):

  | Policy (source) | Enforcing gate — presence check |
  |---|---|
  | Protected-path write block (`safety.md`) | `pretool-guard.sh` contains `PROTECTED_RE`; `settings.json` PreToolUse matcher covers write tools |
  | Bash-write block (`safety.md`) | `pretool-guard.sh` contains `tool_input.command` + write-operator greps |
  | Fail-closed on missing/broken jq (`safety.md`) | `pretool-guard.sh` contains the `command -v jq` → `exit 2` preamble |
  | Secret-read / `rm -rf` / force-push deny (`safety.md`) | `settings.json .permissions.deny` contains the `Read(./**/.env*)`, `Bash(rm -rf*)`, `Bash(git push*--force*)` entries |
  | PII/secret masking in logs (`common/security.md`) | `log-event.sh` (or `lib-protected.sh`) contains the `<masked>` masking path |
  | Stop verification gate (feedback pillar) | `settings.json .hooks.Stop` registered → `stop-verify.sh` |

- **D-11:** Sentinel-handoff rejection — if `specs/HANDOFF.md` exists AND contains `[내용없음]` or `자동 수집`, FAIL ("handoff not implemented"). Absent HANDOFF.md is not a failure (nothing to reject). After Phase 3 the real handoff has no sentinel → baseline passes.
- **D-12:** Orphan direction is one-way: the audit asserts each *mapped* safety policy has its gate. It does NOT try to enumerate every `rules/*` file (that path forces fake mappings — rejected option).

### Cross-cutting
- **D-13:** TDD (RED→GREEN) in the Phase 1/2 harness style; Bash + jq + coreutils only; no new runtime dependency; `bash -n` clean. Negative tests mutate a temp copy of `.claude/` (D-03) so the live harness is never broken. The audit script itself is best-effort readable but, unlike hooks, MAY exit non-zero (it is a report, not a gate that must stay exit 0).

### Claude's Discretion
- Exact check ordering and output wording (follow the `*.test.sh` `ok`/`no` reporter shape).
- Whether the map is a bash array or a sequence of explicit checks (implementer's choice; keep it grep-based and inspectable).
- How the command `.md` passes through (direct `bash …` invocation vs. a short instruction).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` §"Phase 4: Self-Audit" — goal, 4 success criteria, `Mode: mvp`.
- `.planning/REQUIREMENTS.md` — AUDIT-01, AUDIT-02, AUDIT-03 wording.

### Files audited (read to know what to assert)
- `.claude/settings.json` — hook registration (6 events), PreToolUse matcher, `permissions.deny`, `$schema`.
- `.claude/hooks/pretool-guard.sh` — fail-closed preamble, `PROTECTED_RE`, Bash-write `tool_input.command` checks.
- `.claude/hooks/log-event.sh` + `lib-protected.sh` — `<masked>` PII masking path.
- `.claude/hooks/stop-verify.sh`, `session-handoff.sh`, `posttool-format.sh` — registration + `bash -n` targets.
- `specs/HANDOFF.md` — sentinel-rejection target (may be absent).

### Files created / rewritten
- `.claude/hooks/harness-audit.sh` (new), `.claude/hooks/tests/harness-audit.test.sh` (new), `.claude/commands/harness-audit.md` (rewrite).

### Test-harness style
- `.claude/hooks/tests/settings.test.sh` — jq-based `ok`/`no` reporter, temp-dir mutation, tally + `[ "$fail" -eq 0 ]` — the closest analog.

### Policy sources (AUDIT-03)
- `.claude/rules/safety.md`, `.claude/rules/common/security.md` — the safety-critical policies that must map to gates (D-10).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `settings.test.sh` already asserts matcher (GUARD-02), Stop timeout, `$schema`, `${CLAUDE_PROJECT_DIR}` count, and subdir guard resolution — the audit generalizes this style into a re-runnable command.
- The `*.test.sh` reporter (`ok`/`no`/`pass`/`fail` counters, `mktemp` roots, `env -i` for jq-absent) is the template for both the audit output and its test.

### Established Patterns
- `${CLAUDE_PROJECT_DIR}`-anchored root resolution (CFG-02) — the audit adopts it so tests can retarget it (D-03).
- Single-source protected pattern in `lib-protected.sh` — the audit checks for its presence, does not re-implement it.

### Integration Points
- The audit READS settings.json, all hooks, rules/safety+security, and specs/HANDOFF.md; WRITES nothing (pure report). It is the Phase 4 consumer of Phase 1–3 artifacts.

</code_context>

<specifics>
## Specific Ideas

- Removing `NotebookEdit` from the matcher (in a temp copy) must make the audit exit non-zero (SC2).
- Stripping `+x` from a hook, unregistering a hook event, or `env -i` (jq absent) must each make the audit exit non-zero (SC1).
- Seeding `specs/HANDOFF.md` with `[내용없음]` must make the audit FAIL (SC3); removing a `permissions.deny` safety entry must FAIL (SC3 orphan).
- The live, fully-configured harness must pass the audit with exit 0 (SC4).

</specifics>

<deferred>
## Deferred Ideas

- Auditing code-convention style guides → not hook-gatable; permanently out of scope.
- New enforcement (secret content scan GUARD-04, incremental Stop verify GATE-03) → Phase 5.
- Auto-fixing detected drift → the audit only reports; fixing is manual.

*None block Phase 4.*

</deferred>

---

*Phase: 04-self-audit-that-actually-passes-fails*
*Context gathered: 2026-07-07 via default-proposal review*
</content>
