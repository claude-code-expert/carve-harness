# Architecture Research

**Domain:** Claude Code agent harness / guardrail system (drop-in constraints + feedback + state, language-agnostic)
**Researched:** 2026-07-06
**Confidence:** HIGH (hook lifecycle, extension-layer model — official docs); MEDIUM (mature-harness cycle patterns — repo READMEs + articles)

> Scope note: this documents how *mature* harnesses are structured and where our 3-pillar
> design (제약/피드백/상태) has structural gaps. It deliberately does **not** re-describe our
> current files. Every "our harness" mention is a comparison anchor, not a spec.

## Standard Architecture

A Claude Code harness is not an app — it is a set of files that hook into a fixed **session
lifecycle** the runtime exposes. Mature harnesses converge on four architectural layers, mapped
to seven "steering surfaces" Anthropic documents (CLAUDE.md, rules, skills, subagents, hooks,
output styles, system-prompt appends).

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│  CONTEXT LAYER (always-in-window, LLM reads it)                        │
│  ┌────────────┐  ┌──────────────────┐  ┌──────────────┐               │
│  │ CLAUDE.md  │  │ rules/ (paths:)  │  │ output-style │               │
│  │ (always-on)│  │ path-scoped OR   │  │ / sysprompt  │               │
│  │            │  │ always-on        │  │ append       │               │
│  └────────────┘  └──────────────────┘  └──────────────┘               │
├──────────────────────────────────────────────────────────────────────┤
│  ENFORCEMENT LAYER (deterministic, runtime-run, LLM cannot skip)      │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌──────────────┐        │
│  │ PreToolUse │ │ PostToolUse│ │    Stop    │ │ Session*/    │        │
│  │  (block)   │ │  (format)  │ │  (verify)  │ │ *Compact     │        │
│  └─────┬──────┘ └─────┬──────┘ └─────┬──────┘ └──────┬───────┘        │
│        │ exit 2       │ exit 0       │ exit 2        │ context I/O    │
├────────┴──────────────┴──────────────┴───────────────┴───────────────┤
│  JUDGMENT LAYER (LLM decides — invoked by command, skill, or HOOK)   │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────────────┐    │
│  │ subagents/   │  │ skills/      │  │ prompt-/agent-based hooks │    │
│  │ (isolated    │  │ (in-window   │  │ (deterministic trigger →  │    │
│  │  eval/review)│  │  procedures) │  │  LLM judgment)            │    │
│  └──────────────┘  └──────────────┘  └───────────────────────────┘    │
├──────────────────────────────────────────────────────────────────────┤
│  STATE LAYER (survives compaction / session boundary)                │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────┐   │
│  │ spec/plan/tasks    │  │ HANDOFF / decisions│  │ external memory│   │
│  │ (contract of truth)│  │ (session bridge)   │  │ (sqlite, etc.) │   │
│  └────────────────────┘  └────────────────────┘  └────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility (what it owns) | Typical implementation | Our coverage |
|-----------|-------------------------------|------------------------|--------------|
| **CLAUDE.md** | Always-true project facts, global bans | Root markdown, loaded at session start, re-injected on compact | ✓ have it |
| **rules/ (path-scoped)** | File-specific constraints loaded only when relevant files are touched | YAML `paths:` glob frontmatter | ✓ have it (was flagged uncertain — now **confirmed a first-class feature**) |
| **PreToolUse hook** | Block dangerous tool calls *before* they run | Shell, `exit 2` or `permissionDecision:"deny"` | ✓ pretool-guard |
| **PostToolUse hook** | Auto-format / per-file syntax gate *after* edit | Shell, `exit 0` (advisory) | ✓ posttool-format |
| **Stop hook** | End-of-turn verification gate (build/type/test) | Shell, `exit 2` or `decision:"block"` | ✓ stop-verify |
| **Session/Compact hooks** | Save & restore state across boundaries | Shell writing/reading state files | ⚠️ partial (PreCompact + SessionStart only) |
| **Subagents (eval/review)** | Independent verification in isolated context | `.claude/agents/*.md`, own window | ✓ 5 agents — but **invoked manually, not gated** |
| **Skills** | On-demand procedures in the main window | `.claude/skills/*/SKILL.md` | ✓ 2 skills |
| **Spec/plan/tasks** | Authoritative contract that outlives the session | Markdown source-of-truth files | ⚠️ implied via GSD, not harness-owned |
| **Handoff / decisions** | Bridge context across compaction / restart | Append-only markdown | ✓ HANDOFF/DECISIONS |

