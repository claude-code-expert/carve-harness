# OpenHarness 분석

> 분석일: 2026-04-07
> GitHub: https://github.com/HKUDS/OpenHarness
> Stars: 6.5k | License: MIT | 성격: **오픈소스 에이전트 하네스(런타임)**
> 최초 공개: 2026-04-01 (v0.1.0) · 최신: v0.1.2 (2026-04-06)

## 한줄 요약

LLM을 실제로 움직이는 **"하네스(harness)"** — 툴 사용, 스킬, 메모리, 멀티 에이전트 조율 — 을 Python으로 오픈소스화한 경량 구현체. Claude Code가 비공개로 제공하는 런타임 구조를 투명하게 재현해서 연구자·빌더가 내부를 들여다보고 확장할 수 있게 한다.

---

## 핵심 개념: "Model is the agent, Code is the harness"

```
Harness = Tools + Knowledge + Observation + Action + Permissions
```

모델은 지능을, **하네스는 손·눈·기억·안전 경계**를 제공한다. OpenHarness는 프로덕션 AI 에이전트가 내부적으로 어떻게 돌아가는지 이해·실험·확장하기 위한 레퍼런스 구현이다.

---

## 설치

```bash
# 원클릭 설치 (OS 감지 + Python/Node 확인 + pip install)
curl -fsSL https://raw.githubusercontent.com/HKUDS/OpenHarness/main/scripts/install.sh | bash

# 소스에서 (기여자용)
curl -fsSL .../install.sh | bash -s -- --from-source

# IM 채널 포함 (Slack/Telegram/Discord)
bash scripts/install.sh --from-source --with-channels

# 수동
git clone https://github.com/HKUDS/OpenHarness.git
cd OpenHarness && uv sync --extra dev
```

**요구사항:** Python 3.10+ · uv · Node.js 18+ (React TUI 선택) · LLM API 키

---

## 10개 서브시스템 아키텍처

```
openharness/
  engine/         🧠 Agent Loop — query → stream → tool-call → loop
  tools/          🔧 43개 툴 — file/shell/search/web/MCP
  skills/         📚 온디맨드 .md 지식 로딩
  plugins/        🔌 commands + hooks + agents + MCP servers
  permissions/    🛡️ 멀티레벨 모드 + 경로 규칙 + 명령 deny
  hooks/          ⚡ PreToolUse/PostToolUse 라이프사이클
  commands/       💬 54개 커맨드 (/help, /commit, /plan, ...)
  mcp/            🌐 Model Context Protocol 클라이언트
  memory/         🧠 세션 간 지속 메모리
  tasks/          📋 백그라운드 태스크
  coordinator/    🤝 서브에이전트 스폰 + 팀 조율
  prompts/        📝 시스템 프롬프트 + CLAUDE.md + 스킬 주입
  config/         ⚙️ 다층 설정 + 마이그레이션
  ui/             🖥️ React/Ink TUI
```

---

## Agent Loop — 하네스의 심장

```python
while True:
    response = await api.stream(messages, tools)
    if response.stop_reason != "tool_use":
        break
    for tool_call in response.tool_uses:
        # Permission → PreHook → Execute → PostHook → Result
        result = await harness.execute_tool(tool_call)
    messages.append(tool_results)
```

모델이 **무엇을** 할지 결정하고, 하네스가 **어떻게** 할지 — 안전·효율·관측 가능성을 책임진다.

---

## 주요 기능

### 🔧 43개 툴

| 카테고리 | 툴 |
|---------|------|
| File I/O | Bash, Read, Write, Edit, Glob, Grep |
| Search | WebFetch, WebSearch, ToolSearch, LSP |
| Notebook | NotebookEdit |
| Agent | Agent, SendMessage, TeamCreate/Delete |
| Task | TaskCreate/Get/List/Update/Stop/Output |
| MCP | MCPTool, ListMcpResources, ReadMcpResource |
| Mode | EnterPlanMode, ExitPlanMode, Worktree |
| Schedule | CronCreate/List/Delete, RemoteTrigger |
| Meta | Skill, Config, Brief, Sleep, AskUser |

모든 툴: **Pydantic 입력 검증 + JSON Schema 자기 기술 + 권한 통합 + Pre/Post 훅**.

### 📚 Skills — 온디맨드 지식

`.md` 파일을 `~/.openharness/skills/`에 넣으면 모델이 필요할 때만 로드. **anthropics/skills 레포와 완전 호환** — 그대로 복사해서 쓸 수 있다.

### 🔌 Plugins — Claude Code 호환

