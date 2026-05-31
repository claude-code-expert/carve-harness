# Everything Claude Code (ECC) 완벽 가이드

> GitHub: https://github.com/affaan-m/everything-claude-code
> Stars: 143k+ | License: MIT | 최신 버전: v1.10.0 (2026-04)
> Homepage: https://ecc.tools
> 저자: Affaan Mustafa (Anthropic × Forum Ventures Hackathon 우승자)

---

## 1. ECC란 무엇인가

Claude Code(및 기타 AI 코딩 도구)를 위한 **에이전트 하니스 성능 최적화 시스템**.

단순 config 모음이 아니라 **skills, instincts, memory 최적화, 지속 학습, 보안 스캔, 리서치 우선 개발**을 묶은 종합 시스템. 저자가 10개월 이상 매일 실제 제품을 만들면서 다듬어 온 결과물.

### 해결하는 문제

1. **컨텍스트 윈도우 낭비** — MCP/플러그인을 무분별하게 켜두면 200k 컨텍스트가 70k로 줄어든다
2. **반복 실수** — Claude가 같은 실수를 반복하고, 같은 프롬프트를 다시 입력해야 한다
3. **세션 간 메모리 단절** — 어제 알아낸 내용을 오늘 다시 발견해야 한다
4. **토큰/비용 폭주** — 모든 작업에 Opus를 쓰면 비용이 비현실적
5. **검증 부재** — "구현은 했는데 잘 되는지 모르겠다"

### 핵심 철학

- **Skills가 1차 워크플로우 표면** (commands는 legacy slash 호환 레이어)
- **컨텍스트는 귀중한 자원** — MCP 30개 설정해도 활성화는 10개 미만
- **모델은 작업에 맞춰 라우팅** — Haiku/Sonnet/Opus를 의식적으로 선택
- **반복되는 패턴은 skill로 승격** — 한 번 해결한 문제는 다시 해결하지 않는다
- **Configuration은 fine-tuning이지 architecture가 아니다** — 과설계 금지

### 호환 하니스

Claude Code, Codex (CLI + App), Cursor, OpenCode, Gemini CLI, Antigravity, Trae, Kiro, CodeBuddy

### 규모 (v1.10.0 기준)

- **38~47 agents** (manifest 기준 38, 카탈로그 기준 47)
- **156~181 skills**
- **59~79 legacy command shims**
- **12개 언어 생태계** (TypeScript, Python, Go, Java, Kotlin, Rust, C++, Swift, PHP, Perl, 공통 등)
- **997+ 내부 테스트**

---

## 2. 설치

### 방법 1: Plugin 설치 (편한 길)

```bash
# Claude Code 안에서
/plugin marketplace add https://github.com/affaan-m/everything-claude-code
/plugin install ecc@ecc
```

> 단, plugin 시스템은 `rules/`를 자동 배포하지 못한다. Step 2는 수동.

### 방법 2: 소스 설치 (가장 안정적)

```bash
git clone https://github.com/affaan-m/everything-claude-code.git
cd everything-claude-code
npm install   # pnpm/yarn/bun 가능

# 전체 설치 (권장)
./install.sh --profile full

# 특정 언어만
./install.sh typescript
./install.sh typescript python golang swift php

# 다른 하니스 타겟
./install.sh --target cursor typescript
./install.sh --target antigravity typescript
./install.sh --target gemini --profile full
```

Windows:

```powershell
.\install.ps1 --profile full
.\install.ps1 typescript
```

크로스플랫폼 npm 진입점:

```bash
npx ecc-install typescript
```

### Selective Install (v1.9.0+)

manifest 기반 설치 파이프라인. `install-plan.js` + `install-apply.js`로 컴포넌트 단위 설치 가능. SQLite state store가 무엇이 설치됐는지 추적해서 incremental 업데이트 지원.

### Multi-model 커맨드 (별도)

`/multi-plan`, `/multi-execute` 등 multi-* 커맨드는 base install에 포함되지 않는다. 별도 runtime 필요:

```bash
npx ccg-workflow
```

이 runtime이 `~/.claude/bin/codeagent-wrapper`와 `~/.claude/.ccg/prompts/*`를 제공한다.

### Package Manager 자동 감지 우선순위

1. 환경 변수 `CLAUDE_PACKAGE_MANAGER`
2. 프로젝트 `.claude/package-manager.json`
3. `package.json`의 `packageManager` 필드
4. lock 파일 (package-lock.json, yarn.lock, pnpm-lock.yaml, bun.lockb)
5. 글로벌 `~/.claude/package-manager.json`
6. 사용 가능한 첫 번째

