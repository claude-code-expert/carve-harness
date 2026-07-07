---
phase: 01-fail-closed-enforcement-core
verified: 2026-07-07T00:00:00Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
---

# Phase 1: Fail-Closed Enforcement Core — Verification Report

**Phase Goal:** The constraint and Stop gates become un-bypassable — guards fail closed when `jq` is missing or JSON is malformed, cover every write path (all write tools plus Bash write commands), and the Stop gate can neither loop forever nor be silently disabled by timeout; hooks resolve from `${CLAUDE_PROJECT_DIR}`, critical rules are always-on, and the side-effect `commit` command can't be auto-invoked.

**Verified:** 2026-07-07
**Status:** passed
**Re-verification:** No — initial verification

**Method:** Independent execution, not SUMMARY-trust. All three test harnesses were run directly; every SC one-liner in `<how_to_verify>` was additionally re-run by hand outside the harness with fresh stdin payloads (not the harness's own fixtures) to rule out a harness that asserts against itself. Several adversarial edge cases beyond the documented SCs were also probed (empty stdin, bare `Edit`, missing `tool_input`, non-matcher tool names) to disconfirm rather than confirm.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `jq`-absent or malformed JSON → `pretool-guard.sh` exits 2 | VERIFIED | `printf 'not json' \| bash pretool-guard.sh` → exit 2 (`JSON 파싱 실패`). `printf '{}' \| env -i PATH= bash pretool-guard.sh` → exit 2 (`jq 미설치`). jq present-check runs before `cat` so it can't be starved by stdin. |
| 2 | `MultiEdit`/`NotebookEdit` write to protected path blocked identically to `Write`, via `notebook_path` | VERIFIED | `NotebookEdit` w/ `tool_input.notebook_path=".../.env.production"` → exit 2. `MultiEdit` w/ `tool_input.file_path` → exit 2. Code line 44: `jq -r '.tool_input.file_path // .tool_input.notebook_path // empty'` reads both keys. |
| 3 | Bash write to protected path blocked via `.tool_input.command`; benign/keyword-mention reads allowed | VERIFIED | `echo secret > x/.env.production` → 2; `sed -i ... db/migration/001.sql` → 2; `cp foo application-prod.yml` → 2. `grep -ri secret .` → 0; `git commit -m "rotate secret"` → 0; `git log -- .env.example` → 0; `grep -ri secret . 2>/dev/null` → 0. |
| 4 | Second Stop pass (`stop_hook_active=true`) surfaces once and yields (exit 0), no loop; guard still fires via `${CLAUDE_PROJECT_DIR}` from a subdirectory | VERIFIED | `printf '{"stop_hook_active":true}' \| stop-verify.sh` → exit 0 + one-line marker, no re-entry into build/test gate. From `/tmp/.../subdir-test`, `CLAUDE_PROJECT_DIR=<repo> bash "${CLAUDE_PROJECT_DIR}/.claude/hooks/pretool-guard.sh"` on a protected-path payload → exit 2. |
| 5 | `commit.md` has `disable-model-invocation: true`; `settings.json` declares `$schema` and parses; `common/` rules have no `paths:`; stack rules keep `paths:` | VERIFIED | `commit.md` line 3: `disable-model-invocation: true`. `jq . settings.json` parses; `$schema` = `https://json.schemastore.org/claude-code-settings.json`. `grep -c '^paths:'` = 0 for all 3 `common/*.md`; `java-spring/patterns.md` and `react-next/patterns.md` each retain 1 `paths:` line. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.claude/hooks/pretool-guard.sh` | Fail-closed preamble, single-source protected-path regex, Bash + write-tool branches | VERIFIED | 51 lines, substantive. `grep -c 'PROTECTED_RE=' pretool-guard.sh` = 1 (single source, no drift). |
| `.claude/hooks/stop-verify.sh` | `stop_hook_active` short-circuit + jq-absent best-effort, existing build/test gate preserved | VERIFIED | 46 lines. Loop guard and jq-absent branch inserted after `set -o pipefail`; `fail=0`/stack-detect/final exit-2 block unchanged (confirmed by re-reading full file). |
| `.claude/settings.json` | Matcher expansion, `${CLAUDE_PROJECT_DIR}` × 5, Stop `timeout` > 600, `$schema` | VERIFIED | Matcher = `Write\|Edit\|MultiEdit\|NotebookEdit\|Bash`; `CLAUDE_PROJECT_DIR` occurs 5×; Stop `timeout` = 900; `$schema` present; file parses via `jq .`. |
| `.claude/commands/commit.md` | `disable-model-invocation: true`, still user-invocable | VERIFIED | Frontmatter has both `description:` and `disable-model-invocation: true`; body intact. |
| `.claude/rules/common/{git-workflow,security,testing}.md` | No `paths:` key (always-on) | VERIFIED | 0 matches for `^paths:` in all three; first line is the `#` heading (frontmatter block fully removed, not just emptied). |
| `.claude/rules/java-spring/patterns.md`, `.claude/rules/react-next/patterns.md` | Retain scoped `paths:` | VERIFIED | Each still has exactly 1 `paths:` line (`**/*.java` and `**/*.ts`, `**/*.tsx` respectively) — confirms the always-on change was surgical, not blanket. |
| `.claude/hooks/tests/pretool-guard.test.sh` | Exit-code assertions covering SC1-3 | VERIFIED | 15 assertions, all passing, matches independent one-liner results. |
| `.claude/hooks/tests/stop-verify.test.sh` | Loop-guard + jq-absent + pipefail-regression assertions | VERIFIED | 3 assertions, all passing. |
| `.claude/hooks/tests/settings.test.sh` | jq/grep + subdir-resolution assertions | VERIFIED | 6 assertions, all passing. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `settings.json` PreToolUse | `pretool-guard.sh` | `matcher: "Write\|Edit\|MultiEdit\|NotebookEdit\|Bash"` + `${CLAUDE_PROJECT_DIR}` command | WIRED | Confirmed by `jq` read of the hook config and by an actual subdirectory invocation reproducing the exact command string pattern. |
| `settings.json` Stop | `stop-verify.sh` | `timeout: 900` | WIRED | `jq -r '.hooks.Stop[0].hooks[0].timeout'` = 900, sibling of the `command` field in the same hook object (correct schema position, not a dead top-level key). |
| `pretool-guard.sh` Bash branch | `.tool_input.command` | `jq -r '.tool_input.command // empty'` | WIRED | Verified with 7 distinct Bash payloads (3 block, 4 allow) — all correct. |
| `pretool-guard.sh` write-tool branch | `.tool_input.file_path` / `.tool_input.notebook_path` | `jq -r '.tool_input.file_path // .tool_input.notebook_path // empty'` | WIRED | `NotebookEdit` payload with only `notebook_path` set correctly triggers the block — confirms the `//` fallback chain actually reads the second key, not just declares it. |
| `stop-verify.sh` | stdin `.stop_hook_active` | `jq -r '.stop_hook_active // false'` read once via `input=$(cat)` before any other stdin consumption | WIRED | Re-running with `stop_hook_active:true` short-circuits before the Java/Node build-test block executes (no `gradlew`/`tsc` invocation observed in output). |

### Data-Flow Trace (Level 4)

Not applicable in the conventional sense (no UI/dynamic-data rendering) — the "data flow" here is stdin JSON → jq extraction → regex match → exit code, which is exactly what the direct one-liner executions traced end-to-end for every branch (Bash write/read, file_path, notebook_path, stop_hook_active, jq-absent). Each trace above already carries the full input→output path. No hollow/hardcoded intermediate values found — every extracted field (`tool_name`, `.tool_input.command`, `.tool_input.file_path`, `.tool_input.notebook_path`, `.stop_hook_active`) is read from the actual stdin payload, not a hardcoded default that shadows real input.

### Behavioral Spot-Checks / Probe Execution

No project-convention `scripts/*/tests/probe-*.sh` files exist; this project's own convention is `.claude/hooks/tests/*.test.sh`, which the phase's `<how_to_verify>` explicitly names as the executable proofs. All three were run directly (not narrated):

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| `.claude/hooks/tests/pretool-guard.test.sh` | `bash .claude/hooks/tests/pretool-guard.test.sh` | 15 passed, 0 failed, exit 0 | PASS |
| `.claude/hooks/tests/stop-verify.test.sh` | `bash .claude/hooks/tests/stop-verify.test.sh` | 3 passed, 0 failed, exit 0 | PASS |
| `.claude/hooks/tests/settings.test.sh` | `bash .claude/hooks/tests/settings.test.sh` | 6 passed, 0 failed, exit 0 | PASS |

Independent re-runs (own stdin fixtures, not the harness's fixtures) for every SC one-liner in `<how_to_verify>` all matched expected exit codes — see Observable Truths table above for exact commands/outputs.

**Adversarial disconfirmation pass (beyond documented SCs):**
- Empty stdin → exit 0 (not 2). This is `jq empty`'s own semantics (`printf '' | jq empty` → exit 0, jq treats no-input as trivially valid) — not a guard defect, and not what GUARD-01/SC1 describes ("malformed JSON"), since Claude Code's real hook invocation always sends a JSON payload on stdin. Documented here as an observed edge case, not scored as a gap.
- Bare `Edit` (not `MultiEdit`) to a protected path → exit 2, confirming the write-tool branch is tool-name-agnostic (reads `file_path`/`notebook_path` regardless of which of the four write tools called it) — stronger than the letter of SC2, which only required parity for `MultiEdit`/`NotebookEdit`.
- `tool_input` missing entirely → exit 0 (empty path/command extracted, no match) — safe default, does not crash.
- A `Read` tool_name with `file_path` set to a protected path → exit 2 if this script were invoked directly for `Read`. This is because the write-tool branch is only reached for non-Bash tool names and doesn't gate on `tool_name` being one of the four write tools. In practice this is inconsequential: `settings.json`'s matcher (`Write|Edit|MultiEdit|NotebookEdit|Bash`) is what determines which tool calls ever reach this script, and `Read` is not in that matcher — confirmed via `jq -r '.hooks.PreToolUse[0].matcher'`. Noted as an INFO-level observation (script is broader than its wiring requires), not a functional gap.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| GUARD-01 | 01-01 | jq 부재/파싱 실패 시 fail-closed 차단 | SATISFIED | Preamble in `pretool-guard.sh` lines 8-16; independently re-run, exit 2 both cases. |
| GUARD-02 | 01-01, 01-04 | 매처가 Write\|Edit\|MultiEdit\|NotebookEdit 전 포착 | SATISFIED | Code reads both `file_path`/`notebook_path` (01-01); `settings.json` matcher includes all four + Bash (01-04). |
| GUARD-03 | 01-01 | Bash 쓰기 명령이 보호 경로 대상이면 차단 | SATISFIED | 3 write patterns (redirect/tee, sed/perl -i, cp/mv/install) each block; benign reads/keyword-mentions allowed — all independently re-verified. |
| GATE-01 | 01-02 | `stop_hook_active` 확인해 무한루프 방지 | SATISFIED | Short-circuit reads stdin once, exits 0 with marker on second pass; independently re-run. |
| GATE-02 | 01-04 | Stop 타임아웃으로 조용히 무력화되지 않도록 대응 | SATISFIED | Explicit `timeout: 900` set, deliberately above the actual current default of 600s (RESEARCH.md confirms REQUIREMENTS.md's "60s" premise was stale; 900 is intentional margin, not a copy of a wrong baseline). |
| CFG-01 | 01-03 | 크리티컬 규칙 always-on (paths: 없음) | SATISFIED | 0 `paths:` in the 3 `common/*.md` files; stack rules retain theirs. |
| CFG-02 | 01-04 | 훅 경로 `${CLAUDE_PROJECT_DIR}` 기준 | SATISFIED | 5/5 hook commands in `settings.json` prefixed; subdirectory invocation reproduced and blocks correctly. |
| CFG-03 | 01-03 | `commit`에 `disable-model-invocation: true` | SATISFIED | Present in `commit.md` frontmatter, `description:` and body intact (still user-invocable via `/commit`). |
| CFG-04 | 01-04 | `settings.json`에 `$schema` 추가 | SATISFIED | `$schema` present, file still parses cleanly via `jq .`. |

No orphaned requirements — REQUIREMENTS.md traceability table maps exactly these 9 IDs to Phase 1, and all 9 appear across the 4 plans' `requirements:` frontmatter with no gaps.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | none found | — | `TBD\|FIXME\|XXX\|TODO\|HACK\|PLACEHOLDER` scan across all 10 modified/created files returned zero matches. |

One documented, intentional simplification (not an anti-pattern): `stop-verify.sh` line 43 carries a `ponytail:`-style comment acknowledging the full-suite-per-Stop-call performance ceiling, with an explicit upgrade path (deferred to Phase 5 GATE-03, per REQUIREMENTS.md and RESEARCH.md). This is a named, tracked ceiling, not an unresolved debt marker — does not trigger the debt-marker gate.

### Human Verification Required

None. This phase is entirely mechanical (bash exit codes, jq/grep-verifiable config) with no UI, no visual output, and no external service dependency. Every truth was independently re-executed with fresh stdin fixtures (not merely re-running the project's own test harness), satisfying the goal-backward bar without need for human judgment.

### MVP Mode Note (informational, not a gap)

ROADMAP.md tags this phase `Mode: mvp`, but the phase goal is phrased as an infrastructure/technical statement ("guards fail closed when jq is missing...") rather than the User Story format (`As a ..., I want ..., so that ...`) that MVP-mode verification expects. Given this phase ships hook/config hardening with no user-facing flow, the `mode: mvp` tag appears to be inherited/mislabeled metadata rather than an intentional user-story scoping. This does not affect the correctness of the verification above — the phase was verified against its 5 literal ROADMAP Success Criteria — but is flagged for the developer to correct the ROADMAP.md metadata if it was unintentional.

### Gaps Summary

None. All 5 Success Criteria verified with independently-reproduced exit codes (not solely trusting the project's own test harness). All 9 mapped requirements have concrete shipped evidence. All 3 test harnesses pass (24 assertions total). No debt markers, no stub patterns, no orphaned wiring. One adversarial edge case (empty stdin) was probed and found to reflect `jq`'s own semantics rather than a guard defect, and is out of scope for the literal SC wording ("malformed JSON"). One metadata inconsistency (mode: mvp on a non-user-story goal) is noted for developer awareness, not a code gap.

---

_Verified: 2026-07-07_
_Verifier: Claude (gsd-verifier)_