## The Session Lifecycle (control flow)

This is the backbone every harness builds on. **Firing order is fixed by the runtime**, not by
config. Within a single event, all matching hooks run **in parallel** (no ordering guarantee) and
identical handlers are deduplicated. Source: official hooks reference (HIGH confidence).

```
SessionStart ─────────► inject prior context (additionalContext)   [non-blocking]
     │
     ▼  (user submits prompt)
UserPromptSubmit ─────► validate / inject context / reject prompt   [BLOCKING, exit 2]
     │
     ▼  (Claude decides to use a tool)
PreToolUse ───────────► allow / deny / ask                          [BLOCKING, exit 2]
     │ (allowed)
     ▼
   <tool runs>
     │
     ▼
PostToolUse ──────────► format / lint / rewrite output              [non-blocking]
     │   (loop back to PreToolUse for next tool)
     ▼  (Claude finishes its turn)
Stop ─────────────────► verify build/type/test; force-continue      [BLOCKING, exit 2]
     │
     ▼  (subagent finishes, if any)
SubagentStop ─────────► gate subagent completion                    [BLOCKING, exit 2]
     │
     ▼  (context fills)
PreCompact ───────────► save state before compaction                [BLOCKING, exit 2]
PostCompact ──────────► (advisory)                                  [non-blocking]
     │
     ▼  (session ends: clear / logout / exit)
SessionEnd ───────────► final state save                            [non-blocking]
```

### Exit-code contract (the reliability-critical invariant)

This is where harnesses silently fail. The invariant is **not** "exit 2 blocks" — it is
"exit 2 blocks **only on blocking events**." Get the event class wrong and the gate is a no-op.

| Event | Is `exit 2` a block? | If you need a gate here |
|-------|----------------------|-------------------------|
| PreToolUse | **Yes** — tool prevented | `exit 2` (stderr → Claude) or `permissionDecision:"deny"` |
| UserPromptSubmit | **Yes** — prompt erased | `exit 2` or `decision:"block"` |
| Stop / SubagentStop | **Yes** — forces continue | `exit 2` or `decision:"block"` + `reason` |
| PreCompact | **Yes** — compaction blocked | `exit 2` |
| **PostToolUse** | **No** — tool already ran | can only advise (`decision:"block"` feeds text back) |
| SessionStart / SessionEnd / PostCompact / Notification | **No** | stderr shown, action proceeds |

Two corollaries that matter for hardening:
1. **`exit 1` is never a block.** A gate that reports failure with `exit 1` lets the dangerous
   action through. (This is the class of bug our Phase-0 pipefail fix already caught once.)
2. **On `exit 2`, JSON stdout is ignored** — only stderr reaches Claude. To *both* block *and*
   hand back structured feedback (e.g. a machine-readable reason + `additionalContext`), you must
   use the `exit 0` + `decision:"block"` path instead. Exit-2 is the robust/simple path; the JSON
   path is the rich path. Pick per hook, don't mix.

## Recommended Project Structure

Mature harnesses (SuperClaude, spec-kit, Chachamaru harness, Agent OS) share this shape:

```
.claude/
├── settings.json          # hook registration + permissions.deny (the wiring)
├── hooks/                 # deterministic gates (shell)
│   ├── pretool-*          #   block layer
│   ├── posttool-*         #   format/lint layer
│   ├── stop-*             #   verify layer
│   └── session-*          #   state save/restore
├── agents/                # judgment layer, isolated windows (eval + reviewers)
├── skills/                # in-window procedures (handoff, changelog)
├── commands/              # human-invoked verbs (plan/work/review/verify/commit)
└── rules/                 # path-scoped constraints (paths: glob)
    ├── common/            #   paths: **/*  (or no paths = always-on, re-injected on compact)
    └── <stack>/           #   paths: **/*.<ext>
CLAUDE.md                  # always-on facts + global bans
specs/ (or docs/)          # STATE: spec → plan → tasks + handoff + decisions
```

### Structure Rationale

- **hooks/ vs agents/ split** is the core organizing axis every harness uses: *deterministic
  vs judgment*. Hooks are cheap, reliable, and un-skippable; agents are expensive, smart, and
  advisory. Our harness already draws this line correctly.