```bash
export CLAUDE_PACKAGE_MANAGER=pnpm
node scripts/setup-package-manager.js --global pnpm
# 또는 Claude Code 안에서
/setup-pm
```

### Hook Runtime 제어 (v1.8+)

```bash
# 엄격도 프로파일
export ECC_HOOK_PROFILE=minimal   # 또는 standard | strict

# 특정 hook만 비활성화
export ECC_DISABLED_HOOKS="pre:bash:tmux-reminder,post:edit:typecheck"
```

---

## 3. 7대 빌딩 블록

ECC는 7개 구성 요소가 상호작용하는 시스템이다. 각자 역할이 다르다.

| 블록 | 위치 | 역할 |
|------|------|------|
| **Skills** | `~/.claude/skills/` | 1차 워크플로우 표면. 재사용 가능한 패턴 묶음. |
| **Commands** | `~/.claude/commands/` | Legacy slash 진입점 (마이그레이션 중) |
| **Agents** | `~/.claude/agents/` | Subagent — 위임 가능한 전문 프로세스 |
| **Hooks** | `~/.claude/hooks/` | 이벤트 트리거 자동화 |
| **Rules** | `~/.claude/rules/` | Claude가 항상 따라야 할 원칙 |
| **MCPs** | `~/.claude/settings.json` | 외부 서비스 연결 |
| **Plugins** | marketplace | 위 요소들의 패키지 |

### 3.1 Skills (가장 중요)

ECC가 `commands/`에서 `skills/`로 마이그레이션 중인 핵심 표면. Skills는:

- **Codemap 포함 가능** — Claude가 탐색에 토큰을 쓰지 않고 코드베이스를 빠르게 navigate
- **다중 파일 구조 지원** — `SKILL.md` + supporting files
- **YAML frontmatter 표준** (`name`, `description`, `origin`)
- **"When to Use" 섹션 필수** — 언제 활성화될지 명확히

```
~/.claude/skills/
├── tdd-workflow/                  # TDD 방법론
├── security-review/               # 보안 체크리스트
├── continuous-learning/           # 세션에서 패턴 자동 추출
├── continuous-learning-v2/        # Instinct 기반 학습 (confidence scoring)
├── iterative-retrieval/           # Subagent 점진 정제
├── strategic-compact/             # 수동 compaction 제안
├── eval-harness/                  # 검증 루프 평가
├── verification-loop/             # 지속 검증
├── search-first/                  # 코딩 전 리서치
├── skill-stocktake/               # 자기 점검
├── springboot-patterns/           # Spring Boot 패턴
├── springboot-tdd/                # Spring Boot TDD
├── django-patterns/, laravel-patterns/, ...
├── frontend-slides/               # HTML 프레젠테이션 빌더
├── article-writing/               # 사용자 voice로 장문 작성
├── content-engine/, market-research/, investor-materials/
├── cost-aware-llm-pipeline/       # LLM 비용 최적화 + 모델 라우팅
├── content-hash-cache-pattern/    # SHA-256 캐싱
├── regex-vs-llm-structured-text/  # 의사결정 프레임워크
└── configure-ecc/                 # 대화형 설치 위저드
```

### 3.2 Agents (Subagents)

오케스트레이터(메인 Claude)가 위임할 수 있는 제한된 범위의 프로세스. 백그라운드/포그라운드 모두 가능.

```
~/.claude/agents/
├── planner.md                  # 기능 구현 계획
├── architect.md                # 시스템 설계 결정
├── tdd-guide.md                # TDD
├── code-reviewer.md            # 품질/보안 리뷰
├── security-reviewer.md        # 취약점 분석
├── build-error-resolver.md
├── e2e-runner.md               # Playwright E2E
├── refactor-cleaner.md         # 데드 코드 정리
├── doc-updater.md              # 문서 동기화
├── docs-lookup.md              # 문서/API 조회
├── chief-of-staff.md           # 커뮤니케이션 분류
├── loop-operator.md            # 자율 루프 실행
├── harness-optimizer.md        # 하니스 config 튜닝
├── typescript-reviewer.md
├── python-reviewer.md
├── go-reviewer.md, go-build-resolver.md
├── java-reviewer.md, java-build-resolver.md
├── kotlin-reviewer.md, kotlin-build-resolver.md
├── rust-reviewer.md, rust-build-resolver.md
├── cpp-reviewer.md, cpp-build-resolver.md
├── database-reviewer.md
└── pytorch-build-resolver.md
```

각 agent는 YAML frontmatter로 정의:

```yaml
---
name: code-reviewer
description: Review code for quality, security, and maintainability
tools: [Read, Grep, Glob, Bash]
model: sonnet
---
```

### 3.3 Hooks

이벤트 기반 자동화. Skill과 달리 도구 호출/생명주기에 묶인다.

