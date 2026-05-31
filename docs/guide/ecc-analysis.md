# Everything Claude Code (ECC) 분석

> 분석일: 2026-04-07
> GitHub: https://github.com/affaan-m/everything-claude-code
> Stars: 143k+ | License: MIT | 성격: **에이전트 하니스 성능 최적화 시스템**
> 저자: Affaan Mustafa (Anthropic × Forum Ventures Hackathon 우승)

## 한줄 요약

Claude Code(및 타 AI 코딩 하니스)를 위한 skills + agents + hooks + rules + MCPs + plugins 통합 시스템. 10개월의 일상 사용에서 다듬어진 컨텍스트 절약, 메모리 영속화, 모델 라우팅, 검증 루프, 지속 학습 패턴의 모음.

GSD가 "spec → phase → execute"의 워크플로우 엔진이라면, ECC는 "skill을 1차 단위로 둔 하니스 자체의 튜닝 키트"다.

---

## 설치

### Plugin (편한 길)

```bash
/plugin marketplace add https://github.com/affaan-m/everything-claude-code
/plugin install ecc@ecc
```

### 소스 (안정적)

```bash
git clone https://github.com/affaan-m/everything-claude-code.git
cd everything-claude-code && npm install

./install.sh --profile full              # 전체
./install.sh typescript python golang    # 언어별
./install.sh --target cursor typescript  # 다른 하니스
npx ecc-install typescript               # cross-platform
```

호환: **Claude Code, Codex (CLI+App), Cursor, OpenCode, Gemini, Antigravity, Trae, Kiro, CodeBuddy**

규모 (v1.10.0): 38~47 agents, 156~181 skills, 59~79 commands, 12 언어 생태계, 997+ 테스트.

---

## 핵심 빌딩 블록 7개

| 블록 | 위치 | 역할 |
|------|------|------|
| **Skills** | `~/.claude/skills/` | **1차 워크플로우 표면** — 재사용 패턴 묶음 (codemap 포함) |
| Commands | `~/.claude/commands/` | Legacy slash 진입점 (skills로 마이그레이션 중) |
| Agents | `~/.claude/agents/` | Subagent — 위임 가능한 전문 프로세스 |
| Hooks | `~/.claude/hooks/` | 이벤트 트리거 자동화 |
| Rules | `~/.claude/rules/` | Claude가 항상 따를 원칙 (언어별 분리) |
| MCPs | `settings.json` | 외부 서비스 연결 (**컨텍스트 폭주의 주범**) |
| Plugins | marketplace | 위 요소들의 패키지 |

> ECC의 가장 강한 의견: **commands는 legacy, skills가 미래**. Slash 진입점은 호환을 위해 유지되지만 durable logic은 skill에 산다.

---

## Hook Lifecycle

| Hook | 발화 시점 | 핵심 용도 |
|------|----------|----------|
| `PreToolUse` | 도구 실행 전 | 검증, 알림, 차단 |
| `PostToolUse` | 도구 실행 후 | 포매팅, 피드백 루프 |
| `UserPromptSubmit` | 메시지 전송 시 | (지연 누적 — 신중) |
| `Stop` | Claude 응답 종료 | **세션 학습 저장** (Continuous Learning 핵심) |
| `PreCompact` | 컨텍스트 압축 전 | 중요 상태 파일 영속화 |
| `SessionStart` | 세션 시작 | 이전 컨텍스트 자동 로드 |
| `Notification` | 권한 요청 | 알림 |

**Runtime 제어** (v1.8+):

```bash
export ECC_HOOK_PROFILE=minimal      # minimal | standard | strict
export ECC_DISABLED_HOOKS="pre:bash:tmux-reminder,post:edit:typecheck"
```

---

## 토큰 / 모델 라우팅 표

| 작업 | 모델 | 이유 |
|------|------|------|
| 탐색/검색 | Haiku | 빠르고 싸다 |
| 단순 편집 | Haiku | 단일 파일 |
| 다중 파일 구현 | Sonnet | 균형점 (기본값) |
| 복잡한 아키텍처 | Opus | 깊은 추론 |
| PR 리뷰 | Sonnet | 뉘앙스 캐치 |
| 보안 분석 | Opus | 놓치면 안 됨 |
| 문서 작성 | Haiku | 구조 단순 |
| 복잡한 디버깅 | Opus | 시스템 전체 보유 |

`/model-route`로 작업 → 적절 모델 라우팅. 기본 Sonnet, Opus 업그레이드 조건: 첫 시도 실패, 5+ 파일, 아키텍처, 보안.

**추가 절약**:
- mgrep > grep/ripgrep (~50% 토큰 절약)
- MCP → CLI+skill 마이그레이션 (컨텍스트 절약)
- 모듈화된 코드베이스 (메인 파일 100줄 단위)

---

## 검증 메트릭 — pass@k vs pass^k

```
pass@k: k번 중 최소 1번 성공
        k=1: 70%   k=3: 91%   k=5: 97%

pass^k: k번 모두 성공
        k=1: 70%   k=3: 34%   k=5: 17%
```