- **rules/ with `paths:`** keeps stack-specific constraints out of context during unrelated
  work. **Confirmed a real, supported feature** (Anthropic steering guide) — this resolves the
  manual's "⚠️ 재확인" flag on `paths:` frontmatter. See "Rule loading" below for the nuance.
- **specs/ as source-of-truth** is the state anchor. Mature SDD tools name it explicitly:
  spec-kit uses `spec → plan → tasks → implement`; Kiro uses `requirements → design → tasks`;
  the Chachamaru harness treats `spec.md` + `Plans.md` as "the authoritative contract across
  sessions." The pattern: a *small, fixed* set of files that the verify loop checks against.

## Architectural Patterns

### Pattern 1: Deterministic gate, LLM judgment behind it (the hookify ladder)

**What:** Put the *trigger* in a deterministic hook; put *judgment* in the layer behind it.
The runtime now supports three hook execution types — `command` (shell), `prompt` (a model call
in a fresh window), and `agent` (a subagent). This means an evaluator can be attached **as a
hook**, not just invoked by a slash command.

**When to use:** Any check that must *always* run. If it needs judgment, escalate the hook type
(command → prompt → agent) rather than hoping the model remembers to call `/review`.

**Trade-offs:** command hooks are instant and free; prompt/agent hooks cost tokens and latency.
Gate the cheap deterministic checks on every turn; reserve LLM-judgment hooks for expensive
reviews at phase boundaries (Stop / SubagentStop).