| Hook | 발화 시점 | 용도 예시 |
|------|----------|----------|
| `PreToolUse` | 도구 실행 전 | 검증, 알림 |
| `PostToolUse` | 도구 실행 후 | 포매팅, 피드백 루프 |
| `UserPromptSubmit` | 사용자 메시지 전송 시 | (지연 주의 — 매번 실행) |
| `Stop` | Claude 응답 종료 시 | 세션 학습 저장 |
| `PreCompact` | 컨텍스트 압축 직전 | 중요 상태 파일로 저장 |
| `SessionStart` | 새 세션 시작 시 | 이전 컨텍스트 복원 |
| `Notification` | 권한 요청 시 | 알림 |

설정 예시 (`~/.claude/settings.json`):

```json
{
  "PreToolUse": [
    {
      "matcher": "tool == \"Bash\" && tool_input.command matches \"(npm|pnpm|yarn|cargo|pytest)\"",
      "hooks": [
        {
          "type": "command",
          "command": "if [ -z \"$TMUX\" ]; then echo '[Hook] Consider tmux for session persistence' >&2; fi"
        }
      ]
    }
  ],
  "PostToolUse": [
    { "matcher": "Edit && .ts/.tsx", "hooks": ["prettier --write", "tsc --noEmit"] }
  ],
  "Stop": [
    { "matcher": "*", "hooks": ["check modified files for console.log"] }
  ]
}
```

**Tip**: `hookify` 플러그인을 쓰면 JSON을 직접 쓰지 않고 대화로 hook을 만들 수 있다. `/hookify` 실행 후 원하는 동작을 설명.

### 3.4 Rules

Claude가 **항상** 따라야 할 원칙. 두 가지 접근:

1. **단일 CLAUDE.md** — 사용자 또는 프로젝트 레벨
2. **Rules 폴더** — 관심사별 분리 (권장)

```
~/.claude/rules/
├── common/             # 모든 언어 공통
├── typescript/
├── python/
├── golang/
├── java/
├── kotlin/             # Android, KMP 포함
├── rust/
├── cpp/
├── php/
├── perl/
├── security.md
├── coding-style.md
├── testing.md
├── git-workflow.md
├── agents.md           # Subagent 위임 규칙
└── performance.md      # 모델 선택 가이드
```

언어별로 필요한 것만 install 가능 (v1.4+ multi-language rules architecture).

### 3.5 MCPs — 컨텍스트 폭주의 주범

MCP는 외부 서비스를 prompt로 감싼 wrapper. 편하지만 **컨텍스트를 잡아먹는다**.

**규칙**: MCP 20~30개 설정, 활성화는 10개 미만, 도구 80개 미만.

```bash
/mcp                # 활성화된 MCP 확인
/plugins            # MCP/플러그인 토글
```

**저자의 추천 패턴**: 대부분의 MCP는 CLI를 wrap한 것이므로, 자주 쓰는 동작만 skill/command로 만들고 MCP는 끈다.

> 예: GitHub MCP를 항상 켜두는 대신 `/gh-pr` 커맨드로 `gh pr create`를 wrap하면 컨텍스트는 0, 기능은 동일.

### 3.6 Plugins

Skill + MCP + hooks를 묶어서 배포하는 패키지.

```bash
claude plugin marketplace add https://github.com/mixedbread-ai/mgrep
# /plugins → 마켓플레이스에서 install
```

추천 LSP 플러그인:

```
typescript-lsp@claude-plugins-official
pyright-lsp@claude-plugins-official
hookify@claude-plugins-official
mgrep@Mixedbread-Grep
```

---

## 4. 핵심 워크플로우 패턴

### 4.1 기본 코딩 사이클

```
/plan "기능 설명"          ← 요구사항 재진술 + 위험 평가 + 단계별 계획
    ↓ (사용자 승인)
/tdd                       ← 인터페이스 → 실패 테스트 → 구현 → 80%+ 커버리지
    ↓
/code-review               ← 품질/보안 리뷰
    ↓
/build-fix                 ← (필요시) 빌드 에러 자동 수정
    ↓
/verify                    ← build → lint → test → type-check 풀 루프
    ↓
/quality-gate              ← 프로젝트 표준 게이트 통과 확인
```

### 4.2 Sequential Phases (긴 작업)

```markdown
Phase 1: RESEARCH (Explore agent) → research-summary.md
Phase 2: PLAN (planner agent)     → plan.md
Phase 3: IMPLEMENT (tdd-guide)    → 코드 변경
Phase 4: REVIEW (code-reviewer)   → review-comments.md
Phase 5: VERIFY (build-error-resolver) → 완료 또는 Phase 3 회귀
```

