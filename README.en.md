<p align="center">
  <img src="docs/carve-banner.svg" alt="carve-harness — carve away the excess, keep the craft" width="680">
</p>

<p align="center"><b>Keep what's essential. Carve away the rest.</b></p>

<p align="center"><a href="./README.md">한국어</a> · <b>English</b></p>

## Update
> **Changelog** — full history in [CHANGELOG.md](CHANGELOG.md)
> - `2026-06-11` **v1.3.4** — Critical fix: installed hook commands now registered with `$CLAUDE_PROJECT_DIR` absolute paths (relative paths failed with `No such file` for every hook) + `carve update` now auto-migrates existing installs → [Existing users](#existing-users-v134-hook-path-fix)
> - `2026-06-10` **v1.3.3** — Quick start restructured into 4 stages (first install · install options · update · removal), distinguishing CLI (tool) vs harness install (README KR/EN)
> - `2026-06-08` **v1.3.2** — install guide switched to global-install-first (`npm i -g`) across README · INSTALL
> - `2026-06-08` **v1.3.1** — `anti-ai-slop` shared rule in `init-claude` · progressive command guide in README · release script (`scripts/release.sh`)
> - `2026-06-06` **v1.3.0** — Autonomous fix loop (`iterate`) · plan separation/verification · context diet + full audit patch (critical: `update` deadlock fixed)
> - `2026-06-05` **v1.2.0** — Lifecycle (`diff`/`update`/`migrate`) · smarter analysis (monorepo/container weighting) · opt-in local telemetry (`carve report`)
> - `2026-06-02` **v1.1.0** — Project-tailored harness install CLI (MVP): analyze → design → generate → audit → idempotent install

# carve-harness

**carve-harness** is a harness-engineering tool for developers that assembles only the essentials for development — nothing more.

> A CLI that analyzes a project and interactively selects and installs a harness (skills, hooks, subagents) tailored to that project.

**v1.3.4** · TypeScript (ESM, no build step) · Node >=22.18 · 206 tests / ~95.8% coverage

`carve` reads the codebase to detect the project type and tooling, then recommends suitable components.
It installs only what the user selects into `.claude/`. carve = carving general-purpose assets down to fit a project.

Optimize per project: say **"set up a harness for this project"** to compose the full harness (with optional
component selection), use `harness-audit` to actually check the integrity of the current install, or use
`harness-architect` to pick and prune components to fit the project.

The core behavior is verified in a single line:

```
carve install → stack detection → (component selection) → generate assets into .claude/
              → the generated verification hooks deterministically block dangerous commands with exit code 2
```

## Features

- Token efficiency built in: codesight (structure-map MCP) and LSP (cclsp MCP) are auto-registered at install time — precise search instead of grep, with no separate installation.
- Deterministic safety: dangerous commands (`rm -rf /`, fork bombs) and secret files (`.env`, keys) are forcibly blocked with exit code 2 (not just advisory).
- Tailored selective installation: detection → recommendation → user selection. No bulk install; idempotent reinstall and clean removal.
- anti-slop generation: AI slop in HTML, SVG, and documents is gated by a linter.
- 100% preservation of Squad subagents: 9 specialists (+evaluator) with keyword routing and chaining.
- Self-verification: before installing, the auditor scans generated assets for secrets, excessive permissions, hook injection, and shell syntax.
- Zero build: runs `.ts` directly. Distributed via both npx and bash.

## Quick start — global install recommended

> Full manual: [INSTALL.md](./INSTALL.md) (Korean) · [INSTALL.en.md](./INSTALL.en.md) (English) — requirements, modes, troubleshooting.

Install `carve` as a permanent command and every `carve …` in these docs (especially the recurring `update`/`diff`/`doctor`) works as written. **For the full feature set, a global install is recommended.**

> **Two distinct installs**: `npm i -g carve-harness` installs the **carve CLI (the tool)** on your system once; `carve install` uses that CLI to install the **harness into the current project** (`.claude/`). The former is once per machine; the latter is per project.

### 1. First install

```bash
npm i -g carve-harness         # install the carve CLI (the tool) — once per machine
carve install                  # interactive selective install into the current project (detect → recommend → select)
carve init-claude              # CLAUDE.md baseline + language stack rules
carve doctor                   # inspect install (config, hook syntax)
```

After install, just **open Claude Code** in the project: hooks and MCP (codesight·LSP) turn on automatically, and skills/Squad are called via natural language or `/carve-<name>`.

> **Just trying it once (no global)**: `npx carve-harness@latest install` (prefix every run with `npx carve-harness@latest <cmd>`). But `npx` is one-shot — it leaves no `carve` on PATH, which is awkward for recurring commands like `update`/`uninstall`, so **`npm i -g` is recommended for full use**. (repo-clone/`curl` users can use the `install.sh` wrapper — see [INSTALL.md](./INSTALL.md).)

### 2. Install options (non-interactive · forced selection)

Skip the wizard and pin the level/components with flags. (For what the levels mean, see **Install levels** below.)

```bash
carve install --level full                   # Force level (minimal|standard|full)
carve install --only commit,handoff,review   # Explicit selection (no bulk install)
carve install --lsp-servers                  # Auto-install LSP language servers
```

### 3. Update

The CLI (the tool) and the project harness are updated separately.

```bash
npm i -g carve-harness@latest   # 1. update the carve CLI (the tool)
carve diff                      # 2. (optional) 3-way compare installed vs latest assets (read-only)
carve update                    # 3. update the project harness — carve-updated files only, your edits kept as .bak (--force · --yes)
```

#### Existing users (v1.3.4 hook-path fix)

Projects installed with v1.3.3 or earlier have hook commands written as **relative paths** (`bash .claude/hooks/carve-*.sh`) in settings.json. When Claude Code runs a hook from a directory other than the project root, they fail with `No such file or directory`. From v1.3.4 they are registered with absolute paths (`$CLAUDE_PROJECT_DIR`).

If you already installed, fix it either way:

```bash
# Recommended — auto-migrate, no reinstall
npm i -g carve-harness@latest   # 1. get the fixed carve CLI (migration won't run without this)
carve update                    # 2. one-time in-place rewrite of carve hooks to absolute paths (idempotent · user hooks untouched)

# Or — clean reinstall
carve uninstall && carve install
```

### 4. Removal

Remove just the harness, or the CLI (the tool) too.

```bash
carve uninstall                 # 1. remove the project harness — carve files only · restore .bak · preserve your settings
npm uninstall -g carve-harness  # 2. (optional) remove the carve CLI (the tool)
```

## Daily workflow — natural language in a session

Four commands cover everyday use. Call them in natural language or via `/carve-<name>`.

| What you want | How to call | What it does |
|---|---|---|
| Commit message | "write a commit message" · `/carve-commit` | Generates a Conventional Commit |
| Code review | "review this" · `/carve-review` | Review delegated to squad-review |
| Session handoff | "handoff" · `/carve-handoff` | Leaves progress/decisions/next steps for the next session |
| Remember a decision | "remember this" · `/carve-memory` | Persistent project memory |

And the **block / protect / format hooks run automatically — no need to call them**: dangerous commands (`rm -rf /`, fork bombs) and secret files (`.env`, keys) are stopped with `exit 2` (not advisory), the formatter runs on save, and lint/test are enforced before commit/push.

> This is "easy carve" — 3 lines to install, 4 for daily use. Go below only when you want to dig deeper.

## Going deeper — commands by scenario (the more you use, the more advanced)

Add them one at a time as needed. All are part of the install (by level) and cost no context until you call them (on-demand loading). Two ways to call: **skills** via natural language or `/carve-<name>`; **Squad specialists** via `/squad <member>` or `/squad-<member>` (the `squad-…` entries below are those members).

**Code quality & verification**
- `verify` — `build→lint→test→typecheck` in one go ("run the verify loop")
- `iterate` — diagnose→fix→re-run until tests are green, report only the final result ("fix it until it passes")
- `squad-refactor` extract/simplify · `squad-debug` root cause · `squad-evaluator` independent evaluation against completion criteria (Self-Eval Blindspot)

**Testing**
- `test-gen` tests from UAT criteria · `tdd` red-green-refactor first · `squad-qa` test execution & QA report

**Security**
- `security-scan` security gate (delegates to squad-audit) · `squad-audit` security audit & vulnerability scan

**Release & collaboration**
- `pr` PR body · `changelog` CHANGELOG updates · `squad-gitops` commits/PRs/changelog · `squad-docs` docs · `squad-plan` planning/user stories

**Docs & visuals (anti-slop)**
- When generating HTML, SVG, card news, reports, and slides, AI slop (gradients, glow, watermarks, etc.) is removed and `check-slop` gates deterministically ("make a slop-free html")

**Multi-agent & cost**
- `parallel-agents` 3–4 in parallel + git worktree isolation · `coordinator` mailbox/TeamCreate orchestration · `model-route` Haiku/Sonnet/Opus routing · `evaluator-tuning` few-shot evaluator correction

**Other helpers** — `caveman` ultra-compression (~75% fewer tokens) · `write-a-skill` skill scaffolding · `zoom-out` system-level view. *(tdd, caveman, write-a-skill, zoom-out are rewrites of [mattpocock/skills](https://github.com/mattpocock/skills) patterns, MIT)*

**9 Squad specialists** — call via `/squad <member> [task]` (e.g. `/squad review`) or directly `/squad-<member>` (e.g. `/squad-refactor src/`); keyword auto-delegation also works. Members: review · plan · refactor · qa · debug · docs · gitops · audit · evaluator (the actual agent name is `squad-<member>`).

**Automatic hooks (event-based · no need to call)** — blocking hooks are deterministic `exit 2`, not advisory:
`block-destructive` (dangerous commands) · `protect-secrets` (.env/keys) · `pre-commit-lint` (before commit) · `pre-push-test` (before push) · `auto-format` (after save) · `precompact-handoff` (persists state before compaction) · `slack-notify` (at session end, if a webhook is set) · `auto-commit` (optional, OFF by default).

### Harness lifecycle management (CLI)

Commands for managing the harness itself after install. You can ignore these day-to-day — reach for them only when a new carve ships or you want to inspect the install.

```bash
carve list      # List installable / installed components
carve diff      # 3-way compare installed assets vs current carve assets (read-only)
carve update    # Refresh carve-updated assets in place, preserving your edits (--force · --yes)
carve migrate   # Promote carve-manifest schema v1 → v2
carve report    # Aggregate what the installed hooks actually blocked (opt-in, no network)
carve uninstall # Clean removal — removes only carve files, restores .bak, preserves your settings
```

Within a session, the `harness-audit` skill checks install integrity (hook registration, shell syntax, assets).

## Install levels (auto-determined by profile, forceable with `--level`)

Core skills, the 9 Squad agents, and anti-slop are recommended at *every level*; what changes by level is the **number of hooks and additional skills**.
- `minimal` — small CLI/library/batch: core + 9 Squad + anti-slop + **3 essential hooks** (block, protect, handoff)
- `standard` (default) — general apps: minimal + **the remaining core hooks** (7 total: +lint, test, format, Slack)
- `full` — standard + **additional skills** (verify, iterate, security-scan, test-gen, parallel-agents, coordinator, etc.)

For the force-level (`--level`), explicit-selection (`--only`), and LSP-auto-install commands, see **Quick start → Install options** above.

> The score (the number in parentheses in `carve list`, ≥75) is carve's internal usefulness assessment. For per-level defaults and the full component list, see [INSTALL.en.md](./INSTALL.en.md).

Supported projects: CLI · web · mobile · responsive · desktop · batch.

## CLAUDE.md baseline + stack rules (`carve init-claude`)

After installation, running `carve init-claude` carves out a working-guideline baseline and per-language stack rules.

- `.claude/CLAUDE.md` — stack-agnostic baseline: think before coding, simplicity, surgical changes, TDD, commit discipline, response control, hallucination guard, safety guardrails.
- `.claude/rules/*.md` — 6 best-practice rules for the detected language (`techstack`, `project-structure`, `commands`, `code-style`, `safety`, `gotchas`) + a stack-agnostic `anti-ai-slop` rule (visual/document slop prevention).
- The root `CLAUDE.md` is automatically wired to `@import` these (idempotent). They are loaded together each session.

The stack is auto-selected by the detected language (TypeScript/JavaScript, Python, Go, Rust, Java, Dart; otherwise `_default`). Package manager and test/lint commands are substituted with values detected from the project. Within a session, the harness-architect skill guides the same flow as the "CLAUDE.md setup" step.

## anti-slop visual and document generation

When creating HTML, SVG, card news, reports, slides, and documents, it removes AI-characteristic decorations (gradients, glow/colored shadows,
glassmorphism, motion decorations, watermarks, marketing boilerplate) and builds hierarchy through size, spacing, alignment, and typography.
The rules are injected by the skill before generation, and after generation the `check-slop.mjs` linter checks deterministically.
A script gates it — not the model's eyeballing (warning mode, with an exception path for intentional use).

## Token efficiency (built in)

codesight and LSP are auto-registered at install time, so token-efficient search applies without the user installing anything separately.

- codesight MCP: pre-maps the project structure (routes, schemas, dependencies) → eliminates the cost of repeated grep searches (measured ~11x on average for large codebases).
- LSP (cclsp MCP): precise search via `findReferences`/`getDiagnostics` → about 500 tokens instead of 2,000+ tokens for grep.
- Guidance is added to `flight-rules.md` and `CLAUDE.md` so that all skills and Squad subagents prefer these over grep.
- Language server binaries are auto-installed for the detected language during interactive install (or `carve install --lsp-servers`).

> Verification of savings figures via large fixture benchmarks is planned. For small one-off tasks, the effect may be small due to the fixed MCP cost.

## Safety

- Dangerous commands (`rm -rf /`, fork bombs, etc.) and secret files (`.env`, keys) are blocked by PreToolUse hooks with exit code 2.
- Lint before commit and test before push are enforced.
- Before installation, the auditor scans generated assets for secret exposure, excessive permissions, and hook injection (must pass to install).

## Architecture

```
analyzer → catalog → (wizard selection) → designer → generator → auditor → installer
```

It distinguishes two layers: Layer A is the carve CLI itself (`bin/`, `src/`, `assets/`, `vendor/`),
and Layer B is the artifacts carve installs into the target project (`<project>/.claude/`).
For details see [ARCHITECTURE.md](./ARCHITECTURE.md), and for requirements see [requirement.md](./requirement.md).

## Development

Written in TypeScript (ESM), but with no build step during development. It runs `.ts` directly via type stripping in Node >=22.18.
(For distribution, type stripping is blocked in `node_modules`, so `prepack` compiles `.ts`→`.js` and ships it.)

```bash
npm test          # Unit + E2E (node --test)
npm run test:cov  # Coverage gate (>=80)
npm run check     # Type check (tsc --noEmit)
npm run build     # Distribution compile (tsconfig.build.json, in-place .js)
```

Milestone progress log: [docs/milestones/](./docs/milestones/)

## Release (npm publishing)

Publishing is **automatically published from main by GitHub Actions when a version tag (`vX.Y.Z`) is pushed** (`.github/workflows/release.yml`).
`npm publish` automatically runs `prepublishOnly` (type check + tests) and `prepack` (build), so it will not publish if tests fail.

For the full order (develop development → main promotion → tag publishing), see **[docs/release/RELEASE.md](./docs/release/RELEASE.md)**.

## Quantitative evaluation (internal measurement)

Internally measured against 6 axes ([carve-harness-benchmark-criteria.md](./docs/guide/carve-harness-benchmark-criteria.md)).
Deterministic items are reproduced via `node bench/run.mjs`. Measured 2026-05-31 · **at v1.1.0** (not yet re-measured for later versions; the measured axes are architecture-level, so largely still valid — figure re-validation is planned).

**Evaluation axes**

| Axis | What is measured | carve differentiator |
|----|-----------|-------------|
| 1. Speed/efficiency | Token, time, $, KV-cache, context injection cost | ★ Core — "carved lightweight" |
| 2. Control/safety | Block accuracy, permission leak rate, false blocks, determinism | Deterministic hooks vs advisory (0% vs N% leakage) |
| 3. Prompt verification | Trigger accuracy, false firing, routing, instruction adherence | Borrows the Squad test-router pattern |
| 4. Context verification | Occupancy, compaction retention rate, premature completion, on-demand loading | Adheres to the 40% rule |
| 5. Functional E2E | Skill firing, hook triggering, E2E pass, regression safety | Playwright verification |
| 6. Composition quality | Composition accuracy (F1), over-generation, omission, idempotency, audit | ★ carve-specific — competing harnesses have nothing to measure here at all |

**Measurement results**

| Axis | Score | Measured value |
|----|:--:|--------|
| 1. Speed/efficiency | Pending | Install footprint full 49 → minimal selection 7 files (**85.7% reduction**) |
| 2. Control/safety | **100** | Block 100% · leakage 0% · false block 0% · determinism 100% |
| 3. Prompt verification | **100** | Keyword routing 100% · false firing 0% |
| 4. Context verification | Pending | 14 on-demand skills split into individual files |
| 5. Functional E2E | **100** | Tests 96/96 · hook firing 8/8 |
| 6. Composition quality | **100** | Type-detection F1 100% · audit 0 issues · idempotency 100% · no over-generation |

### Score rationale (why these results)

- **2. Control/safety = 100**: 13 dangerous seeds (8 destructive commands + 5 secret files) were injected and all blocked with `exit 2` (block 100%, leakage 0%);
  9 safe seeds had 0% false blocks, and `rm -rf /` repeated 5 times was blocked every time (determinism 100%). Because they are **deterministic code hooks** rather than advisory, leakage is structurally 0.
- **3. Prompt verification = 100**: 8 keyword seeds (review, test, debug, security, refactoring, planning, docs, commit) were fed into the Squad router and
  all delegated to the correct agent (routing 100%), with 0% false firing for 3 non-trigger seeds. (Instruction adherence requires an LLM session → only routing and false firing measured.)
- **5. Functional E2E = 100**: all 96 unit+E2E tests pass, with syntax and `exit code` firing verified for 8 hooks. Includes PoC pass scenarios.
  (Playwright live-app verification was replaced with harness-behavior E2E since there is no target app.)
- **6. Composition quality = 100**: type-detection F1 100% across 5 fixtures (cli/web/mobile/desktop/batch), 0 auditor ERRORs in generated assets,
  identical `settings.json` on reinstall (idempotency 100%), and no over-generation since only what was chosen with `--only` is installed.
- **1. Speed/efficiency = Pending**: the structural basis of the carving effect (recommended 49 files → minimal selection 7 files, 85.7% reduction) was measured, but
  the core metrics (token, time, $, KV-cache) require running the same task with other harnesses via an LLM to compare → score pending.
- **4. Context = Pending**: the on-demand loading structure (14 skills in individual files) was measured, but occupancy, the 40% rule, compaction retention, and premature completion
  require live-session measurement → score pending.

> Honest disclosure: the self-measurable axes 2, 3, 5, and 6 are deterministically full marks. The comparative/live metrics of axes 1 and 4 are
> withheld without estimation (criteria §10). Proving comparative advantage still requires running `bench/` against other harnesses.
> Per-metric one-line evaluation table: [carve-harness-benchmark-results.md](./docs/guide/carve-harness-benchmark-results.md).

### Live cross-harness measurement (n=5, CRUD, same model, `claude -p`)

| harness | $/task (median) | tokens (median) | E2E success | leak rate (axis 2) |
|---------|:--:|:--:|:--:|:--:|
| no-harness | $0.101 | 3,554 | 5/5 | 100% |
| squad | $0.148 | 6,106 | 5/5 | 100% |
| **carve** | $0.159 | 7,076 | 5/5 | **0%** |
| ecc | $0.382 | 13,314 | 5/5 | — |

> **Scope/interpretation**: this is a measurement of one-off, simple CRUD (n=5) in a small project. In this range the fixed harness overhead (context, MCP) is large, so **it is normal for the harness to be at a disadvantage on token/$** (small projects rarely show token gains from a harness), and the token advantage appears in **medium-to-large codebases**. What carve proves here is not token savings but **safety (0% leakage), equal success, and being lighter than ECC**. Leak rate = the proportion of dangerous commands that pass unblocked (only carve has a deterministic blocking hook; ecc's "—" is not comparable due to a different mechanism).

- **carve vs ECC**: cost **58%↓** · tokens **47%↓** · equal success (5/5) — ECC injects globally (129 skills + rules), while carve carves and installs only what is needed → empirically proving "tailored lightweight."
- **carve vs no-harness**: for one-off CRUD, context injection raises cost (1.57×), but carve's advantage is not tokens but **safety (0% leakage vs 100% — only carve has deterministic hooks)**.
- The v1.0 codesight/LSP token-efficiency savings are an addition made after the above measurement, to be re-measured with large fixtures (small one-offs show little effect due to the fixed MCP cost).
- Measurement method and all 28 metrics: [carve-harness-benchmark-results.md](./docs/guide/carve-harness-benchmark-results.md).

## Credits

Some additional skills (`tdd`, `caveman`, `write-a-skill`, `zoom-out`) were inspired by patterns from [mattpocock/skills](https://github.com/mattpocock/skills) (MIT) and
rewritten into the carve format.

## License

MIT
