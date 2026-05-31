# Changelog

All notable changes to this project will be documented in this file.

## [1.3.2] - 2026-04-11

### Added

- **Automated test suite**: `tests/test-router.sh` (67 cases), `tests/test-files.sh` (78 cases), `tests/run-all.sh` unified runner
- **Pre-commit hook**: `install.sh --dev` registers git pre-commit that runs all tests on commit
- **Router enforcement**: `additionalContext` message changed to "MUST delegate" to ensure subagent execution

### Changed

- **CI pipeline**: Replaced manual frontmatter checks with `test-router.sh` + `test-files.sh`
- **VERSION**: Bumped to 1.3.2

## [1.3.1] - 2026-04-11

### Changed

- **README restructure**: `README.md` → Korean (default), `README.en.md` → English (previously `README.ko.md` removed)
- **Hook mechanism docs**: Added "동작 원리 / How It Works" section explaining UserPromptSubmit context injection flow
- **Agent tool reference**: Updated all docs from "Task tool" to "Agent tool" to match current Claude Code API
- **Version section**: Replaced token economics with version history table in both READMEs

### Fixed

- **shellcheck SC2221/SC2222**: Reordered glob patterns — `*"문서화"*` before `*"문서"*` to prevent unreachable pattern
- **shellcheck SC1071**: Excluded zsh script (`subagent-chain.sh`) from CI shellcheck (unsupported shell)

## [1.3.0] - 2026-04-01

### Added

- **Squad Router Hook**: `UserPromptSubmit` hook that auto-detects keywords in user prompts and routes to the appropriate squad subagent via context injection
  - 80 keywords (42 Korean / 38 English) across 8 agents
  - 3-phase matching: skip conditions → conflict resolution (6 multi-word patterns) → general keywords (priority-ordered)
  - Opt-out via `--no-route` (per-prompt), `SQUAD_ROUTER=off` (global), or slash commands (auto-skip)
  - Uses `hookSpecificOutput` with `hookEventName` for reliable context injection
- **docs/SQUAD-ROUTER-KEYWORDS.md**: Complete keyword reference with hit rates and exclusion rationale
- **install.sh**: Auto-registers `UserPromptSubmit` hook in `settings.json` alongside existing SubagentStart/SubagentStop hooks

## [1.2.1] - 2026-04-01

### Added

- **Cross-platform notifications**: `subagent-chain.sh` now auto-detects OS and sends native notifications — macOS (`osascript` + `afplay`), Linux (`notify-send` + `paplay`/`aplay`), Windows/WSL (`PowerShell` popup)
- **Notification customization guide**: README documents how to disable notifications, change sounds, filter by agent, or replace with Slack/ntfy webhooks
- **Subagent verification**: All 8 agents confirmed as independent sub-agents (`isSidechain: true` in transcript) with correct model routing — opus (review, plan, refactor, debug, audit), sonnet (qa, docs), haiku (gitops)
- **docs/ARCHITECTURE.md**: Added Subagent Verification section with test results and methodology

### Changed

- **subagent-chain.sh**: Replaced terminal `echo` with OS-native notifications. Claude Code is a TUI app — `stdout`/`stderr` from `SubagentStart`/`SubagentStop` hooks are not displayed in the terminal, so native notifications are the only visible channel
- **README.md**: Updated Pipeline Hooks section with cross-platform notification docs, added Notifications section with platform support table, bilingual (EN/KO) throughout with anchor links

## [1.1.3] - 2026-04-01

### Added

- **SubagentStart/Stop banners**: Console banner display when squad agents start/stop
- **SHA256 checksum verification**: Remote install now verifies archive integrity
- **Auto hook registration**: `install.sh` automatically registers SubagentStart and SubagentStop hooks via `jq`
- **Boundaries section**: All 8 agents now have explicit Will/Will Not boundaries

### Fixed

- **subagent-chain.sh**: Fixed shebang mismatch (`bash` → `zsh`) to match execution shell
- **subagent-chain.sh**: Fixed field name (`agent_name` → `agent_type`) to match actual schema
- **squad-docs**: Workflow now uses Glob tool instead of Bash `find` command
- **install.sh**: Version read from VERSION file to eliminate dual management

### Improved

- Standardized Bash section names (`Allowed Commands` / `NEVER Run`) across all agents
- Standardized tool ordering (`Read, Bash, Glob, Grep`) across all agents
- Semver tag validation for remote install (`^v[0-9]+.[0-9]+.[0-9]+$`)
- Release workflow generates `.sha256` checksum file alongside archive
- README updated with accurate tool lists and auto-hook documentation
- Uninstall docs note that settings.json hooks require manual removal

## [1.1.0] - 2026-04-01

### Fixed

- **squad-docs**: Added safety rules — NEVER modify source code, Boundaries (Will/Will Not)
- **squad-plan**: Added safety rules, Boundaries, Bash Whitelist/BLACKLIST (had Write+Bash with zero restrictions)

### Improved

- All 8 agents now include `Pipeline:` line in description for workflow context
- Standardized tool ordering across all agents (`Read, Bash, Glob, Grep` / `Read, Write, Edit, Bash, Glob, Grep`)
- Extracted inline bash restrictions into dedicated `Allowed Commands` / `NEVER Run` sections (squad-audit, squad-review, squad-gitops)
- Replaced emoji (✅/❌) with text (PASS/FAIL) in squad-qa output format for consistency
- Enhanced squad-plan command with output description
- Enhanced squad-debug command with input format and output description

## [1.0.0] - 2026-04-01

### Added

- 8 specialized agents: review, plan, refactor, qa, debug, docs, gitops, audit
- 9 slash commands including universal `/squad` command
- SubagentStop pipeline chaining hook
- One-line install script (local + remote + uninstall)
- GitHub Actions release automation
- Bilingual README (EN + KO)
- Architecture documentation and pipeline diagram
