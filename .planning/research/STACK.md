# Stack Research

**Domain:** Claude Code harness building blocks (hooks, settings, skills/commands, subagents, rules, MCP) — current 2025-2026 toolset & syntax
**Researched:** 2026-07-06
**Confidence:** HIGH (every claim verified against the live docs at `code.claude.com/docs`, Claude Code v2.1.x — not training memory)

> Scope note: this is a *subsequent* milestone. We already have a working harness. This file catalogs the **current standard toolset/syntax** and marks where our template is aligned vs. where it drifts, so the roadmap can harden gaps. Docs **moved**: `docs.claude.com/en/docs/claude-code/*` now 301-redirects to `code.claude.com/docs/en/*`. Update any pinned links.

---

## Recommended Stack

### Core Technologies (the harness primitives)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Hook events** (`settings.json` `hooks`) | Claude Code ≥ 2.1 | Deterministic lifecycle gates | Only enforcement layer that runs regardless of what the model decides. CLAUDE.md/rules are *context*, hooks are *enforcement*. |
| **Exit-code protocol** (`exit 2` blocks) | ≥ 2.1 | Block/allow signal from hooks | `exit 2` is the **only** blocking code; `exit 0` = allow (+parse stdout JSON); `exit 1`/other = **non-blocking** error. Our invariant is correct. |
| **stdin JSON + `jq`** | jq 1.6+ | Parse hook input | Canonical, version-stable input contract. `.tool_input.file_path`, `.tool_input.command`, `.prompt`, etc. **Not** env-var scraping. |
| **`permissions` deny/allow/ask** | ≥ 2.1 | Declarative pre-hook gate | Second, cheaper enforcement layer *in front of* hooks. Deny always wins, merges across scopes. Our template already uses `deny` — keep and expand. |
| **`.claude/rules/*.md` + `paths:` frontmatter** | ≥ 2.1 | Path-scoped instruction loading | `paths:` glob is the **current** field name (confirmed). Our java/react rules use it correctly. |
| **`${CLAUDE_PROJECT_DIR}`** | ≥ 2.1 (skill body ≥ 2.1.196) | Portable script paths in hooks/skills/MCP | Resolves to project root independent of cwd. **We don't use it yet** — our hook commands are cwd-relative (gap G1). |

### Supporting Libraries (component primitives)

| Primitive | Location | Purpose | When to Use |
|-----------|----------|---------|-------------|
| **Subagents** | `.claude/agents/<name>.md` | Isolated-context LLM workers (Generator/Evaluator split) | Verbose/side work you don't want in main context; tool-restricted review. Ours: evaluator + 4 reviewers. |
| **Skills** | `.claude/skills/<name>/SKILL.md` | Model- or user-invoked reusable procedures | **Now the recommended primitive** — commands were merged into skills. Supports supporting files, invocation control, `context: fork`. |
| **Commands (legacy)** | `.claude/commands/<name>.md` | `/name` slash procedures | Still fully supported, but a strict subset of skills. New work should prefer skills; existing commands keep working. |
| **MCP servers** | `.mcp.json` (project), `~/.claude.json` (user) | External tool/data integration | Only when the harness needs live external systems (issue trackers, DBs). Referenced in hooks/permissions as `mcp__<server>__<tool>`. |
| **CLAUDE.md / AGENTS.md** | root or `.claude/` | Always-loaded behavioral context | Facts & always-do rules. Claude reads `CLAUDE.md`, **not** `AGENTS.md` — import it (`@AGENTS.md`) so both are read. Ours already does. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `/hooks` | Inspect registered hooks at runtime | Verify hooks actually loaded after drop-in. |
| `/doctor` | Health check | As of v2.1.196 reports **duplicate agent names** and **truncated/dropped skill descriptions** — wire into `/harness-audit`. |
| `/memory` | Lists loaded CLAUDE.md / rules files | Confirms path-scoped rules resolved. |
| `--debug` | Surfaces hook stderr + skill YAML parse errors | Use to debug the silent format hook (our concern C8). |
| `InstructionsLoaded` hook | Log which rule/CLAUDE.md files loaded and why | Deterministic audit of rule loading. |

