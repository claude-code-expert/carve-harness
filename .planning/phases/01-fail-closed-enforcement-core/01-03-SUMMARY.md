---
phase: 01-fail-closed-enforcement-core
plan: 03
status: complete
requirements: [CFG-01, CFG-03]
---

# Plan 01-03 Summary — Always-On Rules + Guarded Commit Command

## What was built
Immunized the three critical `common/` rules against version-drift and stopped the model from auto-invoking the side-effect `/commit` command.

## Self-Check: PASSED
- Three `common/` rules: `grep -c '^paths:'` == 0 each; first line is now the `#` heading.
- Stack rules untouched: `java-spring` (`**/*.java`) and `react-next` (`**/*.ts,tsx`) still carry `paths:` (D-05).
- `commit.md`: `disable-model-invocation: true` present, `description:` intact, exactly 2 `---` delimiters.

## Requirements
- **CFG-01** — removed the `paths: ["**/*"]` frontmatter block from git-workflow/security/testing rules so they are always-on (D-04). Bodies byte-identical otherwise.
- **CFG-03** — added `disable-model-invocation: true` to commit.md (still user-invocable).

## key-files
### modified
- `.claude/rules/common/git-workflow.md`, `security.md`, `testing.md` — frontmatter block removed.
- `.claude/commands/commit.md` — added the no-auto-invoke flag.

## Deviations
- Executed inline by the orchestrator (subagent spawns unreliable this session). No tests (config/frontmatter only — grep-provable).
- SC#5's `$schema` half is Plan 01-04's scope, not here.

## Commits
- `596631e` feat(01-03): CFG-01 always-on rules
- `609384e` feat(01-03): CFG-03 guarded commit