규칙:
1. 각 agent는 **하나의 명확한 입력 → 하나의 명확한 출력**
2. 출력은 다음 phase의 입력
3. Phase 건너뛰지 않기
4. Agent 사이에 `/clear` 사용
5. 중간 출력은 파일로 저장

### 4.3 Iterative Retrieval Pattern (Subagent 컨텍스트 문제)

Subagent는 컨텍스트를 아끼려고 요약만 반환한다. 그러나 오케스트레이터는 subagent가 모르는 **목적**을 안다.

```
1. 오케스트레이터가 subagent 응답을 매번 평가
2. 부족하면 follow-up 질문
3. Subagent는 source로 돌아가 다시 답
4. 충분할 때까지 반복 (최대 3 사이클)
```

**핵심**: query뿐 아니라 **objective context**를 같이 전달.

### 4.4 Two-Instance Kickoff (빈 레포)

빈 레포에서 새 프로젝트 시작 시:

| 인스턴스 | 역할 |
|---------|------|
| **Instance 1: Scaffolding** | 프로젝트 구조, CLAUDE.md, rules, agents 세팅 |
| **Instance 2: Deep Research** | 외부 서비스 연결, PRD, mermaid 다이어그램, 문서 인용 컴파일 |

### 4.5 Cascade Method (병렬 작업)

여러 Claude 인스턴스를 동시에 돌릴 때:

- 새 작업은 오른쪽 새 탭에서
- 왼쪽→오른쪽, 오래된 것→새 것 순서로 sweep
- 한 번에 **3~4개 작업까지만**
- 코드 충돌 방지를 위해 git worktree 필수

```bash
git worktree add ../project-feature-a feature-a
git worktree add ../project-feature-b feature-b
cd ../project-feature-a && claude
```

> **저자의 경고**: "터미널 5개 동시" 같은 임의 숫자를 따라가지 마라. 진짜 필요할 때만 인스턴스를 늘려라. 목표는 **최소 병렬화로 최대 산출**.

### 4.6 Strategic Context Clearing

Plan 모드에서 계획이 확정되면 컨텍스트를 클리어하고 plan만 들고 실행 단계로 진입. 탐색 컨텍스트가 실행을 오염시키지 않도록.

자동 compact는 끄고 **수동 compact** 또는 `/strategic-compact` skill로 논리적 지점에서 압축.

---

## 5. 토큰 최적화

### 5.1 모델 라우팅 표

| 작업 유형 | 모델 | 이유 |
|----------|------|------|
| 탐색/검색 | Haiku | 빠르고 싸고 파일 찾기엔 충분 |
| 단순 편집 | Haiku | 단일 파일, 명확한 지시 |
| 다중 파일 구현 | Sonnet | 코딩 균형점 |
| 복잡한 아키텍처 | Opus | 깊은 추론 필요 |
| PR 리뷰 | Sonnet | 컨텍스트 이해, 뉘앙스 캐치 |
| 보안 분석 | Opus | 취약점 놓치면 안 됨 |
| 문서 작성 | Haiku | 구조가 단순 |
| 복잡한 디버깅 | Opus | 시스템 전체 보유 필요 |

**기본값**: Sonnet (코딩의 90%). Opus로 업그레이드: 첫 시도 실패, 5개+ 파일, 아키텍처 결정, 보안 critical.

`/model-route` 커맨드로 작업을 적절한 모델에 라우팅.

### 5.2 Tool 최적화

- **mgrep > grep/ripgrep** — 50-task 벤치마크에서 토큰 ~50% 절약
- **CLI > MCP** — `gh`, `supabase` CLI를 skill로 wrap하면 컨텍스트 절약
- **모듈화된 코드베이스** — 메인 파일을 천 줄이 아닌 백 줄 단위로

### 5.3 Subagent로 위임

가장 싼 모델로도 충분한 작업은 subagent에 넘기고, 오케스트레이터(Sonnet/Opus)는 종합만 한다.

---

## 6. 검증과 평가 (Verification Loops)

### 6.1 Eval 패턴 종류

| 패턴 | 설명 |
|------|------|
| **Checkpoint-Based** | 명시적 체크포인트 → 기준 검증 → 통과 후 진행 |
| **Continuous** | N분마다 또는 주요 변경 후 → 풀 테스트 + lint |

### 6.2 핵심 메트릭

```
pass@k: k번 시도 중 최소 1번 성공
        k=1: 70%   k=3: 91%   k=5: 97%

pass^k: k번 시도 모두 성공
        k=1: 70%   k=3: 34%   k=5: 17%
```

- **pass@k** → "되기만 하면 됨" 작업
- **pass^k** → 일관성이 필수인 작업 (CI, 프로덕션)

