# carve-harness Install Manual

> A CLI that analyzes your project and **interactively selects** and installs a harness (skills, hooks, subagents, commands) tailored to that project.
> carve = **carving down** general-purpose assets to fit a project. It does not perform bulk installs.

Korean manual: [INSTALL.md](./INSTALL.md) · Overview: [README.md](./README.md)

---

## 1. Requirements

| Item | Value |
|------|----|
| Node.js | **>= 22.18** (runs `.ts` directly via type stripping — no build step) |
| OS | macOS · Linux (generated hooks are bash scripts) |
| git | Optional — only when using commit/push-related hooks |
| Package manager | Auto-detected (npm·pnpm·yarn·bun·pip·poetry·cargo·go) |

The install targets are the **`.claude/` of the current directory** and the guide documents at the project root. carve does not modify source code.

---

## 2. Quick Start — full install flow (3 steps)

```bash
npx carve-harness              # 1. 대화형 선택 설치 (탐지 → 추천 → 선택)
npx carve-harness init-claude  # 2. CLAUDE.md 베이스라인 + 언어 스택 규칙 생성
npx carve-harness doctor       # 3. 설치 점검 (구성·훅 문법)
```

Inside a session (Claude Code), a single phrase — **"set up a harness that fits this project"** — lets the `harness-architect` skill
walk you through the same steps 1–3.

---

## 3. Install methods

### 3.1 npx (recommended)
```bash
npx carve-harness            # = carve install (대화형)
```
Runs the latest version without a separate global install.

### 3.2 bash
```bash
bash install.sh              # 현재 디렉토리에 설치
bash install.sh --uninstall  # 제거
```

### 3.3 Local clone (development/review)
```bash
git clone <repo> && cd carve-harness
node bin/carve.ts install <대상-프로젝트-경로>
```

---

## 4. Install modes — how to choose

| Mode | Command | When |
|------|------|----|
| **Interactive selection** (default) | `carve` or `carve install` | When you want to review recommendations and pick via checkboxes (TTY) |
| **Explicit selection** | `carve install --only commit,handoff,block-destructive` | To install only specific components non-interactively (CI, scripts, etc.) |
| **Force level** | `carve install --level full` | To set the level yourself, ignoring auto-detection |
| **Auto-install language servers** | `carve install --lsp-servers` | When LSP is recommended, also installs the language server (`npm i -g`) for the detected language |

> Interactive install presents recommended items **pre-checked**, but installs **only what you select** (no bulk auto-install).
> Options can be combined: `carve install --level standard --only commit,pr,block-destructive`.

---

## 5. Install levels

Auto-determined by profile (type, language count, CI) and can be forced with `--level`.
What changes by level is the **number of hooks and additional skills** — core skills, the 9 Squad agents, and anti-slop are recommended by default at *every level*.

| Level | Auto-detection criteria | Includes |
|------|----------------|----|
| `minimal` | Small CLI·library·batch·unclassified | Core skills + Squad 9 agents + anti-slop + **3 essential hooks (block·protect·handoff)** |
| `standard` (default) | General apps (web·mobile·desktop) | minimal + **the remaining core hooks (7 total:** +lint, test, format, Slack) |
| `full` | Has CI + multiple languages | standard + **additional skills** (verify, security-scan, test-gen, parallel-agents, coordinator, etc.) |

---

## 6. Components by step (what to choose)

The groups presented during interactive install and a selection guide.

### Token efficiency (recommended by default)
- **codesight** — Project structure map MCP. Eliminates grep re-search cost (measured average ~11x on large codebases).
- **lsp** (cclsp MCP) — Precise lookups via `findReferences`/`getDiagnostics`. ~500 tokens instead of grep's 2,000+ tokens.
- On install, automatically registered under `mcpServers` in `.claude/settings.json`. Language server binaries are installed only via interactive mode or `--lsp-servers`.

### 6 core skills
`handoff` · `memory` · `commit` · `changelog` · `review` · `pr` — triggered by natural language, installed together with `/carve-*` command shims.

### Entry skill
`harness-architect` — guides the install flow via natural language like "set up a harness that fits this project".

### 7 essential hooks
| Hook | Event | Behavior |
|----|--------|----|
| Block destructive commands | PreToolUse(Bash) | `rm -rf /`·fork bombs, etc. → **exit 2 block** |
| Protect secret files | PreToolUse(Read/Edit/Write) | Blocks access to `.env`·keys·credentials |
| Lint before commit | PreToolUse(Bash) | Blocks commit on lint failure |
| Test before push | PreToolUse(Bash) | Blocks push on test failure |
| Auto-format | PostToolUse(Edit/Write) | Runs the formatter after save |
| Slack notification | — | Event notification (optional configuration) |
| PreCompact handoff | PreCompact | Persists context before compaction |

### 1 optional hook
`auto-commit` — not recommended by default. Enable it directly in interactive mode.

### 9 Squad subagents
`review` · `plan` · `refactor` · `qa` · `debug` · `docs` · `gitops` · `audit` · `evaluator` (independent evaluation against completion criteria).
Keyword routing (`squad-router`)·chaining (`subagent-chain`) hooks plus a `/squad <member>` dispatcher command are installed together.

### anti-ai-slop pack (recommended by default regardless of type)
Removes AI slop from HTML·SVG·card news·reports·slides·documents. After generation, the `check-slop.mjs` linter gates deterministically (warning mode; intentional use has an exception path).

### Additional skills (full level)
`verify` · `security-scan` · `test-gen` · `tdd` · `caveman` · `write-a-skill` · `zoom-out`, etc. (score 75+).

---

