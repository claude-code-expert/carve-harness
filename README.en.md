<p align="center">
  <img src="docs/carve-banner.svg" alt="carve-harness — carve away the excess, keep the craft" width="680">
</p>

<p align="center"><b>Carve away the excess, keep the craft.</b></p>

# Claude Harness (language-agnostic drop-in)

[한국어](README.md) · Current version **v0.11.0** ([changes](CHANGELOG.md)) · [course](HARNESS_GUIDE.md) (Korean)

A guardrail template that **blocks** an agent's rule violations with **hook exit 2** instead of persuading. Drop it into a project root and it works immediately.

## Features

| Pillar | Behavior |
|--------|----------|
| **Constraints** | PreToolUse hook blocks writes to protected paths (`.env`, prod configs, migrations) and hardcoded secrets. Fail-closed when jq is missing or JSON is malformed. In an installed harness the hooks, `settings.json` and manifest cannot be edited or deleted either (the agent cannot switch the gates off) |
| **Feedback** | Stop hook blocks a completion claim on build/type/lint/test failure — incremental checks on changed stacks only (runs only when the toolchain is present) |
| **State** | Handoff auto-saved on session end/compaction (real TODOs + decisions), restored on start |
| **Observability** | Every hook verdict logged to `logs/*.jsonl` (PII masked). A session-start banner shows the loaded configuration |
| **Self-audit** | `/harness-audit` — 77 mechanical checks PASS/FAIL the harness configuration itself |
| **Language packs** | Only detected packs are installed — rules, verify gates, scorer adapters, golden-set starters and LSP as one set. Unselected languages have no files at all |
| **Verify loop** | `/verify-loop` — scores each implementation claim 0–100; anything under 95 is reworked. A Stop hook blocks completion while any item is short |
| **Quantitative eval** | `/eval` — re-runs a fixed golden set k times for pass@k/pass^k and regression |

