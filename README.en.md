# Claude Harness (language-agnostic drop-in)

[한국어](README.md) · Current version **v0.0.10** · Changes: [CHANGELOG.md](CHANGELOG.md) · Course: [HARNESS_GUIDE.md](HARNESS_GUIDE.md) (Korean)

A guardrail template that stops coding-agent rule violations with **hook exit 2 blocking** — not persuasion.
Drop it into your project root and it works immediately.

## Features

| Pillar | Behavior |
|--------|----------|
| **Constraints** | PreToolUse hook blocks writes to protected paths (`.env`, prod configs, migrations) and hardcoded secrets. Fail-closed when jq is missing or JSON is malformed |
| **Feedback** | Stop hook blocks "done" claims while build/type/tests fail — incremental, changed stacks only |
| **State** | Handoff auto-saved at session end/compaction (real TODOs and decisions), restored at start |
| **Observability** | Every hook verdict logged to `logs/*.jsonl` (PII masked), with report/rotation |
| **Self-audit** | `/harness-audit` — 42 mechanical checks PASS/FAIL the harness configuration itself |

**Inventory**: 9 hooks (6 events + 3 manual CLI) · 14 slash commands · 20 agents · 23 skills · 18 rule files · 1 workflow · 13 test suites (147 cases)

**Cross-agent**: hook blocking is Claude Code-only. Cursor/Codex/etc. follow `AGENTS.md` as the canonical rules, with `.githooks/pre-commit` as the final gate at commit time.

**Offline-complete**: static jq/shellcheck binaries bundled (`vendor/bin`, SHA256-verified) — installs without internet.

## Install

```bash
cd /path/to/your-project
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash
```

- **Component selection**: before installing, a numbered menu offers 5 groups (required md / hooks / skills / commands / orchestrator; Enter = all). Non-interactive: `HARNESS_COMPONENTS=md,hooks bash install.sh`. The selection is recorded in `.claude/harness-components`, drives update-mode filtering, and re-running adds missing groups.
- Existing files are never touched (reported as SKIP) — installed paths are recorded in `.claude/harness-manifest.txt`.
- **Exception: `.claude/settings.json` is merged, not skipped** — your existing config (`permissions`, `model`, own hooks) is preserved while the harness's 6 hook events are registered via jq (idempotent). Skipping it would leave the hooks unregistered and every gate (banner, guard, verify) inert.
- The installer ends by running `/harness-audit` — 42 PASS means all gates are live.

### Offline / local clone install

```bash
HARNESS_SRC_DIR=/path/to/harness bash /path/to/harness/install.sh          # install
HARNESS_SRC_DIR=/path/to/harness bash /path/to/harness/install.sh update   # update
```

To pull from a different source, set `HARNESS_REPO=<owner>/<repo>` · `HARNESS_REF=<branch|tag>`.

**Initial setup** (optional, every prompt skippable with Enter):

```bash
bash install.sh setup
```

git init · jq PATH · LICENSE generation (MIT/Apache-2.0) · extra protected paths · domain-rule collection · stack detection report · GSD install offer.
For domain rules and per-stack gates, see `GUIDE.md` §8.

## Update / Rollback

Run every command **from the target project root**.

```bash
# Check the installed version
cat .claude/harness-version

# Update — online (recommended)
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash -s -- update

# Update — using the locally installed installer
bash install.sh update

# Update — offline (point at a copy of the new version)
HARNESS_SRC_DIR=/path/to/new-harness bash install.sh update

# Pin a branch/tag
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | HARNESS_REF=v0.0.4 bash -s -- update

# Force re-patch of the same version (file recovery)
HARNESS_FORCE=1 bash install.sh update

# Rollback — restore previous version (no network; run again to step further back)
bash install.sh rollback
```

- update: compares remote `VERSION` vs local `.claude/harness-version` (no-op if equal) → patches manifest scope only; changed files are auto-backed up to `logs/harness-backup/v<prev>/`; user files (SKIPped at install) are inviolate.
- rollback: restores the latest backup and reverts the version stamp. Backups are consumed — run again to step further back.
- Release procedure: `RELEASE.md`.

## Uninstall

