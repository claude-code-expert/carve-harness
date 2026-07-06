# Feature Research

**Domain:** Claude Code AI coding-agent harness / guardrail template (constraints + feedback + state pillars, language-agnostic drop-in for Java/Spring + React/Next)
**Researched:** 2026-07-06
**Confidence:** MEDIUM-HIGH — hook mechanics & lifecycle events are HIGH (official docs + multiple agreeing community repos); pattern taxonomy is MEDIUM (community harness-engineering write-ups, one derived from a Claude Code source-leak analysis).

## How This Maps to What We Already Have

`Coverage` column legend (per `.planning/codebase/CONCERNS.md`):

- **HAVE** — implemented and verified in our template.
- **PARTIAL** — skeleton exists but is a stub / hardcoded / advisory-only.
- **MISS** — not present.
- **N-A** — deliberately out of scope for a zero-runtime-dependency local drop-in (see Anti-Features).

The milestone brief said: do NOT restate our existing features as new. So the value below is concentrated in the **PARTIAL** and **MISS** rows — those are the gaps a best-in-class harness closes that ours does not yet.

## Feature Landscape

### Table Stakes (a harness without these is incomplete)

| Feature | Why Expected | Complexity | Coverage | Notes / CONCERN link |
|---------|--------------|------------|----------|----------------------|
| Pre-write path guard (block protected files, `exit 2`) | The one unconditional block in Claude Code; rules the model "may skip" are not enough | LOW | **HAVE** | `pretool-guard.sh` — `.env/secret/prod/migration`. Verified narrow (no false positives). |
| Post-write auto-format on Edit/Write | Highest-value first hook per every source; keeps diffs clean deterministically | LOW | **HAVE** | `posttool-format.sh` (spotless/prettier). But swallows all output — see TS "hook observability". |
| Stop-time verification gate (compile + typecheck + test, `exit 2` re-prompts) | Stop-hook `exit 2` re-injects stderr so the agent resumes and fixes; enforces the dev-loop SOP | MEDIUM | **HAVE** | `stop-verify.sh` with `pipefail` root-fix. Strong. Latency caveat → see Anti-Features AF2 / C9. |
| Session state handoff surviving compaction (PreCompact save + SessionStart restore) | Context exhaustion is the #1 failure mode; compaction "evaporates rationale, keeps only outcomes" | MEDIUM | **PARTIAL** | `session-handoff.sh` writes `TODO: [자동 수집 — 내용없음]` hardcoded. **C7** — only branch is real. Needs real TODO/next-step capture. |
| Permission deny-list (`rm -rf`, force-push, secret read) | Layer-3 enforcement; advice vs enforcement distinction | LOW | **HAVE** | `settings.json` deny. Best-effort (C5 ceiling: `less/head/grep` bypass) — acknowledged. |
| Generator/Evaluator separation (review subagents in isolated context) | "Most underused SDD pattern": a separate agent checks the work; self-eval is a blindspot | MEDIUM | **HAVE** | 5 agents (evaluator/code/security/silent-failure/state). Matches `AGENTS.md` Self-Eval rule. |
| Stack-scoped rules (path-glob auto-load) | Load only relevant conventions; avoid dumping every rule into context | LOW | **HAVE** | `rules/{common,java-spring,react-next}`. **C10**: `paths:` loading varies by CC version → duplicate only load-bearing rules into `CLAUDE.md`. |
| SDD artifacts persisted to disk (spec / plan / SC survive sessions) | Plan-mode plans live in memory and die; SDD files survive restart with human review between phases | MEDIUM | **HAVE** | `specs/` exists; `README` is a stub. Structure present, discipline not yet wired. |
| **Secret CONTENT scanning on write/commit** (regex `AKIA…`/`sk-…`/`ghp_…` + entropy) | Path guards miss a hardcoded key pasted into a `.java`/`.ts` file — the actual leak vector | MEDIUM | **MISS** | Distinct from C5 (which is about *reading* `.env`). We block by *path*, never scan *content*. gitleaks/trufflehog on `git diff --cached`, or a regex PreToolUse hook. |
| **Hook-failure observability** (don't `2>/dev/null`; surface failures) | "Missing observability when hooks fire" is a named anti-pattern; a formatter that silently isn't installed rots quietly | LOW | **MISS** | **C8** — `posttool-format.sh` swallows everything. Emit to stderr/log; adopt `PostToolUseFailure` event for corrective feedback. |
| **Self-audit that actually pass/fails** the harness config | A harness that can't verify its own wiring is just hope; drift (unregistered hook, missing `chmod +x`) is silent | MEDIUM | **PARTIAL** | `/harness-audit` is a prose prompt, not a real check. Make it assert: hooks registered, scripts executable, `bash -n` clean, specs present → PASS/FAIL. |
| **Decision log** (append-only `DECISIONS.md` on arch/dep/API change) | Rationale is what compaction destroys first; an append-only ledger is the durable record | LOW | **PARTIAL** | `changelog` skill → `DECISIONS.md` exists as stub. Wire the trigger + append format. |

### Differentiators (make a harness notably better)

| Feature | Value Proposition | Complexity | Coverage | Notes |
|---------|-------------------|------------|----------|-------|
| Structured JSONL event log for every hook | "The baseline every project should have" (disler); a replayable session timeline for debugging, zero external infra — just append JSON lines to `logs/` | MEDIUM | **MISS** | Fits our zero-dep constraint (Bash `echo` + `jq` append). This is the observability layer we lack entirely. |
| `PostToolUseFailure` hook (auto corrective feedback) | Fires when a tool errors; feed the error back so the agent self-corrects instead of plowing on | LOW | **MISS** | Directly complements the C8 fix. New-ish event — gate behind a CC-version check. |
| `UserPromptSubmit` hook (audit log + context injection) | Log intent before Claude acts; inject standing context (e.g. current spec) each turn | LOW | **MISS** | Cheap audit trail; also a place to re-assert critical rules that compaction dropped. |
| Command risk classification (deterministic Bash pre-parse: low/med/high) | Beyond a static deny-list — parse the command string, block/ask by risk tier | MEDIUM | **PARTIAL** | C5 names this as the "root" fix beyond deny-list. A Bash-matcher PreToolUse hook inspecting `.tool_input.command`. |
| Explore→Plan→Act permission escalation | Read-only exploration phase before write access; prevents premature edits | MEDIUM | **PARTIAL** | We have `/plan` but don't *enforce* a read-only phase. Advisory today. |
| Incremental / scoped Stop verification | Verify only changed modules, not full build+test every Stop | MEDIUM | **MISS** | This is the fix for AF2 / **C9**. Keeps the gate without the latency tax. |
| PreCompact full-transcript backup (not just summary) | Compaction is lossy; a raw transcript snapshot is recoverable when the summary drops a critical number | LOW | **MISS** | We save a handoff summary, never the raw transcript. One `cp`/append. |
| Context-isolated *research* subagent | Keep exploration noise out of the main window (distinct from review agents) | MEDIUM | **PARTIAL** | We have review agents; no "go explore and return a summary" agent. |

### Anti-Features (deliberately do NOT build)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Over-broad pre-write blocking | "Block more = safer" | Named anti-pattern: "over-blocking without business context." Devs hit false blocks, then disable the whole harness — net negative safety | Keep guards path-scoped and narrow (as ours is). Expand only on a real incident (CLAUDE.md-as-failure-log discipline). |
| Full build + test on every Stop | "Always verify everything" | "Over-verification creating context bloat" + latency; on a big repo the gate stalls every response. This is **C9** | Incremental/changed-scope verify locally; push full test matrix to CI (already Out of Scope per PROJECT.md). |
| Runtime observability infra (real-time dashboard, OpenTelemetry, SIEM) | "Enterprise-grade visibility" | Adds servers/daemons/deps; violates our **zero-runtime-dependency** constraint (Bash+jq only). Overkill for a drop-in | JSONL append to `logs/` (see Differentiators) — infra-free, filesystem-readable. |
| TTS / audio notifications on Stop / SubagentStop | Popular in demo repos | Zero value in a shared template; noise, extra deps (ElevenLabs/OpenAI) | Silent structured logging; let the human read the log. |
| Fork-join git-worktree parallelism / agent teams | "10x throughput" | Heavy orchestration, worktree management, merge conflicts; far beyond a guardrail template's scope | Single-agent Plan→Work→Review. Out of scope for this milestone. |
| Aspirational CLAUDE.md wishlist rules | "Just tell Claude the rules" | Rules the model "skips under context pressure" — enforcement in prose is not enforcement | Failure-to-Constraint tree: dangerous action → **hook**; workflow → **command**; style → **CLAUDE.md**. Put teeth in hooks. |
| Auto-approve-all / YOLO permissions | "Fewer prompts, faster" | Defeats the entire point of the constraints pillar | Deny-list + risk classification + explicit allow for vetted read-only ops. |
| Indiscriminately duplicating all rules into CLAUDE.md | "Guard against `paths:` version drift (C10)" | Bloats every context window with irrelevant stack rules | Duplicate only the *load-bearing critical* rules (secrets, block invariants); leave stack conventions in `paths:`-scoped files. |

## Feature Dependencies

```
Structured JSONL event log (D1)
    └──enables──> Hook-failure observability (TS10 / C8)
    └──enables──> Self-audit pass/fail (TS11)   # audit can read the log for "did hooks fire?"

Real state capture (TS4 / C7)
    └──requires──> Decision log populated (TS12)  # handoff summarizes DECISIONS.md + open SC
    └──enhances──> PreCompact transcript backup (D6)

PostToolUseFailure hook (D2) ──implements──> Hook-failure observability (TS10)

Command risk classification (D4) ──supersedes──> static deny-list (permission layer, C5)

Incremental verify (D7) ──resolves──> Anti-Feature AF2 / C9 (full-build latency)

Secret content scanning (TS9) ──complements──> path guard (pretool-guard, HAVE)
    # path guard blocks editing .env; content scan blocks a key pasted into any file
```

### Dependency Notes

- **Observability (D1) is the keystone.** It's the missing layer (ShipWithAI's Layer 5) and it unblocks both the C8 fix (TS10) and a real self-audit (TS11). Build it first among the gaps.
- **Handoff (C7) depends on the decision log (TS12).** A meaningful handoff summarizes *what was decided* and *what's still open* — both live in `DECISIONS.md` / `specs/`. Fixing the hardcoded `[내용없음]` means having something real to collect.
- **Content scanning (TS9) does not replace the path guard** — they cover different leak vectors. Both are table stakes; we only have the path half.