- **pass@k** → "되기만 하면 됨" 작업
- **pass^k** → 일관성이 필수인 작업 (CI, 프로덕션)

관련: `eval-harness`, `verification-loop` skills + `/eval`, `/quality-gate`, `/test-coverage` 커맨드.

---

## 핵심 워크플로우 패턴

### 1. 기본 코딩 사이클

```
/plan → (승인) → /tdd → /code-review → /build-fix → /verify → /quality-gate
```

### 2. Sequential Phases

```
Phase 1: RESEARCH (Explore)        → research-summary.md
Phase 2: PLAN (planner)            → plan.md
Phase 3: IMPLEMENT (tdd-guide)     → 코드
Phase 4: REVIEW (code-reviewer)    → review-comments.md
Phase 5: VERIFY (build-resolver)   → done or loop
```

규칙: 1입력 → 1출력, 건너뛰기 금지, agent 사이 `/clear`, 출력은 파일로.

### 3. Iterative Retrieval (Subagent 컨텍스트 문제 해결)

Subagent는 query만 안다. 오케스트레이터는 **목적**까지 안다.
→ Subagent 응답을 매번 평가, 부족하면 follow-up, 최대 3 사이클.
→ **objective context**를 query와 함께 전달하는 것이 핵심.

### 4. Two-Instance Kickoff (빈 레포)

| 인스턴스 | 역할 |
|---------|------|
| Scaffolding | CLAUDE.md, rules, agents, 프로젝트 구조 |
| Deep Research | PRD, mermaid 다이어그램, 외부 문서 인용 |

### 5. Cascade Method (병렬)

새 작업은 오른쪽 새 탭, 왼→오 순서로 sweep, **3~4개 동시까지만**, 코드 충돌 방지에 git worktree 필수.

> 저자의 핵심 경고: "터미널 N개" 같은 임의 숫자를 좇지 마라. **최소 병렬화로 최대 산출**이 목표.

---

## 메모리 / 지속 학습

### 세션 간 메모리 (Hook 기반)

```
SessionStart hook   ← 이전 세션 요약 자동 로드
     ↓
   작업
     ↓
PreCompact hook     ← 압축 직전 상태 영속화
     ↓
   계속 작업
     ↓
Stop hook           ← 세션 종료 시 학습 저장
```

저장 파일 내용:
- ✅ 검증된 증거와 함께 **무엇이 작동했는지**
- ❌ 시도했지만 **실패한 접근**
- ⏳ **시도하지 않은 것 + 남은 작업**

### Continuous Learning v2 (Instincts)

| 커맨드 | 동작 |
|--------|------|
| `/learn-eval` | 패턴 추출 + 자기 평가 후 저장 |
| `/evolve` | Instinct → 진화된 skill 구조 제안 |
| `/promote` | 프로젝트 → 글로벌 |
| `/instinct-status` | confidence score 포함 전체 |
| `/instinct-export`, `/instinct-import` | 이식 |
| `/skill-create` | git history → 재사용 skill |

> **왜 Stop hook인가?** UserPromptSubmit은 매 메시지마다 → 지연 누적. Stop은 세션당 1회 → 세션 중 영향 0.

### 동적 시스템 프롬프트 (고급)

CLAUDE.md에 모든 걸 넣지 말고:

```bash
alias claude-dev='claude --system-prompt "$(cat ~/.claude/contexts/dev.md)"'
alias claude-review='claude --system-prompt "$(cat ~/.claude/contexts/review.md)"'
```

권한: **시스템 프롬프트 > 사용자 메시지 > 도구 결과**

---

## 주요 커맨드 (59개 중 핵심)

### 코어
| 커맨드 | 용도 |
|--------|------|
| `/plan` | 요구사항 재진술 + 위험 평가 + 단계 계획 (승인 대기) |
| `/tdd` | 인터페이스 → 실패 테스트 → 구현 → 80%+ 커버리지 |
| `/code-review` | 변경 파일 품질/보안 리뷰 |
| `/build-fix` | 빌드 에러 자동 수정 (언어별 resolver로 위임) |
| `/verify` | build → lint → test → type-check 풀 루프 |
| `/quality-gate` | 프로젝트 표준 게이트 |
| `/e2e` | Playwright + 스크린샷/비디오/trace |

### 메타 / 학습
| 커맨드 | 용도 |
|--------|------|
| `/learn-eval` | 세션 패턴 추출 + 평가 |
| `/evolve` | Instinct → skill 진화 |
| `/skill-health` | Skill 포트폴리오 분석 |
| `/skill-stocktake` | Skill 자기 점검 |
| `/rules-distill` | Skills 스캔 → rules로 증류 |
| `/harness-audit` | 하니스 config 신뢰성/비용 감사 |
| `/context-budget` | 컨텍스트 사용량 분석 |
| `/model-route` | 작업 → 적절 모델 |