### 6.3 관련 Skills/Commands

- `eval-harness` — 검증 루프 평가
- `verification-loop` — 지속 검증
- `/eval` — 평가 하니스 실행
- `/quality-gate` — 프로젝트 표준 게이트
- `/test-coverage` — 커버리지 갭 식별

---

## 7. 메모리와 지속 학습

### 7.1 세션 간 메모리 — Hook 기반

세 가지 hook으로 자동화:

1. **PreCompact Hook** — 압축 직전 중요 상태를 파일로 저장
2. **Stop Hook** — 세션 종료 시 학습 내용 영속화
3. **SessionStart Hook** — 새 세션 시작 시 이전 컨텍스트 자동 로드

저장 파일에 들어갈 내용:
- 검증된 증거와 함께 **무엇이 작동했는지**
- 시도했지만 **실패한 접근**
- **시도하지 않은 것 + 남은 작업**

### 7.2 Continuous Learning Skill

같은 프롬프트를 두 번 입력해야 했다면 그 패턴은 skill로 승격되어야 한다.

**작동 방식**:
- Claude가 trivial하지 않은 무언가(디버깅 기법, workaround, 프로젝트 패턴)를 발견 → 새 skill로 저장
- 다음 번 유사 문제 발생 시 자동 로드

**왜 Stop Hook인가?**
- `UserPromptSubmit`은 매 메시지마다 실행 → 지연 누적
- `Stop`은 세션 종료 시 1회 → 세션 중 영향 0

### 7.3 Continuous Learning v2 (Instincts)

v1.2.0+ 신규: instinct 기반 학습

- Confidence scoring
- Import/export
- Evolution (학습된 instinct를 더 큰 skill로 진화)

관련 커맨드:
- `/learn` — 현재 세션에서 패턴 추출
- `/learn-eval` — 추출 + 자기 평가 후 저장
- `/evolve` — 학습된 instinct → 진화된 skill 구조 제안
- `/promote` — 프로젝트 instinct → 글로벌
- `/instinct-status` — confidence score 포함 전체 리스트
- `/instinct-export`, `/instinct-import`

### 7.4 동적 시스템 프롬프트 주입 (고급)

CLAUDE.md에 모든 걸 넣지 말고 모드별로:

```bash
alias claude-dev='claude --system-prompt "$(cat ~/.claude/contexts/dev.md)"'
alias claude-review='claude --system-prompt "$(cat ~/.claude/contexts/review.md)"'
alias claude-research='claude --system-prompt "$(cat ~/.claude/contexts/research.md)"'
```

권한 우선순위: **시스템 프롬프트 > 사용자 메시지 > 도구 결과**

---

## 8. 보안 (Security Layer)

ECC v1.6.0+에 AgentShield 보안 시스템이 통합되어 있다.

### AgentShield

- **1282 테스트, 102 룰**
- `/security-scan` 커맨드로 Claude Code에서 직접 실행
- npm: `ecc-agentshield`

### 보안 가이드 (the-security-guide.md)

별도 가이드로 제공:
- 공격 벡터 분류
- 샌드박싱 패턴
- 입력 sanitization
- CVE 대응
- AgentShield 통합

### 기본 보안 룰

`security-review/` skill + `rules/security.md`:
- 하드코딩 시크릿 금지
- API 키/토큰을 출력에 노출 금지
- 절대 경로/시스템 경로 출력 금지
- 입력 검증 유지
- 검증 hook 우회 금지

---

## 9. 커맨드 레퍼런스 (59개)

### 코어 워크플로우

| 커맨드 | 용도 |
|--------|------|
| `/plan` | 요구사항 재진술 + 위험 평가 + 단계별 계획 (사용자 확인 대기) |
| `/tdd` | TDD 강제 — 인터페이스 → 실패 테스트 → 구현 → 80%+ 커버리지 |
| `/code-review` | 변경 파일에 대한 품질/보안/유지보수성 리뷰 |
| `/build-fix` | 빌드 에러 감지 + 적절한 build-resolver agent로 위임 |
| `/verify` | 풀 검증: build → lint → test → type-check |
| `/quality-gate` | 프로젝트 표준 게이트 |

### 테스팅

| 커맨드 | 용도 |
|--------|------|
| `/tdd` | 범용 TDD |
| `/e2e` | Playwright E2E + 스크린샷/비디오/trace |
| `/test-coverage` | 커버리지 + 갭 식별 |
| `/go-test`, `/kotlin-test`, `/rust-test`, `/cpp-test` | 언어별 TDD |

### 코드 리뷰 (언어별)

`/python-review`, `/go-review`, `/kotlin-review`, `/rust-review`, `/cpp-review`