---

## Exit-Code Semantics (verified — downstream asked explicitly)

Source: `code.claude.com/docs/en/hooks`. **`exit 1` does NOT block. Use `exit 2`.**

| Exit | Meaning | stdout | stderr destination |
|------|---------|--------|--------------------|
| `0` | Success / allow | Parsed as JSON output if valid; else shown in transcript | — |
| `2` | **Blocking error** | Ignored | Fed to **Claude** (PreToolUse, UserPromptSubmit, Stop, SubagentStop) or user, depending on event |
| `1` / other | **Non-blocking** error | Ignored | First line in transcript, full in debug log — **action proceeds** |

**Does `exit 2` block, per event?**

| Event | `exit 2` blocks? | Effect | Our hook |
|-------|------------------|--------|----------|
| `PreToolUse` | **Yes** | Blocks the tool call; stderr → Claude | ✅ `pretool-guard.sh` (correct) |
| `Stop` | **Yes** | Prevents stopping; conversation continues; stderr → Claude | ✅ `stop-verify.sh` (correct) |
| `UserPromptSubmit` | **Yes** | Blocks prompt, erases input; stderr → Claude | not used (see gap G3) |
| `SubagentStop` | **Yes** | Prevents subagent from stopping | not used |
| `PreCompact` | **Yes** | Blocks compaction | used for *save* only (exit 0 path) |
| `PostToolUse` | **No** (tool already ran) | stderr → Claude as feedback | `posttool-format.sh` (correct: format is advisory) |
| `SessionStart` / `SessionEnd` / `Notification` | **No** | stderr → user notice only | `session-handoff.sh start` (correct) |

**Version-stable alternative to exit codes** (prefer for richer control, less fragile than stderr parsing):
- `PreToolUse`: `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"…"}}`
- `Stop`/`PostToolUse`/`UserPromptSubmit`: `{"decision":"block","reason":"…"}`
- Inject context (any event): `{"hookSpecificOutput":{"additionalContext":"…"}}`
- Hard halt: `{"continue":false,"stopReason":"…"}`

---

## settings.json Schema (verified)

**Permission rule syntax** — `Tool(specifier)`:
- **Bash**: command-prefix match, `*` wildcard → `Bash(npm run test *)`, `Bash(git push*--force*)`
- **Read/Edit/Write**: gitignore-style path globs → `Read(./**/.env*)`, `Read(./secrets/**)`, `Edit(/etc/**)`; `*` within a segment, `**` across dirs
- **WebFetch**: `WebFetch(https://api.github.com/*)`
- **Agent**: `Agent(Explore)` to deny a subagent; **Skill**: `Skill(commit)`, `Skill(deploy *)`

**Precedence:** `deny` > `ask` > `allow`; **deny always wins**. Permission rules **merge** across scopes (all other settings override).

**Scope precedence (high→low):** Managed → CLI args → `.claude/settings.local.json` (Local, gitignored) → `.claude/settings.json` (Project) → `~/.claude/settings.json` (User).

**Hook config = 3-level nesting:** event → `{matcher, hooks[]}` → `{type:"command", command, timeout?}`. Matcher matches the **tool name**; `"Write|Edit"` = OR-list; empty/omitted/`"*"` = all; hyphens are exact-match only on **≥ 2.1.195** (else regex); non-alphanumeric ⇒ unanchored JS regex; MCP ⇒ `mcp__server__.*`.

**Add for cheap hardening:** `"$schema": "https://json.schemastore.org/claude-code-settings.json"` (editor validation, catches version drift).

---

## Frontmatter Reference (verified — downstream asked explicitly)

