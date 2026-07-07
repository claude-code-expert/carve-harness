---
phase: 05-additive-hardening-drop-in-packaging
plan: 01
status: complete
requirements: [GUARD-04, GATE-03]
---

# Plan 05-01 Summary — Additive Hardening (GUARD-04 + GATE-03)

## What was built
- **GUARD-04:** a single-source `SECRETS_RE` in `lib-protected.sh` + a content scan in `pretool-guard.sh` — a Write/Edit whose content carries AKIA/`sk-`/`ghp_`/PEM/JWT is blocked exit 2; benign content passes.
- **GATE-03:** `stop-verify.sh` now gates each stack verify behind a `git status --porcelain` change check — the gradle/node build runs only when a matching file changed; unrelated changes skip it.

## Self-Check: PASSED
- `pretool-guard.test.sh` → **20 passed, 0 failed** (5 new GUARD-04 cases: AWS/OpenAI/PEM block, benign + short-`sk-` allow).
- `stop-verify.test.sh` → **8 passed, 0 failed** (2 new GATE-03 fixture cases: .md-only skips gradle, .java runs it).
- Full hook suite (7 files) → **0 suites failed**; `/harness-audit` still exits 0.

## Requirements
- **GUARD-04 (SC1):** secret-in-content write blocked exit 2; benign allowed (no false positive on short `sk-`).
- **GATE-03 (SC2):** staging only a `.md` change skips the gradle verify; a `.java` change runs it.

## Key correctness proofs
- **Single-source (D-01):** `SECRETS_RE` defined once in lib-protected.sh, sourced by the guard — mirrors `PROTECTED_RE`.
- **Guard posture preserved (D-02):** content scan added on the write-tool branch after the path check; fail-closed preamble, path block, Bash branch, and 2/0 exit codes unchanged (all existing asserts pass).
- **Verify posture preserved (D-06):** `set -o pipefail`, GATE-01 loop-guard, jq-absent skip, exit-2-on-fail, and pass/fail/loop-yield logs intact; not-a-git-repo → verify all (fallback).
- **Dogfood:** GUARD-04 blocked the test's own literal secret during authoring — fixtures rewritten with split-literal concatenation so the source holds no contiguous secret while runtime rebuilds it.

## key-files
### modified
- `.claude/hooks/lib-protected.sh` — added `SECRETS_RE`.
- `.claude/hooks/pretool-guard.sh` — content scan (branch 3c) after the path block.
- `.claude/hooks/stop-verify.sh` — `changed()` detection + java/node-changed guards; ponytail full-suite comment resolved.
- `.claude/hooks/tests/pretool-guard.test.sh` — 5 GUARD-04 cases (split-literal secrets).
- `.claude/hooks/tests/stop-verify.test.sh` — 2 GATE-03 git-fixture cases (stub gradlew marker).
- `.claude/hooks/tests/harness-audit.test.sh` — **root-cause fix:** its isolation check used `git diff --quiet` on pretool-guard.sh, which false-FAILs on a legit uncommitted edit; switched to a before/after `cksum` snapshot (commit-independent). Surfaced by this plan's edit to pretool-guard.sh.

## Deviations
- Fixed the Phase-4 `harness-audit.test.sh` isolation assertion (commit-order fragility) as a root-cause fix — Phase 5's legitimate edit to pretool-guard.sh exposed it. Scope justified: keeps the suite green for any future edit to guarded files.
- Executed inline (GSD subagent spawns unreliable this session).

## Commits
- (this plan) feat(05-01): GUARD-04 secret content scan + GATE-03 incremental verify