## MVP Definition

### Launch With (close the table-stakes gaps)

- [ ] **TS10 / C8 — Hook-failure observability.** Stop swallowing `2>/dev/null`; route formatter/verify output to a log + stderr. Lowest effort, named anti-pattern, unblocks self-audit.
- [ ] **TS11 — Self-audit that actually PASS/FAILs.** `/harness-audit` asserts hooks registered + scripts `+x` + `bash -n` clean + specs present. A harness that can't check itself isn't one.
- [ ] **TS4 / C7 — Real handoff state capture.** Replace hardcoded TODO with actual open-SC / next-step collection.
- [ ] **TS9 — Secret content scanning.** Regex-tier PreToolUse (or pre-commit) scan for `AKIA…/sk-…/ghp_…` + high-entropy strings. The path guard has a hole.

### Add After Validation

- [ ] **D1 — Structured JSONL event log.** Infra-free audit timeline; retro-fits the observability layer.
- [ ] **TS12 — Populate the decision ledger** (append-only `DECISIONS.md`) so handoff has real content to summarize.
- [ ] **D7 / C9 — Incremental Stop verify.** Removes the full-build latency tax once the gate is trusted.

### Future Consideration

- [ ] **D2 `PostToolUseFailure` / D3 `UserPromptSubmit`** — gate behind a CC-version check (C10 volatility).
- [ ] **D4 — Command risk classification** — the "root" upgrade past the deny-list ceiling (C5).
- [ ] **D5 — Enforced Explore→Plan→Act** phase permissions.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| TS10 Hook-failure observability (C8) | HIGH | LOW | P1 |
| TS11 Self-audit pass/fail | HIGH | MEDIUM | P1 |
| TS4 Real handoff capture (C7) | HIGH | MEDIUM | P1 |
| TS9 Secret content scanning | HIGH | MEDIUM | P1 |
| D1 Structured JSONL event log | MEDIUM | MEDIUM | P2 |
| TS12 Decision ledger populated | MEDIUM | LOW | P2 |
| D7 Incremental Stop verify (C9) | MEDIUM | MEDIUM | P2 |
| D2 PostToolUseFailure hook | MEDIUM | LOW | P3 |
| D4 Command risk classification (C5) | MEDIUM | HIGH | P3 |
| D5 Enforced Explore→Plan→Act | LOW | MEDIUM | P3 |

