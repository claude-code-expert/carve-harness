# Pitfalls Research

**Domain:** Claude Code agent harness (constraints / feedback / state pillars) — language-agnostic drop-in for Java/Spring + React/Next
**Researched:** 2026-07-06
**Confidence:** HIGH (exit-code semantics, matcher rules, `stop_hook_active`, SessionStart `compact`/SessionEnd, `$CLAUDE_PROJECT_DIR` all verified against current official docs at code.claude.com; cross-checked against community post-mortems and the actual hook source in `.claude/hooks/`)

> Scope note: the two bugs already fixed this session (pipefail `cmd | tail || fail=1` masking, and `.env.production` / root `db/migration` glob holes) are **not** re-listed here. Everything below is a *different* failure mode found by auditing the real hooks against current Claude Code hook behavior.

---

## Critical Pitfalls

### Pitfall 1: Fail-open guard when `jq` is missing or JSON is unparseable

**What goes wrong:**
Every hook extracts input with `jq -r '.tool_input.file_path // empty' 2>/dev/null`. If `jq` is not installed, or the stdin JSON is malformed, `jq` errors, `2>/dev/null` swallows the error, `f` becomes empty, the `case` falls through, and the hook `exit 0`s — **allowing the action**. The entire constraints pillar depends on a binary that, when absent, silently disables itself. `pretool-guard.sh`, `posttool-format.sh`, and `stop-verify.sh` all share this dependency.

**Why it happens:**
`2>/dev/null` on the parse plus a default of "allow on empty" is convenient for avoiding false positives, but it makes the *safe default* "let it through." A guard should fail **closed** (block on doubt) or at least fail **loud**; this one fails silent-open.

**How to avoid:**
- Dependency preflight at the top of each hook: `command -v jq >/dev/null || { echo "[guard] jq missing — guard DISABLED" >&2; exit 2; }` for the *blocking* guard (fail closed), and a visible stderr warning for feedback hooks.
- Do not send parse errors to `/dev/null`; only the successful value needs to be quiet.
- Have `/harness-audit` assert `jq` is on PATH as a pass/fail check.

**Warning signs:**
Guard "works" in your shell but never fires in a teammate's checkout; `/harness-audit` never flags a missing dependency; blocking a known-protected file succeeds locally but not on a fresh machine / CI container.

**Requirement to address:** `/harness-audit` (add jq + dependency preflight assertions); document install prerequisite in `install.md` (C1).

---

### Pitfall 2: Guard matcher only covers `Write|Edit` — MultiEdit, NotebookEdit, and Bash writes bypass it entirely

