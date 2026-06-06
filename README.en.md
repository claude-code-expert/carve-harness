<p align="center">
  <img src="docs/carve-banner.svg" alt="carve-harness — carve away the excess, keep the craft" width="680">
</p>

<p align="center"><b>Keep what's essential. Carve away the rest.</b></p>

<p align="center"><a href="./README.md">한국어</a> · <b>English</b></p>

> **Changelog** — full history in [CHANGELOG.md](CHANGELOG.md)
> - `2026-06-05` **v1.2.0** — Lifecycle (`diff`/`update`/`migrate`) · smarter analysis (monorepo/container weighting) · opt-in local telemetry (`carve report`)
> - `2026-06-02` **v1.1.0** — Project-tailored harness install CLI (MVP): analyze → design → generate → audit → idempotent install

# carve-harness

**carve-harness** is a harness-engineering tool for developers that assembles only the essentials for development — nothing more.

> A CLI that analyzes a project and interactively selects and installs a harness (skills, hooks, subagents) tailored to that project.

**v1.2.0** · TypeScript (ESM, no build step) · Node >=22.18 · 191 tests / ~95.6% coverage

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

## Installation & Usage

> **Full installation manual**: [INSTALL.md](./INSTALL.md) (Korean) · [INSTALL.en.md](./INSTALL.en.md) (English)
> — covering requirements, install modes, per-level components, and troubleshooting in detail.

**Full install flow (3 steps)**

```bash
npx carve-harness              # 1. Interactive selective install (detect → recommend → select)
npx carve-harness init-claude  # 2. Generate CLAUDE.md baseline + language stack rules
npx carve-harness doctor       # 3. Inspect installation (config, hook syntax)
```

When installing into another project, **`npx carve-harness` is the standard** (run it in the folder you want to install into). `install.sh` is not included in the npm package, so it is only a convenience wrapper for when you have cloned this repo or fetched it via `curl` (internally it calls `npx carve-harness@latest`).
Within a session, saying **"set up a harness that fits this project"** lets the harness-architect skill guide the same flow.

**Command reference**

```bash
carve              # = carve install — interactive selective install (no bulk install)
carve install --level full        # Force level (minimal|standard|full). full = includes multi-agent parallelism and coordination
carve install --only commit,handoff,block-destructive   # Non-interactive explicit selection
carve install --lsp-servers       # Auto-install LSP language servers
carve init-claude  # Generate CLAUDE.md baseline + .claude/rules/* (based on language stack)
carve list         # List installable / installed components
carve doctor       # Inspect the installed harness (config + hook shell syntax)
carve uninstall    # Clean removal (.bak restore)
```

**Install levels** (automatically determined by profile, can be forced with `--level`). Core skills, the 9 Squad agents, and anti-slop are recommended by default at *every level*; what changes by level is the **number of hooks and additional skills**:
- `minimal` — small CLI/library/batch: core skills + 9 Squad agents + anti-slop + **3 essential hooks** (block, protect, handoff)
- `standard` (default) — general apps: minimal + **the remaining core hooks (7 total:** +lint, test, format, Slack)
- `full` — standard + **additional skills** (verify, security-scan, test-gen, parallel-agents, coordinator, etc.)

