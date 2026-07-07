---
phase: 02-observability-keystone-jsonl-event-log
plan: 01
status: complete
requirements: [OBS-01]
---

# Plan 02-01 Summary — JSONL Event Log Keystone

## What was built
The load-bearing observability slice: a single-source, best-effort JSONL append helper (`log-event.sh`) wired into the first hook (`pretool-guard`), so every guard decision records exactly one structured JSON line — while proving the log call can NEVER change the guard's fail-closed exit code.

## Self-Check: PASSED
- `bash .claude/hooks/tests/log-event.test.sh` → **10 passed, 0 failed**.
- RED proven first: 6 assertions failed against the un-wired tree (helper/lib/.gitignore absent).
- `bash .claude/hooks/tests/pretool-guard.test.sh` → exit 0 (Phase 1 regression intact).
- `bash -n` clean on log-event.sh, lib-protected.sh, pretool-guard.sh.

## Requirements
- **OBS-01** — first of the 5 hook entry points now logs. A guard fire appends one line carrying `ts/event/tool/decision` (+ `target` when present); `jq .` on the last line parses (SC1). Bash + jq + coreutils only, zero new dependency (SC3).

## Key correctness proofs
- **D-05 (fail-closed preserved):** logging via an isolated subprocess before a literal `exit`. Proven — `logs` unwritable → protected-write still exit 2, benign still exit 0; `env -i PATH=` (jq absent) → protected-write still exit 2.
- **Injection-safe (T-02-02):** `jq -cn --arg` binds every field; a hostile target (quote + newline + `{"fake":...}`) yields line-count delta == 1 and a parseable line.
- **PII masking (T-02-03):** any target matching the single-source `PROTECTED_RE` → `<masked>`; fail-safe masks unconditionally if lib-protected.sh can't load. Raw Bash commands are NOT logged (target `""`, Open Q2).
- **D-04 single source:** `PROTECTED_RE` now lives only in `lib-protected.sh`, sourced by both guard and helper (inline copy removed from the guard).

## key-files
### created
- `.claude/hooks/log-event.sh` — best-effort JSONL append: schema, `date -u +%Y-%m-%dT%H:%M:%SZ` timestamp, masking, subprocess isolation, always `exit 0`.
- `.claude/hooks/lib-protected.sh` — single-source `PROTECTED_RE` (pure data).
- `.gitignore` — new, `logs/` only (D-02; `.env*` deferred to HYG-02/Phase 5).
- `.claude/hooks/tests/log-event.test.sh` — append-count, jq validity, injection, masking, exit-code preservation, guard integration, regression.
### modified
- `.claude/hooks/pretool-guard.sh` — sources lib-protected.sh; log call before each of the 4 exit points (Bash block/allow, write block/allow). Fail-closed preamble untouched.

## Deviations
- Executed inline by the orchestrator (GSD subagent spawns unreliable this session). Followed the plan's RED→GREEN sequence; each task committed atomically.

## Commits
- `2cc110d` test(02-01): RED harness
- `b806375` feat(02-01): helper + lib + .gitignore + guard wiring (GREEN)