**Subagent** (`.claude/agents/*.md`) — only `name`, `description` required:
`name` · `description` · `tools` (omit = inherit all) · `disallowedTools` · `model` (`sonnet`|`opus`|`haiku`|`fable`|full-id e.g. `claude-opus-4-8`|`inherit`; **default `inherit`**) · `permissionMode` · `skills` · `mcpServers` · `hooks` · `memory` (`user`|`project`|`local`) · `color` · `maxTurns`. Ours use `name/description/tools/model: sonnet` — valid & current.

**Skill** (`.claude/skills/<name>/SKILL.md`) — all optional, `description` recommended:
`name` · `description` · `when_to_use` · `allowed-tools` (**hyphen**; pre-approve, e.g. `Bash(git add *) Bash(git commit *)`) · `disallowed-tools` · `disable-model-invocation` (true = user-only `/name`) · `user-invocable` (false = Claude-only) · `context: fork` + `agent` · `paths` · `hooks` · `argument-hint` · `arguments` · `model` · `effort`. Directory name → command name; frontmatter `name` is only a display label (except plugin-root).

**Command (legacy)** (`.claude/commands/*.md`): same frontmatter as skills; filename → command name.

**Rule** (`.claude/rules/*.md`): `paths:` (comma-string or YAML list of globs; brace expansion `**/*.{ts,tsx}`). **No `paths` = loaded unconditionally** (like CLAUDE.md). Ours: `common/*` unconditional, `java-spring`/`react-next` path-scoped — correct.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| jq stdin parsing | Env-var access (`$TOOL_INPUT`, `$CLAUDE_PROJECT_DIR`) | Env vars exist for a few fields, but **full tool input is only on stdin**. jq is the robust default; env vars only for path bootstrapping. |
| Skills (`SKILL.md`) | Commands (`.claude/commands/*.md`) | Keep commands only for tiny already-working `/x` procedures. Anything needing supporting files, `disable-model-invocation`, or `context: fork` → skill. |
| `exit 2` (shell hooks) | JSON `permissionDecision`/`decision:block` | Use JSON when you need a structured reason, `additionalContext`, or `updatedInput`. More future-proof than stderr scraping; requires emitting valid JSON on stdout with `exit 0`. |
| MCP `type: http` | `type: sse` | **SSE is deprecated** — HTTP is the recommended remote transport. Only use SSE for legacy servers. `streamable-http` is an accepted alias for `http` in JSON. |
| `permissions.deny` + PreToolUse hook | Hook only | Deny-list alone can't do content-aware logic; hook alone loses the declarative cheap gate. Use **both** (defense in depth) — we already do. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **`exit 1` to block** | Non-blocking — the dangerous action proceeds. Classic latent bug. | `exit 2`, or JSON `permissionDecision:"deny"` |
| **cwd-relative hook commands** (`bash .claude/hooks/x.sh`) | Breaks when the session starts in a subdirectory / monorepo package; cwd ≠ project root. **Our current settings.json does this (gap G1).** | `bash ${CLAUDE_PROJECT_DIR}/.claude/hooks/x.sh` |
| **SSE MCP transport** | Deprecated. | `--transport http` |
| **`docs.claude.com/en/docs/claude-code/*` links** | 301-redirected; will rot. | `code.claude.com/docs/en/*` |
| **Side-effect commands without `disable-model-invocation`** | Claude may auto-run `/commit`, `/deploy`. **Our `commit.md` lacks it (gap G2).** | Add `disable-model-invocation: true` to `commit`, and any future deploy/release skill |
| **Hardcoded `docs.claude.com` version assumptions** | Frontmatter/hook syntax is min-version gated (v2.1.x). | Pin a **minimum Claude Code version** in README; verify with `/hooks` + `/doctor` |
| **Reading full tool input from env vars** | Only stdin JSON carries the full `tool_input` object. | `jq -r '.tool_input.command'` on stdin |

---

## Stack Patterns by Variant (harness hardening options)

**If maximizing enforcement reliability (recommended for this template):**
- Keep both layers: `permissions.deny` (declarative) + PreToolUse hook (content-aware). Deny is evaluated cheaply before the hook.
- Switch hook commands to `${CLAUDE_PROJECT_DIR}/...` for subdir-safe drop-in.
- Add `$schema` to settings.json.