**Removal**: `carve uninstall` (= `bash install.sh --uninstall`). Based on `carve-manifest.json`, it removes only the files carve installed and
restores the original from `.bak` if present. It removes exactly the carve hook and MCP entries in `settings.json` (preserving user entries). See [INSTALL.en.md](./INSTALL.en.md#11-uninstall) for details.

## What gets installed — component catalog (roles, usage)

Four invocation methods: **Skills** = natural language or `/carve-<name>` · **Hooks** = automatic (events) · **Squad** = `/squad <member> [task]` or keyword delegation · **MCP** = automatic.
After installation, when you **open Claude Code** in that project, hooks and MCP are immediately active, while skills and Squad are invoked via the methods below.

**Token efficiency (MCP · automatic, built in)**

| Component | Role | Usage |
|----------|------|--------|
| codesight | Project structure-map MCP — structural queries instead of repeated grep searches (~11x fewer tokens for navigating large codebases) | Automatic. Refreshes `.codesight/` on git commit |
| lsp (cclsp) | Precise code-navigation MCP such as `findReferences` and `getDiagnostics` | Automatic. Install language servers with `--lsp-servers` |

**Core skills (natural language or `/carve-<name>`)**

| Skill | Role | Usage |
|------|------|--------|
| handoff | Session handoff — leaves progress, decisions, and next steps so the next session can pick up | "handoff" / `/carve-handoff` |
| memory | Persistent project memory — persists decisions and context | "remember this" / `/carve-memory` |
| commit | Generates Conventional Commit messages | "write a commit message" / `/carve-commit` |
| changelog | Generates and updates the CHANGELOG | "update the changelog" / `/carve-changelog` |
| review | Code review (delegates to squad-review) | "review this" / `/carve-review` |
| pr | Generates PR body | "write a PR body" / `/carve-pr` |
| harness-architect (entry) | Guides analysis → recommendation → selective install | "set up a harness that fits this project" |

**Hooks (automatic · events)** — blocking hooks are not advisory; they block deterministically with `exit 2`

| Hook | Event | Role |
|----|--------|------|
| block-destructive | PreToolUse(Bash) | Blocks dangerous commands such as `rm -rf /` and fork bombs |
| protect-secrets | PreToolUse(Read/Edit/Write) | Blocks access to `.env`, keys, and credentials |
| pre-commit-lint | PreToolUse(Bash) | Lints before `git commit`, blocks on failure |
| pre-push-test | PreToolUse(Bash) | Tests before `git push`, blocks on failure |
| auto-format | PostToolUse(Edit/Write) | Runs the formatter after save (non-blocking) |
| slack-notify | Stop | Slack notification at session end (when a webhook is configured) |
| precompact-handoff | PreCompact | Persists state right before compaction |
| auto-commit *(optional, OFF)* | Stop | Auto-commit at session end. Only when explicitly enabled interactively |

**9 Squad subagents (`/squad <member> [task]` or `/squad-<member>`)**

| Member | Role |
|------|------|
| squad-review | Code review (security, performance, style) |
| squad-plan | Feature planning, user stories, wireframes |
| squad-refactor | Extract, simplify, rename, remove |
| squad-qa | Test execution, QA report |
| squad-debug | Error analysis, root cause |
| squad-docs | Documentation generation and updates |
| squad-gitops | Commit messages, PRs, changelog |
| squad-audit | Security audit, vulnerability scan |
| squad-evaluator | **Independent evaluation** against completion criteria and the Sprint Contract (addresses the Self-Eval Blindspot) |

**anti-ai-slop pack (when generating docs/images)** — removes AI slop from HTML, SVG, card news, reports, and slides + the `check-slop.mjs` gate.
Usage: "make a slop-free html", "deslop this" — the linter automatically checks after generation/edits (warning mode).

**Additional skills (`full` level · natural language or `/carve-<name>`)**

| Skill | Role |
|------|------|
| verify | `build→lint→test→typecheck` verification loop |
| security-scan | Security gate delegating to squad-audit |
| test-gen | Generates tests from UAT criteria |
| tdd | red-green-refactor test-first *(mattpocock/skills, MIT)* |
| caveman | Ultra-compressed communication, ~75% fewer tokens *(MIT)* |
| write-a-skill | Reusable `SKILL.md` scaffolding *(MIT)* |
| zoom-out | Maps modules and call paths at a system-level view *(MIT)* |
| model-route | Routes tasks to a 3-tier Haiku/Sonnet/Opus (cost optimization) |
| parallel-agents | Minimal parallelization of 3–4 agents + git worktree isolation |
| evaluator-tuning | Collects evaluator misjudgments → few-shot correction |
| harness-audit | Self-inspection of the installed harness (doctor + registration, syntax, consistency) |
| coordinator | Multi-agent mailbox/TeamCreate coordination guide |

> See the **Install levels** table above for what is recommended by default at each level. The score (the number in parentheses in `carve list`, ≥75) is carve's internal usefulness assessment.

On installation, it generates `flight-rules.md`, `evaluation-criteria.md`, `sprint-contract.md`, `CLAUDE.md`, and `HARNESS-GUIDE.md` into the project.
Supported projects: CLI · web · mobile · responsive · desktop · batch.

## CLAUDE.md baseline + stack rules (`carve init-claude`)

After installation, running `carve init-claude` carves out a working-guideline baseline and per-language stack rules.

- `.claude/CLAUDE.md` — stack-agnostic baseline: think before coding, simplicity, surgical changes, TDD, commit discipline, response control, hallucination guard, safety guardrails.
- `.claude/rules/*.md` — 6 best-practice rules for the detected language: `techstack`, `project-structure`, `commands`, `code-style`, `safety`, `gotchas`.
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
Deterministic items are reproduced via `node bench/run.mjs`. Measured 2026-05-31 · v1.1.0.

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