**What goes wrong:**
`settings.json` registers the guard with `"matcher": "Write|Edit"`. That is an exact-list match. Verified matcher rules: a bracket-clean list matches only those exact tool names; `MultiEdit` and `NotebookEdit` are **not** matched (you'd need `Edit.*` or an explicit list), and **`Bash` is not matched at all**. So a protected file can be written via:
- `Bash: printf 'x' > .env.production`
- `Bash: cp template.yml src/main/resources/application-prod.yml`
- `Bash: sed -i 's/.../.../' db/migration/V1__init.sql` (mutating an existing migration — the exact thing the rule forbids)
- `MultiEdit` / `NotebookEdit` on any protected path

Worse, even if Bash *were* matched, the guard reads `.tool_input.file_path`, but the Bash tool's payload is `.tool_input.command` — so it would read empty and pass anyway. This is the single largest remaining hole after the two already fixed: the guard protects one write path and leaves four open.

**Why it happens:**
`Write|Edit` looks exhaustive; it silently isn't. Tool surface drifts across Claude Code versions (MultiEdit has come and gone), and Bash-as-a-write-vector is easy to forget because it's not a "file" tool in the mental model.

**How to avoid:**
- Broaden the file-tool matcher to `Write|Edit|MultiEdit|NotebookEdit` (or `Write|.*Edit`).
- Add a **separate Bash matcher hook** that inspects `.tool_input.command` for writes to protected paths: redirects (`>`, `>>`, `tee`), in-place edits (`sed -i`, `perl -i`), and copies/moves (`cp`, `mv`, `install`) whose target matches the protected set. `ponytail:` this is best-effort (same ceiling as C5 — a determined shell can still evade); the goal is to close the *obvious* redirect, not to sandbox bash.
- Assert the matcher covers all write-capable tools in `/harness-audit`.

**Warning signs:**
`/harness-audit` can't answer "which tools can write `.env.production`?"; a test that blocks `Write .env.production` passes while `Bash echo > .env.production` succeeds.

**Requirement to address:** new guard-hardening requirement (C4/C5 family — none currently in Active covers Bash-write vector); `/harness-audit`.

---

### Pitfall 3: Stop hook forces an infinite / unfixable-gate loop (no `stop_hook_active` check)

**What goes wrong:**
`stop-verify.sh` returns `exit 2` on gate failure. For the `Stop` event, exit 2 does not just report — it **blocks the stop and forces Claude to continue the conversation**. The hook never reads `stop_hook_active`. So: Claude finishes → Stop hook `exit 2` → Claude is forced to keep working → finishes again → Stop hook `exit 2` again → loop. If the failing test is pre-existing, flaky, or something Claude cannot fix (e.g. missing DB, unrelated red build), the session is trapped burning tokens and never yields control. The docs and multiple post-mortems name this the #1 Stop-hook mistake.

**Why it happens:**
The naive model is "block until green," which is correct only when the failure is *caused by and fixable in* this turn. `stop_hook_active: true` in the Stop hook's stdin exists precisely to signal "you already forced a continuation once"; skipping the check turns a gate into a trap.

**How to avoid:**
- Read the flag: `active=$(jq -r '.stop_hook_active // false')`; if `true`, surface the failure once and `exit 0` (let the human decide) instead of blocking again.
- Distinguish "this turn broke it" from "repo was already red" where feasible, so the gate doesn't punish pre-existing failures.
- Be aware of the 60s hook timeout (see Pitfall 8) — a timeout is treated as a non-blocking error, which *also* silently defeats the gate in the opposite direction.

**Warning signs:**
A turn that won't end; repeated identical "검증 실패" messages; token spend climbing with no file changes between iterations.

**Requirement to address:** new Stop-hook robustness requirement (neighbor of C9); `/harness-audit` should confirm the flag is honored.

---

### Pitfall 4: State pillar is theater — handoff mechanism fires but carries hardcoded/empty content, and never saves on session end

**What goes wrong:**
Two independent problems in `session-handoff.sh`:
1. **Empty payload.** `save` writes `TODO: [자동 수집 — 내용없음]`. The compaction-survival *mechanism* is actually correct (PreCompact `save` → SessionStart re-fires with `source: "compact"` and its stdout is injected as context — both verified real behaviors), but the *content* is a constant, so nothing meaningful survives. The pillar looks continuous and is semantically empty.
2. **Save only on PreCompact.** The hook is wired to `PreCompact` only. Sessions that end *without* compaction — normal quit, `/clear`, logout, crash — never trigger a save. There is a dedicated `SessionEnd` event (matchers: `clear`, `resume`, `logout`, `prompt_input_exit`, `bypass_permissions_disabled`, `other`) that the harness does not use. So the restored handoff is only ever as fresh as the last *compaction*, which may be many turns stale or absent.

**Why it happens:**
"State survives compaction" was validated as a mechanism and checked off, but nobody verified the *content* was real or that the *non-compaction* exit paths were covered. Handoff correctness is invisible until the session you needed it for.

**How to avoid:**
- Collect real state in the `handoff` skill: open TODOs, current spec/SC, last-touched files, next step (this is C7).
- Wire `save` to `SessionEnd` as well as `PreCompact`, so ordinary session ends persist state.
- Verify restore end-to-end: after a compaction, confirm the injected context actually contains the saved TODOs (not the `[내용없음]` sentinel).

**Warning signs:**
`specs/HANDOFF.md` still contains the `[자동 수집 — 내용없음]` sentinel after real work; a resumed session has no idea what was in flight; `git branch --show-current` is the only live field.

**Requirement to address:** C7 (real TODO/next-step collection) + `SessionEnd` wiring; `/harness-audit` should reject the sentinel string as "not implemented."

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `2>/dev/null` on every hook command (format + jq parse) | No noisy output; hooks "just work" | Missing/broken formatter, missing jq, and parse failures all vanish — silent-open safety net (C8, Pitfall 1) | Only for genuinely optional cosmetic steps; never on the guard's parse or on dependency checks |
| Coverage 80% delegated to build config (jacoco/vitest thresholds) | Stop hook stays simple; no coverage math in bash | In a fresh drop-in the target repo has no threshold wired → rule is declared, nothing enforces it (policy/enforcement drift) | Acceptable *if* `/harness-audit` verifies the threshold exists in the target build config; never assume it's there |
| Relative hook paths (`bash .claude/hooks/…`, `[ -f gradlew ]`) | Shorter settings.json | Breaks in monorepo subdirs / after `cd` — our own layout has `backend/gradlew` + `frontend/package.json`; wrong cwd = silent no-op (fail-open again) | Single-root repos only; prefer `${CLAUDE_PROJECT_DIR}` |
| Blanket `*db/migration/*` block | One line stops migration edits | Also blocks *creating new* migrations — the exact intended workflow ("new versions only") — frustrating real work | Never as a blanket; must distinguish new file (allow) from edit of existing (block) |
| Full build+test on every Stop | Strongest possible gate | Multi-minute stalls per turn on large repos; risks 60s timeout → gate silently disabled (C9, Pitfall 8) | Small repos; otherwise scope to changed modules / push full suite to CI |

---

## Hook Event & Tool Integration Gotchas

Mistakes when wiring into Claude Code's hook API and the shell — the harness's "external services."

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `PostToolUse` exit code | Believing `exit 2` in a PostToolUse hook blocks the write | PostToolUse is **non-blocking** — the tool already ran; exit 2 only feeds stderr back to Claude. Enforcement must live in **PreToolUse**. The format hook rightly `exit 0`s, but don't ever rely on it to *reject* a bad edit. |
| `exit 1` vs `exit 2` | Using conventional Unix `exit 1` to block | Only `exit 2` blocks (for PreToolUse/Stop/UserPromptSubmit/PreCompact). `exit 1` and any other non-zero = **non-blocking** error, action proceeds. Verified in official docs. |
| Matcher tool names | Case/spelling drift (`write`, `edit`) or assuming a list is exhaustive | Tool names are **case-sensitive** and matched exactly for clean lists; run `/hooks` to confirm registration and coverage after every edit/upgrade. |
| `PreCompact` exit 2 | Not realizing a buggy PreCompact hook can **block compaction** | For PreCompact, exit 2 *prevents* compaction — a crashing `save` step can wedge the session. Keep `save` `exit 0` on its own errors. |
| `SessionStart` stdout | Assuming stdout is inert | SessionStart stdout is **injected as context**. Keep it clean and small (10k-char cap); junk (e.g., shell-profile banners if a hook spawns a login shell) pollutes the model's context. |
| `settings.json` paths | Using `$HOME`/`$VAR` in JSON command paths | Env vars are **not expanded** in settings JSON; use `${CLAUDE_PROJECT_DIR}` (supported) or absolute/`~` paths, or the hook silently fails to load. |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Full `gradlew compileJava test` + `tsc` + `pnpm test` on **every** Stop | Each turn ends with a multi-minute pause; UX feels frozen | Scope to changed modules; keep Stop to fast compile/typecheck, push full suite to CI (C9) | Medium+ repos; noticeable by ~1–2 min test suites |
| Synchronous hook exceeding the **60s default timeout** | Gate "passes" intermittently for no reason; hook logged as error | Keep hooks fast (<500ms for guards); raise timeout only for the heavy Stop gate and know a timeout = non-blocking = gate *off* | Any repo whose test/build > 60s — the gate you rely on quietly stops gating |
| Guard/format hook on every file write | Cumulative latency on multi-file edits | Guards must be trivial; never put API calls / heavy scans in PreToolUse or PostToolUse file-write hooks | High-frequency editing sessions |

---

## Security Mistakes

Domain-specific — beyond "don't hardcode secrets."

| Mistake | Risk | Prevention |
|---------|------|------------|
| Relying on `Bash(cat *.env*)` / `Bash(cat *secret*)` deny to stop secret reads | Trivially bypassed: `head`, `less`, `grep`, `xxd`, `source .env`, `python -c "open('.env')"`, `./.env` path variants — none match the prefix pattern (C5 ceiling) | Root defense is **keep secrets out of the repo** (env / secret manager), enforced by `security.md` + `CLAUDE.md`; `.gitignore` must list `.env*` so they're never committed (C11). Deny-list is best-effort only. |
| `Bash(git push*--force*)` deny as force-push protection | `git push -f`, `git push --force-with-lease`, `git push origin +main` all bypass the pattern | Prefer server-side branch protection; treat the deny as a speed-bump, not a control. |
| Over-broad `*secret*` block (guard + `Read(./**/*secret*)`) | Blocks legit source: `SecretManager.java`, `SecretConfig`, `docs/secrets.md` → agent can't read/edit real code, users disable the guard | Narrow to actual secret *files* (`*.env`, credential files), not any path containing "secret". Over-blocking that gets a guard switched off is a net security loss. |
| `*.env.*` blocks `.env.example` / `.env.sample` | The template files you *want* committed/edited are blocked | Exempt `*.example`, `*.sample`, `*.template` suffixes explicitly. |

---

## UX Pitfalls (developer experience of the harness)

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Over-blocking (`*secret*`, `*.env.*` template files, blanket migration dir) | Agent refuses legitimate edits; developer's fix is to delete/disable the guard → protection lost | Precision patterns + suffix exemptions; a guard that's turned off protects nothing (see Security table) |
| Silent format-hook failure (`2>/dev/null`, always `exit 0`) | Formatter silently not running or mangling files; developer trusts formatting that never happened (C8) | Emit a one-line visible notice on formatter failure (non-blocking is fine); optionally log to a file |
| Stop-gate lock with no escape (Pitfall 3) | Session won't end; user force-quits, loses in-flight state (compounds with Pitfall 4) | Honor `stop_hook_active`; give the human an exit |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces — run these during hardening.

- [ ] **Guard coverage:** blocks `Write .env.production` — but also verify `Bash echo > .env.production`, `cp … application-prod.yml`, `sed -i` on an existing migration, and `MultiEdit`/`NotebookEdit` on a protected path. (Pitfall 2)
- [ ] **Guard dependency:** works on a machine with **no `jq`** — does it fail closed/loud, or silently allow everything? (Pitfall 1)
- [ ] **Stop gate escape:** with a **pre-existing/unfixable** failure, does the turn eventually end, or loop forever? Confirm `stop_hook_active` is read. (Pitfall 3)
- [ ] **Stop gate timeout:** with a >60s test suite, does the gate still enforce, or does the timeout silently pass it? (Pitfall 8 / C9)
- [ ] **Handoff content:** after real work + a compaction, does `specs/HANDOFF.md` contain **actual TODOs**, or the `[내용없음]` sentinel? Does a non-compaction session end also save (SessionEnd)? (Pitfall 4 / C7)
- [ ] **Policy has a gate:** for every rule declared in `rules/*` (testing 80%, PII, Conventional Commits), name the gate that enforces it — or mark it "declared, unenforced." (Pitfall: policy/enforcement drift)
- [ ] **Registration:** run `/hooks` after install and after any Claude Code upgrade — are all 5 hooks actually loaded? (C10)
- [ ] **Over-block regression:** confirm `.env.example`, `SecretConfig.java`, and *creating a new* migration are all still allowed.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Fail-open guard shipped without jq check (P1) | LOW | Add preflight + audit assertion; ship. No data loss — just latent exposure until fixed. |
| Protected file written via Bash/MultiEdit bypass (P2) | LOW–MEDIUM | `git` history recovers file state if committed; add matcher breadth + Bash-write hook. If a secret was written to a tracked file, rotate the secret. |
| Stop-hook infinite loop hit in a live session (P3) | LOW | User interrupts; add `stop_hook_active` check before it can recur. |
| Empty/stale handoff discovered mid-resume (P4) | MEDIUM | State for that session is gone — reconstruct from git log / open buffers; implement real collection + SessionEnd so the next one survives. |
| Guard disabled by frustrated dev due to over-blocking (UX) | MEDIUM | Re-enable with narrowed patterns; audit git history for edits made while disabled. |

---

## Pitfall-to-Requirement Mapping

Mapped to the Active requirements in `.planning/PROJECT.md` (C1/C7/C8/C10/C11 + `/harness-audit`). Where no Active requirement covers a pitfall, a **new requirement** is flagged — these are the gaps the roadmap should add.

| Pitfall | Prevention Owner | Verification |
|---------|------------------|--------------|
| P1 Fail-open on missing jq | **`/harness-audit`** + `install.md` (C1) | Audit asserts `command -v jq`; guard test on jq-less PATH fails closed/loud |
| P2 Matcher misses MultiEdit/NotebookEdit/Bash writes | **NEW req: guard hardening** (C4/C5 family); `/harness-audit` | Bash `echo > .env.production` is blocked; audit enumerates write-tool coverage |
| P3 Stop-gate infinite loop | **NEW req: Stop-hook robustness** (neighbor of C9) | `stop_hook_active=true` path exits 0; pre-existing-failure session terminates |
| P4 Handoff empty + no SessionEnd save | **C7** + SessionEnd wiring; `/harness-audit` | HANDOFF.md contains real TODOs post-compaction; audit rejects `[내용없음]` sentinel |
| Policy/enforcement drift (rules with no gate) | **`/harness-audit`** | Audit maps each `rules/*` policy → enforcing gate; flags orphans (Core Value check) |
| Silent format failure | **C8** | Formatter failure emits visible notice; not `2>/dev/null`-swallowed |
| Version drift (matcher/frontmatter/JSON schema) | **C10** + `install.md` (C1) | Install/upgrade guidance says run `/hooks`; critical rules duplicated in CLAUDE.md |
| Deny-list secret-read/force-push bypass | **C11** (`.gitignore` `.env*`) + existing `security.md`/`CLAUDE.md` | `.env*` gitignored; documented as best-effort ceiling (already in C5) |
| Over-blocking (`*secret*`, `.env.example`, migrations) | **NEW/within guard hardening** | `.env.example`, `SecretConfig.java`, new migration file all allowed |
| Full build/test every Stop (perf + timeout) | **C9** | Stop scoped to changed modules or CI-offloaded; stays under/aware of 60s timeout |
| Relative hook paths / cwd | **C10** (portability) | settings.json uses `${CLAUDE_PROJECT_DIR}`; works from a subdir |

---

## Sources

- Claude Code Hooks reference — exit-code-per-event semantics, matcher regex rules (case-sensitive exact lists vs unanchored RegExp, `Edit.*` catches NotebookEdit), `SessionStart` `source: compact`/`resume` + stdout-as-context, `SessionEnd` event + matchers, `PreCompact` exit-2-blocks-compaction, `${CLAUDE_PROJECT_DIR}`, JSON output schema (`permissionDecision`, top-level `decision`/`reason`), 10k-char output cap, 60s timeout. https://code.claude.com/docs/en/hooks — HIGH
- Claude Code Settings reference — permissions `deny` patterns, gitignore-style Read globs, Bash prefix matching, scope precedence. https://code.claude.com/docs/en/settings — HIGH
- "5 Claude Code Hook Mistakes That Silently Break Your Safety Net" (dev.to/yurukusa) — exit 1 vs 2, `$HOME` not expanded in JSON, missing-`jq` silent failure, perf/<500ms, context-exhaustion auto-save. https://dev.to/yurukusa/5-claude-code-hook-mistakes-that-silently-break-your-safety-net-58l3 — MEDIUM (community, corroborated by official docs)
- "You're using Claude Code hooks wrong" (augmentedswe.com) — matcher case sensitivity, PostToolUse cannot block, 60s timeout silent failure, event-selection-for-purpose. https://www.augmentedswe.com/p/guide-to-claude-code-hooks — MEDIUM
- "Claude Code Stop Hook: Force Task Completion" (claudefa.st) & community posts — `stop_hook_active` infinite-loop pattern, `if stop_hook_active: sys.exit(0)`. https://claudefa.st/blog/tools/hooks/stop-hook-task-enforcement — MEDIUM (corroborated by official Stop-hook loop warning)
- anthropics/claude-code#10412 — Stop hooks with exit code 2 fail to continue when installed via plugins (version-drift evidence for C10). https://github.com/anthropics/claude-code/issues/10412 — MEDIUM
- Actual harness source: `.claude/hooks/{pretool-guard,stop-verify,posttool-format,session-handoff}.sh`, `.claude/settings.json`, and `.planning/codebase/CONCERNS.md` — HIGH (direct read)

---
*Pitfalls research for: Claude Code agent harness (constraints/feedback/state)*
*Researched: 2026-07-06*
</content>
</invoke>
