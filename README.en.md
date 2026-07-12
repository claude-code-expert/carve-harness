# Claude Harness (language-agnostic drop-in)

[한국어](README.md) · Current version **v0.0.12** · Changes: [CHANGELOG.md](CHANGELOG.md) · Course: [HARNESS_GUIDE.md](HARNESS_GUIDE.md) (Korean)

A guardrail template that stops coding-agent rule violations with **hook exit 2 blocking** — not persuasion.
Drop it into your project root and it works immediately.

## Features

| Pillar | Behavior |
|--------|----------|
| **Constraints** | PreToolUse hook blocks writes to protected paths (`.env`, prod configs, migrations) and hardcoded secrets. Fail-closed when jq is missing or JSON is malformed |
| **Feedback** | Stop hook blocks "done" claims while build/type/lint/tests fail — incremental, changed stacks only (Node runs `lint`/`test` scripts when present, bringing CI's `npm run lint` local) |
| **State** | Handoff auto-saved at session end/compaction (real TODOs and decisions), restored at start |
| **Observability** | Every hook verdict logged to `logs/*.jsonl` (PII masked), with report/rotation. The session-start banner lists every loaded component, and all hook messages carry a unified `[carve-harness:<hook>]` prefix |
| **Self-audit** | `/harness-audit` — 42 mechanical checks PASS/FAIL the harness configuration itself |

**Inventory**: 9 hooks (6 events + 3 manual CLI) · 14 slash commands · 20 agents · 26 skills · 18 rule files · 1 workflow · 14 test suites (172 cases) — full lists in the [component tables](#full-component-list-skills--commands--hooks) below

**Cross-agent**: hook blocking is Claude Code-only. Cursor/Codex/etc. follow `AGENTS.md` as the canonical rules, with `.githooks/pre-commit` as the final gate at commit time.

**Offline-complete**: static jq/shellcheck binaries bundled (`vendor/bin`, SHA256-verified) — installs without internet.

> **Demo**: <a href="https://claude-code-expert.github.io/carve-harness/docs/html/harness-demo/index.html" target="_blank" rel="noopener noreferrer">before/after screen comparison (new window)</a> — the same prompt rendered without the harness (slop) and with it (clean), side by side, with a table mapping each change to the rule that forced it.

## Install

```bash
cd /path/to/your-project
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash
```

- **Project-aware build (recommended)**: at install start you're asked `[1] Analyze the project and build a tailored harness / [2] Manual component selection`. `[1]` full-installs, then running `/carve-harness-create` in a Claude Code session analyzes your stack and proposes/prunes rules, agents, and skills that don't fit — shrinking the always-loaded token surface (fully functional before pruning too). `[2]` is the checkbox list below. (env / non-interactive installs skip this prompt.)
- **Component selection**: before installing, every item is listed as checkboxes grouped by section (required md / hooks / skills / commands / orchestrator). `↑↓`/`jk` to move · Space to toggle (on a section row, toggles all children) · `1`-`5` to jump to a section · `a` to toggle all · Enter to install. Default is everything selected — just press Enter for a full install. Non-interactive: `HARNESS_COMPONENTS=md,hooks bash install.sh`. The selection is recorded in `.claude/harness-components`, drives update-mode filtering, and re-running adds missing items.
- Existing files are never touched (reported as SKIP) — installed paths are recorded in `.claude/harness-manifest.txt`.
- **Exception: `.claude/settings.json` is merged, not skipped** — your existing config (`permissions`, `model`, own hooks) is preserved while the harness's 6 hook events plus LSP/plugin declarations are registered via jq (idempotent). Skipping it would leave the hooks unregistered and every gate (banner, guard, verify) inert.
- **LSP + plugins auto-declared**: settings.json declares the `vtsls` (TypeScript/React/JavaScript LSP), `jdtls` (Java LSP), `ponytail`, and `frontend-design` (design-direction skill) plugins along with their marketplaces (`claude-code-lsps` · `ponytail` · `claude-code-plugins`) — Claude Code installs them after a trust prompt at session start. Server binaries are separate: `bash install.sh setup` offers a global npm install of vtsls; jdtls needs `brew install jdtls` (JDK required). Missing binaries are reported as NOTE lines at the end of install.
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
- prune: `bash install.sh prune --keep-list <file>` — removes only the components that don't fit the project (core hooks and cross-agent entry files are refused); removed files are backed up under `logs/harness-backup/` and restorable via `rollback`. Usually invoked automatically by the `/carve-harness-create` skill after analysis.
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
| `npm test` / `npm run test:install` | all 14 hook test suites / installer component-selection suite |

For customization (protected paths, formatters, verify commands, new stacks) and the full reference, see **`GUIDE.md`**.

## Full component list (skills · commands · hooks)

### Skills (26)

| Skill | Group | Purpose |
|------|------|------|
| `anti-ai-slop` | core | Anti-slop gate before any visual output (blocks gradients/glow/decoration) |
| `carve-guide` | core | Author harness HTML output — design system · anti-slop · 1000px embed-safe (§release-refresh mode is repo-only) |
| `handoff` | core | Hand off progress to `specs/HANDOFF.md` before session end/compaction |
| `changelog` | core | Record irreversible decisions + rationale in `specs/DECISIONS.md` |
| `version-changelog` | core | Sync VERSION · CHANGELOG · README version history on release |
| `carve-harness-create` | core | Detect stack, prune components that don't fit → tailored harness |
| `codebase-design` | design | Shared vocabulary for deep-module design |
| `design-an-interface` | design | Generate several interface designs via parallel sub-agents |
| `domain-modeling` | design | Build/sharpen the domain model & ubiquitous language |
| `improve-codebase-architecture` | design | Scan for deepening opportunities → HTML report → apply |
| `prototype` | design | Throwaway prototype to answer a design question |
| `implement` | build | Implement from a PRD or set of issues |
| `qa` | build | Conversational QA → file GitHub issues |
| `request-refactor-plan` | build | Tiny-commit refactor plan filed as an issue |
| `migrate-to-shoehorn` | build | Migrate test `as` assertions → `@total-typescript/shoehorn` |
| `resolving-merge-conflicts` | build | Resolve an in-progress merge/rebase conflict |
| `setup-pre-commit` | build | Set up Husky + lint-staged pre-commit hooks |
| `teach` | docs/learn | Teach a new concept or skill |
| `edit-article` | docs/learn | Edit articles for structure & clarity |
| `scaffold-exercises` | docs/learn | Scaffold exercise directory structures |
| `to-prd` | docs/learn | Turn the conversation into a PRD on the issue tracker |
| `to-issues` | docs/learn | Break a plan/PRD into independently-grabbable issues |
| `loop-me` | docs/learn | Interrogate specs for workflows you want to build |
| `ask-matt` | docs/learn | Router — which skill/flow fits your situation |
| `setup-matt-pocock-skills` | setup | Set up engineering skills for this repo (tracker, labels) |
| `theme-factory` | vendor | Apply color/font themes to artifacts — anti-slop gate still applies |

> The vendored skill (`theme-factory`) is SKILL.md-only, sourced from `composiohq/awesome-claude-plugins`. Plugins `frontend-design` (design direction) and `ponytail` (simplification) ship as settings.json declarations, not skills.

### Slash commands (14)

| Command | Purpose |
|------|------|
| `/harness-audit` | 42-check PASS/FAIL of the harness configuration |
| `/plan` | Break work into success-criteria (SC) units → `specs/` |
| `/verify` | Verify current changes against SC · build · types · tests |
| `/review` | Review a diff for types, security, exceptions, state |
| `/commit` | Prepare a commitlint-compliant commit message |
| `/squad` | Invoke a Squad agent — `/squad <member> [task]` |
| `/squad-plan` | Feature planning |
| `/squad-review` | Code review |
| `/squad-qa` | Run QA tests |
| `/squad-refactor` | Refactor code |
| `/squad-debug` | Debug an issue |
| `/squad-audit` | Security audit |
| `/squad-docs` | Generate docs |
| `/squad-gitops` | Git workflow (commit · PR · changelog) |

### Hooks (9 — 4 event gates · 2 shared helpers · 3 manual CLI)

| Hook | Trigger | Role |
|------|------|------|
| `pretool-guard` | PreToolUse | Block writes to protected paths, secrets, dangerous git (exit 2); fail-closed |
| `posttool-format` | PostToolUse | Detect language by extension and format (post-process, exit 0) |
| `stop-verify` | Stop | Build/type/test gate for changed stacks (exit 2 on failure) |
| `session-handoff` | SessionStart · PreCompact · SessionEnd | Restore/save handoff + config banner |
| `log-event` | subprocess call | JSONL observability append — single source for schema & PII masking |
| `lib-protected` | sourced | Single definition of the protected-path regex (pure data) |
| `harness-audit` | manual `/harness-audit` | 42 read-only checks PASS/FAIL |
| `logs-report` | manual CLI | JSONL verdict summary + N-day rotation |
| `eval-java` | manual scorer | Deterministic Java/Spring quality probability `P∈[0,1]`, no LLM |

## Layout

```
├── CLAUDE.md / AGENTS.md    # canonical rules (Claude / cross-agent)
├── VERSION · CHANGELOG.md · RELEASE.md
├── install.sh / uninstall.sh   # install·update·rollback·setup / removal
├── vendor/bin/              # bundled jq·shellcheck (+ SHA256SUMS)
├── .githooks/              # pre-commit·commit-msg (agent-agnostic commit gate)
├── specs/                   # state: handoffs & decision log
└── .claude/
    ├── settings.json        # 6 hook events registered
    ├── hooks/  (9 + 14 test suites)
    ├── workflows/ (fable-team-pipeline)
    ├── commands/ (14) · agents/ (20) · skills/ (26) · rules/ (18)
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
| v0.0.13 | 2026-07-12 | `carve-guide` generalized HTML-authoring skill + **bundled** (25→26 skills) · embed hardening (1000px `!important` width · SPA TOC crash fix · new-window demo) |
| v0.0.12 | 2026-07-11 | project-aware build (tailored/manual choice · `carve-harness-create` prune) · **hook-dir self-heal fix** (partial install → all-commits-blocked bug) · **local lint gate** (shift-left) · `theme-factory` vendored + `frontend-design` declared · component tables & demo · 25 skills · 14 test suites (172 cases) |
| v0.0.11 | 2026-07-10 | checkbox TUI component selection · session banner inventory + unified `[carve-harness:<hook>]` prefix · LSP (vtsls/jdtls) + ponytail plugin declarations · public source repo (no token needed) |
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