## 7. CLAUDE.md baseline + stack rules (`carve init-claude`)

Running it after install carves out a working-guideline baseline and per-language stack rules.

```bash
carve init-claude
```

Outputs:
- **`.claude/CLAUDE.md`** — stack-agnostic baseline: think before coding · simplicity · surgical changes · TDD · commit discipline · response control · hallucination guards · safety guardrails.
- **`.claude/rules/*.md`** — 6 best-practice files for the detected language (`techstack` · `project-structure` · `commands` · `code-style` · `safety` · `gotchas`) + a stack-agnostic `anti-ai-slop` rule (visual/document slop prevention).
- Automatically links the root `CLAUDE.md` to **`@import`** the above files (idempotent). They are loaded together each session.

Automatic stack selection:

| Detected language | Applied bundle |
|-----------|-----------|
| TypeScript / JavaScript | `typescript` |
| Python | `python` |
| Go | `go` |
| Rust | `rust` |
| Java / Kotlin | `java` |
| Dart / Flutter | `dart` |
| Other / undetected | `_default` |

Package manager and test/lint/format commands are substituted with values detected in the project (stack defaults when undetected).

> Claude Code does not auto-load `.claude/CLAUDE.md`, so it is loaded via the root `CLAUDE.md`'s `@import` (which is why the root link is required and handled idempotently).

---

## 8. Generated files (target project)

```
<project>/
├── CLAUDE.md                  # (install) 하네스 안내 + (init-claude) @import 블록
├── flight-rules.md            # 금지/필수 규칙 (훅이 강제)
├── evaluation-criteria.md     # 측정 가능 품질 기준
├── sprint-contract.md         # 스프린트 계약
├── HARNESS-GUIDE.md           # 하네스 사용법
├── carve-manifest.json        # 설치 추적(멱등·제거 기준)
└── .claude/
    ├── settings.json          # 훅·MCP 병합(carve 마커)
    ├── CLAUDE.md              # (init-claude) 베이스라인
    ├── rules/*.md             # (init-claude) 스택 규칙 6종 + 공용 anti-ai-slop
    ├── skills/                # 선택 스킬 + 커맨드 shim
    ├── hooks/                 # 선택 훅 스크립트
    ├── agents/                # Squad 서브에이전트
    └── commands/              # 커맨드(/squad 등)
```

---

## 9. Command reference

| Command | Description |
|------|----|
| `carve` / `carve install` | Interactive selection install |
| `carve install --level <minimal\|standard\|full>` | Force level |
| `carve install --only a,b,c` | Explicit selection (non-interactive) |
| `carve install --lsp-servers` | Auto-install LSP language servers |
| `carve init-claude` | Generate CLAUDE.md baseline + `.claude/rules/*` |
| `carve list` | List installable/installed components |
| `carve doctor` | Install check (component list + hook shell syntax) |
| `carve uninstall` | Clean removal (.bak restore) |
| `carve diff` | 3-way compare installed assets vs manifest/current carve assets (read-only) |
| `carve update` | Refresh only carve-updated assets in place, preserve user edits (`--force`, `--yes`) |
| `carve migrate` | Promote a v1 manifest to v2 (per-file hash back-fill) |
| `carve report` | Aggregate local-effect telemetry of installed hooks (opt-in) |
| `carve --version` · `carve --help` | Version / help |

---

## 10. Idempotency & reinstall

- Reinstall is safe. Files modified by the user are **preserved once as `.bak`** and then recorded.
- Hooks·MCP in `settings.json` are **merged without duplicates** based on carve markers.
- `init-claude` adds the `@import` block to the root `CLAUDE.md` **idempotently by marker** (once even if run twice).

---

## 11. Uninstall

```bash
carve uninstall              # = bash install.sh --uninstall
```

- Based on `carve-manifest.json`, removes only files installed by carve, and **restores the original** if a `.bak` exists.
- Removes exactly the carve hook·MCP entries from `settings.json` (preserving user entries).
- Note: since only files are removed, emptied directories (e.g. `.claude/rules/`) may remain — clean up manually if needed.

---

## 12. Doctor

```bash
carve doctor
```
Inspects the install manifest (version·files·hooks·backup count) and the **shell syntax** of installed hooks (uses `shellcheck` if present, otherwise `bash -n`).

---

## 13. Safety — why "deterministic"

Blocking dangerous commands and secret files is enforced **not as advice but via a PreToolUse hook's `exit code 2`**.
Because it is a deterministic script rather than a model judgment, the same input yields the same result — leakage is structurally zero.
Before install, `auditor` scans generated artifacts for secret exposure·excessive permissions·hook injection·shell syntax, and they are installed only if they pass.

---

## 14. Troubleshooting

| Symptom | Resolution |
|------|----|
| `node: bad option` / type-stripping error | Confirm Node **>= 22.18** (`node -v`) |
| MCP (codesight/cclsp) not working | Check `mcpServers` registration in `.claude/settings.json`; manually verify `npx codesight --mcp`·`npx cclsp` |
| Language server not installed | Re-run `carve install --lsp-servers` or see the `lsp` skill's manual guidance (go/rust, etc.) |
| Hooks not firing | Check syntax with `carve doctor`; verify hook registration in `.claude/settings.json` |
| `shellcheck` missing | Automatically falls back to `bash -n` — no operational issue |

---

## See also

- Overview·features: [README.md](./README.md)
- Architecture: [ARCHITECTURE.md](./ARCHITECTURE.md)
- Quantitative evaluation: [docs/guide/carve-harness-benchmark-results.md](./docs/guide/carve-harness-benchmark-results.md)
- Changelog: [CHANGELOG.md](./CHANGELOG.md)