**Priority key:** P1 = must-close table-stakes gap · P2 = high-leverage differentiator · P3 = version-sensitive / advanced.

## Competitor Feature Analysis

| Feature | disler hooks-mastery / observability | ShipWithAI 5-layer / cc-sdd | Our Approach |
|---------|--------------------------------------|-----------------------------|--------------|
| Hook coverage | All 13 lifecycle events wired | Pre/Post/Stop minimum + escalate on incident | We use 5 events; add PostToolUseFailure + optionally UserPromptSubmit |
| Observability | Every event → JSONL in `logs/`, replayable timeline | Layer 5: session logs, verification middleware, decision audit trail | Adopt JSONL append (zero-dep) — currently our biggest missing layer |
| Secret prevention | PreToolUse regex + gitleaks/trufflehog fallback | Deny-list + prod-env gates | Path guard (HAVE) + add content scan (MISS) |
| Verification | Stop hook + `/done` checklist middleware | Separate Verifier agent vs Implementor | Stop gate + evaluator agent (HAVE) — make incremental |
| State / compaction | PreCompact transcript backup | Tiered memory + MEMORY.md weekly index | Handoff summary (PARTIAL) — make real, add transcript backup |
| Anti-pattern stance | — | Explicitly warns: over-blocking, over-verification, context bloat, aspirational rules | Aligns with our ponytail/YAGNI + zero-dep constraints |

