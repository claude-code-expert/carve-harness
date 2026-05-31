# Squad Agent

**[English](README.en.md)** | **[한국어](README.md)**

**Claude Code 서브에이전트 시스템 — 리뷰, 기획, 리팩토링, QA, 디버깅, 문서, GitOps, 보안 감사를 전문 에이전트에 위임합니다.**

![Squad Pipeline](docs/pipeline-diagram.svg)

---

## 빠른 시작

### 방법 1: 원라인 설치 (curl) — 권장

```bash
curl -sL https://raw.githubusercontent.com/claude-code-expert/subagents/main/install.sh | bash
```

### 방법 2: 클론 후 설치

```bash
git clone https://github.com/claude-code-expert/subagents.git
cd subagents
bash install.sh
```

### 방법 3: 릴리스 다운로드

[Releases](https://github.com/claude-code-expert/subagents/releases) 페이지에서 최신 `squad-agents-vX.Y.Z.tar.gz`를 다운로드하세요.

```bash
tar xzf squad-agents-v*.tar.gz
bash install.sh
```

### 설치 후

1. **Claude Code를 재시작합니다**
2. `/agents`로 등록을 확인합니다
3. `/squad-review`로 시작해보세요

설치 스크립트가 3개 훅(SubagentStart, SubagentStop, UserPromptSubmit)을 `~/.claude/settings.json`에 자동 등록합니다.

---

## 서브에이전트 동작 원리

### 서브에이전트란?

서브에이전트는 메인 Claude Code 세션 안에서 **독립된 컨텍스트 윈도우**를 갖고 동작하는 전문화된 AI 인스턴스입니다. 일반 대화에서 "코드 리뷰해줘"라고 하면 모든 분석 과정이 하나의 컨텍스트에 쌓이지만, 서브에이전트에 위임하면 분석은 별도 윈도우에서 일어나고 메인에는 요약만 돌아옵니다.

### 내부 동작

서브에이전트는 Claude Code의 **Agent 도구**를 통해 호출됩니다. `bash`로 `claude -p`를 실행하는 것이 아닙니다.

```
1. 사용자: "/squad-review src/auth/"

2. 메인 세션 → Agent(subagent_type="squad-review", prompt="...")
   Agent 도구로 위임

3. 새 컨텍스트 윈도우 생성:
   - squad-review.md의 시스템 프롬프트 로드
   - frontmatter에 명시된 도구만 사용 가능
   - frontmatter에 명시된 모델 사용

4. 서브에이전트가 자체 컨텍스트에서 작업:
   - git diff, 파일 읽기, 분석 — 모두 서브에이전트 컨텍스트에만 남음
   - 메인 세션 컨텍스트는 증가하지 않음

5. 결과 반환:
   - 최종 메시지만 메인 세션에 반환
   - 서브에이전트 컨텍스트는 폐기
```

### 버전

**v1.3.2** (현재) — [전체 변경 이력](CHANGELOG.md)

| 버전 | 주요 변경 |
|------|----------|
| v1.3.2 | 자동 테스트 145건, pre-commit hook, 라우터 위임 강제, `run-all.sh` |
| v1.3.1 | README 구조 개편 (KO/EN 분리), CI shellcheck 수정, 훅 메커니즘 문서화 |
| v1.3.0 | Squad Router 훅 추가 (80 키워드, 3단계 매칭, context injection) |
| v1.2.1 | 크로스 플랫폼 알림 (macOS/Linux/WSL), 서브에이전트 검증 완료 |
| v1.1.3 | SubagentStart/Stop 배너, SHA256 체크섬, 자동 훅 등록 |
| v1.1.0 | 에이전트 안전 규칙 추가, 파이프라인 컨텍스트, 도구 순서 표준화 |
| v1.0.0 | 8개 에이전트, 9개 커맨드, SubagentStop 훅, 설치 스크립트 |

<!--
### 솔직한 토큰 비용 구조

> **"서브에이전트가 토큰을 절약한다"는 흔한 오해입니다. 실제로는 더 씁니다.**

서브에이전트의 가치는 토큰 절약이 아니라 **메인 컨텍스트 품질 유지**입니다.

#### 예시: 20개 파일 변경 리뷰

**인라인 (서브에이전트 없음):**

```
메인 컨텍스트: 24k (대화) + 30k (git diff) + 16k (파일 읽기) + 15k (분석) = 85k
코딩 가능 용량: 115k / 200k
총 토큰 소비: ~85k
```

**squad-review 서브에이전트 사용:**

```
메인 컨텍스트:       24k (대화) + 2k (반환된 요약) = 26k
서브에이전트 컨텍스트: 4k (시스템) + 30k (diff) + 16k (읽기) + 15k (분석) + 4k (오버헤드) = 69k (폐기됨)
코딩 가능 용량: 174k / 200k
총 토큰 소비: ~95k (인라인보다 더 많음)
```

| 지표 | 인라인 | 서브에이전트 |
|------|--------|------------|
| 메인 컨텍스트 사용 | 85k | 26k |
| 총 토큰 소비 | 85k | **95k (+12%)** |
| 작업 가능 공간 | 115k | **174k (+51%)** |
| 세션 후반 품질 | 저하 (context rot) | **유지** |

#### 병렬 실행 비용

Anthropic 문서에 따르면 멀티 에이전트 워크플로우는 단일 에이전트 대비 **4~7배의 토큰**을 소비합니다. 실측 보고에 따르면 Pro plan에서 5개 병렬 서브에이전트를 실행하면 15분 만에 사용량 한도에 도달합니다 (순차 처리 시 30분).

#### 가치 있는 경우

| 가치 있음 | 비효율적 |
|----------|---------|
| 대량 출력 (큰 diff, 로그) | 단일 파일 조회 |
| 긴 세션 (context rot 방지) | 짧은 세션 |
| 읽기 중심 탐색·분석 | 코드베이스 전체 추론 |
| 병렬 독립 분석 | 순차 의존 작업 |
| 도구 제한 강제 (Read-only) | 모든 도구 필요 작업 |

> **결론:** 서브에이전트는 **컨텍스트 위생 도구**입니다. 총 토큰은 더 쓰지만, 메인 세션이 깨끗하게 유지되어 세션 후반부 품질 저하를 방지합니다.
-->

### 쓰는 이유

1. **컨텍스트 격리 및 메인 컨텍스트 오염 방지** — 30k git diff가 서브에이전트에만 남고, 메인에는 요약 2k만 반환, 메인 컨텍스트가 늘어나면 토큰 소모도 비례하여 올라가므로 이를 서브에이전트로 분리하여 관리 
2. **도구 제한** — squad-review는 Read-only. 도구 레벨 하드 제약 (프롬프트가 아님)
3. **병렬 실행** — 여러 모듈을 동시에 분석
4. **모델 라우팅** — 보안은 opus, 커밋 메시지는 haiku로 비용 최적화

> **왜 장기적으로 토큰을 절약하는가?**
>
> 1. 단일 연산 기준으론 서브에이전트가 더 비쌈 (85k vs 95k)
> 2. 하지만 메인 컨텍스트에 85k가 쌓이면, 이후 **매 턴마다** 그 85k가 input token으로 재전송됨
> 3. 서브에이전트로 분리하면 메인은 26k만 유지 → 이후 매 턴의 input 비용이 59k씩 절감
> 4. 10턴만 지나도 `59k × 10 = 590k` 토큰 차이 — 초기 10k 오버헤드를 훨씬 상회
>
> 세션이 길어질수록 서브에이전트의 가치는 기하급수적으로 증가합니다.

### 에이전트 정의 형식

```markdown
---
name: squad-review                    # 에이전트 ID
description: >                        # 자동 위임 트리거
  Use PROACTIVELY after code changes.
tools: Read, Grep, Glob, Bash         # 허용 도구 (하드 제약)
model: opus                           # 모델
maxTurns: 15                          # 안전 제한
---
당신은 시니어 스태프 엔지니어...       # 시스템 프롬프트
```

---

## 에이전트

| 에이전트 | 역할 | 모델 | 도구 |
|---------|------|------|------|
| `squad-review` | 코드 리뷰 | opus | Read, Bash, Glob, Grep |
| `squad-plan` | 기획 & 와이어프레임 | opus | Read, Write, Edit, Bash, Glob, Grep |
| `squad-refactor` | 리팩토링 | opus | Read, Write, Edit, Bash, Glob, Grep |
| `squad-qa` | 테스트 & QA | sonnet | Read, Bash, Glob, Grep |
| `squad-debug` | 디버깅 | opus | Read, Bash, Glob, Grep |
| `squad-docs` | 문서 작성 | sonnet | Read, Write, Edit, Glob, Grep |
| `squad-gitops` | Git 자동화 | haiku | Read, Bash, Glob, Grep |
| `squad-audit` | 보안 감사 | opus | Read, Bash, Glob, Grep |

---

## 파이프라인

코어 파이프라인은 에이전트를 자동으로 체이닝합니다:

```
squad-plan → [구현] → squad-review → squad-qa → squad-gitops
                           │    ▲
                           │    │
                           ▼    │
                      squad-refactor
                       (변경 요청 시)
```

언제든 호출 가능한 **온디맨드 에이전트**:

- `squad-debug` — 근본 원인 분석
- `squad-audit` — 보안 스캐닝
- `squad-docs` — 문서 생성

---

## 훅 시스템

3개의 훅이 자동화 레이어를 구동합니다. `install.sh`가 모두 자동 등록합니다.

### 1. Squad Router (UserPromptSubmit)

![Squad Router Flow](docs/wireframes/squad-router-flow.svg)

자연어 자동 라우팅 — 슬래시 커맨드 없이도 키워드를 감지하여 적절한 서브에이전트로 위임합니다.

#### 동작 원리

Claude Code의 `UserPromptSubmit` 훅은 사용자가 프롬프트를 제출할 때마다 실행됩니다. Squad Router는 이 메커니즘을 활용합니다:

```
┌──────────────────────────────────────────────────────────────────┐
│ 1. 사용자가 프롬프트 입력                                              │
│    "이 코드 보안 검사해줘"                                            │
│                                                                  │
│ 2. Claude Code가 훅 실행 (프롬프트가 Claude에 전달되기 전)                │
│    stdin → {"prompt": "이 코드 보안 검사해줘"}                        │
│                                                                  │ 
│ 3. squad-router.sh가 키워드 매칭                                    │
│    "보안" 감지 → AGENT="squad-audit"                               │
│                                                                  │ 
│ 4. stdout으로 JSON 출력 (context injection)                        │
│    {"hookSpecificOutput": {                                      │
│      "hookEventName": "UserPromptSubmit",                        │
│      "additionalContext": "[Squad Router] Use the squad-audit..."│
│    }}                                                            │
│                                                                  │
│ 5. Claude가 주입된 컨텍스트를 보고 서브에이전트에 위임                      │
│    → Agent(subagent_type="squad-audit", prompt="...")            │
└──────────────────────────────────────────────────────────────────┘
```

핵심은 `hookSpecificOutput.additionalContext`입니다. 이 필드로 출력한 텍스트는 Claude가 프롬프트를 처리할 때 system-reminder로 주입되어, Claude가 자연스럽게 해당 서브에이전트를 호출하도록 유도합니다. 프롬프트 자체는 변경되지 않습니다.

```
"이 코드 리뷰해줘"    → squad-review
"에러가 나요"          → squad-debug
"보안 검사해줘"        → squad-audit
"테스트 돌려줘"        → squad-qa
"기획해줘"             → squad-plan
"리팩토링 해줘"        → squad-refactor
"문서 작성해줘"        → squad-docs
"커밋 메시지 작성해"   → squad-gitops
```

**80개 키워드** (한국어 42 / 영어 38)가 8개 에이전트에 매핑됩니다. 3단계 매칭:

1. **스킵** — 슬래시 커맨드, `--no-route`, `SQUAD_ROUTER=off`
2. **충돌 해결** — 다단어 패턴 (예: "PR 리뷰" → review, "PR 작성" → gitops)
3. **일반 키워드** — 우선순위 기반 단일 단어 매칭

**비활성화:**

| 방법 | 범위 | 예시 |
|------|------|------|
| `--no-route` 프롬프트에 추가 | 건별 | "리뷰해줘 --no-route" |
| `SQUAD_ROUTER=off` | 전역 (환경변수) | 전체 비활성화 |
| `/squad-*` 슬래시 커맨드 | 자동 | 자동 스킵 |

전체 키워드 목록은 [docs/SQUAD-ROUTER-KEYWORDS.md](docs/SQUAD-ROUTER-KEYWORDS.md)를 참고하세요.

### 2. 파이프라인 체이닝 (SubagentStart / SubagentStop)

`subagent-chain.sh` 훅이 시작/종료 이벤트를 모두 처리합니다:

- **SubagentStart** — OS 알림: "Squad: {agent} RUNNING"
- **SubagentStop** — OS 알림: "Squad: {agent} COMPLETED" + 다음 단계 안내

에이전트별 다음 단계 안내:

| 에이전트 | 완료 시 |
|---------|---------|
| squad-plan | → implement, then /squad-review |
| squad-review | → /squad-refactor or /squad-qa |
| squad-refactor | → /squad-review to verify |
| squad-qa | → /squad-gitops commit |
| squad-debug | → implement the fix |
| squad-docs | Documentation updated. |
| squad-gitops | Git artifacts generated. |
| squad-audit | Address findings before deploy. |

### 3. 알림 시스템 (크로스 플랫폼)

서브에이전트 시작/종료 시 OS 네이티브 알림이 발생합니다:

| 플랫폼 | 방식 | 사운드 |
|--------|------|--------|
| macOS | `osascript` (알림 센터) | `afplay` (Pop/Glass) |
| Linux | `notify-send` | `paplay` / `aplay` |
| Windows/WSL | PowerShell 팝업 | — |

**알림 비활성화:**

```bash
# ~/.claude/settings.json에서 SubagentStart/SubagentStop 훅 제거
# 또는 ~/.claude/hooks/subagent-chain.sh의 notify() 호출 주석 처리
```

### 훅 등록 (settings.json)

```jsonc
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/squad-router.sh" }]
      }
    ],
    "SubagentStart": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "zsh ~/.claude/hooks/subagent-chain.sh" }]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "zsh ~/.claude/hooks/subagent-chain.sh" }]
      }
    ]
  }
}
```

---

## 커맨드

| 커맨드 | 예시 |
|--------|------|
| `/squad-review` | `/squad-review src/auth/` |
| `/squad-plan` | `/squad-plan payment system` |
| `/squad-refactor` | `/squad-refactor src/utils/` |
| `/squad-qa` | `/squad-qa` |
| `/squad-debug` | `/squad-debug TypeError: Cannot read...` |
| `/squad-docs` | `/squad-docs readme` |
| `/squad-gitops` | `/squad-gitops pr` |
| `/squad-audit` | `/squad-audit` |
| `/squad` | `/squad review src/auth/` (통합 커맨드) |

---

## 사용 예시

> 📖 **명령어별 상세 사용법과 실전 시나리오**는 [docs/SQUAD-COMMANDS-GUIDE.md](docs/SQUAD-COMMANDS-GUIDE.md)를 참고하세요.

### 새 기능 개발

```
/squad-plan user profile editing       → 기획
[구현]                                  → 코드 작성
/squad-review                          → REQUEST_CHANGES
/squad-refactor src/profile/           → 리팩토링
/squad-review                          → APPROVE
/squad-qa                              → PASS
/squad-audit src/auth/                 → 보안 점검
/squad-gitops pr                       → PR 생성
```

### 프로덕션 버그

```
/squad-debug "TypeError: Cannot read properties of undefined"
[수정]
/squad-qa → /squad-gitops commit
```

### 레거시 정리

```
/squad-review src/legacy/              → 문제 식별
/squad-refactor src/legacy/utils/      → 리팩토링
/squad-qa                              → 회귀 테스트
/squad-docs readme                     → 문서 업데이트
```

---

## 모델 라우팅

| 에이전트 | 모델 | 이유 |
|---------|------|------|
| squad-review | opus | 보안·로직은 깊은 추론 필요 |
| squad-plan | opus | 설계와 엣지케이스 |
| squad-refactor | opus | 안전한 구조 변환 |
| squad-qa | sonnet | 테스트 실행·결과 정리 |
| squad-debug | opus | 근본 원인 분석 |
| squad-docs | sonnet | 코드→문서화 |
| squad-gitops | haiku | 패턴 작업, 비용 최적화 |
| squad-audit | opus | 보안은 놓치면 안 됨 |

전역 오버라이드: `export CLAUDE_CODE_SUBAGENT_MODEL=sonnet`

---

## 프로젝트별 오버라이드

프로젝트에 `.claude/agents/squad-review.md`를 두면 전역 버전보다 우선합니다:

```markdown
---
name: squad-review
description: >
  Expert code review for MyProject.
tools: Read, Grep, Glob, Bash
model: opus
---

## MyProject Rules
- TypeScript `any` PROHIBITED
- All API responses must use Result type
...
```

---

## 제거

```bash
bash install.sh --uninstall
```

Squad Agent 파일만 `~/.claude/`에서 제거합니다. 백업 파일(`.bak`)은 유지됩니다.

> 참고: `~/.claude/settings.json`의 훅 항목은 수동 제거가 필요합니다.

---

## 아키텍처

상세 아키텍처 문서는 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)를 참고하세요.

---

## 기여

새 에이전트 추가나 개선 방법은 [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요.

---

## 라이선스

[Apache License 2.0](LICENSE)

---

## 참고 자료

- [Claude Code Sub-agents (공식)](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
- [Claude Agent SDK](https://docs.anthropic.com/en/docs/agents/agent-sdk)
- [shanraisshan/claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice)
- [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
