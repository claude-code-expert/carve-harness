# Contributing / 기여 가이드

Thank you for contributing to Squad Agent!

Squad Agent에 기여해 주셔서 감사합니다!

## Adding a New Agent / 새 에이전트 추가

Each agent requires **two files**:

새 에이전트를 추가하려면 **두 개의 파일**이 필요합니다:

### 1. Agent definition: `agents/squad-{name}.md`

```markdown
---
name: squad-{name}
description: >
  What this agent does. Include trigger keywords.
  Use PROACTIVELY if it should auto-invoke.
  Pipeline: where this agent sits in the workflow
tools: Read, Bash, Glob, Grep
model: opus
maxTurns: 15
---

You are a [role description].

## Process
1. Step 1...

## Rules
- NEVER [safety constraint]

## Allowed Commands
```
git log, git diff, ...
```

## NEVER Run
```
rm, git commit, ...
```

## Boundaries

**Will:**
- [explicit scope items]

**Will Not:**
- [explicit out-of-scope items] (→ /squad-{other})

## Output Format
```markdown
## Report Title
**Date**: {YYYY-MM-DD}
...
```
```

**Required sections for all agents / 모든 에이전트 필수 섹션:**
- `## Rules` with at least one NEVER clause / NEVER 규칙 최소 1개
- `## Allowed Commands` + `## NEVER Run` (if agent has Bash) / Bash 도구 시 필수
- `## Boundaries` (Will/Will Not) for Write-enabled agents / Write 도구 시 필수
- `## Output Format` with markdown template / 출력 형식 템플릿
- `Pipeline:` line in description / description에 파이프라인 위치

### 2. Command definition: `commands/squad-{name}.md`

```markdown
---
description: "Short description. Usage: /squad-{name} [args]"
allowed-tools: Agent
---
Invoke the squad-{name} subagent.
$ARGUMENTS
```

### 3. Register in `commands/squad.md`

Add your agent to the available agents list in `commands/squad.md`.

`commands/squad.md`의 에이전트 목록에 추가하세요.

### 4. Update `install.sh`

Add the new agent name to the `SQUAD_AGENTS` array in `install.sh`.

`install.sh`의 `SQUAD_AGENTS` 배열에 새 에이전트 이름을 추가하세요.

---

## Frontmatter Reference / Frontmatter 레퍼런스

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `name` | Yes | — | Agent ID (e.g., `squad-review`) |
| `description` | Yes | — | Auto-delegation trigger. Include `PROACTIVELY` for auto-invoke |
| `tools` | No | (inherit) | Comma-separated. Supports `Task(squad-name)` |
| `model` | No | `inherit` | `haiku` / `sonnet` / `opus` / `inherit` |
| `maxTurns` | No | — | Max turns limit |

---

## Naming Convention / 네이밍 규칙

- Prefix: `squad-` + descriptive function name
- Examples: `squad-review`, `squad-plan`, `squad-audit`

---

## Tool Ordering Convention / 도구 순서 규칙

Follow this canonical order for the `tools:` field:

`tools:` 필드에 다음 표준 순서를 따르세요:

- **Read-only**: `Read, Bash, Glob, Grep`
- **Write (no Bash)**: `Read, Write, Edit, Glob, Grep`
- **Write + Bash**: `Read, Write, Edit, Bash, Glob, Grep`

---

## Pull Request Guidelines / PR 가이드라인

1. One agent per PR / PR당 하나의 에이전트
2. Include both `agents/` and `commands/` files / 두 파일 모두 포함
3. Test with `bash install.sh` locally / 로컬에서 설치 테스트
4. Update README agent table if adding new agents / 새 에이전트 추가 시 README 테이블 갱신
5. Use [Conventional Commits](https://www.conventionalcommits.org/) / Conventional Commits 사용
6. All Write-enabled agents MUST have Boundaries section / Write 에이전트는 반드시 Boundaries 포함
7. All Bash-enabled agents MUST have Allowed Commands + NEVER Run / Bash 에이전트는 명령어 제한 필수

---

## Code Style

- Shell scripts: Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Agent prompts: Clear, concise, with structured output formats
- Use `set -euo pipefail` in all shell scripts
