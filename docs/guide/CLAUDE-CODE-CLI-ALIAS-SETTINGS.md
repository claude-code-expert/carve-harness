# Claude Code CLI Alias & Settings 레퍼런스

> Claude Code 명령어를 효율적으로 사용하기 위한 alias 모음과 settings 설정 가이드.
> `~/.zshrc`에 추가하고, settings.json 계층 구조를 이해하면 작업 흐름이 크게 개선된다.

---

## Table of Contents

1. [CLI 플래그 레퍼런스](#1-cli-플래그-레퍼런스)
2. [추천 Alias 모음](#2-추천-alias-모음)
3. [Settings 계층 구조](#3-settings-계층-구조)
4. [Settings.json 주요 설정](#4-settingsjson-주요-설정)
5. [Permission 설정 (allowlist / denylist)](#5-permission-설정-allowlist--denylist)
6. [Hooks 설정](#6-hooks-설정)
7. [모델 설정](#7-모델-설정)
8. [환경변수](#8-환경변수)
9. [--dangerously-skip-permissions 안전 가이드](#9---dangerously-skip-permissions-안전-가이드)
10. [유용한 Shell 함수](#10-유용한-shell-함수)

---

## 1. CLI 플래그 레퍼런스

### 기본 명령어

| 명령어 | 설명 |
|--------|------|
| `claude` | 대화형 REPL 시작 |
| `claude "query"` | 초기 프롬프트로 REPL 시작 |
| `claude -p "query"` | 비대화형 (SDK 모드), 결과 출력 후 종료 |
| `cat file \| claude -p "query"` | 파이프 입력 처리 |
| `claude -c` | 마지막 대화 이어서 계속 |
| `claude -c -p "query"` | 마지막 대화에 비대화형으로 이어서 |
| `claude -r "session-id"` | 특정 세션 ID로 재개 |
| `claude update` | 최신 버전으로 업데이트 |
| `claude mcp` | MCP 서버 관리 |

### 주요 플래그

| 플래그 | 설명 | 예시 |
|--------|------|------|
| `--model` | 모델 지정 (`sonnet`, `opus`, `haiku` 또는 전체 모델명) | `claude --model opus` |
| `--continue`, `-c` | 마지막 대화 이어서 | `claude -c` |
| `--resume`, `-r` | 특정 세션 재개 | `claude -r abc123` |
| `--print`, `-p` | 비대화형 모드 (스크립트용) | `claude -p "query"` |
| `--dangerously-skip-permissions` | 모든 권한 프롬프트 스킵 ⚠️ | `claude --dangerously-skip-permissions` |
| `--permission-mode` | 권한 모드 지정 | `claude --permission-mode plan` |
| `--allowedTools` | 추가 허용 도구 지정 | `claude --allowedTools "Bash(git:*)" "Read"` |
| `--disallowedTools` | 차단 도구 지정 | `claude --disallowedTools "Bash(rm:*)"` |
| `--append-system-prompt` | 기본 시스템 프롬프트에 추가 | `claude --append-system-prompt "TypeScript만 사용"` |
| `--system-prompt` | 시스템 프롬프트 전체 교체 | `claude --system-prompt "You are a Python expert"` |
| `--output-format` | 출력 형식 (`text`, `json`, `stream-json`) | `claude -p --output-format json "query"` |
| `--max-turns` | 비대화형 모드 최대 턴 수 제한 | `claude -p --max-turns 3 "query"` |
| `--verbose` | 상세 로그 출력 | `claude --verbose` |
| `--debug` | 디버그 모드 (카테고리 필터링 가능) | `claude --debug "api,hooks"` |
| `--add-dir` | 추가 작업 디렉토리 지정 | `claude --add-dir ../apps ../lib` |
| `--mcp-config` | MCP 서버 JSON 설정 파일 로드 | `claude --mcp-config ./mcp.json` |
| `--agents` | 커스텀 서브에이전트 JSON 정의 | `claude --agents '{...}'` |
| `--tools` | 사용 가능한 도구 제한 | `claude -p --tools "Bash,Edit,Read" "query"` |
| `--fork-session` | 세션 재개 시 새 세션 ID 생성 | `claude --resume abc --fork-session` |
| `--fallback-model` | 기본 모델 과부하 시 대체 모델 | `claude -p --fallback-model sonnet "query"` |
| `--notify` | 작업 완료 시 시스템 알림 | `claude --notify` |
| `--version`, `-v` | 버전 출력 | `claude -v` |

### 시스템 프롬프트 플래그 비교

| 플래그 | 동작 | 모드 | 용도 |
|--------|------|------|------|
| `--system-prompt` | 기본 프롬프트 **전체 교체** | Interactive + Print | 완전한 제어가 필요할 때 |
| `--system-prompt-file` | 파일에서 로드, **전체 교체** | Print only | 팀 일관성, 버전 관리 |
| `--append-system-prompt` | 기본 프롬프트에 **추가** | Interactive + Print | 대부분의 경우 **권장** |
| `--append-system-prompt-file` | 파일에서 로드, **추가** | Interactive + Print | 버전 관리된 추가 지시문 |

> `--system-prompt`과 `--system-prompt-file`은 동시 사용 불가. `--append-*` 플래그는 어디에나 조합 가능.

---

## 2. 추천 Alias 모음

`~/.zshrc` (또는 `~/.bashrc`)에 추가:

### 기본 Alias

```bash
# ── Claude Code 기본 ─────────────────────────────────
alias cc="claude"                              # 기본 실행
alias ccc="claude -c"                          # 마지막 대화 이어서
alias ccr="claude -r"                          # 특정 세션 재개 (뒤에 session-id)

# ── 모델 지정 실행 ───────────────────────────────────
alias cco="claude --model opus"                # Opus로 실행
alias ccs="claude --model sonnet"              # Sonnet으로 실행
alias cch="claude --model haiku"               # Haiku로 실행
alias ccop="claude --model opusplan"           # OpusPlan (plan=opus, exec=sonnet)

# ── 대화 이어서 + 모델 ──────────────────────────────
alias ccco="claude -c --model opus"            # 이어서 + Opus
alias cccs="claude -c --model sonnet"          # 이어서 + Sonnet
```

### 자율 실행 모드 (YOLO)

```bash
# ── Dangerous Mode ⚠️ ────────────────────────────────
alias ccd="claude --dangerously-skip-permissions"          # YOLO 모드
alias ccdo="claude --dangerously-skip-permissions --model opus"   # YOLO + Opus
alias ccds="claude --dangerously-skip-permissions --model sonnet" # YOLO + Sonnet
alias ccdc="claude --dangerously-skip-permissions -c"      # YOLO + 이어서

# ── YOLO + 알림 (작업 완료 시 시스템 알림) ────────────
alias ccdn="claude --dangerously-skip-permissions --notify"
```

### 비대화형 (스크립트/파이프라인)

```bash
# ── Print 모드 (비대화형) ────────────────────────────
alias ccp="claude -p"                          # 비대화형 기본
alias ccpj="claude -p --output-format json"    # JSON 출력
alias ccps="claude -p --output-format stream-json"  # 스트리밍 JSON

# ── CI/CD 파이프라인용 ───────────────────────────────
alias ccpipe="claude -p --dangerously-skip-permissions --output-format stream-json"
```

### 디버그 / 유틸리티

```bash
# ── 디버그 & 정보 ───────────────────────────────────
alias ccv="claude --verbose"                   # 상세 로그
alias ccdb="claude --debug"                    # 디버그 모드
alias ccdba="claude --debug 'api,hooks,mcp'"   # API/Hook/MCP 디버그

# ── 빠른 질문 (비대화형 + Haiku) ─────────────────────
alias ccq="claude -p --model haiku"            # 빠른 질문 (Haiku, 저렴)
```

### 프로젝트 특화 (예시)

```bash
# ── 프로젝트별 alias ─────────────────────────────────
alias cctest="claude -p 'npm test를 실행하고 실패한 테스트를 분석해줘'"
alias cclint="claude -p '린트 에러를 찾아서 모두 수정해줘'"
alias ccpr="claude -p 'PR description을 작성해줘. conventional commit 스타일로'"
alias ccreview="claude -p '현재 git diff를 코드 리뷰해줘'"
```

---

## 3. Settings 계층 구조

### 파일 위치 & 우선순위

설정은 **낮은 우선순위 → 높은 우선순위** 순으로 병합된다:

```
우선순위 (낮음 → 높음)
─────────────────────────────────────────────────────────
1. User (전역)          ~/.claude/settings.json
2. Project (공유)       <project>/.claude/settings.json
3. Project Local (개인) <project>/.claude/settings.local.json
4. Enterprise Managed   서버/MDM에서 배포 (override 불가)
─────────────────────────────────────────────────────────
```

| 파일 | 범위 | Git 포함 | 용도 |
|------|------|---------|------|
| `~/.claude/settings.json` | 모든 프로젝트 | N/A | 전역 기본 설정 |
| `.claude/settings.json` | 이 프로젝트 전체 | ✅ Yes | 팀 공유 설정 (permissions, hooks) |
| `.claude/settings.local.json` | 이 프로젝트, 나만 | ❌ No (.gitignore) | 개인 설정 (webhook URL, 모델 등) |
| `~/.claude.json` | 전역 (레거시) | N/A | MCP 서버, 전역 도구 허용 |

> **충돌 시**: 높은 우선순위 설정이 이긴다. deny 규칙은 allow보다 우선.

### 어디에 무엇을 넣을까

| 설정 항목 | 추천 위치 | 이유 |
|----------|----------|------|
| 모델 (`model`) | `settings.local.json` | 개인 취향 |
| 권한 allow/deny | `settings.json` | 팀 공유 |
| Hooks (Slack 알림 등) | `settings.local.json` | 개인 webhook URL 포함 |
| MCP 서버 | `settings.json` or `.mcp.json` | 팀 공유 |
| `skipDangerousModePermissionPrompt` | `settings.local.json` | 개인 설정 |

### `/status`로 확인

Claude Code 내에서 `/status` 슬래시 명령어를 실행하면 현재 활성화된 settings 소스와 출처를 볼 수 있다.

---

## 4. Settings.json 주요 설정

### 전체 구조

```jsonc
{
  // 모델 설정
  "model": "sonnet",                    // 기본 모델 (sonnet, opus, haiku, opusplan)
  "effortLevel": "medium",             // Opus 추론 강도 (low, medium, high)

  // 업데이트 채널
  "autoUpdatesChannel": "stable",      // "latest" (즉시) 또는 "stable" (1주 지연)

  // YOLO 경고 스킵
  "skipDangerousModePermissionPrompt": true,

  // Attribution (커밋 메시지)
  "includeCoAuthoredBy": false,
  "attribution": {
    "commit": "",
    "pr": ""
  },

  // 권한 규칙
  "permissions": {
    "allow": [ /* ... */ ],
    "deny": [ /* ... */ ]
  },

  // Hook 설정
  "hooks": {
    "PreToolUse": [ /* ... */ ],
    "PostToolUse": [ /* ... */ ],
    "Notification": [ /* ... */ ],
    "PermissionRequest": [ /* ... */ ],
    "Stop": [ /* ... */ ]
  },

  // MCP 서버
  "mcpServers": { /* ... */ },

  // MCP JSON 서버 활성화
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["context7"],

  // 환경변수
  "env": {
    "DISABLE_AUTOUPDATER": "1"          // 자동 업데이트 비활성화
  }
}
```

---

## 5. Permission 설정 (allowlist / denylist)

### 규칙 형식

```
Tool
Tool(specifier)
Tool(pattern:*)        ← 와일드카드
```

평가 순서: **deny → ask → allow**. 첫 매칭 규칙이 적용됨.

### 실전 예시: 팀 공유용 (`.claude/settings.json`)

```jsonc
{
  "permissions": {
    "allow": [
      // 읽기 전용 도구 (항상 허용)
      "Read",
      "Glob",
      "Grep",

      // 안전한 bash 명령어
      "Bash(npm run dev)",
      "Bash(npm run build)",
      "Bash(npm run lint)",
      "Bash(npm run test)",
      "Bash(npm run test:*)",
      "Bash(npm run db:generate)",
      "Bash(npm run db:studio)",
      "Bash(npm run format)",

      // Git 읽기
      "Bash(git status:*)",
      "Bash(git log:*)",
      "Bash(git diff:*)",
      "Bash(git branch:*)",
      "Bash(git fetch:*)",

      // 빌드 도구
      "Bash(npx tsc:*)",
      "Bash(npx jest:*)"
    ],
    "deny": [
      // 위험한 Git 명령어
      "Bash(git push --force*)",
      "Bash(git reset --hard*)",
      "Bash(git commit --no-verify*)",
      "Bash(git clean -f*)",

      // 위험한 시스템 명령어
      "Bash(rm -rf*)",
      "Bash(sudo*)",
      "Bash(npm audit fix --force*)",

      // 민감한 파일 접근
      "Read(.env)",
      "Read(.env.*)",
      "Write(production.config.*)"
    ]
  }
}
```

### 개인용 추가 (`.claude/settings.local.json`)

```jsonc
{
  "permissions": {
    "allow": [
      // 개인 작업 흐름에 필요한 추가 명령어
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git push:*)",
      "Bash(git checkout:*)",
      "Bash(git stash:*)",
      "Bash(npm install:*)",
      "Bash(npm uninstall:*)",
      "Bash(psql:*)"
    ]
  }
}
```

### /permissions 인터랙티브 설정

CLI에서 `/permissions` 슬래시 명령어로 와일드카드 문법을 사용한 권한 설정이 가능하다:

```
Bash(npm run *)        ← npm run으로 시작하는 모든 명령
Edit(/docs/**)         ← docs 디렉토리 하위 모든 파일 편집
Write(src/**)          ← src 디렉토리 하위 모든 파일 쓰기
```

---

## 6. Hooks 설정

### Hook 이벤트 목록

| 이벤트 | 발생 시점 | 제어 가능 |
|--------|----------|----------|
| `PreToolUse` | 도구 실행 전 | ✅ 차단/수정 가능 |
| `PostToolUse` | 도구 실행 후 | ✅ 컨텍스트 추가 가능 |
| `PostToolUseFailure` | 도구 실행 실패 후 | ✅ 컨텍스트 추가 가능 |
| `Notification` | 알림 발생 시 | ❌ 읽기 전용 |
| `PermissionRequest` | 권한 요청 시 | ✅ allow/deny 결정 |
| `Stop` | 응답 완료 시 | ✅ 중단 차단 가능 (exit 2) |
| `UserPromptSubmit` | 사용자 입력 시 | ✅ 프롬프트 수정/차단 |
| `SubagentStart` | 서브에이전트 시작 | ❌ 로깅용 |
| `SubagentStop` | 서브에이전트 종료 | ✅ 중단 차단 가능 |
| `SessionStart` | 세션 시작/재개 | ❌ 컨텍스트 주입 |
| `SessionEnd` | 세션 종료 | ❌ 로깅용 |
| `PreCompact` | 컴팩션 전 | ❌ 백업용 |
| `Setup` | 저장소 진입 시 (init/maintenance) | ❌ 환경 설정 |

### Notification matcher 종류

| matcher | 발생 시점 |
|---------|----------|
| `permission_prompt` | Permission Prompt가 뜰 때 |
| `idle_prompt` | 60초 이상 입력 대기 시 |
| `auth_success` | 인증 성공 시 |
| `elicitation_dialog` | MCP 도구 다이얼로그 시 |

### 통합 Hook 설정 예시

```jsonc
{
  "hooks": {
    // 권한 요청 시 알림음 + 폰 알림
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "afplay /System/Library/Sounds/Glass.aiff &"
          }
        ]
      },
      {
        "matcher": "idle_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "afplay /System/Library/Sounds/Ping.aiff &"
          }
        ]
      }
    ],

    // 원격 권한 승인 (ntfy.sh)
    "PermissionRequest": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "zsh ~/.claude/hooks/permission-ntfy.sh"
          }
        ]
      }
    ],

    // 작업 완료 시 Slack 알림
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "zsh ~/.claude/hooks/notify-slack.sh"
          }
        ]
      }
    ]
  }
}
```

### macOS 시스템 사운드 목록

Hook에서 사용할 수 있는 소리 파일 (`/System/Library/Sounds/`):

| 파일명 | 느낌 |
|--------|------|
| `Glass.aiff` | 맑은 유리 소리 (권한 요청에 적합) |
| `Ping.aiff` | 짧은 핑 (idle 알림에 적합) |
| `Pop.aiff` | 팝 소리 |
| `Tink.aiff` | 가벼운 틱 소리 |
| `Purr.aiff` | 부드러운 진동 |
| `Submarine.aiff` | 잠수함 소리 (주의 환기) |
| `Hero.aiff` | 영웅적 사운드 (작업 완료에 적합) |
| `Funk.aiff` | 펑크 사운드 (에러에 적합) |

---

## 7. 모델 설정

### 모델 별칭

| 별칭 | 설명 |
|------|------|
| `sonnet` | Claude Sonnet 최신 (기본값) |
| `opus` | Claude Opus 최신 (가장 강력) |
| `haiku` | Claude Haiku 최신 (가장 빠름/저렴) |
| `opusplan` | Plan 단계: Opus, 실행 단계: Sonnet (하이브리드) |

### 설정 방법

```bash
# CLI 플래그 (세션 단위)
claude --model opus

# settings.json (영구)
# settings.local.json에 추가:
{
  "model": "opus"
}

# 환경변수
export ANTHROPIC_MODEL="claude-opus-4-6"
```

### Effort Level (Opus 전용)

```bash
# CLI 환경변수
export CLAUDE_CODE_EFFORT_LEVEL=high    # low, medium, high

# settings.json
{
  "effortLevel": "high"
}
```

---

## 8. 환경변수

### Claude Code 전용

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `ANTHROPIC_MODEL` | 모델 override | — |
| `CLAUDE_CODE_EFFORT_LEVEL` | Opus 추론 강도 | `medium` |
| `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` | 적응형 사고 비활성화 (1) | — |
| `CLAUDE_CODE_DISABLE_1M_CONTEXT` | 1M 컨텍스트 비활성화 (1) | — |
| `DISABLE_AUTOUPDATER` | 자동 업데이트 비활성화 (1) | — |
| `CLAUDE_CODE_REMOTE` | 원격 웹 환경 여부 (`true`) | — |

### Hook/알림 관련 (프로젝트 커스텀)

| 변수 | 설명 | 설정 위치 |
|------|------|----------|
| `CLAUDE_SLACK_WEBHOOK_URL` | Slack Incoming Webhook URL | `~/.zshenv` |
| `CLAUDE_NTFY_TOPIC` | ntfy.sh 토픽 이름 | `~/.zshenv` |
| `CLAUDE_PUSH_TOPIC` | claude-push 토픽 | `~/.config/claude-push/config` |
| `CLAUDE_PUSH_TIMEOUT` | 원격 승인 타임아웃 (초) | `~/.config/claude-push/config` |

> **중요**: Hook에서 사용하는 환경변수는 반드시 `~/.zshenv`에 설정해야 한다. `~/.zshrc`에만 있으면 non-interactive 프로세스인 hook에서 인식하지 못한다.

---

## 9. --dangerously-skip-permissions 안전 가이드

### 이 플래그가 하는 것

- 모든 권한 프롬프트 자동 승인 (파일 수정, bash 명령어, 네트워크 등)
- 서브에이전트도 동일한 권한 상속
- 명령어 차단 목록(blocklist) 우회
- 쓰기 접근 제한 해제

`--permission-mode bypassPermissions`와 동일한 동작.

### 실제 사고 사례

| 사고 | 내용 |
|------|------|
| rm -rf / (2025.10) | 펌웨어 프로젝트에서 루트부터 삭제 시도 |
| ~ 디렉토리 삭제 (2025.12) | `rm -rf tests/ patches/ ~/` — 홈 디렉토리 전체 삭제 |
| 틸드 디렉토리 트릭 (2025.11) | `~`라는 이름의 디렉토리를 만든 뒤 `rm -rf *` 시 홈 디렉토리로 확장 |

### 안전하게 사용하는 방법

**필수 조건:**

```bash
# 1. 반드시 Git 저장소에서 사용 (롤백 가능하도록)
git add -A && git commit -m "checkpoint: pre-YOLO"

# 2. Docker 컨테이너에서 실행 (Anthropic 공식 권장)
docker run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  --network none \
  claude-code:latest --dangerously-skip-permissions "task"

# 3. 또는 disallowedTools로 위험 명령 차단
claude --dangerously-skip-permissions \
  --disallowedTools "Bash(rm:*)" "Bash(sudo:*)" "query"
```

**사용해도 괜찮은 경우:**

- CI/CD 파이프라인 (에페메럴 컨테이너)
- 격리된 Docker 환경
- Git 저장소 + 최근 커밋이 있는 상태
- 잘 정의된 단일 작업 (린트 수정, 테스트 작성 등)

**절대 사용하면 안 되는 경우:**

- 프로덕션 자격증명이 있는 환경
- 민감한 데이터가 있는 디렉토리
- 장기 자율 세션 (컨텍스트 오염 위험)
- 신뢰할 수 없는 코드베이스

### 더 나은 대안: Granular Permissions

```jsonc
// settings.json — YOLO 대신 세밀한 권한 설정
{
  "permissions": {
    "allow": [
      "Read", "Glob", "Grep",
      "Bash(npm run *)",
      "Bash(git *)",
      "Bash(npx *)",
      "Write(src/**)",
      "Edit(src/**)"
    ],
    "deny": [
      "Bash(rm -rf*)",
      "Bash(sudo*)",
      "Bash(git push --force*)"
    ]
  }
}
```

이 방식이 YOLO보다 안전하면서도 대부분의 작업에서 권한 프롬프트를 줄여준다.

---

## 10. 유용한 Shell 함수

`~/.zshrc`에 추가:

### 안전한 YOLO (Git 체크포인트 + 실행)

```bash
# YOLO 실행 전 자동으로 Git 체크포인트 생성
ccyolo() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "⚠️  Git 저장소가 아닙니다. YOLO 모드는 Git 저장소에서만 사용하세요."
    return 1
  fi

  # 변경사항이 있으면 자동 체크포인트
  if ! git diff --quiet HEAD 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    git add -A && git commit -m "checkpoint: pre-YOLO $(date '+%H:%M:%S')"
    echo "✅ Git 체크포인트 생성됨"
  fi

  claude --dangerously-skip-permissions "$@"
}
```

### 파이프 처리 함수

```bash
# 파일 내용을 Claude에게 전달
ccfile() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: ccfile <file> <prompt>"
    return 1
  fi
  cat "$1" | claude -p "$2"
}

# Git diff를 Claude에게 코드 리뷰 요청
ccreview() {
  local target="${1:-HEAD}"
  git diff "$target" | claude -p "이 diff를 코드 리뷰해줘. 버그, 성능 이슈, 개선점을 알려줘."
}

# 에러 로그를 Claude에게 분석 요청
ccerror() {
  if [ -z "$1" ]; then
    echo "Usage: ccerror <logfile>"
    return 1
  fi
  tail -100 "$1" | claude -p "이 에러 로그를 분석하고 원인과 해결 방법을 알려줘."
}
```

### claudify (명령어 실패 시 자동 수정)

```bash
# 마지막 실패한 명령어를 Claude에게 수정 요청
claudify() {
  local last_cmd=$(fc -ln -1)
  local last_output=$(eval "$last_cmd" 2>&1)
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    echo "❌ 명령어 실패 (exit $exit_code). Claude에게 수정 요청 중..."
    echo "Command: $last_cmd\nOutput: $last_output" | \
      claude -p "이 명령어가 실패했어. 원인을 분석하고 수정된 명령어를 알려줘."
  else
    echo "✅ 명령어가 성공했습니다."
  fi
}
```

---

## 참고 자료

- [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference) — 공식 CLI 문서
- [Claude Code Settings](https://code.claude.com/docs/en/settings) — 공식 설정 문서
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) — 공식 Hook 문서
- [Claude Code Model Configuration](https://code.claude.com/docs/en/model-config) — 모델 설정 문서

---

*Last updated: 2026-03-01*
