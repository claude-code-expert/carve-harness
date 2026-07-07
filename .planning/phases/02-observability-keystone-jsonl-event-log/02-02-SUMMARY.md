---
phase: 02-observability-keystone-jsonl-event-log
plan: 02
status: complete
requirements: [OBS-02]
---

# Plan 02-02 Summary — posttool-format Outcome Logging (C8)

## What was built
Restructured `posttool-format.sh` so every fire records exactly one outcome (`format-ok` / `format-fail` / `format-skip`) in the JSONL via the Plan 01 helper — resolving C8, where format failures previously vanished into `2>/dev/null`. The formatter's own stdout stays silenced and the hook stays non-blocking (exit 0).

## Self-Check: PASSED
- `bash .claude/hooks/tests/posttool-format.test.sh` → **7 passed, 0 failed**.
- RED proven first: the 4 decision-branch assertions failed against the swallow-everything original.
- `bash -n .claude/hooks/posttool-format.sh` clean.

## Requirements
- **OBS-02 / C8** — a recognized ext with an absent formatter now logs `format-fail:missing` (SC2) instead of discarding it; a formatter that runs and exits non-zero → `format-fail:error`; a clean run → `format-ok`; an unrecognized ext → `format-skip`. Exactly one line per fire (SC1). No new dependency (SC3).

## Key correctness proofs
- **Non-blocking (T-02-08):** hook ends on a literal `exit 0`; no `exit 2` statement — a format miss records a fact, never a spurious hook error.
- **D-05:** the outcome is logged via the Plan 01 subprocess helper; a logging failure cannot change the hook's exit 0.
- All four decision branches exercised **behaviorally** (gradlew-less CWD for missing; stub `./gradlew` exit 0/1 for ok/error), not just by source grep.
- stdin consumed once into `input`, then `f` derived from it (no re-`cat`); formatter calls keep `2>/dev/null`.

## key-files
### created
- `.claude/hooks/tests/posttool-format.test.sh` — missing/skip/ok/error branches, delta==1 per fire, exit 0 every case, `2>/dev/null` + no-`exit 2` source checks.
### modified
- `.claude/hooks/posttool-format.sh` — if/elif/else per arm (missing→error→ok) + catch-all `format-skip`; one `log-event.sh PostToolUse` call per arm.

## Deviations
- Executed inline (GSD subagent spawns unreliable this session), RED→GREEN, atomic commits.
- One test grep (`exit 2`) initially matched an inline comment; reworded the hook comment so the "no exit-2 statement" check stays precise (no test weakening).

## Commits
- `fb9fec0` test(02-02): RED harness
- `543099c` feat(02-02): outcome logging (GREEN)