### 빌드 픽서

`/build-fix`, `/go-build`, `/kotlin-build`, `/rust-build`, `/cpp-build`, `/gradle-build`

### 계획 & 아키텍처

| 커맨드 | 용도 |
|--------|------|
| `/plan` | 단일 모델 계획 |
| `/multi-plan` | **다중 모델 협업 계획** (별도 ccg-workflow 필요) |
| `/multi-workflow`, `/multi-backend`, `/multi-frontend`, `/multi-execute` | 다중 모델 |
| `/orchestrate` | tmux/worktree 멀티 에이전트 가이드 |
| `/devfleet` | DevFleet으로 병렬 Claude Code agent 오케스트레이션 |

### 세션 관리

| 커맨드 | 용도 |
|--------|------|
| `/save-session` | `~/.claude/session-data/`에 저장 |
| `/resume-session` | 가장 최근 세션 로드 + 재개 |
| `/sessions` | 세션 히스토리 브라우징 |
| `/checkpoint` | 현재 세션에 체크포인트 |
| `/aside` | 컨텍스트 잃지 않고 빠른 사이드 질문 |
| `/context-budget` | 컨텍스트 사용량 분석 — 토큰 오버헤드 찾기 |

### 학습 & 개선

| 커맨드 | 용도 |
|--------|------|
| `/learn`, `/learn-eval` | 세션에서 패턴 추출 |
| `/evolve` | Instinct → 진화된 skill 구조 |
| `/promote` | 프로젝트 → 글로벌 |
| `/instinct-status`, `/instinct-export`, `/instinct-import` | Instinct 관리 |
| `/skill-create` | git history → 재사용 skill |
| `/skill-health` | Skill 포트폴리오 분석 |
| `/rules-distill` | Skills 스캔 → 횡단 원칙 추출 → rules로 증류 |

### 리팩토링 & 정리

`/refactor-clean`, `/prompt-optimize`

### 문서 & 리서치

`/docs` (Context7 통한 라이브러리 조회), `/update-docs`, `/update-codemaps`

### 루프 & 자동화

| 커맨드 | 용도 |
|--------|------|
| `/loop-start`, `/loop-status` | 주기 agent 루프 |
| `/claw` | **NanoClaw v2** — 모델 라우팅, skill hot-load, 브랜칭, 메트릭 포함 영속 REPL |

### 프로젝트 & 인프라

| 커맨드 | 용도 |
|--------|------|
| `/projects` | 알려진 프로젝트 + instinct 통계 |
| `/harness-audit` | 에이전트 하니스 config 신뢰성/비용 감사 |
| `/eval` | 평가 하니스 실행 |
| `/model-route` | 작업 → Haiku/Sonnet/Opus 라우팅 |
| `/pm2` | PM2 프로세스 매니저 초기화 |
| `/setup-pm` | 패키지 매니저 설정 |

### 빠른 결정 가이드

```
새 기능 시작?           → /plan → /tdd
방금 코드 작성?          → /code-review
빌드 깨짐?              → /build-fix
실시간 문서 필요?        → /docs <library>
세션 종료 임박?          → /save-session 또는 /learn-eval
다음 날 재개?           → /resume-session
컨텍스트 무거움?         → /context-budget → /checkpoint
배운 거 추출?           → /learn-eval → /evolve
반복 작업?              → /loop-start
```

---

## 10. 키보드 & UX 팁

### 키보드 단축키

| 키 | 동작 |
|---|------|
| `Ctrl+U` | 라인 전체 삭제 |
| `!` | 빠른 bash 명령 |
| `@` | 파일 검색 |
| `/` | 슬래시 커맨드 |
| `Shift+Enter` | 멀티라인 입력 |
| `Tab` | thinking 표시 토글 |
| `Esc Esc` | Claude 중단 / 코드 복원 |

### 유용한 빌트인 커맨드

- `/fork` — 비중첩 작업을 병렬로
- `/rewind` — 이전 상태로
- `/statusline` — branch, context %, todos 커스터마이즈
- `/checkpoints` — 파일 단위 undo
- `/compact` — 수동 압축
- `/rename <name>` — 멀티 인스턴스 운영 시 채팅 명명

### 에디터 추천 (저자 의견)

- **Zed** (1순위) — Rust로 작성, Claude의 빠른 편집 속도를 따라잡음, Agent Panel 통합
- **VSCode/Cursor** — Claude Code 확장으로 native UI

---

## 11. 디렉토리 구조