## Sources

- Claude Code Hooks reference (official) — https://code.claude.com/docs/en/hooks — HIGH
- Claude Code Hooks: Complete Guide to All 12 Lifecycle Events (claudefa.st) — https://claudefa.st/blog/tools/hooks/hooks-guide — HIGH (cross-checks official)
- disler/claude-code-hooks-mastery (13 events, JSONL logging baseline) — https://github.com/disler/claude-code-hooks-mastery — MEDIUM
- disler/claude-code-hooks-multi-agent-observability — https://github.com/disler/claude-code-hooks-multi-agent-observability — MEDIUM
- 12 Agentic Harness Patterns from Claude Code (generativeprogrammer, source-leak analysis) — https://generativeprogrammer.com/p/12-agentic-harness-patterns-from — MEDIUM
- The Claude Code Leak: 10 Agentic AI Harness Patterns (Ken Huang) — https://kenhuangus.substack.com/p/the-claude-code-leak-10-agentic-ai — MEDIUM
- Claude Code Harness Engineering: The Complete Guide, 5 layers (ShipWithAI) — https://shipwithai.io/blog/claude-code-harness-engineering-guide/ — MEDIUM
- Claude Code Harness Pattern 9: Observability & Debugging (Ken Huang) — https://kenhuangus.substack.com/p/claude-code-harness-pattern-9-observability — MEDIUM
- Steering Claude Code: skills, hooks, rules, subagents (Anthropic) — https://claude.com/blog/steering-claude-code-skills-hooks-rules-subagents-and-more — HIGH
- Block API Keys & Secrets with Claude Code Hooks (aitmpl) — https://aitmpl.com/blog/security-hooks-secrets/ — MEDIUM
- coo-quack/sensitive-canary (secret/PII guard hooks) — https://github.com/coo-quack/sensitive-canary — MEDIUM
- mafiaguy/claude-security-guardrails (PreToolUse/PostToolUse dangerous-op scanning) — https://github.com/mafiaguy/claude-security-guardrails — MEDIUM
- Gitleaks vs TruffleHog comparison (Rafter) — https://rafter.so/blog/secrets/secret-scanning-tools-comparison — MEDIUM
- Chachamaru127/claude-code-harness (Plan→Work→Review cycle) — https://github.com/Chachamaru127/claude-code-harness — MEDIUM
- gotalab/cc-sdd (SDD harness with Agent Skills) — https://github.com/gotalab/cc-sdd — MEDIUM

---
*Feature research for: Claude Code AI coding-agent harness / guardrail template*
*Researched: 2026-07-06*
</content>
</invoke>
