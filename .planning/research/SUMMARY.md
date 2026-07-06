# Project Research Summary

**Project:** Claude 하네스 템플릿 (language-agnostic Claude Code guardrail drop-in — Java/Spring + React/Next)
**Domain:** Developer-tooling / AI coding-agent harness (constraints + feedback + state pillars)
**Researched:** 2026-07-06
**Confidence:** HIGH

## Executive Summary

This is a Claude Code **harness** — not an application — built from four steering surfaces (hooks, rules, subagents, skills) around a fixed, runtime-owned session lifecycle. The template already has the right shape: a PreToolUse block layer, a PostToolUse format layer, a Stop verify layer, and a state-handoff layer, plus path-scoped rules and a Generator/Evaluator subagent split. All four research passes agree on the same conclusion: **the architecture is correct; the enforcement is leaky.** Every load-bearing "gate" in the current template has at least one silent bypass — a fail-open dependency, an unmatched tool, an unhandled loop flag, or a boundary event nobody wired — and none of these leaks were visible from reading the code casually, because each hook *looks* like it works in the common case.

The recommended approach is to hunt down and close these enforcement leaks **before** adding any new capability, in strict reliability-per-effort order: (1) make every guard fail closed instead of fail open when `jq` is missing or JSON is malformed; (2) widen the write-tool matcher to cover `MultiEdit`/`NotebookEdit` and add a Bash-command inspection path, since `Write|Edit` alone leaves `echo >`, `cp`, and `sed -i` completely unguarded; (3) make the Stop gate honor `stop_hook_active` so a pre-existing/unfixable failure can't trap the session in an infinite continuation loop; (4) give the state pillar real content and a second save trigger (`SessionEnd`, not just `PreCompact`) so ordinary session exits aren't silent data loss; and (5) add a structured JSONL event log — the one missing architectural layer — because it is the cheapest, zero-dependency way to make hook failures visible and to give `/harness-audit` something concrete to check.

