# OpenHarness 완벽 가이드

> GitHub: https://github.com/HKUDS/OpenHarness
> Stars: 6.5k | License: MIT | 최신 버전: v0.1.2 (2026-04-06)
> 최초 공개: v0.1.0 (2026-04-01) · 저자: HKUDS (홍콩대 Data Science Lab)

---

## 1. OpenHarness란 무엇인가

LLM을 실제로 "에이전트"로 만드는 **하네스(harness) 레이어**의 오픈소스 Python 구현체. Claude Code 같은 상용 에이전트 런타임이 비공개로 제공하는 것을 투명하게 재현해서, 연구자와 빌더가 내부를 읽고 확장할 수 있게 만든 프로젝트다.

### 핵심 공식

```
Harness = Tools + Knowledge + Observation + Action + Permissions
```

> *"The model is the agent. The code is the harness."*

모델은 지능을 제공하고, 하네스는 **손·눈·기억·안전 경계**를 제공한다. OpenHarness가 존재하는 이유:

- **Understand** — 프로덕션 AI 에이전트의 내부 동작 원리를 읽는다
- **Experiment** — 최신 툴/스킬/멀티 에이전트 패턴을 실험한다
- **Extend** — 커스텀 플러그인·프로바이더·도메인 지식으로 확장한다
- **Build** — 검증된 아키텍처 위에 특화 에이전트를 쌓는다

### 호환성 — "Claude-friendly" 생태계

- **anthropics/skills** 의 `.md` 스킬을 그대로 복사해서 사용 가능
- **claude-code plugins** 12개 공식 플러그인과 호환 테스트 완료
- **MCP (Model Context Protocol)** 네이티브 지원
- 프로바이더: Anthropic · OpenAI · Kimi · GLM · MiniMax · DeepSeek · OpenRouter · DashScope · SiliconFlow · Groq · Ollama · GitHub Models · GitHub Copilot

---

## 2. 설치

### 원클릭 설치 (권장)

```bash
curl -fsSL https://raw.githubusercontent.com/HKUDS/OpenHarness/main/scripts/install.sh | bash
```

스크립트가 하는 일:
1. OS 감지 (Linux / macOS / WSL)
2. Python ≥ 3.10 및 Node.js ≥ 18 검증
3. `pip`로 OpenHarness 설치
4. React TUI 설정 (`npm install`, Node 있으면)
5. `~/.openharness/` 설정 디렉토리 생성
6. `oh --version`으로 확인

### 옵션 플래그

| 플래그 | 설명 |
|--------|------|
| `--from-source` | GitHub 클론 + editable 설치 (`pip install -e .`) |
| `--with-channels` | IM 채널 의존성 포함 (slack-sdk, python-telegram-bot, discord.py) |

```bash
# 소스 설치
bash scripts/install.sh --from-source

# IM 채널 포함
bash scripts/install.sh --from-source --with-channels
```

### 수동 설치

```bash
git clone https://github.com/HKUDS/OpenHarness.git
cd OpenHarness
uv sync --extra dev
```

### 요구사항