### 세션 / 다중 인스턴스
| 커맨드 | 용도 |
|--------|------|
| `/save-session`, `/resume-session`, `/sessions` | 세션 영속화 |
| `/checkpoint` | 세션 체크포인트 |
| `/aside` | 사이드 질문 (컨텍스트 보존) |
| `/fork` | 비중첩 작업 병렬화 |
| `/orchestrate` | tmux/worktree 가이드 |
| `/devfleet` | 병렬 Claude 오케스트레이션 |
| `/claw` | NanoClaw v2 — 영속 REPL + 모델 라우팅 + skill hot-load + 메트릭 |
| `/loop-start`, `/loop-status` | 주기 agent 루프 |

### 멀티 모델 (별도 `npx ccg-workflow` 필요)
`/multi-plan`, `/multi-execute`, `/multi-backend`, `/multi-frontend`, `/multi-workflow`

---

## 보안 (AgentShield)

- v1.6+ 통합. **1282 테스트, 102 룰**.
- `/security-scan` 커맨드로 직접 실행
- npm: `ecc-agentshield`
- 별도 가이드: `the-security-guide.md`

기본 보안 룰:
- 시크릿/토큰/절대경로 출력 금지
- 검증 hook 우회 금지
- 입력 검증 유지
- 보안 hook 자동 차단 (exit 1)

---

## ECC 2.0 Alpha (`ecc2/`)

v1.10.0 (2026-04)에 in-tree로 들어온 **Rust 컨트롤 플레인** 프로토타입.

명령: `dashboard`, `start`, `stop`, `resume`, `sessions`, `status`, `daemon`

> **상태**: alpha. 로컬 빌드 가능, 일반 릴리스 아님.

---

## Run-AI 적용 매핑

| Run-AI 작업 | ECC 자산 |
|------------|---------|
| Spring Boot 컨트롤러 | `springboot-patterns` skill + `java-reviewer` agent |
| Spring Boot 보안/TDD | `springboot-security`, `springboot-tdd`, `springboot-verification` |
| React + TypeScript | `frontend-patterns` + `typescript-reviewer` |
| AI 파이프라인 (Claude/Gemini) | **`cost-aware-llm-pipeline`** skill (모델 라우팅, 비용 추적) |
| Firecrawl 캐싱 | `content-hash-cache-pattern` (SHA-256) |
| 분류 — regex vs LLM | `regex-vs-llm-structured-text` (의사결정 프레임워크) |
| Flyway 마이그레이션 | `database-migrations` + `database-reviewer` |
| PostgreSQL | `postgres-patterns` skill |
| Docker / Nginx | `docker-patterns`, `deployment-patterns` |
| API 설계 | `api-design` skill |
| E2E 테스트 | `/e2e` + `e2e-runner` agent |
| 빌드 에러 | `/build-fix` → `java-build-resolver`, `gradle-build` |
| 세션 메모리 | `continuous-learning-v2` + memory-persistence hooks |
| 컨텍스트 회복 (`/compact` 후) | SessionStart hook + `/resume-session` |

---

## ECC vs GSD vs 우리 `.claude/`

| | 우리 `.claude/` | GSD | ECC |
|---|---|---|---|
| 성격 | 프로젝트 도메인 지식 | Spec 기반 워크플로우 엔진 | 하니스 성능 최적화 시스템 |
| 1차 단위 | 수동 commands/skills | Phase | **Skill** |
| 컨텍스트 전략 | (없음) | Phase별 fresh 200k | MCP/skill lazy load + memory hook |
| 학습 | 수동 | 마일스톤 → 아카이브 | **Instinct (continuous)** |
| 병렬화 | (없음) | Wave 의존성 그룹화 | Cascade method |
| 검증 | (없음) | Plan checker + Verifier | pass@k/pass^k + eval-harness |
| 보안 | safety.md | Path/injection 검사 | **AgentShield (1282 tests)** |
| 디렉토리 | `.claude/` | `.planning/` | `~/.claude/` (글로벌) |
| **충돌** | — | 없음 (`.planning/`) | 없음 (`~/.claude/`) |

### 셋 다 같이 쓰는 권장 분담

- **우리 `.claude/`** → 도메인 지식 (Spring 패턴, AI 파이프라인 규칙, 포인트/등급)
- **GSD** → 새 기능 한 phase부터 끝까지 spec-driven 진행
- **ECC** → 일상 작업의 hook/skill/instinct/모델 라우팅, 세션 메모리

세 시스템 모두 우리 `.claude/skills/`의 도메인 skill을 참조하도록 설정.

---

## 핵심 takeaway

1. **Skills are the durable unit** — commands는 legacy shim
2. **Context window is precious** — MCP 30 설정, 활성화 10 미만, 도구 80 미만
3. **Cheapest model that works** — 의식적인 모델 라우팅
4. **Memory beats re-discovery** — instinct로 패턴 영속
5. **Verify, don't trust** — pass@k/pass^k 측정
6. **Minimum viable parallelization** — 임의 터미널 수 금지
7. **Configuration is fine-tuning, not architecture** — 과설계 금지
8. **Compound effects matter** — 재사용 패턴에 일찍 투자