```
everything-claude-code/
├── .claude-plugin/         # plugin.json, marketplace.json
├── agents/                 # 36~47 subagents
├── skills/                 # 156~181 skills
├── commands/               # 59~79 legacy slash shims
├── hooks/                  # 이벤트 자동화 (memory-persistence 포함)
├── rules/                  # 다중 언어 룰 (common/, typescript/, python/, ...)
├── plugins/                # 묶음 플러그인
├── manifests/              # selective install용
├── mcp-configs/            # MCP 샘플
├── schemas/                # JSON 스키마
├── scripts/                # install-plan.js, install-apply.js 등
├── tests/                  # 997+ 내부 테스트
├── ecc2/                   # ECC 2.0 alpha (Rust 컨트롤 플레인)
├── examples/               # 세션 예시 등
├── research/, contexts/    # 리서치/컨텍스트 자료
├── docs/                   # 다국어 README + 가이드
├── README.md
├── CLAUDE.md
├── RULES.md
├── COMMANDS-QUICK-REF.md
├── EVALUATION.md
├── REPO-ASSESSMENT.md
├── SECURITY.md
├── SOUL.md                 # 프로젝트 철학
├── WORKING-CONTEXT.md
├── the-shortform-guide.md  # 시작 가이드 (먼저 읽기)
├── the-longform-guide.md   # 고급 패턴
├── the-security-guide.md   # 보안 심층
├── install.sh / install.ps1
└── VERSION                 # 1.10.0
```

---

## 12. ECC 2.0 Alpha (`ecc2/`)

v1.10.0 (2026-04)에 in-tree로 들어온 **Rust 컨트롤 플레인 프로토타입**.

명령:
- `dashboard` — 시각 대시보드
- `start`, `stop`, `resume` — 세션 제어
- `sessions` — 세션 목록
- `status` — 현재 상태
- `daemon` — 백그라운드 데몬

> **상태**: alpha. 로컬 빌드 가능, 일반 릴리스 아님. 실험용.

---

## 13. 트러블슈팅

| 문제 | 해결 |
|------|------|
| 컨텍스트 70k로 줄어듦 | `/mcp` → 안 쓰는 MCP 끄기, `/plugins`에서 LSP 등 정리 |
| 같은 실수 반복 | `/learn-eval` → 패턴을 instinct로 저장 |
| Hook이 너무 시끄러움 | `ECC_HOOK_PROFILE=minimal` 또는 `ECC_DISABLED_HOOKS` |
| 플러그인이 rules를 안 가져옴 | 정상 — `./install.sh --profile full` 수동 실행 |
| `/multi-*` 동작 안 함 | `npx ccg-workflow` 별도 설치 필요 |
| 컨텍스트 잃음 | SessionStart hook 활성 + `/resume-session` |
| 비용 폭주 | `/model-route` 활성 + 기본을 Sonnet으로 |
| 빌드 자동 수정 실패 | `/build-fix` → 언어별 `/go-build`, `/rust-build` 등 |
| 토큰이 너무 많이 듦 | mgrep 설치, 모듈화, MCP → CLI+skill 마이그레이션 |
| Skill 너무 많아 헷갈림 | `/skill-health`, `/skill-stocktake` |

---

## 14. Run-AI 프로젝트에 적용하는 방법

### 14.1 설치

```bash
cd /Users/jys/project/ai-community
git clone https://github.com/affaan-m/everything-claude-code.git /tmp/ecc
cd /tmp/ecc
npm install

# Java + TypeScript + Python만 설치 (Run-AI 스택에 맞춰)
./install.sh typescript python --profile full
# Java/Spring Boot rules와 skills 별도 추가
./install.sh java
```

또는 plugin으로:

```bash
# Claude Code 안에서
/plugin marketplace add https://github.com/affaan-m/everything-claude-code
/plugin install ecc@ecc
```

### 14.2 우리 프로젝트와 매핑되는 ECC 컴포넌트

| Run-AI 작업 | ECC 자산 |
|------------|---------|
| Spring Boot 컨트롤러 작성 | `springboot-patterns` skill + `java-reviewer` agent |
| Spring Boot 보안 | `springboot-security` skill |
| Spring Boot TDD | `springboot-tdd` + `springboot-verification` skills |
| React 컴포넌트 | `frontend-patterns` skill + `typescript-reviewer` agent |
| Tiptap 에디터 통합 | `frontend-patterns` + `/docs` 커맨드 (Context7 조회) |
| AI 파이프라인 (Claude/Gemini) | `cost-aware-llm-pipeline` skill (모델 라우팅) |
| Firecrawl 결과 캐싱 | `content-hash-cache-pattern` skill |
| 분류 — regex vs LLM | `regex-vs-llm-structured-text` skill (의사결정) |
| Flyway 마이그레이션 | `database-migrations` skill + `database-reviewer` agent |
| PostgreSQL 최적화 | `postgres-patterns` skill |
| Docker / Nginx | `docker-patterns` + `deployment-patterns` skills |
| API 설계 | `api-design` skill |
| E2E 테스트 | `/e2e` 커맨드 + `e2e-runner` agent |
| 빌드 에러 | `/build-fix` → `java-build-resolver`, `gradle-build` |
| 세션 메모리 | `continuous-learning-v2` skill + memory-persistence hooks |

