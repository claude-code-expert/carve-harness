# Architecture / 아키텍처

> Detailed technical documentation for the Squad Agent system.
>
> Squad Agent 시스템의 상세 기술 문서입니다.

---

## Overview / 개요

Squad Agent is a sub-agent system for Claude Code that provides 8 specialized agents, each with a distinct persona, model routing, and tool permissions. Agents chain together via the SubagentStop hook to form automated development pipelines.

Squad Agent는 Claude Code용 서브에이전트 시스템으로, 8종의 전문 에이전트가 고유한 페르소나, 모델 라우팅, 도구 권한을 가집니다. SubagentStop 훅을 통해 파이프라인으로 체이닝됩니다.

---

## Pipeline / 파이프라인

![Squad Pipeline](pipeline-diagram.svg)

### Core Pipeline Flow

```
squad-plan → [implement] → squad-review → squad-qa → squad-gitops
```

### Review-Refactor Loop

```
/squad-review
    │
    ├─ APPROVE ──────────► /squad-qa → /squad-gitops
    │
    └─ REQUEST_CHANGES ──► /squad-refactor
                                │
                                └──► /squad-review (re-verify)
```

`squad-review` is Read-only (find issues), `squad-refactor` is Write (fix them), `squad-qa` has Bash (run tests). Complete separation of concerns.

`squad-review`는 Read-only(찾기만), `squad-refactor`는 Write(수정), `squad-qa`만 Bash(테스트). 관심사 완전 분리.

### Full Map

```
┌─── Core Pipeline ──────────────────────────────────────────────┐
│                                                                │
│  squad-plan → [impl] → squad-review → squad-qa → squad-gitops  │
│    opus                  opus  ◄──┐    sonnet      haiku       │
│    R+W                   R-only   │    R+Bash      R+Bash      │
│                                   │                            │
│                            squad-refactor                      │
│                              opus · R+W                        │
│                                                                │
├─── On-demand ──────────────────────────────────────────────────┤
│  squad-debug (opus)   squad-docs (sonnet)   squad-audit (opus) │
│  R+Bash               R+W                   R-only             │
└────────────────────────────────────────────────────────────────┘
```

---

## Agent Details / 에이전트 상세

### squad-review — Code Review / 코드 리뷰

- `git diff` → Critical/High/Medium/Low classification → `APPROVE` / `REQUEST_CHANGES`
- Bash whitelist: `git diff`, `grep`, `cat` — read-only only. File modification **strictly prohibited**

### squad-plan — Planning / 기획

- User stories (US-001...) + SVG/HTML wireframes (`docs/wireframes/`) + implementation plan
- Analyzes existing code structure before designing
- **Boundaries**: NEVER modifies source code. Writes only to `docs/wireframes/` and `docs/plans/`
- **Bash restricted**: Whitelist (git, grep, cat, find) / Blacklist (npm, node, rm, mv)

### squad-refactor — Refactoring / 리팩토링