**If tightening the State pillar (handoff continuity — concern C7):**
- Add a `SessionEnd` hook alongside `PreCompact` — current handoff only saves on compaction, missing clean exits (`logout`/`clear`/`prompt_input_exit`). `SessionEnd` input carries `reason`.
- Consider `SessionStart` `hookSpecificOutput.additionalContext` to *inject* the restored handoff as context (stronger than printing to stdout).

**If tightening the Constraint pillar:**
- Add a `UserPromptSubmit` hook to scan pasted content for secrets / inject guardrail reminders (`exit 2` blocks + erases input; or `additionalContext` to nudge). Complements PII rule baseline.

**If migrating commands → skills (optional, low urgency):**
- `.claude/commands/*.md` keep working; only migrate when you need supporting files, `context: fork`, or invocation control. Net-new procedures start as skills.

**Version-fragility future-proofing:**
- Duplicate the load-bearing constraints into `CLAUDE.md` (context) *and* enforce via hook/permissions (deterministic) — never rely on frontmatter syntax alone. This is already the template's stated C10 strategy; the research confirms it's the correct hedge.

---

## Version Compatibility

| Feature | Min Claude Code version | Notes |
|---------|-------------------------|-------|
| Hook exit-code + stdin JSON protocol | Stable across 2.1.x | Core contract; safe to depend on |
| `paths:` rule frontmatter | ≥ 2.1 | Confirmed current field name |
| `${CLAUDE_PROJECT_DIR}` in **skill body / allowed-tools** | ≥ 2.1.196 | In hooks it's long-standing; in skills it's newer |
| Hyphenated hook/subagent matcher = exact match | ≥ 2.1.195 | Earlier: treated as regex → anchor with `^…$` |
| `/doctor` reports duplicate agents + skill-desc truncation | ≥ 2.1.196 | Useful for `/harness-audit` |
| Commands-merged-into-skills model | Current | Commands remain a supported subset |
| SSE MCP transport | Deprecated (still works) | Prefer `http` |
| Subagent `model: inherit` default | Current | We override to `sonnet` deliberately (cost/consistency) — valid |

**Our template's alignment summary:** hook exit-code protocol ✅, jq stdin ✅, `paths:` rules ✅, agent frontmatter ✅, `permissions.deny` present ✅. **Drift to fix:** cwd-relative hook paths (G1), `commit` command missing `disable-model-invocation` (G2), no `SessionEnd`/`UserPromptSubmit` hooks (G3), no `$schema` (G5), stale `docs.claude.com` links (G-docs).

---

## Sources

- `code.claude.com/docs/en/hooks` — full event list, exit-code-per-event table, stdin schema, JSON output fields, matcher semantics — **HIGH**
- `code.claude.com/docs/en/settings` — permissions allow/deny/ask syntax, scope precedence, `$schema` — **HIGH**
- `code.claude.com/docs/en/sub-agents` — subagent frontmatter field table, `model` values, hooks-in-frontmatter, `mcpServers` — **HIGH**
- `code.claude.com/docs/en/skills` — skill frontmatter table, "commands merged into skills", `disable-model-invocation`, `allowed-tools`, `context: fork` — **HIGH**
- `code.claude.com/docs/en/mcp` — `.mcp.json`, transports (http/sse-deprecated/stdio/ws), `mcp__server__tool` naming, scopes — **HIGH**
- `code.claude.com/docs/en/memory` — `.claude/rules/` + `paths:` frontmatter (exact field name), `@import`, AGENTS.md handling — **HIGH**
- Local: `.claude/settings.json`, `.claude/agents/evaluator.md`, `.claude/commands/commit.md`, `.claude/skills/handoff/SKILL.md`, `.claude/rules/java-spring/patterns.md`, `.claude/hooks/*.sh` — grounded gap analysis — **HIGH**

---
*Stack research for: Claude Code harness building blocks (2025-2026 current toolset)*
*Researched: 2026-07-06*