### 14.3 권장 룰 통합

ECC 룰 일부를 우리 `.claude/rules/`에 통합:

```bash
# common rules는 항상 가져오기
cp -i /tmp/ecc/rules/common/*.md /Users/jys/project/ai-community/.claude/rules/ecc-common/
cp -i /tmp/ecc/rules/typescript/*.md /Users/jys/project/ai-community/.claude/rules/ecc-typescript/
cp -i /tmp/ecc/rules/java/*.md /Users/jys/project/ai-community/.claude/rules/ecc-java/
```

> 충돌 방지: 우리 `safety.md`, `project-structure.md`가 우선. ECC 룰은 보충용.

### 14.4 Hook 통합 전략

**memory-persistence hooks** 만 가져오는 것을 추천:

- SessionStart: `/compact` 후에도 CLAUDE.md + 이전 세션 요약 자동 로드
- Stop: 세션 종료 시 결정/차단/위치를 `.claude/sessions/`에 저장
- PreCompact: 압축 전 진행 상황 저장

PostToolUse 자동 포매팅 hook은 **신중하게** — 우리 ESLint/Prettier 설정과 충돌 가능.

### 14.5 GSD와의 비교 / 공존

| | GSD | ECC |
|---|-----|-----|
| 성격 | Spec 기반 워크플로우 엔진 | 하니스 성능 최적화 시스템 |
| 1차 단위 | Phase (계획→실행→검증) | Skill (재사용 패턴) |
| 컨텍스트 전략 | Phase마다 fresh 200k | MCP/skill lazy load + memory hook |
| 학습 | 명시적 마일스톤 → 아카이브 | Continuous learning (instinct) |
| 병렬화 | Wave 그룹화 (의존성 분석) | Cascade method (사용자 운영) |
| 검증 | Plan checker + Verifier 에이전트 | pass@k/pass^k + eval-harness |
| 보안 | Path traversal, prompt injection 검사 | AgentShield (1282 테스트) |
| 디렉토리 | `.planning/` | `~/.claude/` (글로벌 또는 프로젝트) |

**공존 가능**: GSD는 `.planning/`을 쓰고 ECC는 `~/.claude/`를 쓴다. 충돌 없음.

**언제 무엇을?**
- **새 기능 한 phase부터 끝까지** → GSD (`/gsd:plan-phase` → `/gsd:execute-phase`)
- **개별 작업, TDD, 코드 리뷰, 세션 메모리** → ECC (`/plan`, `/tdd`, `/code-review`, instincts)
- **두 시스템 모두 우리 `.claude/skills/`의 도메인 skill을 참조하도록 설정**

---

## 15. 핵심 원칙 요약 (저자의 takeaway)

1. **Don't overcomplicate** — Configuration은 fine-tuning, architecture가 아님
2. **Context window is precious** — 안 쓰는 MCP/플러그인은 무조건 끄기
3. **Parallel execution** — fork conversations, git worktree
4. **Automate the repetitive** — 포매팅/린팅/리마인더는 hook으로
5. **Scope your subagents** — 도구 제한 = 집중된 실행
6. **Skills are the durable unit** — commands는 legacy shim
7. **Memory beats re-discovery** — instinct로 패턴 영속화
8. **Cheapest model that works** — 모델 선택은 의식적 결정
9. **Verify, don't trust** — pass@k/pass^k로 측정
10. **Build reusable patterns early** — 컴파운드 효과는 시간이 갈수록 커진다

---

## 16. 참고 자료

- **저장소**: https://github.com/affaan-m/everything-claude-code
- **공식 사이트**: https://ecc.tools
- **Marketplace 앱**: https://github.com/marketplace/ecc-tools
- **Shortform Guide**: `the-shortform-guide.md` (먼저 읽기)
- **Longform Guide**: `the-longform-guide.md` (고급 패턴)
- **Security Guide**: `the-security-guide.md`
- **저자**: Affaan Mustafa (@affaanmustafa)
- **Anthropic 공식 문서**:
  - Plugins: https://code.claude.com/docs/en/plugins-reference
  - Hooks: https://code.claude.com/docs/en/hooks
  - Subagents: https://code.claude.com/docs/en/sub-agents
  - MCP: https://code.claude.com/docs/en/mcp-overview
  - Memory: https://code.claude.com/docs/en/memory