```bash
bash uninstall.sh          # dry run — prints what would be removed
bash uninstall.sh --yes    # actually remove (manifest scope only; pre-existing files are safe)
```

## Usage

Once installed, the gates are automatic — protected-path writes are blocked, only changed stacks are verified when a response ends, and state is saved at session boundaries. Manual tools:

| Command | Purpose |
|---------|---------|
| `/harness-audit` | 42-check PASS/FAIL of the harness configuration |
| `/plan` `/verify` `/review` `/commit` | SC breakdown · SC verification · code review · commit prep |
| `/squad-*` (8) | plan→review→QA→refactor→debug→security→docs→git pipeline |
| `bash .claude/hooks/logs-report.sh [days]` | hook verdict log summary (`--rotate N` to rotate) |
| `npm test` / `npm run test:install` | all 13 hook test suites / installer component-selection suite |

For customization (protected paths, formatters, verify commands, new stacks) and the full reference, see **`GUIDE.md`**.

## Layout

```
├── CLAUDE.md / AGENTS.md    # canonical rules (Claude / cross-agent)
├── VERSION · CHANGELOG.md · RELEASE.md
├── install.sh / uninstall.sh   # install·update·rollback·setup / removal
├── vendor/bin/              # bundled jq·shellcheck (+ SHA256SUMS)
├── .githooks/pre-commit     # agent-agnostic commit gate
├── specs/                   # state: handoffs & decision log
└── .claude/
    ├── settings.json        # 6 hook events registered
    ├── hooks/  (9 + 13 test suites)
    ├── workflows/ (fable-team-pipeline)
    ├── commands/ (14) · agents/ (20) · skills/ (23) · rules/ (18)
```

## Limitations

- Hook blocking is Claude Code-only — other agents are caught by pre-commit at commit time.
- Bash write guard is best-effort: pipe/heredoc indirection is not detected (pre-commit is the second net).
- Stop gate stacks: Java/Node/Python/bash — others pass unverified.
- Always-on `rules/` increase session-start token cost.

## Roadmap

- [ ] Stack gate expansion: Go·Rust (detect → gofmt/vet/test, cargo)
- [ ] Stronger detection of indirect Bash writes (pipes, heredocs)
- [ ] Cover deny-pattern variants (`rm -r -f`, etc.)
- [ ] Clean up files added by an update on rollback (manifest diff)
- [ ] Semantic version comparison (downgrade protection)
- [ ] Skill trigger-phrase (description-level) duplicate detection

## Version history

| Version | Date | Summary |
|---------|------|---------|
| v0.0.10 | 2026-07-10 | installer component selection (5-group CLI + `HARNESS_COMPONENTS`) · fable orchestrator team (4 workers + workflow + guides) · npm test runner · macOS portability fixes |
| v0.0.9 | 2026-07-09 | deterministic Java/Spring output-verification evaluator (`eval-java.sh` — reproducible P without an LLM) · ArchUnit rule promotion · AUDIT-08 |
| v0.0.8 | 2026-07-09 | gateway verification layer (rule + Stop gate GATE-04/05 + AUDIT-07) · commit-msg discipline gate · 3 test subagents · anti-ai-slop skill |
| v0.0.7 | 2026-07-09 | revert v0.0.6 (private source is intentional) + restore private-repo token guidance (404 root cause = missing auth) |
| v0.0.6 | 2026-07-09 | ~~switch source repo to public~~ (reverted in 0.0.7 — wrong fix) |
| v0.0.5 | 2026-07-09 | CLAUDE.md response-language protocol (English summary → Korean conclusion) |
| v0.0.4 | 2026-07-09 | fix: ship VERSION in the install list — installed-copy self-test failures and chained-install version loss · harness course (HARNESS_GUIDE.md) |
| v0.0.3 | 2026-07-08 | Interactive `setup` · update-safe pattern extension files · LICENSE generation |
| v0.0.2 | 2026-07-08 | `update`/`rollback` CLI · VERSION↔CHANGELOG pre-commit gate · release docs |
| v0.0.1 | 2026-07-08 | First complete build — fail-closed guard, Stop gate, JSONL observability, handoff, self-audit, offline installer |

Details: [CHANGELOG.md](CHANGELOG.md).