Key risk: none of these gaps are visible without actively trying to defeat the guard (a missing binary, an unusual tool call, a red pre-existing test). That is exactly why they survived the first hardening pass. Mitigation is to treat `/harness-audit` as the single highest-leverage remaining piece of work — it is the only place all these checks can be asserted mechanically and re-run after every Claude Code upgrade — and to close every enforcement leak before broadening scope (new stacks, new stacks' rules, CI integration are correctly Out of Scope).

## Key Findings

### Recommended Stack

The harness's building blocks are current and mostly aligned: hook exit-code protocol (`exit 2` = block, `exit 1` = never blocks), stdin-JSON+`jq` parsing, `permissions.deny/ask/allow`, and `.claude/rules/*.md` `paths:` frontmatter are all verified against the live 2.1.x docs and match what the template already does. Two stack-level drifts matter for hardening: hook commands are cwd-relative instead of using `${CLAUDE_PROJECT_DIR}` (breaks in subdirectories/monorepo packages), and `commit.md` lacks `disable-model-invocation: true` (Claude could auto-trigger a side-effect command). Both are one-line fixes.

**Core technologies (already in use, confirmed current):**
- Hook events + `exit 2` block protocol — the only enforcement layer the model cannot skip
- `jq` stdin JSON parsing — canonical, version-stable input contract (not env-var scraping)
- `permissions.deny` + PreToolUse hook (defense in depth) — deny is cheap/declarative, hook is content-aware
- `.claude/rules/*.md` with `paths:` frontmatter — confirmed current field name; **no `paths:` = always-on, re-injected on compaction by design** (this is new information — see Architecture)

### Expected Features

**Must have (table stakes) — currently MISS or PARTIAL, not new-build wishlist:**
- Hook-failure observability (stop swallowing `2>/dev/null`; surface formatter/parse failures) — C8
- A self-audit that actually PASS/FAILs (`/harness-audit` today is a prose prompt)
- Real handoff state capture (replace the hardcoded `[내용없음]` TODO sentinel) — C7
- Secret **content** scanning (regex `AKIA…`/`sk-…`/`ghp_…` + entropy) — distinct hole from the existing path-based guard; a hardcoded key pasted into a `.java`/`.ts` file is currently invisible to the harness

**Should have (differentiators):**
- Structured JSONL event log (Bash+jq append, zero infra) — the architectural keystone, see Roadmap Implications
- Decision ledger populated (append-only `DECISIONS.md`) so handoff has real content to summarize
- Incremental/scoped Stop verification (fixes the full-build-every-Stop latency tax, C9)

**Defer (v2+ / version-gated):**
- `PostToolUseFailure` hook, `UserPromptSubmit` audit/injection — useful but gate behind a Claude Code version check
- Command risk classification (parse Bash string into low/med/high tiers) — the "root" upgrade past the deny-list ceiling, but HIGH implementation cost
- Enforced Explore→Plan→Act permission escalation

**Anti-features — explicitly do NOT build:**
- Full build+test on every Stop (already C9 — go incremental, push full suite to CI)
- Runtime-heavy observability (OpenTelemetry/SIEM/dashboards) — violates the zero-runtime-dependency constraint; JSONL append is the infra-free answer
- Over-broad pre-write blocking, TTS notifications, fork-join worktree parallelism, auto-approve-all — all named anti-patterns that either erode the guard's precision or blow the drop-in's scope

### Architecture Approach

Four layers stack on the fixed session lifecycle: a **context layer** (CLAUDE.md, rules, output style — always in the model's window, advisory), an **enforcement layer** (PreToolUse/PostToolUse/Stop/Session* hooks — deterministic, un-skippable), a **judgment layer** (subagents, skills, prompt/agent-typed hooks — smart but expensive), and a **state layer** (spec/plan/tasks, handoff/decisions — survives compaction and session boundaries). The template already draws the hooks-vs-agents line correctly. The two structural gaps research surfaces: (1) the evaluator/reviewer subagents are invoked only via `/review` — nothing forces them to run, so the Generator/Evaluator separation only pays off when a developer remembers; (2) the Stop gate checks build/type/test but never the spec's acceptance criteria (SC) — the "intent layer" of the standard 3-layer verification model is missing from the automatic loop.

**Major components (current, with the gap each carries):**
1. **PreToolUse guard** — blocks dangerous writes; gap: matcher and payload-field coverage (see Pitfalls #2)
2. **Stop verify gate** — build/type/test re-injection loop; gap: no `stop_hook_active` check, no SC check, full-suite latency
3. **Session-handoff (PreCompact + SessionStart)** — state bridge across compaction; gap: hardcoded empty payload, no `SessionEnd` coverage
4. **Subagents (evaluator + 4 reviewers)** — isolated-context judgment; gap: opt-in, not gated into the loop
5. **rules/ (paths:)** — path-scoped context; **newly confirmed:** a rule file with no `paths:` is always-on and re-injected on compaction — this **obsoletes** the planned C10 workaround of duplicating critical rules into CLAUDE.md

### Critical Pitfalls

1. **Fail-open guard on missing/broken `jq`** — every hook's `2>/dev/null` parse + "empty means allow" default means a missing `jq` binary silently disables the entire constraints pillar. Fix: preflight `command -v jq` and fail **closed** (`exit 2`) in blocking guards, never swallow the parse error itself.
2. **Guard matcher coverage holes** — `"Write|Edit"` doesn't match `MultiEdit`, `NotebookEdit`, or `Bash`; and even if `Bash` were matched, the guard reads `.tool_input.file_path` while Bash's payload is `.tool_input.command`. Net effect: `echo > .env.production`, `cp … application-prod.yml`, `sed -i` on an existing migration all bypass the guard entirely today. Fix: broaden the tool matcher and add a dedicated Bash-command inspection hook.
3. **Stop-gate infinite loop** — `exit 2` without checking `stop_hook_active` means a pre-existing/unfixable failure traps the session in forced continuation forever. Fix: read the flag, surface-once-and-yield on the second pass.
4. **State pillar is theater** — the compaction-survival *mechanism* is real and correctly wired, but the *content* is a hardcoded sentinel, and the *trigger* only fires on `PreCompact` — a normal `/clear`/logout/exit never saves state at all. Fix: real TODO/decision collection (C7) + add `SessionEnd` as a second save trigger.
5. **Silent policy/enforcement drift** — every `rules/*` policy (PII, 80% coverage, Conventional Commits) needs a named enforcing gate or it's just prose the model can skip under context pressure; nothing currently maps declared rules to enforcing hooks.

## Implications for Roadmap

Research across all four files converges on the same ordering principle: **fix the enforcement leaks in the gates you already have before adding new gates or new capability.** The observability layer (JSONL log) is a second, cross-cutting keystone — it is infra-free, and it is what makes both hook-failure visibility (C8) and a real `/harness-audit` possible, so it should land early even though it is itself a "new" component.

### Phase 1: Fail-Closed Enforcement Core
**Rationale:** The exit-2 block path is the harness's only truly un-skippable layer; every other pillar is advisory by comparison. A leak here silently defeats the entire Core Value ("드롭인 즉시 게이트가 실제로 작동한다"). This must be airtight before anything else is layered on top.
**Delivers:** `jq`-missing preflight that fails closed on guard hooks; widened write-tool matcher (`Write|Edit|MultiEdit|NotebookEdit`) plus a Bash-command inspection hook for redirects/`sed -i`/`cp` against protected paths; `stop_hook_active` handling in `stop-verify.sh`; `${CLAUDE_PROJECT_DIR}` for all hook commands; `disable-model-invocation: true` on `commit.md`.
**Addresses:** Pitfalls #1, #2, #3 above; STACK.md gaps G1/G2.
**Avoids:** Fail-open guard, matcher bypass, Stop-loop trap — all three are silent-until-exploited, i.e. exactly the failures that make a "done" declaration false.

### Phase 2: Observability Keystone (JSONL event log)
**Rationale:** FEATURES.md and ARCHITECTURE.md both independently name this as the single missing architectural layer, and it is a *dependency* for the next two phases — you cannot build a real `/harness-audit` or fix C8's silent-format-failure without something to check/log against. Zero-dependency (Bash + `jq` append to `logs/`), consistent with the "no runtime dependency" constraint.
**Delivers:** Structured JSONL append on every hook fire (event, tool, decision, timestamp); `posttool-format.sh` stops swallowing stderr and logs failures instead of `2>/dev/null`-discarding them.
**Addresses:** C8 (hook-failure observability), FEATURES.md D1 (structured event log).
**Implements:** ARCHITECTURE.md's "enforcement layer" pattern — closing Anti-Pattern "gate on a non-blocking event" requires first being able to *see* what fired.

### Phase 3: State Pillar — Real Content + Full Boundary Coverage
**Rationale:** The mechanism (PreCompact save → SessionStart restore via `additionalContext`) is verified correct; only the content and trigger coverage are broken. This is a contained, well-understood fix, not exploratory work.
**Delivers:** Real TODO/decision/open-SC collection in the `handoff` skill (replacing the `[내용없음]` sentinel); `SessionEnd` wired alongside `PreCompact`; decision ledger (`DECISIONS.md`) populated with an append trigger; verify SessionStart injection actually lands end-to-end.
**Addresses:** C7, and the "policy has a gate" checklist item for the state pillar.
**Uses:** JSONL log from Phase 2 can double as a source for "what happened since last save."

### Phase 4: Self-Audit That Actually Passes/Fails
**Rationale:** This is the highest-leverage single piece of remaining work — it is the only place all of Phases 1–3's checks can be asserted mechanically and re-run after every Claude Code upgrade, turning "we hope the gates work" into "we verified the gates work." It should come after (not before) the fixes it needs to assert, and after the JSONL log it reads.
**Delivers:** `/harness-audit` that asserts: `jq` present; write-tool matcher enumerates all write-capable tools + Bash-write check; every `rules/*` policy maps to a naming enforcing gate (or is flagged orphaned); the `[내용없음]` handoff sentinel is rejected as "not implemented"; `bash -n` clean + `+x` + hooks actually registered (`/hooks` check); `stop_hook_active` path exercised.
**Addresses:** The template's own stated Active item ("`/harness-audit` 실효화"), plus the PITFALLS.md "Pitfall-to-Requirement Mapping" table wholesale.

### Phase 5 (lower priority / defer-after-validation): Secret Content Scan + Incremental Stop Verify
**Rationale:** Both are real table-stakes-adjacent gaps but are additive capability, not enforcement-leak fixes — correctly ordered after the core is trustworthy.
**Delivers:** Regex/entropy content scan (PreToolUse or pre-commit) for `AKIA…`/`sk-…`/`ghp_…` complementing the existing path guard; Stop gate scoped to changed modules instead of full `gradlew`/`tsc`/test suite every turn (resolves C9 and the 60s-timeout silent-disable risk). Both are independent of each other and can be sequenced by whichever the maintainer hits first in practice.

### Phase Ordering Rationale

- **Enforcement-leak fixes always precede new capability** — this is the universal ordering rule all four research files state explicitly (ARCHITECTURE.md's "Build-Order Implications," PITFALLS.md's severity ranking, FEATURES.md's P1 list).
- **Observability (JSONL) is a dependency, not a nice-to-have** — Phase 2 must land before Phase 4 (audit needs something to check) and before C8 can be closed (need somewhere to route failures other than `/dev/null`).
- **State-pillar fix (Phase 3) is independent of Phases 1–2** and could run in parallel if the roadmapper wants to split work, but is sequenced after observability because the decision ledger and JSONL log both feed "what does the handoff actually say."
- **`/harness-audit` (Phase 4) must be last among these five** because it is meant to *assert* the fixes above exist — building it first would just re-encode the same gaps as unchecked TODOs.

### Research Flags

Needs deeper research during planning:
- **Phase 1 (Bash-write inspection hook):** parsing arbitrary shell command strings for write-intent (redirects, `sed -i`, `cp`/`mv`/`install` targets) is inherently best-effort; the planner should scope precisely which command patterns to cover vs. explicitly declare out-of-scope (a determined shell will always find another path — this is a documented ceiling, not a bug to fully close).
- **Phase 4 (`/harness-audit` implementation):** needs a concrete design for "map each `rules/*` policy to its enforcing gate" — this is a new check pattern, not a documented Claude Code feature, and will need its own small design pass during phase planning.

Phases with standard, well-documented patterns (safe to skip `--research-phase`):
- **Phase 1 (jq preflight, matcher widening, `stop_hook_active`, `${CLAUDE_PROJECT_DIR}`):** all directly verified against official docs with exact syntax already given above — implementation, not research.
- **Phase 2 (JSONL append):** trivial Bash+jq pattern, multiple corroborating community references.
- **Phase 3 (`SessionEnd` wiring):** documented event, same shape as the existing `PreCompact` hook.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Every claim verified against live `code.claude.com/docs` for Claude Code v2.1.x, not training memory; cross-checked against the actual template files. |
| Features | MEDIUM-HIGH | Hook mechanics/lifecycle = HIGH (official docs); pattern taxonomy (JSONL-as-baseline, layer naming) = MEDIUM (consistent community harness write-ups, one derived from a source-leak analysis). |
| Architecture | HIGH / MEDIUM | Lifecycle, exit-code-per-event, matcher parallel-execution = HIGH (official docs); mature-harness structural conventions (SDD artifact naming, 3-layer verification) = MEDIUM (repo READMEs + articles, internally consistent). |
| Pitfalls | HIGH | Exit-code semantics, `stop_hook_active`, `SessionEnd` matchers, `${CLAUDE_PROJECT_DIR}` all verified against current official docs; cross-checked against the literal hook source in `.claude/hooks/` — these are grounded, not speculative. |

**Overall confidence:** HIGH

### Gaps to Address

- **Bash-write matcher precision** — exactly which shell patterns (redirect ops, `sed -i`, `cp`/`mv`/`install` targets) to inspect needs a scoping decision during Phase 1 planning; over-broad regex risks the same "over-blocking → dev disables the guard" failure mode PITFALLS.md warns about for the existing path guard.
- **`/harness-audit` policy→gate mapping design** — no existing reference implementation to copy; needs a small design pass rather than pure research, flagged above.
- **Claude Code version drift for newer hook types** (`PostToolUseFailure`, prompt/agent-typed hooks) — deferred features should gate behind a version check at implementation time, not assumed available.
- **Secret-content-scan false-positive rate** — regex/entropy scanning on `.java`/`.ts` source can false-positive on test fixtures and long tokens; needs validation against the real target repos during Phase 5 planning, not blocking for now.

## Sources

### Primary (HIGH confidence)
- `code.claude.com/docs/en/hooks` — full event list, exit-code-per-event table, stdin schema, matcher semantics, `stop_hook_active`, `SessionEnd` matchers, `${CLAUDE_PROJECT_DIR}`, 60s timeout, 10k-char output cap
- `code.claude.com/docs/en/settings` — permissions allow/deny/ask syntax, scope precedence, `$schema`
- `code.claude.com/docs/en/sub-agents`, `code.claude.com/docs/en/skills`, `code.claude.com/docs/en/mcp`, `code.claude.com/docs/en/memory` — frontmatter references, rules `paths:` semantics (including always-on-when-omitted)
- Anthropic, "Steering Claude Code: skills, hooks, rules, subagents and more" — extension-layer mental model
- Local: `.claude/settings.json`, `.claude/hooks/*.sh`, `.claude/agents/*.md`, `.claude/rules/*` — direct grounded gap analysis against the actual template

### Secondary (MEDIUM confidence)
- disler/claude-code-hooks-mastery, disler/claude-code-hooks-multi-agent-observability — JSONL logging as baseline pattern
- ShipWithAI 5-layer harness guide, Chachamaru127/claude-code-harness, GitHub Spec Kit, Martin Fowler SDD article — mature-harness structural conventions, review-as-blocker pattern
- "5 Claude Code Hook Mistakes That Silently Break Your Safety Net" (dev.to/yurukusa), "You're using Claude Code hooks wrong" (augmentedswe.com), claudefa.st Stop-hook post — corroborate `stop_hook_active`, matcher case-sensitivity, exit-1-vs-2 pitfalls against official docs
- anthropics/claude-code#10412 — version-drift evidence for plugin-installed Stop hooks

### Tertiary (LOW confidence)
- "12 Agentic Harness Patterns from Claude Code" / "The Claude Code Leak" (source-leak-derived analyses) — used only for pattern-naming context, not load-bearing claims

---
*Research completed: 2026-07-06*
*Ready for roadmap: yes*
