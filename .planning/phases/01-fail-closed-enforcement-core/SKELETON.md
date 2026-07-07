# Walking Skeleton — Claude 하네스 템플릿 하드닝

**Phase:** 1
**Generated:** 2026-07-06

> Adapted for a shell-hook / config tooling project (Bash + jq only, zero runtime deps). There is no DB, UI, web framework, or deployment. The "full stack" here is the hook enforcement lifecycle: **tool call → hook stdin JSON → guard decision → exit code**. The thinnest working end-to-end slice is a guard that fails closed and is proven by feeding synthetic JSON on stdin and asserting the exit code.

## Capability Proven End-to-End

A developer's protected-path write is blocked (`exit 2`) by `pretool-guard.sh` **even when the environment is degraded** — `jq` missing or the stdin JSON malformed — instead of silently allowed. The guard is already wired into `.claude/settings.json` (PreToolUse `Write|Edit`) so it fires today, and the behavior is proven by an executable test that pipes synthetic JSON to the hook and asserts exit code 2.

This is the fail-closed core (SC #1 / GUARD-01) that every other Phase 1 slice builds outward from.

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Runtime | Bash (`#!/usr/bin/env bash`) + `jq 1.8.1` only | Locked "런타임 의존성 0" invariant (CLAUDE.md, CONTEXT §Established Patterns). No new tool introduced in any phase. |
| Enforcement mechanism | Claude Code hooks; **block = `exit 2`, allow = `exit 0`, `exit 1` = non-blocking pass-through** | MANUAL §2.2 / ARCHITECTURE §핵심 불변식. Only exit 2 blocks — the load-bearing invariant. |
| Input contract | Hooks read stdin JSON, parse with `jq` (env-var style is legacy) | RESEARCH §Standard Stack; MANUAL §6. |
| Fail mode (write paths) | **Fail-closed** — jq-absent/parse-fail → `exit 2` with cause-specific stderr | D-01/D-03. Degraded environment must not weaken write enforcement. |
| Fail mode (Stop gate) | **Best-effort** — jq-absent → warn + `exit 0` (non-blocking) | D-02. Hard-failing verification would paralyze completion on jq-less machines. Deliberate asymmetry with the write guard. |
| Protected-path pattern | Single-source regex `(\.env($\|[./])\|application-prod\|secret\|db/migration/)` consumed by both the write-tool and Bash branches | CONTEXT single-source requirement; preserves the existing glob's `.environment.ts` non-match (RESEARCH A2). |
| Hook path resolution | `${CLAUDE_PROJECT_DIR}`-prefixed command strings | CFG-02 — resolves from project root so the guard fires from any subdirectory. |
| Directory layout | Edits to existing files under `.claude/`; new tests under `.claude/hooks/tests/` | No new files beyond test harnesses. All fixes are surgical/subtractive. |

## Stack Touched in Phase 1

Adapted checklist (no DB/UI/deploy in this project):

- [x] Hook runtime — `pretool-guard.sh` fail-closed preamble + tool_name branch (Plan 01)
- [x] Input handling — real stdin JSON read + `jq empty` parse-check (Plan 01)
- [x] Every write path — Write/Edit/MultiEdit `file_path` + NotebookEdit `notebook_path` + Bash `.tool_input.command` (Plan 01)
- [x] Feedback gate — `stop-verify.sh` `stop_hook_active` loop guard (Plan 02)
- [x] Config declarations — always-on rules (no `paths:`), `commit` no-auto-invoke (Plan 03)
- [x] Wiring/integrity — matcher expansion, `${CLAUDE_PROJECT_DIR}`, Stop `timeout`, `$schema` (Plan 04)
- [x] Executable proof — stdin-fed exit-code test harnesses under `.claude/hooks/tests/` (all plans)

## Out of Scope (Deferred to Later Slices)

Explicit — prevents later phases re-litigating Phase 1's minimalism:

- **Secret content scan** (file contents: AKIA/sk-/ghp-/PEM/JWT) → GUARD-04, Phase 5. Phase 1 is path-based blocking only.
- **Changed-module incremental Stop verify** → GATE-03, Phase 5. Phase 1 only adds an explicit timeout; it does not scope verification to changed modules.
- **Bash write-guard obfuscation coverage** — pipe writes, variable-substituted/heredoc paths, read paths (`less`/`head`) → **documented ceiling, NOT a bug** (CONTEXT Claude's-Discretion; STATE.md C4). Best-effort substring/regex match; root defense is `.gitignore .env*` + `security.md`.
- **JSONL observability log** → OBS-01/02, Phase 2.
- **Real handoff content + SessionEnd** → STATE-01/02/03, Phase 3.
- **Mechanical `/harness-audit`** → AUDIT-01/02/03, Phase 4.

## Subsequent Slice Plan

Each later phase adds one vertical enforcement slice on top of this fail-closed core without renegotiating the decisions above:

- **Phase 2:** Structured JSONL event log — every hook fire recorded; format-hook failures surfaced.
- **Phase 3:** Real session handoff content + `SessionEnd` boundary coverage.
- **Phase 4:** `/harness-audit` mechanically PASS/FAILs every fix from Phases 1–3.
- **Phase 5:** Secret content scan (GUARD-04), incremental Stop verify (GATE-03), filled stubs + drop-in hygiene files.