**Gap this exposes:** Our generator/evaluator separation (AGENTS.md) is real, but the evaluator
and reviewers are **opt-in via `/review`** — nothing forces them to run. Mature harnesses wire
review into the loop as a *gate that blocks progression* (Chachamaru: "review findings treated as
blockers"). Build implication: an agent-based Stop/SubagentStop hook can make the evaluator
un-skippable without collapsing the generator/evaluator separation.

### Pattern 2: Three-layer self-verification loop

**What:** Layer verification by cost and scope, mapped to lifecycle events:
- **Syntax layer** — PostToolUse, per file, fast (format + compile-of-one-file).
- **Task layer** — Stop, whole turn, medium (build + typecheck + test).
- **Intent/regression layer** — agent at Stop/SubagentStop, expensive (does it meet the spec's
  acceptance criteria / SC?).

**When to use:** Always. This is the canonical Claude Code guardrail shape.

**Gap this exposes:** Our Stop gate checks build/type/test but **not the spec's SC** — SC are
only checked on demand via `/verify`. The intent layer exists (evaluator agent) but is not on the
loop. The strongest harnesses close this: the verify gate reads the plan contract and blocks if
acceptance criteria aren't demonstrably met.

### Pattern 3: State that bypasses the context window

**What:** Three tiers of memory, chosen by how long the fact must live:
- **always-on rule** (no `paths:`) — re-injected automatically on every compaction.
- **CLAUDE.md** — loaded at start, re-injected on compact (crude, always-on).
- **handoff/decisions files** — written at boundaries, re-read at SessionStart via
  `hookSpecificOutput.additionalContext` (deterministic injection that bypasses the compaction
  budget entirely).

**When to use:** Match tier to lifetime. A cross-cutting invariant → always-on rule. A running
task ledger → handoff file re-injected at SessionStart.

**Gap this exposes:** The manual's workaround "duplicate critical rules into CLAUDE.md to survive
compaction" is now obsolete — an **always-on rule** (rule file with no `paths:`) is re-injected on
compaction by design. Cleaner than duplication. And our state save fires on **PreCompact only**;
`SessionEnd` (clear/logout/exit) is a second, un-covered way context is lost.

## Data Flow

### Enforcement flow (per turn)

```
prompt ─► [UserPromptSubmit gate] ─► model plans ─► tool call
                                                      │
                              ┌───────[PreToolUse gate: block?]
                              │ allow
                              ▼
                          tool runs ─► [PostToolUse: format] ─► (repeat)
                              │
                    turn ends ▼
                        [Stop gate: build/type/test/SC → block & loop if fail]
                              │ pass
                              ▼
                          idle / next prompt
```

### State flow (across boundaries)

```
work happens ──► DECISIONS.md (append) ──┐
                                          ├─► [PreCompact/SessionEnd: write HANDOFF.md]
spec/plan/tasks (contract) ──────────────┘
                                                        │
next session ──► [SessionStart: read HANDOFF.md ──► inject via additionalContext]
```

## Multi-Stack Detection Strategies

Three approaches seen in the wild; they compose:

| Strategy | How | Best when | Our stance |
|----------|-----|-----------|------------|
| **Marker-file / extension sniffing in hooks** | `case` on `.java`/`.ts`, presence of `gradlew`/`package.json` | one harness must cover N stacks; simple | ✓ our approach — fine, keep it |
| **Path-scoped rules** | `paths: **/*.java` loads Java rules only when Java files touched | keeping stack rules out of unrelated context | ✓ our approach |
| **Hierarchical CLAUDE.md** | root CLAUDE.md + per-package `backend/CLAUDE.md`, `frontend/CLAUDE.md`; runtime reads cwd upward | true monorepo with divergent per-package conventions | ✗ not used — viable alternative/complement for Java+React split layouts |

Recommendation: our extension/marker + path-glob combination is the correct default for a
*drop-in template* (zero assumptions about directory layout). Hierarchical CLAUDE.md is worth
documenting as the escape hatch for real monorepos, not baking in.

## Scaling Considerations

"Scale" for a harness = number of stacks, session length, and autonomy level — not users.

| Scale | Architecture adjustments |
|-------|--------------------------|
| 1 stack, short sessions | Single CLAUDE.md + 4 hooks is enough. (Our baseline.) |
| 2+ stacks (Java+React) | Path-scoped rules + marker detection; keep gates stack-branched, not duplicated. |
| Long / autonomous sessions | State layer becomes load-bearing: always-on rules for invariants, SessionEnd+PreCompact both saving, SessionStart injecting. Verify gate must check SC, not just build. |
| Multi-phase autonomous loop | Explicit phase gates (plan→work→review→release) with an independent reviewer that **blocks** progression. This is the jump from "toolbox" to "loop." |

### First bottleneck: gates are un-enforced, not missing

The most common failure isn't a missing gate — it's a gate wired to a non-blocking event, or a
review agent that exists but is never invoked. Reliability effort belongs on **the exit-2 block
path** (PreToolUse, Stop) and on **making the evaluator un-skippable**, before adding new checks.

### Second bottleneck: state loss at un-covered boundaries

PreCompact-only state saving loses context on clear/logout/exit. Add SessionEnd. Verify the
SessionStart injection actually lands (`additionalContext`), because a handoff that writes but
never re-injects is silent data loss.

## Anti-Patterns

### Anti-Pattern 1: Gate on a non-blocking event

**What people do:** put `exit 2` in a PostToolUse hook expecting it to undo a bad edit.
**Why it's wrong:** the tool already ran; PostToolUse `exit 2` is advisory. The edit stands.
**Do this instead:** block *before* the fact in PreToolUse; use PostToolUse only to format or to
feed corrective text back for the *next* turn.

### Anti-Pattern 2: Rules-only harness (constraints without enforcement)

**What people do:** encode every guardrail as CLAUDE.md / rules prose and trust the model.
**Why it's wrong:** context is advisory and degrades over long sessions; the model can ignore it.
A real guardrail must be deterministic (hook or permission).
**Do this instead:** promote must-hold rules to hooks ("hookify"). Prose states intent; a hook
enforces it. (This is exactly our RULES.md "hookify" guidance — the gap is *coverage*, not doctrine.)

### Anti-Pattern 3: Review that's a command, not a gate

**What people do:** define reviewer subagents but leave them behind an opt-in `/review`.
**Why it's wrong:** the generator/evaluator separation only pays off if the evaluator *always*
runs. Manual invocation is the first thing skipped under time pressure.
**Do this instead:** wire the evaluator as an agent-based Stop/SubagentStop hook that blocks on
major findings — keeping generation and evaluation in separate windows (no Self-Eval Blindspot).

### Anti-Pattern 4: Duplicating rules into CLAUDE.md for compaction survival

**What people do:** copy critical rules into CLAUDE.md so they survive compaction.
**Why it's wrong:** duplication drifts; two sources of truth.
**Do this instead:** make it an **always-on rule** (rule file with no `paths:`), which the runtime
re-injects on compaction by design.

## Integration Points

### Runtime lifecycle events (the harness's real "API")

| Event | Integration pattern | Notes / gotchas |
|-------|--------------------|-----------------|
| PreToolUse | block via `exit 2` / `permissionDecision` | matcher on tool name (`Edit|Write`, `Bash`, `mcp__.*`) |
| PostToolUse | format via `exit 0` | exit 2 does **not** undo; matching hooks run in parallel |
| Stop | verify via `exit 2` / `decision:"block"` | no matcher — fires always; the SC-check belongs here |
| SubagentStop | gate subagent output | matcher = agent name; unused by us, relevant for our 5 agents |
| SessionStart | inject state via `additionalContext` | matchers: `startup`/`resume`/`clear`/`compact` |
| PreCompact + SessionEnd | save state | **use both**; PreCompact-only misses clear/logout/exit |
| UserPromptSubmit | pre-validate / inject | blocking; unused by us — could enforce "spec exists before work" |

### Internal boundaries

| Boundary | Communication | Considerations |
|----------|---------------|----------------|
| hooks ↔ runtime | stdin JSON in, exit code + stdout/stderr out | parse with `jq`; env-var style is legacy |
| hook ↔ Claude context | stderr (on exit 2) / `additionalContext` (on exit 0) | exit 2 discards JSON — choose per hook |
| main agent ↔ subagent | prompt in, final message out | isolation prevents context pollution; also means only the *summary* returns |
| harness ↔ spec/state files | file read/write at lifecycle boundaries | the contract (spec/plan/tasks) is what makes the loop resumable |

## Build-Order Implications (for hardening the remaining gaps)

Ordered by reliability-per-effort. Enforcement correctness before new capability.

1. **Lock the exit-2 block path first.** Audit every hook: is the event blocking? is failure
   `exit 2` (never `exit 1`)? does `set -o pipefail` hold so a failing sub-command actually
   fails the gate? This is where a silent hole costs the most. (Partly done in Phase 0 — make
   `/harness-audit` assert it.)
2. **Close the state-loss boundary.** Add SessionEnd saving alongside PreCompact; verify
   SessionStart re-injects via `additionalContext`. State that writes but never restores is the
   quietest failure. Replace CLAUDE.md rule-duplication with always-on rules.
3. **Put the intent check on the loop.** Extend the Stop gate (or an agent-based Stop hook) to
   verify the spec's acceptance criteria (SC), not just build/type/test — closing the loop from
   `/verify` (manual) to automatic.
4. **Make the evaluator un-skippable.** Wire reviewers as agent-based SubagentStop/Stop hooks
   that block on major findings, preserving generator/evaluator separation.
5. **Only then, breadth.** New stacks, hierarchical CLAUDE.md, UserPromptSubmit "spec-first"
   gating — capability that assumes the enforcement core is already trustworthy.

## Sources

- Claude Code Hooks reference — full event list, exit-2 semantics per event, JSON/`additionalContext`/`decision` fields, parallel execution & dedup — https://code.claude.com/docs/en/hooks (HIGH)
- Claude Code Hooks guide — canonical hook use cases, prompt-/agent-based hooks — https://code.claude.com/docs/en/hooks-guide (HIGH)
- Anthropic, "Steering Claude Code: skills, hooks, rules, subagents and more" — extension-layer mental model, rules `paths:` glob, always-on vs path-scoped, compaction re-injection — https://claude.com/blog/steering-claude-code-skills-hooks-rules-subagents-and-more (HIGH)
- Chachamaru127/claude-code-harness — Plan→Work→Review→Release autonomous cycle, spec.md/Plans.md as contract, review-as-blocker — https://github.com/Chachamaru127/claude-code-harness (MEDIUM)
- GitHub Spec Kit — Spec→Plan→Tasks→Implement SDD artifact structure — https://github.github.com/spec-kit/ (MEDIUM)
- Martin Fowler, "Understanding Spec-Driven Development: Kiro, spec-kit, Tessl" — requirements→design→tasks artifacts — https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html (MEDIUM)
- Monorepo / hierarchical CLAUDE.md + marker detection — https://code.claude.com/docs/en/large-codebases (MEDIUM)
- Self-verification loop (3 layers: PostToolUse syntax / Stop task / regression) — https://dev.to/shipwithaiio/how-to-build-a-self-verification-loop-in-claude-code-3-layers-20-minutes-m1p (LOW/MEDIUM — community, consistent with official)

---
*Architecture research for: Claude Code agent harness (3-pillar guardrail template)*
*Researched: 2026-07-06*
