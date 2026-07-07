# Phase 1: Fail-Closed Enforcement Core - Research

**Researched:** 2026-07-06
**Domain:** Claude Code hook runtime contract (PreToolUse/Stop lifecycle, exit-code enforcement) + robust Bash/jq guard scripting
**Confidence:** HIGH (hook contract, fail-closed patterns, CFG mechanics verified against official docs + multiple sources)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** `jq` absence or JSON parse failure → hard-fail (exit 2) applies to **write paths only** — `pretool-guard.sh` and the Bash-write check (GUARD-03). Both unconditionally `exit 2` on `jq`/parse failure.
- **D-02:** The Stop gate (`stop-verify.sh`) is **non-blocking when `jq` is absent** — skip only the stack test steps and warn on stderr. (Hard-failing verification would make completion impossible on jq-less machines → work paralysis. Write-blocking is fail-closed; verification is best-effort.)
- **D-03:** When a guard fail-closes, it must state the **reason on stderr** (e.g. `[guard] jq 미설치/JSON 파싱 실패 → fail-closed 차단`) so the blocked user knows the cause.
- **D-04:** Remove the `paths:` **key entirely** from all three `common/` rules (`git-workflow.md`, `security.md`, `testing.md`) → always injected regardless of file (incl. auto re-injection after compaction). All three are currently `paths: ["**/*"]`; glob loading is itself the C10 version-drift surface, so key removal immunizes it.
- **D-05:** java-spring/react-next stack rules stay extension-scoped (`**/*.java`, `**/*.ts,tsx`) — do NOT promote to stack-agnostic always-on.
- **D-06:** Add an **explicit `timeout`** to the `settings.json` Stop hook (generous, e.g. 300–600s) → eliminate silent truncation of the gate by the default timeout. Exact value is planner discretion, but large enough that real builds are not cut off.
- **D-07:** Keep verification **lightweight** (compile+test). Changed-module incrementalization is deferred to **Phase 5 GATE-03** (do not cross this phase's boundary).

### Claude's Discretion
- **Bash-write coverage (GUARD-03) — user did not discuss; Claude's default:**
  - **In-scope (block):** redirects (`>`, `>>`, `tee`), in-place edits (`sed -i`, `perl -i`), copy/move (`cp`, `mv`, `install`) when targeting a **protected-path pattern** (`.env`/`.env.*`/`application-prod*`/`*secret*`/`db/migration/*`). Detection = protected-pattern match on `.tool_input.command`.
  - **Explicit out-of-scope ceiling (documented, NOT a bug):** writes via pipe, variable-substituted/obfuscated paths, read paths (`less`/`head`), heredoc bypass. Best-effort — STATE.md already acknowledges this as a documented ceiling. Root defense is `.gitignore .env*` + rules (security.md).
  - Protected-path pattern should be **single-sourced** with `pretool-guard.sh`'s `file_path` case (avoid duplicate definition / drift).
- GATE-01 loop-prevention wording/exit handling, CFG-02/03/04 mechanical application: per SC — discretion.

### Deferred Ideas (OUT OF SCOPE)
- **Changed-module incremental verify** — already assigned to **Phase 5 GATE-03**. Phase 1 only eliminates silent timeout truncation via explicit `timeout`; incrementalization is deferred.
- **Secret content scan** (file contents: AKIA/sk-/ghp-/PEM/JWT) — GUARD-04, **Phase 5**. Phase 1 is path-based blocking only.
- **Full Bash read-path blocking** (`less`/`head`/`grep` etc.) — REQUIREMENTS Out of Scope. Deny-list best-effort suffices; root defense is `.gitignore .env*`.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GUARD-01 | Guard fail-closes (exit 2) on `jq` absent or JSON parse failure | §Pattern 1 (fail-closed preamble), §Pitfall 1. Current hook is fail-open (empty `file_path` → `exit 0`). Verified exit-2 = PreToolUse block. |
| GUARD-02 | Matcher covers `Write\|Edit\|MultiEdit\|NotebookEdit` | §Pitfall 2 — **NotebookEdit uses `notebook_path`, not `file_path`**; matcher expansion alone is insufficient. Hook must read both fields. |
| GUARD-03 | Bash write to protected path blocked via `.tool_input.command` | §Pattern 2 (Bash-write branch), §Don't Hand-Roll (no shell parser). `.tool_input.command` verified as the Bash command field. |
| GATE-01 | Stop gate checks `stop_hook_active` to prevent infinite loop | §Pattern 3. Field verified real (community sources + SC); exit 0 when `true`. |
| GATE-02 | Stop gate not silently disabled by hook timeout | §State of the Art — **default is now 600s, not 60s**; add explicit `timeout` (D-06). |
| CFG-01 | Critical rules always-on (no `paths:`) | D-04. All three `common/` rules currently `paths: ["**/*"]` → remove key. |
| CFG-02 | Hooks resolve from `${CLAUDE_PROJECT_DIR}` | §Pattern 4 — verified: resolves to project root, available in command strings. |
| CFG-03 | `commit` has `disable-model-invocation: true` | §CFG Mechanics — verified official field; docs use `/commit` as the canonical example. |
| CFG-04 | `settings.json` declares `"$schema"` | §CFG Mechanics — SchemaStore URL (community, no official Anthropic-hosted schema). |
</phase_requirements>

## Summary

This is a shell-hook/config hardening phase, not application development: the entire deliverable is edits to four existing files (`pretool-guard.sh`, `stop-verify.sh`, `settings.json`, `commit.md`) plus removing three frontmatter keys. No packages are installed; the stack is Bash + `jq 1.8.1` (both already present). The work closes five fail-open leaks in an existing, working harness.

Every claim about the runtime contract was verified against the current official docs (`code.claude.com/docs/en/hooks`, `/slash-commands`→`/skills`) and cross-checked with community sources. Two verified facts correct stale premises in the requirement: (1) the default `command` hook timeout is now **600s (10 min)**, not 60s — but the D-06 fix (explicit `timeout`) is still correct and now *more* justified, because the default silently changed across versions (exactly the C10 drift the phase exists to fight); and (2) **NotebookEdit's path field is `notebook_path`, not `file_path`** — so simply widening the matcher (GUARD-02) will NOT block NotebookEdit writes unless the hook also reads `notebook_path`. That is the single highest-risk pitfall in the phase.

The core enforcement invariant — **block = `exit 2`, allow = `exit 0`, `exit 1` passes through non-blocking** — is confirmed for PreToolUse (blocks tool) and Stop (forces continuation). `stop_hook_active` is a real Stop-hook input field (the WebFetch summarizer missed it, but multiple sources and the phase SC confirm it); the loop-guard pattern is `[ "$(jq -r .stop_hook_active)" = true ] && exit 0`. `${CLAUDE_PROJECT_DIR}` resolves to the project root and is valid in hook command strings. `disable-model-invocation: true` is a current, documented frontmatter field whose docs literally cite `/commit` as the use case.

**Primary recommendation:** Consolidate GUARD-01/02/03 into the single existing `pretool-guard.sh` with a shared protected-path pattern: a fail-closed preamble (jq-present + JSON-parses, else `exit 2` with cause), then branch on `tool_name` — Bash → inspect `.tool_input.command`; all write tools → inspect **both** `.tool_input.file_path` and `.tool_input.notebook_path`. Expand the `settings.json` PreToolUse matcher to `Write|Edit|MultiEdit|NotebookEdit|Bash`, prefix all hook commands with `${CLAUDE_PROJECT_DIR}`, add an explicit Stop `timeout`, and add `$schema`. Add the `stop_hook_active` guard atop `stop-verify.sh`. Verify everything with stdin-fed synthetic JSON + exit-code asserts.

## Architectural Responsibility Map

This project has no traditional tiers. The relevant "tiers" are the harness pillars and the hook lifecycle stages.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Block protected-file writes (GUARD-01/02/03) | Constraints pillar — `pretool-guard.sh` (PreToolUse) | `settings.json` matcher + `.gitignore`/rules (defense-in-depth) | PreToolUse is the only stage that can block *before* the write happens (exit 2). |
| Prevent Stop loop / timeout bypass (GATE-01/02) | Feedback pillar — `stop-verify.sh` (Stop) | `settings.json` `timeout` | `stop_hook_active` lives only in Stop input; timeout is a settings-level property of the Stop handler. |
| Always-on rules (CFG-01) | Constraints pillar — `rules/common/*` frontmatter | `CLAUDE.md` (former duplication workaround, now obsolete) | Rule injection is a context-loading concern, not a hook; removing `paths:` makes it version-drift-immune. |
| Path resolution / config integrity (CFG-02/03/04) | `settings.json` + command/skill frontmatter | — | These are static config declarations read at session start, not runtime code. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Bash | system (`/usr/bin/env bash`) | Hook execution | Zero-runtime-dep invariant; all existing hooks are Bash. |
| jq | 1.8.1 (installed) `[VERIFIED: /usr/bin/jq]` | Parse hook stdin JSON, extract `.tool_input.*` | The documented, canonical way Claude Code hooks read input (env-var style is legacy per MANUAL §6). |

### Supporting
None. **Do not introduce any new tool** — the "런타임 의존성 0" invariant is a locked project constraint (CONTEXT §Established Patterns, CLAUDE.md "무거운 도구 도입 금지").

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `jq` for JSON parse | pure-Bash JSON parsing | Violates the zero-dep goal in the wrong direction — hand-rolling a JSON parser is exactly the "Don't Hand-Roll" trap. jq is already a hard dependency. |
| shell parser for Bash-write detection | `bash -n` / real tokenizer | Out of scope by design (documented ceiling). Substring/regex match on `.tool_input.command` is the accepted best-effort. |

**Installation:** None — `jq` and `bash` are already present (verified below).

## Package Legitimacy Audit

**N/A — this phase installs no external packages.** The only external reference is the settings.json `$schema` URL (`https://json.schemastore.org/claude-code-settings.json`), which is a documentation/editor-validation hint, not an installed dependency. No npm/PyPI/crates package is added. slopcheck not applicable.

## Architecture Patterns

### System Architecture Diagram

Data flow through the hardened PreToolUse guard (the phase's central change):

```
Claude tool call (Write|Edit|MultiEdit|NotebookEdit|Bash)
        │
        ▼  stdin = hook input JSON
┌─────────────────────────────────────────────┐
│ pretool-guard.sh                             │
│                                              │
│ 1. FAIL-CLOSED PREAMBLE (GUARD-01)           │
│    command -v jq?  ──no──► stderr cause ─► exit 2 (BLOCK)
│    input=$(cat)                              │
│    echo "$input" | jq empty? ──fail──► stderr cause ─► exit 2 (BLOCK)
│                                              │
│ 2. BRANCH on .tool_name                      │
│    ├─ Bash ──► c=.tool_input.command         │
│    │           c matches PROTECTED? ─yes─► exit 2 (BLOCK, GUARD-03)
│    │                                └─no──► exit 0 (ALLOW)
│    └─ write tools ──► p = .tool_input.file_path
│                       ∪ .tool_input.notebook_path   ◄── NotebookEdit!
│                       p matches PROTECTED? ─yes─► exit 2 (BLOCK, GUARD-02)
│                                          └─no──► exit 0 (ALLOW)
└─────────────────────────────────────────────┘
        PROTECTED = single shared pattern (file_path case reuse)
```

Stop gate flow (GATE-01/02):

```
Claude finishes response ──► Stop hook (stdin JSON incl. stop_hook_active)
        │
        ▼
┌──────────────────────────────────────────────┐
│ stop-verify.sh                               │
│  stop_hook_active == true? ──yes──► (surface once) exit 0  (GATE-01: no loop)
│  jq absent?                ──yes──► warn stderr, exit 0     (D-02: best-effort)
│  else: detect stack ─► compile+test ─► fail? ─► exit 2 (BLOCK stop)
│                                        pass? ─► exit 0
└──────────────────────────────────────────────┘
   settings.json Stop handler carries explicit timeout (GATE-02, D-06)
```

### Recommended Project Structure
No new files. All changes land in existing files:
```
.claude/
├── hooks/
│   ├── pretool-guard.sh     # GUARD-01/02/03 — preamble + branch + shared pattern
│   └── stop-verify.sh       # GATE-01 — stop_hook_active guard on top
├── settings.json            # GUARD-02 matcher, CFG-02 ${CLAUDE_PROJECT_DIR}, GATE-02 timeout, CFG-04 $schema
├── commands/commit.md       # CFG-03 disable-model-invocation
└── rules/common/*.md        # CFG-01 remove paths: key (×3)
```

### Pattern 1: Fail-closed preamble (GUARD-01)
**What:** Before extracting any field, prove `jq` exists and the input parses; otherwise block with a cause-specific message (D-03).
**When to use:** Top of `pretool-guard.sh` and the Bash-write path (D-01 scope: write paths).
**Example:**
```bash
# Source: derived from code.claude.com/docs/en/hooks exit-code contract (exit 2 = PreToolUse block)
#!/usr/bin/env bash
# GUARD-01: fail-closed. jq missing OR unparseable JSON → block (exit 2), not allow.
if ! command -v jq >/dev/null 2>&1; then
  echo "[guard] jq 미설치 → fail-closed 차단 (jq 설치 후 재시도)" >&2
  exit 2
fi
input=$(cat)                                  # read stdin ONCE
if ! printf '%s' "$input" | jq empty >/dev/null 2>&1; then
  echo "[guard] JSON 파싱 실패 → fail-closed 차단" >&2
  exit 2
fi
```
Notes: `jq empty` is the canonical "is this valid JSON?" check (exit 0 on parse-OK regardless of truthiness; non-zero only on parse error) — cleaner than `jq -e .`, which also fails on `null`/`false`. Read stdin once into `$input` and reuse; consuming stdin twice does not work.

### Pattern 2: Bash-write branch with shared protected pattern (GUARD-03)
**What:** After the preamble, branch on `tool_name`. For Bash, substring/regex-match the command against the SAME protected pattern used for file paths (single source, per CONTEXT).
**When to use:** GUARD-03. Benign Bash commands must exit 0 (SC #3).
**Example:**
```bash
# ponytail: single-source the pattern. One regex, consumed by both branches — no drift.
# Mirrors pretool-guard.sh's existing case: *.env|*.env.*|*application-prod*|*secret*|*db/migration/*
PROTECTED='(\.env($|[./])|application-prod|secret|db/migration/)'

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
case "$tool" in
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
    if printf '%s' "$cmd" | grep -Eq "$PROTECTED"; then
      echo "[guard] Bash 쓰기 차단(보호 경로): $cmd" >&2; exit 2
    fi
    ;;
  *)  # Write|Edit|MultiEdit|NotebookEdit — read BOTH path fields (see Pitfall 2)
    p=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
    if printf '%s' "$p" | grep -Eq "$PROTECTED"; then
      echo "[guard] 보호 파일 수정 차단: $p" >&2; exit 2
    fi
    ;;
esac
exit 0
```
Caveat: the `grep -E` regex above is *illustrative* — the planner owns the exact regex. The load-bearing requirement is that **one** pattern definition feeds both branches. (An alternative is keeping the existing `case` glob and reusing it via a shell function; either satisfies single-source.)

### Pattern 3: Stop loop guard (GATE-01)
**What:** On the second Stop pass, `stop_hook_active` is `true` — surface the failure once and yield (exit 0) so Claude can actually stop.
**When to use:** Top of `stop-verify.sh`, before running the build.
**Example:**
```bash
# Source: verified pattern (community sources + SC #4). stop_hook_active is a real Stop-hook input field.
set -o pipefail                               # already present (Phase 0 fix — keep)
input=$(cat)
if command -v jq >/dev/null 2>&1 \
   && [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ]; then
  echo "[verify] 이미 재검증 continuation 상태 — 루프 방지 위해 종료 허용" >&2
  exit 0
fi
# D-02: jq absent → best-effort, non-blocking (skip stack tests, warn) — NOT fail-closed here.
if ! command -v jq >/dev/null 2>&1; then
  echo "[verify] jq 미설치 → 검증 스킵(best-effort)" >&2
  exit 0
fi
# ... existing stack-detect compile+test ...
```
Note: `stop-verify.sh` currently reads nothing from stdin. Adding `input=$(cat)` to read `stop_hook_active` is a new, required behavior. Keep the existing `set -o pipefail` and stack-detection untouched (surgical change per CLAUDE.md §3).

### Pattern 4: `${CLAUDE_PROJECT_DIR}` hook resolution (CFG-02)
**What:** Prefix hook command strings so scripts resolve from project root regardless of cwd (SC #4: guard fires from a subdirectory).
**Example:**
```jsonc
// Source: code.claude.com/docs/en/hooks — ${CLAUDE_PROJECT_DIR} resolves to project root
"command": "bash ${CLAUDE_PROJECT_DIR}/.claude/hooks/pretool-guard.sh"
```
Apply to all five hook command strings in `settings.json` (CFG-02 says "hooks", plural). This fixes **script location resolution** only. `stop-verify.sh`'s internal cwd-relative build detection (`[ -f gradlew ]`) is a separate concern owned by Phase 5 (GATE-03 incremental verify) — do not expand into it.

### Anti-Patterns to Avoid
- **Widening the matcher without reading `notebook_path`:** blocks nothing new for NotebookEdit (fail-open). See Pitfall 2.
- **`2>/dev/null` on the jq extraction as the only "handling":** that IS the current fail-open bug — a missing/failed jq yields empty output and the `case` falls through to `exit 0`.
- **Duplicating the protected pattern in two places:** guarantees drift (CONTEXT §Specifics). Single-source it.
- **Building a shell parser for Bash-write detection:** explicitly out of scope; documented ceiling.
- **Using `exit 1` to block:** `exit 1` is non-blocking pass-through. Only `exit 2` blocks.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Parse hook stdin JSON | pure-Bash JSON parser | `jq` (already a dep) | JSON edge cases (escaping, nesting) are exactly what jq exists for. |
| Detect "is this a write command?" in Bash | full shell tokenizer / AST | substring/regex match on `.tool_input.command` (best-effort) | A correct shell parser is enormous; CONTEXT explicitly declares obfuscated/piped writes an out-of-scope ceiling. Root defense is `.gitignore` + rules. |
| settings.json schema validation | custom validator | declare `$schema` → editor validates | CFG-04's intent is *early drift detection*, which editors give for free via the schema. |

**Key insight:** This phase's failures are all *fail-open leaks in existing code*, not missing features. The fix is subtractive/surgical (add a preamble, read one more field, remove a key) — resist adding machinery. The single biggest correctness lever is reading `notebook_path`, which is one extra `//` fallback in a jq expression.

## Runtime State Inventory

> This phase edits hooks/config (a refactor-class change). The relevant runtime state is *how Claude Code loads config*, not stored data.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no datastore in this project. | None. |
| Live service config | **`settings.json` hook registration is read at session start.** Matcher/timeout/command changes do NOT take effect mid-session. | After editing `settings.json`, Claude Code must be restarted (or a fresh session started) for the new matcher/timeout to apply. Testing must therefore drive the hook scripts directly via stdin, not rely on live in-session triggering. |
| OS-registered state | None — no OS-level task/service registration. | None. |
| Secrets/env vars | `${CLAUDE_PROJECT_DIR}` is set by Claude Code in the hook process environment; the guard's protected-path *patterns* reference `.env*` by name but the change is code/config only. | None — no secret key is renamed. |
| Build artifacts | None — Bash scripts are not compiled; no egg-info/dist. `git init` is absent (C3) but Phase 1 changes are git-independent. | None; C3 is not a Phase 1 blocker. |

**The canonical question — after all files are edited, what still holds old behavior?** Only the *live Claude Code session*: it keeps the previously-registered matcher/timeout until restarted. Verify via direct script invocation (stdin + exit-code asserts), which is session-independent.

## Common Pitfalls

### Pitfall 1: Fail-open on jq/parse failure (the GUARD-01 bug itself)
**What goes wrong:** `f=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)` — when jq is missing or JSON is malformed, `f` becomes empty, the `case` matches nothing, and the script falls through to `exit 0` (ALLOW). A protected write slips past exactly when the environment is degraded.
**Why it happens:** `//empty` + `2>/dev/null` silently coerce failure into "no match," and the default terminal action is allow.
**How to avoid:** Fail-closed preamble (Pattern 1) *before* any extraction. Distinguish jq-absent vs parse-failure in the message (D-03).
**Warning signs:** Any guard path where an error yields empty output followed by an allow.

### Pitfall 2: NotebookEdit path is `notebook_path`, not `file_path` (breaks SC #2)
**What goes wrong:** Widening the matcher to include `NotebookEdit` (GUARD-02) while the hook only reads `.tool_input.file_path` blocks nothing new — NotebookEdit puts the file at `.tool_input.notebook_path`, so `file_path` is empty → `exit 0` (fail-open). SC #2 ("`NotebookEdit` write to a protected path blocked identically to Write/Edit") silently fails.
**Why it happens:** Different tools use different `tool_input` field names; the wrapper (`tool_name`/`tool_input`) is uniform but the inner keys are not. `[VERIFIED: multiple sources — NotebookEditToolParams uses notebook_path]`
**How to avoid:** Read both: `jq -r '.tool_input.file_path // .tool_input.notebook_path // empty'`. (Write/Edit/MultiEdit all use `file_path`; only NotebookEdit differs.)
**Warning signs:** A NotebookEdit test to `.env.production` that returns exit 0.

### Pitfall 3: jq-absent fail-closed blocks ALL Bash commands (blast-radius consequence of D-01)
**What goes wrong:** D-01 says the Bash-write check fail-closes on jq absence. Because a jq-less hook cannot inspect `.tool_input.command`, the fail-closed rule blocks **every** Bash command (including `npm test`, `ls`) until jq is installed — not just writes.
**Why it happens:** Fail-closed means "if you can't inspect, assume dangerous." With the Bash matcher active and jq gone, nothing can be inspected.
**How to avoid:** This is intended per D-01, not a bug — but the D-03 message must make the remedy obvious ("jq 설치 후 재시도"). Because it is a broad consequence, it is flagged in Open Questions for reconfirmation during planning.
**Warning signs:** On a jq-less box, a benign `Bash(ls)` returns exit 2.

### Pitfall 4: Stop timeout default changed (60s → 600s) — the "60s" premise is stale
**What goes wrong:** GATE-02/REQUIREMENTS/D-06 assume a 60s default. The current default for `command` hooks is **600s** (verified). A `timeout` set to "300–600s thinking it raises 60s" may actually be *at or below* today's default and give a false sense of hardening.
**Why it happens:** The default silently changed across Claude Code versions — the exact C10 drift the phase fights.
**How to avoid:** Set the explicit `timeout` to comfortably exceed the *longest expected build*, and document the value's intent. If builds can exceed 600s, set higher (do not assume 600 is a floor). Making it explicit is drift-proof regardless of the moving default.
**Warning signs:** A long build's Stop verification "passes" instantly because the hook was cancelled at timeout (a cancelled command hook is non-blocking → gate bypassed).

### Pitfall 5: `set -o pipefail` regression in stop-verify.sh
**What goes wrong:** `cmd | tail` returns tail's exit code (always 0) without `pipefail`, so a failing build never sets `fail=1` → gate never blocks. This was the Phase 0 root-cause fix.
**How to avoid:** Keep the existing `set -o pipefail` line. When adding the `input=$(cat)` / `stop_hook_active` guard on top, do not remove or reorder it above the pipefail set-up in a way that reintroduces the leak.
**Warning signs:** A deliberately-failing build test exits 0 from `stop-verify.sh`.

## Code Examples

### Test harness: feed synthetic JSON, assert exit code
```bash
# Block case (protected path) — expect exit 2
echo '{"tool_name":"Write","tool_input":{"file_path":"x/.env.production"}}' \
  | bash .claude/hooks/pretool-guard.sh; echo "exit=$?"   # → 2

# NotebookEdit block (SC #2) — expect exit 2
echo '{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"a/.env.production"}}' \
  | bash .claude/hooks/pretool-guard.sh; echo "exit=$?"   # → 2

# Bash write block (SC #3) — expect exit 2
echo '{"tool_name":"Bash","tool_input":{"command":"echo secret > x/.env.production"}}' \
  | bash .claude/hooks/pretool-guard.sh; echo "exit=$?"   # → 2

# Benign Bash allow (SC #3) — expect exit 0
echo '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' \
  | bash .claude/hooks/pretool-guard.sh; echo "exit=$?"   # → 0

# Malformed JSON (SC #1) — expect exit 2
printf 'not json' | bash .claude/hooks/pretool-guard.sh; echo "exit=$?"   # → 2
```

### Test harness: simulate jq-absent (SC #1) without uninstalling jq
```bash
# Symlink only the externals the hook legitimately needs (NOT jq) into a temp PATH.
# bash builtins (command, case, exit, printf) work under any PATH.
nojq=$(mktemp -d); ln -s "$(command -v cat)" "$nojq/cat" 2>/dev/null
echo '{"tool_name":"Write","tool_input":{"file_path":"foo.txt"}}' \
  | PATH="$nojq" bash .claude/hooks/pretool-guard.sh; echo "exit=$?"   # → 2 (fail-closed)
```
Note: if the hook reads stdin via `input=$(</dev/stdin)` instead of `$(cat)`, no external is needed and `PATH= bash hook.sh` works directly (even cleaner). Either is fine.

### Stop loop-guard test (SC #4)
```bash
echo '{"stop_hook_active":true}' | bash .claude/hooks/stop-verify.sh; echo "exit=$?"  # → 0 (no loop)
```

### CFG verification asserts (SC #5)
```bash
# commit disable-model-invocation
grep -q 'disable-model-invocation: true' .claude/commands/commit.md && echo OK

# settings.json declares $schema and still parses
jq -e '."$schema"' .claude/settings.json >/dev/null && echo OK

# critical rules have NO paths: key
for f in git-workflow security testing; do
  grep -q '^paths:' ".claude/rules/common/$f.md" && echo "FAIL $f" || echo "OK $f"
done
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hook `command` default timeout 60s | **Default 600s** for `command`/`http`/`mcp_tool` hooks (30s for UserPromptSubmit, 10s for MessageDisplay) | Changed across Claude Code versions (exact version not pinned) | GATE-02: the "60s" premise is stale; set explicit `timeout` regardless (Pitfall 4). `[CITED: code.claude.com/docs/en/hooks]` |
| Slash commands as `.claude/commands/*.md` (separate system) | **Custom commands merged into skills**; `.claude/commands/*.md` still work and support the same frontmatter | Recent | CFG-03: adding `disable-model-invocation: true` to `commit.md` frontmatter is valid; the file keeps working. `[CITED: code.claude.com/docs/en/skills]` |
| `paths:` glob for rule loading | Version-fragile (MANUAL §6 ⚠️); always-on (no `paths:`) recommended for critical rules | — | CFG-01 rationale — D-04 removes the key entirely. |

**Deprecated/outdated:**
- **Env-var hook input:** legacy. Hooks read stdin JSON via `jq` (MANUAL §6, official docs). Confirmed still current.
- **"exit 1 blocks":** never true — `exit 1` is non-blocking. Only `exit 2` blocks. Confirmed current.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The `$schema` SchemaStore URL (`json.schemastore.org/claude-code-settings.json`) accepts a top-level `$schema` key and validates the current settings.json shape | CFG Mechanics | Low — `$schema` is advisory/editor-side; a stale schema at worst shows a spurious editor warning, does not affect runtime. Verify the current settings.json validates before claiming SC #5's "validates against its declared $schema." |
| A2 | The exact regex for the shared protected pattern (Pattern 2) correctly matches all in-scope cases with no false positives (e.g. `.environment.ts` must NOT match) | Pattern 2 | Medium — a bad regex either misses a protected path (fail-open) or blocks benign files. Planner must table-test both directions; the existing `case` glob already avoids the `.environment` false-positive (C4), so reuse its semantics. |

*Both are implementation-detail assumptions, not decision-level. No new user decision is required beyond the Open Questions below.*

## Open Questions (RESOLVED)

1. **jq-absent blast radius on Bash (Pitfall 3) — confirm intent.**
   - What we know: D-01 (locked) says the Bash-write check fail-closes on jq absence → with the Bash matcher active, ALL Bash commands are blocked until jq is installed, not just writes.
   - What's unclear: whether the user fully intended blocking *every* Bash command (not just writes) in a jq-less environment.
   - Recommendation: proceed per D-01 (honor the locked decision), ensure the D-03 message states "install jq to restore," and surface this consequence to the user at plan/discuss time for a quick reconfirm. Low reversal cost (one branch).
   - **RESOLVED:** Plan 01-01 honors D-01 as-is (fail-closed preamble on the write paths; the jq-absent case blocks with a `install jq` cause message per D-03). Intent accepted at planning time; no reconfirm needed.

2. **Exact Stop `timeout` value (D-06 leaves it to planner; Pitfall 4 shifts the baseline).**
   - What we know: current default is 600s; D-06 wants "generous."
   - What's unclear: the longest realistic build for this template's target stacks (gradle test + vitest).
   - Recommendation: set explicitly to a value that clearly exceeds expected builds and is unambiguously intentional (e.g. 600s if that comfortably covers builds; higher for large monorepos). Document the chosen value's rationale in-line so it reads as intent, not a copy of the default.
   - **RESOLVED:** Plan 01-04 sets Stop `timeout: 900` — deliberately above the current 600s command-hook default so it reads as intent, not a stale-60s copy — with inline rationale.

3. **Single `pretool-guard.sh` (matcher `…|Bash`) vs. two PreToolUse entries.**
   - What we know: CONTEXT allows "별 매처 or 통합 훅." One hook branching on `tool_name` gives single-source pattern for free.
   - Recommendation: one hook, combined matcher `Write|Edit|MultiEdit|NotebookEdit|Bash`, branch internally (Pattern 2). Fewer files, one pattern definition. Split only if the planner finds the branch unwieldy.
   - **RESOLVED:** Plan 01-01 chose the single combined hook branching on `tool_name`; Plan 01-04 wires the combined matcher `Write|Edit|MultiEdit|NotebookEdit|Bash`.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| jq | All guard/gate JSON parsing | ✓ | 1.8.1 `[VERIFIED: jq --version]` | For guard: fail-closed (exit 2) is the deliberate "fallback" (D-01). For Stop: skip tests, warn (D-02). |
| bash | Hook execution | ✓ | system (`/usr/bin/env bash`) | — |
| git | Not needed by Phase 1 (C3: repo not init'd) | ✗ | — | None needed — all Phase 1 changes are git-independent. `git init` surfaces in Phase 3/5, not here. |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** git absent, but not required by Phase 1 (Phase 1 tests run via stdin + exit-code asserts, no git).

## Security Domain

> This phase IS a security-enforcement phase. ASVS web categories (auth/session/access-control) are N/A — there is no web surface. The applicable category is **V5 Input Validation**, because the guard consumes untrusted input (hook stdin JSON + arbitrary Bash command strings).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth surface. |
| V3 Session Management | no | No sessions. |
| V4 Access Control | partial | The guard *is* the access-control gate for protected files; the control is the exit-2 block on matched paths. |
| V5 Input Validation | **yes** | Validate hook input parses (`jq empty`) before trusting it; fail-closed on invalid input (Pattern 1). Do not `eval` the Bash command string — only string-match it. |
| V6 Cryptography | no | No crypto in this phase (secret *content* scanning is Phase 5 GUARD-04). |

### Known Threat Patterns for Bash-hook enforcement

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Guard fail-open on degraded environment (jq gone / malformed JSON) | Elevation of Privilege (bypass) | Fail-closed preamble → exit 2 (GUARD-01, Pattern 1). |
| Write-tool coverage gap (NotebookEdit `notebook_path`) | Tampering (protected file written) | Read all path fields; expand matcher (GUARD-02, Pitfall 2). |
| Command-string obfuscation (pipes, var-substitution, heredoc) | Tampering (bypass Bash-write guard) | Best-effort substring/regex match; documented ceiling; root defense `.gitignore .env*` + rules. Do NOT `eval` the command. |
| Stop-gate silent disable (infinite loop / timeout truncation) | Denial of Service / bypass | `stop_hook_active` guard (GATE-01) + explicit generous `timeout` (GATE-02). |
| Injection via crafted command string being *executed* by the hook | Tampering | Never execute `.tool_input.command`; treat it as opaque data to match against, never pass to `eval`/`sh -c`. |

## Sources

### Primary (HIGH confidence)
- `code.claude.com/docs/en/hooks` — exit-code contract (exit 2 = PreToolUse block / Stop continue; exit 1 non-blocking), `command` default timeout 600s, `timeout` field (seconds, per-handler), `${CLAUDE_PROJECT_DIR}` resolves to project root and is valid in command strings, `.tool_input.command` for Bash, `tool_name`/`tool_input` wrapper.
- `code.claude.com/docs/en/skills` (slash-commands redirect) — `disable-model-invocation: true` frontmatter (default false; docs cite `/commit`/`/deploy` as the canonical use); `.claude/commands/*.md` still work and support the same frontmatter.
- Existing codebase: `pretool-guard.sh`, `stop-verify.sh`, `settings.json`, `commit.md`, `rules/common/*` frontmatter (all read directly), `HARNESS-TEMPLATE-MANUAL.md` §2.2/§3/§6, `.planning/codebase/{ARCHITECTURE,CONCERNS}.md`.
- Environment probes: `jq 1.8.1` present, actual `paths: ["**/*"]` frontmatter confirmed on all three `common/` rules.

### Secondary (MEDIUM confidence)
- WebSearch (multiple concurring sources: claudefa.st, amitkoth.com, codingwithroby, aiorg.dev) — `stop_hook_active` is a real Stop-hook input boolean, `true` on forced-continuation; loop-guard pattern `[ stop_hook_active = true ] && exit 0`. Corroborated by phase SC #4.
- WebSearch (SchemaStore + anthropics/claude-code#11795) — settings.json `$schema` = `https://json.schemastore.org/claude-code-settings.json` (community-maintained; no official Anthropic-hosted schema, per the open issue).
- WebSearch (Piebald-AI system-prompts repo, NotebookEditToolParams) — NotebookEdit uses `notebook_path` (+ `cell_number`, `new_source`, `cell_type`, `edit_mode`).

### Tertiary (LOW confidence)
- None relied upon. The one WebFetch that claimed `stop_hook_active` "does not exist" was a summarizer miss (the docs excerpt didn't include the Stop-specific input section); overridden by concurring secondary sources and the phase's own SC.

## Metadata

**Confidence breakdown:**
- Hook exit-code contract & lifecycle: HIGH — official docs + existing manual agree.
- `stop_hook_active`: HIGH — multiple concurring sources + phase SC; single WebFetch miss discounted.
- Timeout default (600s): HIGH — quoted twice from official docs; corrects the requirement's stale 60s.
- NotebookEdit `notebook_path`: HIGH — multiple sources; directly load-bearing for SC #2.
- `disable-model-invocation` / `${CLAUDE_PROJECT_DIR}`: HIGH — official docs, exact field names quoted.
- `$schema` URL: MEDIUM — community SchemaStore, no official schema; advisory only.
- Bash-write detection: HIGH on approach, MEDIUM on exact regex (planner owns it; documented ceiling caps ambition).

**Research date:** 2026-07-06
**Valid until:** ~2026-08-05 (30 days). Hook contract is version-sensitive (MANUAL §6, C10) — re-confirm `timeout` default and `stop_hook_active` against `/hooks` and code.claude.com/docs if Claude Code is upgraded before implementation.