**Inventory**: 22 hooks · 6 stack definitions · 6 language packs · 14 slash commands · 7 agents · 10 skills · 11 rule files · 3 workflows · 20 golden-set starters · 31 test suites (545 cases). Full lists in the [component tables](#full-component-list-skills--commands--hooks).

**Cross-agent**: hook blocking is Claude Code-only. Cursor/Codex/etc. follow `AGENTS.md` as the canonical rules, with `.githooks/pre-commit` as the final gate at commit time.

## Which projects fit

This harness **enforces with hooks**. It earns its keep only where there is a place to enforce.

- **Good fit** — a service codebase in one or more of TypeScript/React/Next · Java/Spring · Python/FastAPI · Go · Rust. Developed with **Claude Code**, a **git repo**, with **jq** and stack toolchains present, a test runner, PR-based work. Where there are "wrong = incident" paths (gateway, payment, auth), the verify loop and golden set pay off most.
- **Partial** — toolchains only in CI (local gates skip) · single-script/notebook repos (guards only) · monorepos (detection covers root and one level down).
- **No fit** — Ruby/PHP/C#/Swift/Dart primary (one stack file attaches it, per `GUIDE.md` §8.2) · non-git directories · native Windows shell (needs WSL) · research/doc repos where the agent barely writes code.

## Compare: with vs without the harness

<a href="https://claude-code-expert.github.io/carve-harness/docs/html/ohpen-demo/index.html" target="_blank" rel="noopener noreferrer">**Open the live demo (new window)**</a> — the landing page for **ohpen**, a macOS screen-annotation app, built twice by the same agent (Claude · Fable 5.1) from the same source documents: once with no harness, once with carve applied. Both pages sit side by side at 0.44× with three diff tables.

| Axis | Without harness | With harness | What caught it |
|---|---|---|---|
| **Visual** | check-slop **76 errors / 49 warnings** — 15 gradients · 11 colored shadows · 5 glassmorphism · 5 hover motions · 32 emoji · 11 marketing clichés | **0 errors / 3 warnings** (each justified) | `anti-ai-slop` hard gate + `check-slop.mjs` deterministic linter |
| **Facts** | 8 claims the source doc forbids — a Windows ETA, "100% offline", memory-based "lightweight", Pro pricing tiers, a download for the unreleased v0.2.0, "all tests pass", invented OS/zoom numbers, decoration filling in for assets that don't exist | canonical copy only, undecided items (T-xx) left as labelled placeholders, download button disabled | `CLAUDE.md` no unverified completion claims · AGENTS §1 never pretend empty input was filled · source doc §14 claim boundaries |
| **Safety · a11y** | hardcoded API key · `innerHTML` XSS · no `label`/`aria` | no forms or keys, `aria-label` · `alt` · `aria-disabled` | `safety.md` · `common/security.md` · `pretool-guard` GUARD-04 · a11y rules |

**Harness components that actually fired for this job**

- **`anti-ai-slop` skill (v2)** — a hard gate invoked *before* any visual work (bans gradients, glow, `blur≥20`, decorative motion, emoji bullets, card accent bars, marketing boilerplate). `references/visual-craft.md` (hierarchy, type scale, 8pt grid, contrast) is read right before authoring.
- **`check-slop.mjs` linter + `posttool-slop` hook** — the moment an `.html/.css/.svg` file is written or edited, PostToolUse runs the linter and reports one line, `N error, M warn` (report-only). ERROR 0 is the completion bar — an exit code, not eyeballing. Run it yourself: `node .claude/hooks/check-slop.mjs <file>`.
- **`carve-guide` skill** — the harness HTML design system (Pretendard + JetBrains Mono, neutral base + one accent, 1px borders, embed-safe anchor script).
- **Rules · hooks** — `safety.md` · `common/security.md` (secrets, XSS), `pretool-guard` (blocks secret writes), root `CLAUDE.md` absolute bans, AGENTS §0·§1.
- **Canon first** — the two source docs (spec 07-10 vs consolidated 09-06) disagreed in 6 places (Windows, editions, network, memory, Enter behavior, effects default); the newer canon won. The harness doesn't only make things "pretty" — it makes the agent leave blank what the document left blank.

> The 3 warnings kept on the clean page (brand blue only inside the logo mark · `kbd` chip line-height · circular tool glyph) have their rationale recorded in the demo's WHY section. Warnings are judgement calls; only errors block.

## Install

```bash
cd /path/to/your-project
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash
```

- At install start you're asked `[1] tailored build (recommended) / [2] manual selection`. `[1]` full-installs, then `/carve-harness-create` in a session prunes what doesn't fit the stack. Non-interactive installs skip the prompt and install everything.
- Existing files are left untouched (SKIP). The one exception is `.claude/settings.json`, which is **merged** — your config is preserved while the harness's 6 hook events + LSP/plugin declarations are registered via jq (idempotent). Skipping it leaves every gate inert.
- Install ends by running `/harness-audit` — `0 failed` means all gates are active.
- `bash install.sh setup` (optional) — git init · jq PATH · LICENSE · protected paths · domain-rule collection · stack-detection report.

### Language packs

Install lays down **detected languages only**. One pack = rules (`.claude/rules/<stack>/`) + verify gate/scorer adapter (`.claude/stacks/<pack>.sh`) + golden-set starters + LSP toggle. Unselected packs have no files.

| Pack | Detection markers | Gate / format | LSP |
|---|---|---|---|
| `typescript` | `package.json` · `tsconfig.json` | `tsc --noEmit` · `lint`/`test` · prettier | vtsls |
| `java-spring` | `gradlew` · `build.gradle(.kts)` · `pom.xml` | gradle compile/test · spotless · `eval-java` scorer | jdtls |
| `python` | `pyproject.toml` · `requirements.txt` · `setup.py/cfg` | ruff check · pytest · ruff format | pyright |
| `go` | `go.mod` | go build/vet/test · gofmt | gopls |
| `rust` | `Cargo.toml` | cargo check/test · rustfmt | rust-analyzer |
| `database` | ORM deps (prisma·drizzle·typeorm·sqlalchemy·JPA·gorm…) | rules only (`database.md`) | — |

```bash
HARNESS_PACKS=auto bash install.sh                 # detected (default for tty-less installs)
HARNESS_PACKS=typescript,python bash install.sh    # explicit
HARNESS_PACKS=none bash install.sh                 # core only (guards, handoff, audit)
bash install.sh pack list|add <name>|remove <name> # adjust later (remove backs up → rollback)
```

## Getting started

After install, walk this order once and the harness lines up with your project. Steps 1–3 already activate all guards and gates.

1. **Install** — `curl … | bash`. Choose `[1] tailored build (recommended)`.
2. **Confirm packs** — detected packs are the default. Adjust with `bash install.sh pack list|add|remove`.
3. **Prepare the machine** — gates bite only if `jq`·`git` and stack toolchains (`tsc`·`gradlew`·`ruff/pytest`·`go`·`cargo`) are present. `bash install.sh setup`.
4. **Tailor (optional)** — `/carve-harness-create` in a session; prunes packs/agents/skills that don't fit, after one confirmation.
5. **Domain rules** — add 3 project invariants to `CLAUDE.md` (e.g. "order amount cannot be negative"). Hooks can't see code patterns, so **enforce with tests**.
6. **Verify** — `/harness-audit` returning `0 failed` means all gates are active.
7. **Use it** — protected paths/secrets/dangerous commands are auto-blocked, changed stacks verified on completion, state saved/restored at session boundaries.
8. **(After 1–2 weeks) golden set** — once real failures accumulate, run `/eval-init` once → then track regression with `/eval`.

## Update / rollback / uninstall

Run from the target project root.

```bash
cat .claude/harness-version    # current installed version
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash -s -- update   # update
bash install.sh rollback       # restore previous version (consumes a backup — repeat to go further back)
bash uninstall.sh --yes        # uninstall (manifest scope only, original files safe)
```

- update: remote `VERSION` vs local (no-op if equal) → patches the manifest scope only, backs up changed files to `logs/harness-backup/`, never touches your files. Force a same-version re-patch with `HARNESS_FORCE=1 bash install.sh update`.
- prune: `bash install.sh prune --keep-list <file>` — removes only what doesn't fit (refuses core/hooks), backed up → `rollback`. Usually invoked by `/carve-harness-create`.

## Usage

Once installed, gates are automatic — protected-path writes are blocked, changed stacks are verified on completion, state is saved at session boundaries. Manual tools:

| Command | Purpose |
|---------|---------|
| `/harness-audit` | Harness config PASS/FAIL (AUDIT-01~09, 77 checks in this repo) |
| `/plan` `/verify` `/review` `/commit` | SC breakdown · SC verify · code review · commit→pull→push |
| `/verify-loop <goal>` | When there are many requirements — per-item 0–100 scoring, rework to 95 |
| `/eval-init` · `/eval` | **One-time** golden-set setup · re-score → pass@k/pass^k · regression |
| `bash install.sh pack list\|add\|remove` | Language-pack table / add / remove |
| `bash .claude/hooks/eval-score.sh` | Build-health scorecard `specs/SCORE.json` (no LLM) |
| `bash .claude/hooks/logs-report.sh [days]` | Hook verdict log summary (`--tokens` per-session tokens) |
| `npm test` | All hook test suites — 31 suites (545 cases) |

Customization (protected paths, formatters, verify commands, new stacks) and the full reference live in **`GUIDE.md`**.

## Full workflow — which tool, when

| Step | When | What | Gate / artifact |
|---|---|---|---|
| 0 Install | Once | `curl … \| bash` → pack detection → `harness-audit` | 6 hook events · manifest |
| 1 Tailor | Right after | `/carve-harness-create` — pack add/remove + prune (one confirm) | backed up → `rollback` |
| 2 Domain rules | Right after | 3 invariants in `CLAUDE.md` | rules **enforced by tests** |
| 3 Daily dev | Every response | Just code | PreToolUse blocks · changed stacks only · `logs/*.jsonl` |
| 4 Plan/verify | Per feature | `/plan` → build → `/verify`·`/review` | `specs/` SC |
| 5 Verify loop | Many requirements | `/verify-loop <goal>` — rework only <95 | blocks completion while short |
| 6 Health score | Before PR | `eval-score.sh` | `specs/SCORE.json` |
| 7 Golden set | After 1–2 weeks | `/eval-init` | `specs/goldenset/*.json` |
| 8 Regression | On prompt/rule change | `/eval` → `eval-gate --mode report\|block` | trend · `[REGRESSION]` |

Session boundaries are automatic. Steps 6–8 are optional — 0–5 alone activate all guards and gates.

## Orchestration · verify loop

Three higher workflows sit on top of the single-session guard. None is tied to a specific model — walk the same SOP by hand and it works on opus/sonnet/Cursor/Codex.

- **Fable team** ([guide](docs/md/fable-team-guide.md)) — the main session splits work into 3–5 tasks for role workers (`fable-researcher`·`fable-builder`·`fable-doc-writer`·`fable-visualizer`·`evaluator`) and synthesizes results. Workers hold non-overlapping file ownership + worktree isolation, so they run in parallel without clashing. Generator and evaluator are never the same agent. Opt-in — runs when you name the `ultracode` keyword or the workflow.
- **Verify loop** ([guide](docs/md/verify-loop-guide.md)) — an independent evaluator scores each "done" claim by reading the code and running tests, 0–100 (exists·match·test·contract·no_regress). Only sub-95 items get their gap fed back for rework, looping to 95. While any item is short or unscored, the `checklist-gate` Stop hook **blocks** completion. `/verify-loop <goal>`.
- **Golden-set eval (carve-eval)** — a fixed case set (`specs/goldenset/*.json`, input→rubric) is run k times per case for pass@k (capability) and pass^k (consistency), appended to a trend, flagged `[REGRESSION]` on a drop vs baseline. **"Score the state of the environment, not the agent's words"** — state asserts (`file_exists`·`cmd_exit0`·`git_diff_contains`) rank above text and LLM rubric. Auto-committing cases is disabled (prevents self-reinforcement) — humans set critical paths and strictness. Setup is `/eval-init` once, then `/eval`.

## Full component list (skills · commands · hooks)

### Skills (10)

> **Trigger** = auto (description match) or manual `/name`.

| Skill | Kind | Purpose |
|-------|------|---------|
| `anti-ai-slop` | core | Slop gate (gradients/glow/decoration) before any visual output (auto) |
| `carve-guide` | core | Harness HTML output — design system · anti-slop · 1000px embed-safe (auto) |
| `handoff` | core | Hand off progress to `specs/HANDOFF.md` before session end/compaction |
| `changelog` | core | Record irreversible decisions in `specs/DECISIONS.md` |
| `version-changelog` | core | Sync VERSION · CHANGELOG · README version on release |
| `carve-harness-create` | core | Prune ill-fitting config after stack detection → tailored harness |
| `checklist-loop` | verify | Claim-vs-code scoring loop SOP + checklist.json schema |
| `eval-goldenset` | verify | Golden-set quantitative scoring / regression SOP + case format |
| `eval-init` | verify | One-time post-install setup — interview to fix eval/quality gates → golden-set draft |
| `theme-factory` | vendor | Apply color/font theme to output — anti-slop gate still applies |

> The vendor skill (`theme-factory`) vendors SKILL.md only. Plugins `frontend-design`·`ponytail` ship as settings.json declarations, not skills.

### Slash commands (14)

| Command | Purpose |
|---------|---------|
| `/harness-audit` | Harness config PASS/FAIL (AUDIT-01~09, 77 checks) |
| `/plan` `/verify` `/review` | SC breakdown → `specs/` · verify against SC/build/type/test · type/security/exception/state review |
| `/verify-loop` | Spec→build→checklist→score loop, all items to 95 ([guide](docs/md/verify-loop-guide.md)) |
| `/eval` | Golden-set re-score → pass@k/pass^k · trend · regression |
| `/commit` `/commit-branch` | commit→pull→push (arg = message) · Conventional Commits commit+push (no direct `main`) |
| `/ponytail*` (6) | ponytail mode control · audit · debt · gain · review · help |

### Hooks (20 — 5 event gates · 3 libraries · 12 CLI/helpers)

| Hook | Trigger | Role |
|------|---------|------|
| `pretool-guard` | PreToolUse (before Write·Edit·Bash) | Blocks protected paths, secrets, dangerous commands + self-protection (GUARD-07) + loop break (exit 2), fail-closed |
| `posttool-format` | PostToolUse (after a write) | Detect language by extension, format (exit 0) |
| `posttool-slop` | PostToolUse (after writing `.html·.htm·.css·.svg`) | One-line anti-slop linter summary, non-blocking (exit 0). Full report via JSONL or a manual run |
| `check-slop.mjs` | Manual CLI · called by `posttool-slop` | Deterministic slop linter, 34 rules (HTML/CSS · SVG · MD dispatch, WCAG contrast math). `0` clean · `1` ERROR · `2` bad invocation |
| `stop-verify` | Stop (before completion) | Changed-stack build/type/test gate (fail exit 2) |
| `checklist-gate` | Stop (after `stop-verify`) | Blocks completion while `checklist.json` items are <95 or unscored. `domain_safety` requires 100. Self-bypass blocked (tombstone) |
| `session-handoff` | SessionStart·PreCompact·SessionEnd | Restore/save handoff + config banner |
| `log-event` | When another hook records a verdict | JSONL observability append — single source for schema + PII masking |
| `lib-protected` · `lib-stop-guard` · `lib-packs` | `source`d (never run directly) | Protected-path/dangerous-command regex / Stop loop guard / language-pack manifest reader |
| `config-doctor` | On config check | Diagnose settings/config consistency |
| `harness-audit` | `/harness-audit` | read-only PASS/FAIL — AUDIT-01~09 |
| `logs-report` | Manual CLI | JSONL verdict summary + rotation + `--tokens` token accounting |
| `eval-java` | Java quality score (manual) | Deterministic Java/Spring quality probability `P∈[0,1]`, no LLM |
| `eval-state` | carve-eval state-assert scoring | Scores file/command/diff against real state — distrusts self-report |
| `eval-gate` | CI/local regression | Reads trend only: `unable→stale→suspicious→regressed→ok`. `--mode block` exits 1 unless ok |
| `carve-validate` | `/eval` Phase 0 · manual | Golden-set preflight. `--red` detects NO-SIGNAL cases |
| `redteam` | Guardrail periodic check | Scores 34 attacks · 19 normal by exit code (no LLM). Block/over-block rates. `--strict` |
| `eval-run` | `/eval` case run (helper) | One case setup→respond→score. `--target session\|claude\|exec:` |
| `eval-trend` | `/eval` trend read/write (helper) | Deterministic append to `eval-score.json` — rejects tampered `prevHash` |
| `eval-score` | Build-health score (manual) | Language-agnostic scorecard (§5.7) — G1 build · G2 tests · G3 safety (veto) + lint · regression · coverage |

## Structure

Each directory has a `README.md` describing its role.

```
├── CLAUDE.md / AGENTS.md       # canonical rules (Claude / cross-agent)
├── VERSION · CHANGELOG.md · RELEASE.md
├── install.sh / uninstall.sh   # install·update·rollback·setup / uninstall
├── .githooks/                  # pre-commit·commit-msg (agent-agnostic commit gate)
├── packs/                      # 6 language-pack definitions
├── specs/                      # state: handoff · decisions · golden set (goldenset/)
└── .claude/
    ├── settings.json           # 6 hook events registered
    ├── hooks/  (20 + tests 30 suites)
    ├── stacks/ (6 — per-stack gate/format/scorer adapters)
    ├── workflows/ (fable-team-pipeline · carve-verify-loop · carve-eval)
    └── commands/ (14) · agents/ (7) · skills/ (10) · rules/ (11)
```

## Limits

> Measured — only what an adversarial audit (34 bypass attempts) **actually broke through** is listed.

- Hook blocking is Claude Code-only — other agents get pre-commit at commit time.
- The Bash write guard sees only the command surface. **Variable indirection (`F=.env; echo x > $F`) and interpreter routing are missed** (pre-commit catches them at commit).
- Secret scanning is **literal** — base64 and split-string assembly are missed.
- Dangerous-command blocking covers `env`/`sudo`/`VAR=` prefixes but **misses alias/function wrapping and two-step downloads**.
- Stop-gate stacks: Java·Node/TS·Python·Go·Rust·bash — others pass unverified. **Each bites only when its toolchain is installed**.
- Self-protection (GUARD-07) is active **only in an installed harness**. The verify loop can't catch a scored verdict that is itself false (mitigated by evaluator separation).

## License

MIT — [LICENSE](LICENSE). The vendored `ponytail` keeps its own license (`vendor/ponytail/LICENSE`).

## Version history

Current **v0.10.1**. Full history in [CHANGELOG.md](CHANGELOG.md).