- Python 3.10+ 와 [uv](https://docs.astral.sh/uv/)
- Node.js 18+ (React TUI용, 선택)
- LLM API 키 (Anthropic/OpenAI/Kimi/... 중 하나)

### 첫 실행 데모

```bash
ANTHROPIC_API_KEY=your_key uv run oh -p "Inspect this repository and list the top 3 refactors"
```

### Kimi를 백엔드로 쓰는 예

```bash
export ANTHROPIC_BASE_URL=https://api.moonshot.cn/anthropic
export ANTHROPIC_API_KEY=your_kimi_api_key
export ANTHROPIC_MODEL=kimi-k2.5

oh                    # venv 활성화 시
uv run oh             # 활성화 없이
```

---

## 3. 초기 설정 — `oh setup`

raw auth/provider를 만지는 대신 **워크플로우 단위**로 설정하게 해주는 통합 플로우.

```bash
uv run oh setup
```

`oh setup`이 안내하는 단계:

1. **워크플로우 선택:**
   - `Anthropic-Compatible API`
   - `Claude Subscription`
   - `OpenAI-Compatible API`
   - `Codex Subscription`
   - `GitHub Copilot`
2. compatible API 계열이면 구체 백엔드 프리셋 선택
3. 필요 시 워크플로우 인증
4. 모델 선택/확인
5. 프로필 저장 및 활성화

OpenHarness는 API-키 기반 compatible 프로필을 **프로필 스코프 자격증명**으로 저장한다 — 서로 다른 compatible 엔드포인트가 하나의 글로벌 키를 공유하지 않는다.

---

## 4. 하네스 아키텍처 — 10개 서브시스템

```
openharness/
  engine/         🧠 Agent Loop — query → stream → tool-call → loop
  tools/          🔧 43개 툴 — File/Shell/Search/Web/MCP
  skills/         📚 온디맨드 .md 지식 로딩
  plugins/        🔌 commands + hooks + agents + MCP servers
  permissions/    🛡️ 멀티레벨 모드 + 경로 규칙 + 명령 deny
  hooks/          ⚡ PreToolUse/PostToolUse 라이프사이클
  commands/       💬 54개 커맨드 (/help, /commit, /plan, /resume, ...)
  mcp/            🌐 Model Context Protocol 클라이언트
  memory/         🧠 세션 간 지속 메모리
  tasks/          📋 백그라운드 태스크
  coordinator/    🤝 서브에이전트 스폰 + 팀 조율
  prompts/        📝 시스템 프롬프트 + CLAUDE.md + 스킬 주입
  config/         ⚙️ 다층 설정 + 마이그레이션
  ui/             🖥️ React/Ink TUI (백엔드 프로토콜 + 프론트)
```

### Agent Loop — 심장

```python
while True:
    response = await api.stream(messages, tools)

    if response.stop_reason != "tool_use":
        break  # 모델 완료

    for tool_call in response.tool_uses:
        # 권한 체크 → PreHook → 실행 → PostHook → 결과
        result = await harness.execute_tool(tool_call)

    messages.append(tool_results)
    # 루프 계속 — 모델이 결과 보고 다음 액션 결정
```

### Harness Flow

```
User Prompt → CLI or React TUI → RuntimeBundle → QueryEngine
                                                     ↓
                                          Anthropic-compatible API
                                                     ↓
                                               Tool Registry
                                                     ↓
                                          Permissions + Hooks
                                                     ↓
                                    Files / Shell / Web / MCP / Tasks
                                                     ↓
                                                (루프로 복귀)
```

---

## 5. 주요 기능

### 5.1 Tools (43+)

| 카테고리 | 툴 | 설명 |
|----------|-----|------|
| **File I/O** | Bash, Read, Write, Edit, Glob, Grep | 권한 체크 포함 핵심 파일 조작 |
| **Search** | WebFetch, WebSearch, ToolSearch, LSP | 웹/코드 검색 |
| **Notebook** | NotebookEdit | Jupyter 셀 편집 |
| **Agent** | Agent, SendMessage, TeamCreate/Delete | 서브에이전트 스폰 및 조율 |
| **Task** | TaskCreate/Get/List/Update/Stop/Output | 백그라운드 태스크 관리 |
| **MCP** | MCPTool, ListMcpResources, ReadMcpResource | Model Context Protocol |
| **Mode** | EnterPlanMode, ExitPlanMode, Worktree | 워크플로우 모드 전환 |
| **Schedule** | CronCreate/List/Delete, RemoteTrigger | 스케줄/원격 실행 |
| **Meta** | Skill, Config, Brief, Sleep, AskUser | 지식 로딩, 설정, 상호작용 |

모든 툴의 공통 속성:
- **Pydantic 입력 검증** — 구조화·타입 안전
- **자기 기술 JSON Schema** — 모델이 툴을 자동 이해
- **권한 통합** — 모든 실행 전 체크
- **훅 지원** — PreToolUse/PostToolUse 라이프사이클

### 5.2 Skills System — 온디맨드 지식

Skills는 모델이 필요할 때만 로드되는 `.md` 파일이다:

```
Available Skills:
- commit: Create clean, well-structured git commits
- review: Review code for bugs, security, quality
- debug: Diagnose and fix bugs systematically
- plan: Design an implementation plan before coding
- test: Write and run tests
- simplify: Refactor for simplicity
- pdf: PDF processing (from anthropics/skills)
- xlsx: Excel operations (from anthropics/skills)
- ... 40+ more
```

**anthropics/skills와 완전 호환** — `.md` 파일을 `~/.openharness/skills/`에 복사만 하면 된다.

### 5.3 Plugin System — Claude Code 호환

[claude-code plugins](https://github.com/anthropics/claude-code/tree/main/plugins) 포맷과 호환. 테스트 완료된 12개 공식 플러그인:

| 플러그인 | 타입 | 역할 |
|---------|------|------|
| `commit-commands` | Commands | Git commit/push/PR 워크플로우 |
| `security-guidance` | Hooks | 파일 편집 시 보안 경고 |
| `hookify` | Commands + Agents | 커스텀 동작 훅 생성 |
| `feature-dev` | Commands | 기능 개발 워크플로우 |
| `code-review` | Agents | 멀티 에이전트 PR 리뷰 |
| `pr-review-toolkit` | Agents | 특화 PR 리뷰 에이전트 |

```bash
# 플러그인 관리
oh plugin list
oh plugin install <source>
oh plugin enable <name>
```

### 5.4 Permissions — 멀티레벨 안전망

| 모드 | 동작 | 용도 |
|------|------|------|
| **Default** | write/execute 전 승인 | 일상 개발 |
| **Auto** | 전부 허용 | 샌드박스 환경 |
| **Plan Mode** | write 전부 차단 | 대규모 리팩터 사전 리뷰 |

`settings.json`의 경로 레벨 규칙:

```json
{
  "permission": {
    "mode": "default",
    "path_rules": [
      {"pattern": "/etc/*", "allow": false}
    ],
    "denied_commands": ["rm -rf /", "DROP TABLE *"]
  }
}
```

### 5.5 Terminal UI — React/Ink

- **Command picker**: `/` → 화살표 선택 → Enter
- **Permission dialog**: 툴 디테일과 함께 인터랙티브 y/n
- **Mode switcher**: `/permissions` → 리스트에서 선택
- **Session resume**: `/resume` → 히스토리 선택
- **Animated spinner**: 툴 실행 중 실시간 피드백
- **Keyboard shortcuts**: 하단 컨텍스트 기반 표시

---

## 6. CLI 레퍼런스

```
oh [OPTIONS] COMMAND [ARGS]

Session:     -c/--continue, -r/--resume, -n/--name
Model:       -m/--model, --effort, --max-turns
Output:      -p/--print, --output-format text|json|stream-json
Permissions: --permission-mode, --dangerously-skip-permissions
Context:     -s/--system-prompt, --append-system-prompt, --settings
Advanced:    -d/--debug, --mcp-config, --bare

Subcommands: oh setup | oh provider | oh auth | oh mcp | oh plugin
```

### Non-Interactive 모드 (파이프/스크립트)

```bash
# 단일 프롬프트 → stdout
oh -p "Explain this codebase"

# 프로그램용 JSON 출력
oh -p "List all functions in main.py" --output-format json

# 실시간 JSON 이벤트 스트림
oh -p "Fix the bug" --output-format stream-json
```

### Provider 관리

```bash
oh setup              # 워크플로우 기반 설정
oh provider list      # 저장된 워크플로우 목록
oh provider use <profile>  # 활성 워크플로우 전환

# 커스텀 compatible 엔드포인트 추가
oh provider add my-endpoint \
  --label "My Endpoint" \
  --provider openai \
  --api-format openai \
  --auth-source openai_api_key \
  --model my-model \
  --base-url https://example.com/v1
```

---

## 7. Provider 호환성

### Built-in Workflows

| Workflow | 설명 | 백엔드 |
|----------|------|--------|
| **Anthropic-Compatible API** | Anthropic 스타일 요청 포맷 | Claude 공식, Kimi, GLM, MiniMax |
| **Claude Subscription** | Claude CLI 구독 브리지 | `~/.claude/.credentials.json` |
| **OpenAI-Compatible API** | OpenAI 스타일 요청 포맷 | OpenAI, OpenRouter, DashScope, DeepSeek, SiliconFlow, Groq, Ollama, GitHub Models |
| **Codex Subscription** | Codex CLI 구독 브리지 | `~/.codex/auth.json` |
| **GitHub Copilot** | Copilot OAuth 워크플로우 | Device-flow 로그인 |

### Anthropic-Compatible 백엔드 예시

| 백엔드 | Base URL | 예시 모델 |
|--------|----------|-----------|
| Claude 공식 | `https://api.anthropic.com` | `claude-sonnet-4-6`, `claude-opus-4-6` |
| Moonshot/Kimi | `https://api.moonshot.cn/anthropic` | `kimi-k2.5` |
| Zhipu/GLM | custom | `glm-4.5` |
| MiniMax | custom | `minimax-m1` |

### OpenAI-Compatible 백엔드 예시

| 백엔드 | Base URL | 예시 모델 |
|--------|----------|-----------|
| OpenAI | `https://api.openai.com/v1` | `gpt-5.4`, `gpt-4.1` |
| OpenRouter | `https://openrouter.ai/api/v1` | provider-specific |
| DashScope | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen3.5-flash`, `qwen3-max`, `deepseek-r1` |
| DeepSeek | `https://api.deepseek.com` | `deepseek-chat`, `deepseek-reasoner` |
| GitHub Models | `https://models.inference.ai.azure.com` | `gpt-4o`, `Meta-Llama-3.1-405B-Instruct` |
| SiliconFlow | `https://api.siliconflow.cn/v1` | `deepseek-ai/DeepSeek-V3` |
| Groq | `https://api.groq.com/openai/v1` | `llama-3.3-70b-versatile` |
| Ollama (로컬) | `http://localhost:11434/v1` | 모든 로컬 모델 |

### GitHub Copilot 포맷

```bash
# 최초 로그인 (GitHub OAuth 브라우저)
oh auth copilot-login

# Copilot을 프로바이더로 실행
uv run oh --api-format copilot

# 또는 환경변수
export OPENHARNESS_API_FORMAT=copilot
uv run oh

# 인증 상태 / 로그아웃
oh auth status
oh auth copilot-logout
```

| 기능 | 상세 |
|------|------|
| 인증 | GitHub OAuth device flow (API 키 불필요) |
| 토큰 | 단명 세션 토큰 자동 갱신 |
| Enterprise | `--github-domain`으로 GitHub Enterprise 지원 |
| 모델 | Copilot 기본 모델 선택 |
| API | 내부적으로 OpenAI 호환 chat completions |

---

## 8. ohmo — 개인 에이전트 앱

`oh` 위에 얹힌 퍼스널 에이전트 앱. 자체 워크스페이스와 게이트웨이를 가진다.

### 기본 명령

```bash
ohmo init                # 개인 워크스페이스 초기화
ohmo config              # 게이트웨이 채널 + 프로바이더 프로필 설정
ohmo                     # 개인 에이전트 실행
ohmo gateway run         # 게이트웨이 포그라운드 실행
ohmo gateway status      # 상태 확인
ohmo gateway restart     # 재시작
```

### `~/.ohmo/` 워크스페이스

| 파일 | 역할 |
|------|------|
| `soul.md` | 장기 에이전트 퍼스널리티/행동 |
| `identity.md` | ohmo가 누구인지 |
| `user.md` | 사용자 프로필 및 선호 |
| `BOOTSTRAP.md` | 첫 실행 랜딩 의례 |
| `memory/` | 개인 메모리 |
| `gateway.json` | 선택된 프로바이더 프로필 + 채널 설정 |

### 프로바이더 & 채널

`ohmo config`는 `oh setup`과 같은 워크플로우 언어를 사용 — Anthropic/OpenAI compatible, Claude/Codex Subscription, GitHub Copilot 전부 가리킬 수 있다.

**현재 채널 통합:** Telegram · Slack · Discord · Feishu

`ohmo init`은 홈 워크스페이스를 한 번 생성한다. 이후엔 `ohmo config`로 프로바이더/채널 설정을 업데이트하며, 게이트웨이가 이미 돌고 있으면 설정 플로우가 재시작해준다.

---

## 9. 테스트

| Suite | 테스트 수 | 상태 |
|-------|----------|------|
| Unit + Integration | 114 | ✅ |
| CLI Flags E2E | 6 | ✅ 실제 모델 호출 |
| Harness Features E2E | 9 | ✅ retry, skills, parallel, permissions |
| React TUI E2E | 3 | ✅ welcome, conversation, status |
| TUI Interactions E2E | 4 | ✅ commands, permissions, shortcuts |
| Real Skills + Plugins | 12 | ✅ anthropics/skills + claude-code/plugins |

```bash
uv run pytest -q                           # 114 unit/integration
python scripts/test_harness_features.py     # Harness E2E
python scripts/test_real_skills_plugins.py  # Real plugins E2E
```

---

## 10. 확장하기

### 10.1 커스텀 툴 추가

```python
from pydantic import BaseModel, Field
from openharness.tools.base import BaseTool, ToolExecutionContext, ToolResult

class MyToolInput(BaseModel):
    query: str = Field(description="Search query")

class MyTool(BaseTool):
    name = "my_tool"
    description = "Does something useful"
    input_model = MyToolInput

    async def execute(self, arguments: MyToolInput, context: ToolExecutionContext) -> ToolResult:
        return ToolResult(output=f"Result for: {arguments.query}")
```

### 10.2 커스텀 스킬 추가

`~/.openharness/skills/my-skill.md`:

```markdown
---
name: my-skill
description: Expert guidance for my specific domain
---

# My Skill

## When to use
Use when the user asks about [your domain].

## Workflow
1. Step one
2. Step two
...
```

### 10.3 플러그인 추가

`.openharness/plugins/my-plugin/.claude-plugin/plugin.json`:

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "My custom plugin"
}
```

추가:
- `commands/*.md` — 슬래시 커맨드
- `hooks/hooks.json` — 라이프사이클 훅
- `agents/*.md` — 커스텀 서브에이전트

---

## 11. 상황별 어떤 기능을 써야 하나

| 상황 | 사용할 것 |
|------|-----------|
| 처음 설정 | `oh setup` (워크플로우 안내) |
| 일상 코딩 | `oh` (인터랙티브 TUI) |
| 단일 쿼리 → stdout | `oh -p "..."` |
| 스크립트/자동화 | `oh -p "..." --output-format json\|stream-json` |
| 세션 이어하기 | `oh -c` 또는 `oh -r` |
| 대규모 리팩터 사전 검토 | `--permission-mode plan` |
| 샌드박스 전부 허용 | `--dangerously-skip-permissions` |
| 프로바이더 전환 | `oh provider use <profile>` |
| 커스텀 백엔드 추가 | `oh provider add ...` |
| MCP 서버 추가 | `oh mcp ...` |
| 플러그인 설치 | `oh plugin install <source>` |
| 개인 에이전트 실행 | `ohmo` |
| Telegram/Slack 봇화 | `ohmo config` → 채널 선택 |

---

## 12. Run-AI 프로젝트에 적용하는 방법

### 용도 1 — 레퍼런스 구현으로 읽기

Run-AI의 AI 분석 파이프라인(`backend/src/main/java/kr/runai/ai/`)을 설계할 때 OpenHarness의 `engine/`, `tools/`, `permissions/` 모듈이 훌륭한 **Python 레퍼런스**가 된다. Spring Boot로 포팅할 때 개념 매핑:

| OpenHarness (Python) | Run-AI (Spring Boot 4) |
|----------------------|------------------------|
| `engine/` Agent Loop | `AnalysisService` (@Async 파이프라인) |
| `tools/` 43개 | `ClaudeClient`, `GeminiClient`, `FirecrawlClient`, `GitHubMetaClient` |
| `permissions/` | `SecurityConfig` + `@PreAuthorize` |
| `hooks/` | Spring AOP (`@Before`/`@After`) |
| `memory/` | Redis + `ai_analysis_logs` 테이블 |
| `coordinator/` | `@Async` thread pool + `SseEmitter` |

### 용도 2 — 사내 CLI 에이전트로 설치

```bash
# Run-AI 리포에 OpenHarness 설치
cd run-ai
curl -fsSL https://raw.githubusercontent.com/HKUDS/OpenHarness/main/scripts/install.sh | bash

# Kimi 또는 Claude 구독을 백엔드로
oh setup
```

Run-AI의 `.claude/skills/` 파일들(spring-conventions, ai-pipeline, point-role-system)을 `~/.openharness/skills/`에 복사하면 그대로 작동한다 — **포맷이 동일하기 때문**.

### 용도 3 — ohmo로 관리자 에이전트 구축

Run-AI의 어드민 작업(새 카테고리 승인, 포인트 조정, AI 비용 모니터링)을 Slack/Telegram으로 처리하는 개인 에이전트:

```bash
ohmo init
ohmo config     # Slack/Telegram 채널 + Claude 프로필 선택
# soul.md에 "Run-AI 관리자 보조" 퍼스널리티 작성
# memory/에 카테고리 승인 규칙 저장
ohmo gateway run
```

### 12.4 기존 `.claude/`와의 관계

Run-AI는 이미 `.claude/skills/`, `.claude/commands/`, `.claude/agents/`를 가지고 있다. OpenHarness는 **같은 포맷을 읽는다**:

| Run-AI 자산 | OpenHarness 경로 |
|------------|------------------|
| `.claude/skills/*.md` | `~/.openharness/skills/` 로 심볼릭 링크 가능 |
| `.claude/commands/*.md` | `.openharness/plugins/*/commands/` |
| `.claude/agents/*.md` | `.openharness/plugins/*/agents/` |

즉 **Claude Code와 OpenHarness를 동시에 쓰면서 동일한 도메인 지식**(Spring 컨벤션, AI 파이프라인 규칙, 포인트/등급 시스템)을 공유할 수 있다.

---

## 13. 트러블슈팅

| 문제 | 해결 |
|------|------|
| `oh: command not found` | `uv run oh` 사용 또는 venv 활성화 |
| Python 버전 오류 | 3.10+ 필요 — `uv python install 3.11` |
| React TUI가 안 뜸 | Node 18+ 설치 후 `npm install` |
| API 키 인식 안 됨 | `oh provider list`로 활성 프로필 확인, `oh setup` 재실행 |
| Claude Subscription 브리지 실패 | `~/.claude/.credentials.json` 존재 확인 |
| Copilot 로그인 실패 | `oh auth copilot-login` 재시도, 브라우저 device flow 완료 확인 |
| 권한 다이얼로그가 계속 뜸 | `--permission-mode auto` (샌드박스 한정) |
| compatible 엔드포인트가 공유 키 사용 | 프로필별 자격증명으로 `oh provider add` 재등록 |
| MCP 서버 안 붙음 | `oh mcp` 서브커맨드로 설정 확인 |
| 테스트 실패 | `uv sync --extra dev` 후 `uv run pytest -q` |

---

## 14. 요약

| 축 | 값 |
|----|-----|
| **정체성** | Claude Code 스타일 에이전트 하네스의 오픈소스 Python 구현체 |
| **강점** | 투명한 내부 구조, anthropics/skills 및 claude-code plugins 호환 |
| **약점** | v0.1.x 초기 단계, 문서 성숙도 낮음, 커뮤니티 작음 |
| **킬러 피처** | 10개 모듈로 깔끔하게 분리된 아키텍처, Workflow 기반 프로바이더 추상화, ohmo 퍼스널 에이전트 |
| **대상 사용자** | 에이전트 내부를 읽고 싶은 연구자·빌더, Claude 생태계를 재사용하고 싶은 개발자 |
| **철학** | *"The model is the agent. The code is the harness."* |