- **PROACTIVELY** triggered on squad-review Medium/Low issues
- **Safe**: Auto-runs `git stash push -m "pre-squad-refactor-checkpoint"` before work
- **Catalog**: Extract, Simplify, Move/Rename, Remove
- **Scope**: Up to module/directory level. STOP at cross-module
- **Workflow**: Assess → Plan (output before modifying) → Execute → Verify → Report
- No testing (squad-qa's domain), no bug fixing

### squad-qa — QA / 테스트

- `timeout 120 npm test` for hang prevention. Build/typecheck/lint validation
- PASS / FAIL / PARTIAL + regression risk assessment. Cannot modify code

### squad-debug — Debugging / 디버깅

- Reproduce → Isolate → Hypothesize → Verify → Root Cause → Solution
- Cannot modify files. Processes verbose logs within sub-agent context

### squad-docs — Documentation / 문서 작성

- README, API docs, architecture docs, JSDoc/TSDoc
- `<!-- auto-generated -->` markers for auto-generated sections
- **Boundaries**: NEVER modifies source code logic. Documentation files and JSDoc comments only

### squad-gitops — Git Automation / Git 자동화

- Conventional Commits messages, PR descriptions, changelogs
- `haiku` for cost optimization. Read-only git commands only

### squad-audit — Security Audit / 보안 감사

- Secrets, OWASP Top 10, `npm audit`, infrastructure security
- Read-only. LOW ~ CRITICAL risk classification

---

## Pipeline Context / 파이프라인 컨텍스트

Each agent's `description` includes a `Pipeline:` line indicating its position in the workflow. This provides workflow context both to Claude Code (for auto-delegation) and to the SubagentStop hook.

각 에이전트의 `description`에 `Pipeline:` 라인이 포함되어 워크플로우 위치를 명시합니다. Claude Code의 자동 위임과 SubagentStop 훅 양쪽에 컨텍스트를 제공합니다.

| Agent | Pipeline Position |
|-------|-------------------|
| squad-plan | `START → implement → /squad-review` |
| squad-review | `APPROVE → /squad-qa, REQUEST_CHANGES → /squad-refactor` |
| squad-refactor | `→ /squad-review (re-verify)` |
| squad-qa | `→ /squad-gitops` |
| squad-gitops | `after /squad-qa PASS → commit/PR` |
| squad-debug | `on-demand. After fix → /squad-qa → /squad-gitops` |
| squad-audit | `on-demand, typically before deployment` |
| squad-docs | `on-demand, any time during development` |

## SubagentStop Chaining / 체이닝

The `subagent-chain.sh` hook complements the Pipeline context by showing next-step guidance after each agent completes.

`subagent-chain.sh` 훅은 에이전트 완료 후 다음 단계 안내를 표시하여 Pipeline 컨텍스트를 보완합니다.

| Completed | Suggests |
|-----------|----------|
| squad-plan | → implement, then `/squad-review` |
| squad-review | REQUEST_CHANGES → `/squad-refactor`. APPROVE → `/squad-qa` |
| squad-refactor | → `/squad-review` to verify |
| squad-qa | → `/squad-gitops` commit |

---

## Model Routing / 모델 라우팅

| Agent | Model | Reason |
|-------|-------|--------|
| squad-review | opus | Security/logic = complex reasoning |
| squad-plan | opus | Architecture, edge cases |
| squad-refactor | opus | Code structure understanding + safe transformation |
| squad-qa | sonnet | Test execution + result formatting |
| squad-debug | opus | Root cause analysis |
| squad-docs | sonnet | Code → documentation |
| squad-gitops | haiku | Pattern work, cost-optimized |
| squad-audit | opus | Security — can't afford to miss |

Global override: `export CLAUDE_CODE_SUBAGENT_MODEL=sonnet`

---

## Tool Ordering Standard / 도구 순서 표준

All agents follow a canonical tool ordering convention:

모든 에이전트는 통일된 도구 순서 규칙을 따릅니다:

| Type | Tools | Agents |
|------|-------|--------|
| Read-only | `Read, Bash, Glob, Grep` | audit, debug, gitops, review |
| Read + Bash | `Read, Bash, Glob, Grep` | qa |
| Write (no Bash) | `Read, Write, Edit, Glob, Grep` | docs |
| Write + Bash | `Read, Write, Edit, Bash, Glob, Grep` | plan, refactor |

### Bash Restriction Format / Bash 제한 형식

All agents with Bash access use standardized sections:

Bash 접근 권한이 있는 모든 에이전트는 표준화된 섹션을 사용합니다:

```markdown
## Allowed Commands

```
{whitelisted commands}
```

## NEVER Run

```
{blacklisted commands}
```
```

---

## Frontmatter Reference / Frontmatter 레퍼런스

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `name` | Yes | — | Agent ID (e.g., `squad-review`) |
| `description` | Yes | — | Auto-delegation trigger. Include `PROACTIVELY` for auto-invoke |
| `tools` | No | (inherit) | Comma-separated. Supports `Task(squad-name)` |
| `model` | No | `inherit` | `haiku` / `sonnet` / `opus` / `inherit` |
| `maxTurns` | No | — | Max turns limit |
| `permissionMode` | No | — | `plan` / `acceptEdits` / `bypassPermissions` |
| `memory` | No | — | `user` / `project` / `local` |
| `background` | No | `false` | Background execution |
| `skills` | No | — | Preloaded skills |
| `mcpServers` | No | — | Agent-specific MCP servers |
| `hooks` | No | — | Agent-specific hooks |

---

## Installed Directory Structure / 설치 디렉토리 구조

```
~/.claude/
├── agents/
│   ├── squad-review.md
│   ├── squad-plan.md
│   ├── squad-refactor.md
│   ├── squad-qa.md
│   ├── squad-debug.md
│   ├── squad-docs.md
│   ├── squad-gitops.md
│   └── squad-audit.md
├── commands/
│   ├── squad.md
│   ├── squad-review.md
│   ├── squad-plan.md
│   ├── squad-refactor.md
│   ├── squad-qa.md
│   ├── squad-debug.md
│   ├── squad-docs.md
│   ├── squad-gitops.md
│   └── squad-audit.md
└── hooks/
    ├── subagent-chain.sh
    └── squad-router.sh
```

---

## Squad Router Hook / 키워드 자동 라우팅

The `squad-router.sh` hook intercepts `UserPromptSubmit` events and auto-detects keywords to route user prompts to the appropriate squad subagent.

`squad-router.sh` 훅은 `UserPromptSubmit` 이벤트를 가로채 키워드를 자동 감지하고, 적절한 squad 서브에이전트로 라우팅합니다.

### Execution Flow / 실행 흐름

```
User prompt → UserPromptSubmit hook
  │
  ├─ Phase 1: SKIP
  │    "/" prefix → exit (slash command)
  │    "--no-route" / "#direct" → exit (opt-out)
  │    SQUAD_ROUTER=off → exit (global disable)
  │
  ├─ Phase 2: CONFLICT (multi-word patterns, checked first)
  │    "PR 리뷰" → squad-review (not gitops)
  │    "보안 리뷰" → squad-audit (not review)
  │    "빌드 에러" → squad-debug (not qa)
  │
  ├─ Phase 3: GENERAL (single keywords, priority order)
  │    audit(1) > debug(2) > plan(3) > refactor(4)
  │    > docs(5) > gitops(6) > qa(7) > review(8)
  │
  └─ Output: JSON with hookSpecificOutput
       → Claude sees as additional context
       → Delegates to matched subagent
```

### Output Format / 출력 형식

```json
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "[Squad Router] Use the squad-review subagent..."
  }
}
```

See [docs/SQUAD-ROUTER-KEYWORDS.md](SQUAD-ROUTER-KEYWORDS.md) for the full keyword reference.

전체 키워드 목록은 [docs/SQUAD-ROUTER-KEYWORDS.md](SQUAD-ROUTER-KEYWORDS.md)를 참고하세요.

---

## Subagent Verification / 서브에이전트 검증

All 8 agents have been verified to launch correctly as Claude Code sub-agents via the `Agent` tool with `subagent_type` parameter.

8개 에이전트 모두 Claude Code의 `Agent` 도구를 통해 서브에이전트로 정상 구동됨을 검증했습니다.

| Agent | subagent_type | Status | Verified |
|-------|---------------|--------|----------|
| squad-docs | `squad-docs` | OK | Read, Write, Edit, Glob, Grep |
| squad-plan | `squad-plan` | OK | Read, Write, Edit, Bash, Glob, Grep |
| squad-audit | `squad-audit` | OK | Read, Bash, Glob, Grep |
| squad-qa | `squad-qa` | OK | Read, Bash, Glob, Grep |
| squad-gitops | `squad-gitops` | OK | Read, Bash, Glob, Grep |
| squad-refactor | `squad-refactor` | OK | Read, Write, Edit, Bash, Glob, Grep |
| squad-review | `squad-review` | OK | Read, Bash, Glob, Grep |
| squad-debug | `squad-debug` | OK | Read, Bash, Glob, Grep |

### How it works / 동작 방식

Each `/squad-*` command invokes the corresponding agent definition (`~/.claude/agents/squad-*.md`) as a sub-agent. Claude Code spawns a separate agent context with the tools, model, and system prompt defined in the agent's frontmatter.

각 `/squad-*` 커맨드는 해당 에이전트 정의(`~/.claude/agents/squad-*.md`)를 서브에이전트로 호출합니다. Claude Code가 에이전트 frontmatter에 정의된 도구, 모델, 시스템 프롬프트로 별도 에이전트 컨텍스트를 생성합니다.

### Verification method / 검증 방법

```
Agent(subagent_type="squad-review", prompt="...")
```

Each agent was dispatched in parallel via the `Agent` tool with its `subagent_type` set. All 8 confirmed their specialized system prompts were loaded and tools were accessible.

각 에이전트를 `Agent` 도구로 병렬 디스패치하여 전용 시스템 프롬프트 로드 및 도구 접근을 확인했습니다.

---

## Troubleshooting / 디버깅

| Problem | Solution |
|---------|----------|
| Agent not registered | Run `/agents` to verify |
| YAML error | Use `>` block for `description` with `:`, spaces not tabs |
| Infinite execution | Set `maxTurns: 15` |
| Inter-agent calls | Use `tools: Read, Task(squad-review)` |
| Debug mode | `claude --debug "api,hooks"` |

---

## References

- [Claude Code Sub-agents (Official)](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
- [Claude Agent SDK](https://docs.anthropic.com/en/docs/agents/agent-sdk)
- [shanraisshan/claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice)
- [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
