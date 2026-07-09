# Claude Harness (language-agnostic drop-in)

[한국어](README.md) · Current version **v0.0.6** · Changes: [CHANGELOG.md](CHANGELOG.md) · Course: [HARNESS_GUIDE.md](HARNESS_GUIDE.md) (Korean)

A guardrail template that stops coding-agent rule violations with **hook exit 2 blocking** — not persuasion.
Drop it into your project root and it works immediately.

## Features

| Pillar | Behavior |
|--------|----------|
| **Constraints** | PreToolUse hook blocks writes to protected paths (`.env`, prod configs, migrations) and hardcoded secrets. Fail-closed when jq is missing or JSON is malformed |
| **Feedback** | Stop hook blocks "done" claims while build/type/tests fail — incremental, changed stacks only |
| **State** | Handoff auto-saved at session end/compaction (real TODOs and decisions), restored at start |
| **Observability** | Every hook verdict logged to `logs/*.jsonl` (PII masked), with report/rotation |
| **Self-audit** | `/harness-audit` — 38 mechanical checks PASS/FAIL the harness configuration itself |

**Inventory**: 8 hooks (Claude Code only, 6 events) · 14 slash commands · 13 agents · 22 skills · 17 rule files · 10 test suites (106 cases)

**Cross-agent**: hook blocking is Claude Code-only. Cursor/Codex/etc. follow `AGENTS.md` as the canonical rules, with `.githooks/pre-commit` as the final gate at commit time.

**Offline-complete**: static jq/shellcheck binaries bundled (`vendor/bin`, SHA256-verified) — installs without internet.

## Install

```bash
cd /path/to/your-project
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash
```

Offline: `HARNESS_SRC_DIR=/path/to/harness-copy bash /path/to/harness-copy/install.sh`

- Existing files are never touched (reported as SKIP) — installed paths are recorded in `.claude/harness-manifest.txt`.
- The installer ends by running `/harness-audit` — 38 PASS means all gates are live.

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

# Update — online (recommended: runs the new installer, so new files are received too)
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
| `/harness-audit` | 38-check PASS/FAIL of the harness configuration |
| `/plan` `/verify` `/review` `/commit` | SC breakdown · SC verification · code review · commit prep |
| `/squad-*` (8) | plan→review→QA→refactor→debug→security→docs→git pipeline |
| `bash .claude/hooks/logs-report.sh [days]` | hook verdict log summary (`--rotate N` to rotate) |

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
    ├── hooks/  (8 + 10 test suites)
    ├── commands/ (14) · agents/ (13) · skills/ (22) · rules/ (17)
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
| v0.0.6 | 2026-07-09 | fix: default source repo → public carve-harness (private repo 404 broke update) |
| v0.0.5 | 2026-07-09 | CLAUDE.md response-language protocol (English summary → Korean conclusion) |
| v0.0.4 | 2026-07-09 | fix: ship VERSION in the install list — installed-copy self-test failures and chained-install version loss · harness course (HARNESS_GUIDE.md) |
| v0.0.3 | 2026-07-08 | Interactive `setup` · update-safe pattern extension files · LICENSE generation |
| v0.0.2 | 2026-07-08 | `update`/`rollback` CLI · VERSION↔CHANGELOG pre-commit gate · release docs |
| v0.0.1 | 2026-07-08 | First complete build — fail-closed guard, Stop gate, JSONL observability, handoff, self-audit, offline installer |

Details: [CHANGELOG.md](CHANGELOG.md).