[`anthropics/claude-code/plugins`](https://github.com/anthropics/claude-code/tree/main/plugins) 형식과 호환. 12개 공식 플러그인 테스트 완료:

| Plugin | 역할 |
|--------|------|
| commit-commands | Git commit/push/PR |
| security-guidance | 파일 편집 보안 경고 |
| hookify | 커스텀 훅 생성 |
| feature-dev | 기능 개발 워크플로우 |
| code-review | 멀티 에이전트 PR 리뷰 |

### 🛡️ Permissions — 멀티레벨 안전망

| 모드 | 동작 | 용도 |
|------|------|------|
| Default | write/execute 전 승인 | 일상 개발 |
| Auto | 전부 허용 | 샌드박스 |
| Plan Mode | write 차단 | 대규모 리팩터 사전 리뷰 |

```json
{
  "permission": {
    "mode": "default",
    "path_rules": [{"pattern": "/etc/*", "allow": false}],
    "denied_commands": ["rm -rf /", "DROP TABLE *"]
  }
}
```

### 🖥️ React/Ink TUI

커맨드 피커(`/`) · 인터랙티브 권한 다이얼로그 · 모드 스위처 · 세션 리줌(`/resume`) · 애니메이션 스피너 · 컨텍스트 키보드 숏컷.

---

## Provider 호환성 — Workflow 단위

`oh setup`이 raw auth/provider 내부 대신 **워크플로우**로 선택하게 해준다.

| Workflow | 백엔드 |
|----------|--------|
| **Anthropic-Compatible API** | Claude 공식, Kimi, GLM, MiniMax |
| **Claude Subscription** | `~/.claude/.credentials.json` 브리지 |
| **OpenAI-Compatible API** | OpenAI, OpenRouter, DashScope, DeepSeek, SiliconFlow, Groq, Ollama, GitHub Models |
| **Codex Subscription** | `~/.codex/auth.json` 브리지 |
| **GitHub Copilot** | OAuth device flow (API 키 불필요) |

프로필별 자격증명 바인딩 — 여러 compatible 엔드포인트가 하나의 글로벌 키를 공유하지 않아도 된다.

---

## CLI

```
oh [OPTIONS] COMMAND [ARGS]

Session:     -c/--continue, -r/--resume, -n/--name
Model:       -m/--model, --effort, --max-turns
Output:      -p/--print, --output-format text|json|stream-json
Permissions: --permission-mode, --dangerously-skip-permissions
Context:     -s/--system-prompt, --append-system-prompt, --settings
Advanced:    -d/--debug, --mcp-config, --bare

Sub: oh setup | oh provider | oh auth | oh mcp | oh plugin
```

### Non-Interactive (파이프/스크립트)

```bash
oh -p "Explain this codebase"
oh -p "List functions" --output-format json
oh -p "Fix the bug"  --output-format stream-json
```

---

## ohmo — 개인 에이전트 앱

`oh` 위에 얹힌 퍼스널 에이전트. 전용 워크스페이스(`~/.ohmo/`)와 게이트웨이를 가진다.

```bash
ohmo init              # 워크스페이스 생성
ohmo config            # 프로바이더/채널 설정
ohmo                   # 실행
ohmo gateway run       # 게이트웨이 포그라운드
ohmo gateway status
```

**핵심 파일:**
- `soul.md` — 장기 퍼스널리티/행동
- `identity.md` — ohmo가 누구인지
- `user.md` — 사용자 프로필·선호
- `BOOTSTRAP.md` — 최초 실행 랜딩 의례
- `memory/` — 개인 메모리
- `gateway.json` — 프로바이더 프로필 + 채널 설정

**채널 통합:** Telegram · Slack · Discord · Feishu

---

## 테스트 커버리지

| Suite | 테스트 수 | 상태 |
|-------|----------|------|
| Unit + Integration | 114 | ✅ |
| CLI Flags E2E | 6 | ✅ 실제 모델 호출 |
| Harness Features E2E | 9 | ✅ retry/skills/parallel/permissions |
| React TUI E2E | 3 | ✅ |
| TUI Interactions E2E | 4 | ✅ |
| Real Skills + Plugins | 12 | ✅ anthropics/skills + claude-code/plugins |

---

## 확장 예시

### 커스텀 툴

```python
class MyTool(BaseTool):
    name = "my_tool"
    description = "Does something useful"
    input_model = MyToolInput

    async def execute(self, arguments, context) -> ToolResult:
        return ToolResult(output=f"Result for: {arguments.query}")
```

### 커스텀 스킬

`~/.openharness/skills/my-skill.md`에 frontmatter + 본문만 작성하면 끝.

### 플러그인

`.openharness/plugins/my-plugin/.claude-plugin/plugin.json` + `commands/*.md` + `hooks/hooks.json` + `agents/*.md`.

---

## OpenHarness vs Claude Code vs GSD

| 축 | Claude Code (CC) | OpenHarness (OH) | GSD |
|----|------------------|------------------|-----|
| 성격 | 비공개 런타임 (공식) | **오픈소스 런타임 구현체** | CC 위의 워크플로우 엔진 |
| 레이어 | 하네스 자체 | 하네스 자체 | 메타 (CC 위) |
| 언어 | 비공개 | Python | Markdown 커맨드 |
| 확장 | Skills + Plugins + MCP | **동일 포맷 호환** | 슬래시 커맨드 |
| 대상 | 엔드유저 | 연구자·빌더 | 개발자 자동화 |

**핵심 포인트:** OH는 CC의 *경쟁자*가 아니라 **투명한 오픈 구현체**. CC가 만든 `.md` 스킬·플러그인 생태계를 그대로 재사용하면서 내부를 파헤칠 수 있게 해준다.

---

## Run-AI 프로젝트 관점에서의 함의

1. **하네스 구조 학습** — Run-AI의 AI 분석 파이프라인(Claude/Gemini/Firecrawl)을 에이전트화할 때 레퍼런스
2. **Skills 포맷 재사용** — Run-AI의 `.claude/skills/`(spring-conventions, ai-pipeline)를 OH에도 그대로 쓸 수 있음
3. **권한/훅 모델** — Spring @Async 파이프라인에 Pre/Post 훅 개념을 녹일 때 참고
4. **Provider 추상화** — Run-AI의 `ClaudeClient`/`GeminiClient`/`FirecrawlClient`도 비슷한 workflow-profile 패턴으로 묶을 수 있음
5. **ohmo 패턴** — Run-AI의 관리자/큐레이터 에이전트를 장기 메모리 + 채널 통합으로 구현할 때 참고

---

## 한 줄 결론

> *"The model is the agent. The code is the harness."*
> — 하네스가 뭔지 궁금했다면, OpenHarness는 **읽을 수 있는 대답**이다.
