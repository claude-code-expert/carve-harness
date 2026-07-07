---
phase: 01-fail-closed-enforcement-core
plan: 01
status: complete
requirements: [GUARD-01, GUARD-02, GUARD-03]
---

# Plan 01-01 Summary — Fail-Closed Guard Core (Walking Skeleton)

## What was built
Rewrote `.claude/hooks/pretool-guard.sh` from fail-open to fail-closed, and added an executable exit-code test harness. This is the Walking Skeleton slice — the thinnest end-to-end enforcement path (synthetic JSON on stdin → guard → exit 2), wired and test-proven — that later plans build on.

## Self-Check: PASSED
- `bash -n .claude/hooks/pretool-guard.sh` clean.
- `bash .claude/hooks/tests/pretool-guard.test.sh` → **15 passed, 0 failed** (exit 0).
- RED proven first: harness reported 6 failures against the unmodified fail-open guard.

## Requirements
- **GUARD-01** — jq present-check + `jq empty` parse-check, each `exit 2` with cause-specific stderr (jq-absent vs parse-fail, D-03), on the write paths only (D-01). SC#1 asserts (`not json` → 2, `env -i PATH=` → 2) pass.
- **GUARD-02** — reads `.tool_input.file_path // .tool_input.notebook_path`; NotebookEdit→protected exits 2 (Pitfall 2 fix). MultiEdit covered identically.
- **GUARD-03** — Bash branch blocks only when a write operator targets a protected path; benign keyword-mentioning reads (`grep -ri secret .`, `git commit -m "rotate secret"`, `git log -- .env.example`, `… 2>/dev/null`) exit 0.

## key-files
### created
- `.claude/hooks/tests/pretool-guard.test.sh` — 15 stdin-JSON exit-code assertions.
### modified
- `.claude/hooks/pretool-guard.sh` — fail-closed preamble + single-source `PROTECTED_RE` + tool_name branch.

## Deviations
- Executed inline by the orchestrator (not a subagent): the spawned executor died on a mid-response API connection error after reading files but before writing anything. Inline execution followed the plan's TDD sequence exactly; independent verification deferred to gsd-verifier.
- Code comments written in English per CLAUDE.md §7; stderr block messages kept Korean per plan (existing `[guard]` convention).

## Ceiling (documented, not a bug)
Bash-write detection is best-effort: pipe writes, variable-substituted/obfuscated paths, heredoc, and `sudo`-wrapped writes are out of scope (CONTEXT Claude's-Discretion; STATE C4). Root defense remains `.gitignore .env*` + `security.md`.

## Commits
- `fbd29ec` test(01-01): RED harness
- `d1c3a9b` feat(01-01): fail-closed guard (GREEN)
