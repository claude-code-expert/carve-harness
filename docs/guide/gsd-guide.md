# Get Shit Done (GSD) 완벽 가이드

> GitHub: https://github.com/gsd-build/get-shit-done
> Stars: 59.3k | License: MIT | 최신 버전: v1.39.1 (2026-05-01)
> 게시자: TÂCHES
> 공식 User Guide: https://github.com/gsd-build/get-shit-done/blob/main/docs/USER-GUIDE.md
>
> ⚠️ **명령어 네이밍 규약**: GSD 명령어는 모두 하이픈(`-`) 형식이다 (`/gsd-help`, `/gsd-new-project` 등). Codex 런타임만 `$gsd-help` 형식 사용.

---

## 1. GSD란 무엇인가

Claude Code(및 기타 AI 코딩 도구)를 위한 **컨텍스트 엔지니어링 + 스펙 기반 개발 시스템**.

### 해결하는 문제: Context Rot

Claude Code로 작업하다 보면 컨텍스트 윈도우가 차면서 품질이 점진적으로 저하된다. GSD는 이것을 해결하기 위해 **매 단계를 새로운 200K 컨텍스트에서 실행**하는 구조를 사용한다.

### 핵심 철학

- 복잡성은 시스템 안에, 사용자 워크플로우는 단순하게
- 모든 태스크는 atomic commit으로 추적 가능
- 서브에이전트가 작업하고, 메인 세션은 30~40%만 사용
- 계획 → 실행 → 검증의 명확한 분리

### 호환 런타임 (15개)

Claude Code, OpenCode, Gemini CLI, **Kilo**, Codex, Copilot, Cursor, Windsurf, Antigravity, **Augment**, **Trae**, **Qwen Code**, **Hermes Agent**, **CodeBuddy**, **Cline**

> Claude Code 2.1.88+, Qwen Code, Codex는 skills 형식(`.claude/skills/`, `.codex/skills/`)으로 설치된다. 구버전 Claude Code는 `commands/gsd/` 형식. 설치기가 자동 감지.

### Anthropic ToS 변경 후 재진입 안내

Anthropic 약관 변경으로 GSD를 다시 사용하는 경우, 기존 프로젝트는 다음 두 명령으로 재초기화한다 (코드는 그대로, 플래닝 컨텍스트만 재구축):

```
/gsd-map-codebase    # 현재 코드베이스 스캔/인덱싱
/gsd-new-project     # codebase map을 컨텍스트로 새 GSD 플래닝 구조 초기화
```

---

## 2. 설치

### 기본 설치 (대화형)

```bash
npx get-shit-done-cc@latest
```

설치 시 두 가지를 선택한다:
1. **Runtime** — 사용할 AI 코딩 도구 (복수 선택 가능)
2. **Location** — Global(모든 프로젝트) 또는 Local(현재 프로젝트만)

### 비대화형 설치 (CI/Docker/스크립트)

```bash
# Claude Code
npx get-shit-done-cc --claude --local      # → ./.claude/
npx get-shit-done-cc --claude --global     # → ~/.claude/

# 여러 런타임 동시 설치
npx get-shit-done-cc --all --global

# 그 외 런타임
npx get-shit-done-cc --opencode --global   # → ~/.config/opencode/
npx get-shit-done-cc --gemini --global     # → ~/.gemini/
npx get-shit-done-cc --kilo --local        # → ./.kilo/
npx get-shit-done-cc --codex --local       # → ./.codex/
npx get-shit-done-cc --copilot --local     # → ./.github/
npx get-shit-done-cc --cursor --local      # → ./.cursor/
npx get-shit-done-cc --windsurf --local    # → ./.windsurf/
npx get-shit-done-cc --antigravity --local # → ./.agent/
npx get-shit-done-cc --augment --local     # → ./.augment/
npx get-shit-done-cc --trae --local        # → ./.trae/
npx get-shit-done-cc --qwen --local        # → ./.qwen/
npx get-shit-done-cc --hermes --local      # → ./.hermes/  (honors $HERMES_HOME)
npx get-shit-done-cc --codebuddy --local   # → ./.codebuddy/
npx get-shit-done-cc --cline --local       # → ./.clinerules
```

### `--minimal` 설치 프로파일 (v1.39.0+)

```bash
npx get-shit-done-cc --claude --local --minimal   # alias: --core-only
```

6개 핵심 main-loop skill만 설치 (`new-project`, `discuss-phase`, `plan-phase`, `execute-phase`, `help`, `update`), `gsd-*` subagent는 모두 제외.
**시스템 프롬프트 cold-start 오버헤드를 ~12k → ~700 토큰으로 94% 절감.**
로컬 LLM(32K~128K 컨텍스트)이나 토큰 과금 API 환경에 유용.

### 설치 확인

```bash
claude
/gsd-help     # 전체 커맨드 목록 출력되면 성공
```

런타임별 검증 명령:
- Claude Code / Gemini / Copilot / Antigravity / Qwen / Hermes: `/gsd-help`
- OpenCode / Kilo / Augment / Trae / CodeBuddy: `/gsd-help`
- Codex: `$gsd-help`
- Cline: `.clinerules` 파일 존재 확인

### 업데이트

```bash
npx get-shit-done-cc@latest
```

GSD는 빠르게 진화하므로 주기적으로 업데이트할 것.

### 제거

```bash
npx get-shit-done-cc --claude --local --uninstall    # 로컬
npx get-shit-done-cc --claude --global --uninstall   # 전역
```

### Docker 환경

```bash
CLAUDE_CONFIG_DIR=/home/youruser/.claude npx get-shit-done-cc --global
```

### 개발자 설치 (소스에서)

```bash
git clone https://github.com/gsd-build/get-shit-done.git
cd get-shit-done
node bin/install.js --claude --local
```

---

## 3. 권장 설정

### 권한 모드

GSD는 자동화를 위해 설계되었으므로 권한 승인 없이 실행하는 것을 권장한다:

```bash
claude --dangerously-skip-permissions
```

세밀한 제어를 원하면 `.claude/settings.json`에 추가:

```json
{
  "permissions": {
    "allow": [
      "Bash(date:*)", "Bash(echo:*)", "Bash(cat:*)", "Bash(ls:*)",
      "Bash(mkdir:*)", "Bash(wc:*)", "Bash(head:*)", "Bash(tail:*)",
      "Bash(sort:*)", "Bash(grep:*)", "Bash(tr:*)",
      "Bash(git add:*)", "Bash(git commit:*)", "Bash(git status:*)",
      "Bash(git log:*)", "Bash(git diff:*)", "Bash(git tag:*)"
    ]
  }
}
```

### 민감 파일 보호

```json
{
  "permissions": {
    "deny": [
      "Read(.env)", "Read(.env.*)", "Read(**/secrets/*)",
      "Read(**/*credential*)", "Read(**/*.pem)", "Read(**/*.key)"
    ]
  }
}
```

---

## 4. 핵심 워크플로우: 6단계 루프

```
┌──────────────────────────────────────────────────┐
│                   NEW PROJECT                    │
│  /gsd-new-project                                │
│  질문 → 리서치 → 요구사항 → 로드맵              │
└─────────────────────────┬────────────────────────┘
                          │
           ┌──────────────▼─────────────┐
           │      FOR EACH PHASE:       │
           │                            │
           │  /gsd-discuss-phase N      │  ← 구현 결정 토론
           │          │                 │
           │  /gsd-ui-phase N           │  ← UI 디자인 계약 (프론트 Phase만)
           │          │                 │
           │  /gsd-plan-phase N         │  ← 리서치 + 계획 + 검증
           │          │                 │
           │  /gsd-execute-phase N      │  ← Wave 병렬 실행
           │          │                 │
           │  /gsd-verify-work N        │  ← 사용자 수동 검증
           │          │                 │
           │  /gsd-ship N               │  ← PR 생성
           │          │                 │
           │     다음 Phase? ───────────┘
           │          │ No
           └──────────┼──────────────┘
                      │
      /gsd-audit-milestone    ← 마일스톤 달성 확인
      /gsd-complete-milestone ← 아카이브 + 태그
      /gsd-new-milestone      ← 다음 버전 시작
```

---

## 5. 각 단계 상세 설명

### 5.1 new-project: 프로젝트 초기화

```bash
/gsd-new-project                        # 대화형
/gsd-new-project --auto                 # 자동 모드
/gsd-new-project --auto @idea.md        # 기존 문서에서 자동 생성
```

**하는 일:**
1. 아이디어를 완전히 이해할 때까지 질문
2. 병렬 에이전트 4개가 도메인 리서치 (선택이지만 권장)
3. v1/v2/out-of-scope로 요구사항 추출
4. 요구사항에 매핑된 Phase 로드맵 생성

**생성 파일:**

| 파일 | 역할 |
|------|------|
| `PROJECT.md` | 프로젝트 비전 (항상 로드됨) |
| `REQUIREMENTS.md` | v1/v2 요구사항 + Phase 매핑 |
| `ROADMAP.md` | 전체 로드맵 + 완료 상태 |
| `STATE.md` | 결정/차단요소/위치 — 세션 간 메모리 |
| `.planning/research/` | 도메인 리서치 결과 |

**기존 코드가 있는 경우 (Brownfield):**

```bash
/gsd-map-codebase         # 먼저 기존 코드 분석
/gsd-new-project          # 분석 결과 기반으로 초기화 — 질문이 "추가할 것"에 집중됨
```

`map-codebase` 옵션 (v1.39 통합):
```bash
/gsd-map-codebase --fast      # 빠른 모드
/gsd-map-codebase --query "..."  # 특정 영역만 매핑
```

`map-codebase`가 생성하는 파일:
- `codebase/STACK.md` — 기술 스택 분석
- `codebase/ARCHITECTURE.md` — 아키텍처 분석
- `codebase/CONVENTIONS.md` — 코드 컨벤션 분석
- `codebase/CONCERNS.md` — 우려사항 분석

### 5.2 discuss-phase: 구현 결정 토론

```bash
/gsd-discuss-phase 1                    # 기본 (하나씩 질문)
/gsd-discuss-phase 1 --batch            # 질문 묶음으로 빠르게
/gsd-discuss-phase 1 --chain            # 토론 → 계획 → 실행 자동 체이닝
/gsd-discuss-phase 1 --analyze          # 트레이드오프 분석 포함
```

**하는 일:**
로드맵의 한두 줄 설명을 내가 원하는 방식으로 구체화. Phase 유형에 따라 다른 질문:

| Phase 유형 | 질문 영역 |
|-----------|-----------|
| 시각적 기능 | 레이아웃, 밀도, 인터랙션, 빈 상태 |
| API/CLI | 응답 형식, 플래그, 에러 처리, 상세도 |
| 콘텐츠 시스템 | 구조, 톤, 깊이, 흐름 |
| 정리 작업 | 그룹화 기준, 네이밍, 중복, 예외 |

**생성 파일:** `.planning/phases/{NN}-{slug}/CONTEXT.md`

**왜 중요한가:** 이 CONTEXT.md를 리서처와 플래너가 읽는다. 여기서 결정을 깊게 할수록 내가 원하는 것에 가까운 결과가 나온다. 건너뛰면 합리적인 기본값이 사용된다.

**Assumptions 모드:** 질문 대신 코드베이스를 분석해서 가정을 제시하고 확인/수정을 요청하는 방식. 경험 많은 개발자나 패턴이 확립된 프로젝트에 적합.

```bash
# /gsd-settings 에서 discuss_mode를 assumptions로 변경
```

### 5.3 plan-phase: 리서치 + 계획

```bash
/gsd-plan-phase 1                       # 기본 (리서치 + 계획 + 검증)
/gsd-plan-phase 1 --skip-research       # 리서치 생략
/gsd-plan-phase 1 --skip-verify         # 검증 생략
/gsd-plan-phase 1 --reviews             # 코드 리뷰 결과도 참고
```

**하는 일:**

```
플래닝 에이전트 조율도
─────────────────────
Phase Researcher (4개 병렬)
  ├── Stack researcher       → 기술 스택 조사
  ├── Features researcher    → 기능 구현 방법
  ├── Architecture researcher → 아키텍처 패턴
  └── Pitfalls researcher    → 위험 요소/함정
         │
    RESEARCH.md 생성
         │
    Planner → PROJECT.md, REQUIREMENTS.md, CONTEXT.md, RESEARCH.md 읽고 계획 생성
         │
    Plan Checker → 계획이 요구사항을 충족하는지 검증 (최대 3회 반복)
         │
    PLAN.md 파일들 생성
```

**XML 태스크 구조:**

```xml
<task type="auto">
  <name>Create login endpoint</name>
  <files>backend/src/main/java/kr/runai/api/controller/AuthController.java</files>
  <action>
    Spring Security OAuth2로 Google 로그인 구현.
    JWT 토큰 발행, httpOnly 쿠키 설정.
  </action>
  <verify>curl -X POST localhost:8080/api/auth/login returns 200 + Set-Cookie</verify>
  <done>유효한 자격증명은 쿠키 반환, 무효한 자격증명은 401 반환</done>
</task>
```

**생성 파일:** `RESEARCH.md`, `{NN}-{MM}-PLAN.md` (PLAN/SUMMARY만 phase-task 번호 prefix 사용)

**품질 게이트 (자동 검증):**
- 스키마 드리프트 감지: ORM 변경인데 마이그레이션이 빠진 경우 플래그
- 보안 검증: 위협 모델 기반 검증
- 범위 축소 감지: 플래너가 요구사항을 조용히 누락하면 감지

### 5.4 execute-phase: Wave 병렬 실행

```bash
/gsd-execute-phase 1
```

**하는 일:**

```
의존성 분석 → Wave 그룹화 → 병렬 실행

WAVE 1 (parallel)          WAVE 2 (parallel)          WAVE 3
┌──────────┐ ┌──────────┐  ┌──────────┐ ┌──────────┐  ┌──────────┐
│ Plan 01  │ │ Plan 02  │  │ Plan 03  │ │ Plan 04  │  │ Plan 05  │
│ User     │ │ Product  │→ │ Orders   │ │ Cart     │→ │ Checkout │
│ Model    │ │ Model    │  │ API      │ │ API      │  │ UI       │
└──────────┘ └──────────┘  └──────────┘ └──────────┘  └──────────┘
     │           │              ↑           ↑              ↑
     └───────────┴──────────────┴───────────┘              │
            Plan 03은 Plan 01 필요                         │
            Plan 04는 Plan 02 필요                         │
            Plan 05는 Plan 03+04 필요 ─────────────────────┘
```

- 각 executor가 독립된 **200K 컨텍스트**에서 작업
- 태스크별 **atomic git commit**
- 메인 세션은 **30~40%만 사용**
- 완료 후 자동 검증 (코드가 Phase 목표를 달성했는지)

**Post-merge build & test gate (v1.39.0+):** Wave 완료 후 5.6 단계에서 빌드/테스트 자동 실행. `workflow.build_command` 우선, 없으면 Xcode(`.xcodeproj`) → Makefile → Justfile → Cargo → Go → Python → npm 순으로 자동 감지. iOS 프로젝트는 `xcodebuild build` + `xcodebuild test` 자동 실행.

**생성 파일:** `{NN}-{MM}-SUMMARY.md`, `VERIFICATION.md`

### 5.5 verify-work: 사용자 수동 검증 (UAT)

```bash
/gsd-verify-work 1
```

**하는 일:**
1. 테스트 가능한 항목을 추출 ("로그인이 되나요?", "게시물 작성이 되나요?")
2. 하나씩 제시, 사용자가 Yes/No 또는 문제 설명
3. 실패 시 디버그 에이전트가 자동으로 원인 분석
4. 수정 플랜 자동 생성 → `/gsd-execute-phase`로 재실행

**생성 파일:** `UAT.md`, fix plans (문제 발견 시)

### 5.6 ship: PR 생성

```bash
/gsd-ship 1                  # PR 생성
/gsd-ship 1 --draft          # Draft PR
```

### 5.7 phase 편집 (v1.39.0+)

```bash
/gsd-edit-phase N            # ROADMAP.md의 phase 필드 수정 (번호/위치 유지)
/gsd-edit-phase N --force    # 확인 diff 건너뛰기
```

`depends_on` 참조가 자동 검증되고, `STATE.md`도 같이 업데이트된다.

### 5.8 마일스톤 완료 → 다음 마일스톤

```bash
/gsd-audit-milestone         # 마일스톤 달성 확인 (requirements coverage, stub 감지)
/gsd-plan-milestone-gaps     # audit에서 갭 발견 시 Phase 추가
/gsd-complete-milestone      # 아카이브 + 릴리스 태그
/gsd-new-milestone [name]    # 다음 버전 시작 (같은 흐름, 기존 코드베이스 기반)
```

---

## 6. Quick Mode & Fast Mode

### quick: 빠른 단건 작업

풀 파이프라인이 필요 없는 소규모 작업용.

```bash
/gsd-quick                              # 기본 (계획 → 실행)
/gsd-quick --discuss                    # 토론 후 실행
/gsd-quick --research                   # 리서치 후 실행
/gsd-quick --validate                   # 계획 검증 + 실행 후 검증
/gsd-quick --full                       # 전체 파이프라인 (토론+리서치+검증)
/gsd-quick --discuss --research         # 플래그 조합 가능
```

```bash
/gsd-quick
> What do you want to do? "Settings 페이지에 다크모드 토글 추가"
```

별도 `.planning/quick/`에 저장, 메인 Phase와 분리.

### fast: 즉시 실행

계획도 필요 없는 사소한 작업.

```bash
/gsd-fast "README의 오타 수정"
/gsd-fast "설정 파일에 Redis timeout 추가"
```

---

## 7. 상황별 어떤 커맨드를 써야 하나

### 프로젝트 시작

| 상황 | 커맨드 |
|------|--------|
| 완전히 새 프로젝트 | `/gsd-new-project` |
| 기존 PRD/아이디어 문서 있음 | `/gsd-new-project --auto @문서.md` |
| 기존 코드가 있는 프로젝트 | `/gsd-map-codebase` → `/gsd-new-project` |

### 개발 중

| 상황 | 커맨드 |
|------|--------|
| 다음 단계가 뭔지 모르겠음 | `/gsd-next` 또는 `/gsd-progress` |
| Phase 구현 시작 | `/gsd-discuss-phase N` → `/gsd-plan-phase N` → `/gsd-execute-phase N` |
| 작은 버그 수정 | `/gsd-quick` |
| 오타, 설정값 변경 | `/gsd-fast "설명"` |
| 세션 중단해야 함 | `/gsd-pause-work` |
| 다음 세션에서 이어서 작업 | `/gsd-resume-work` 또는 `/gsd-progress` |
| 진행 상황 확인 + 다음 작업 실행 | `/gsd-progress --next` 또는 `/gsd-progress --do` |
| 중간에 긴급 작업 필요 | `/gsd-insert-phase N` |
| 스코프 변경 (추가) | `/gsd-add-phase` |
| Phase 필드 수정 | `/gsd-edit-phase N` |
| 스코프 변경 (삭제) | `/gsd-remove-phase N` |

### 코드 품질

| 상황 | 커맨드 |
|------|--------|
| 커밋 전 리뷰 | `/gsd-review --phase N` |
| 코드 리뷰 + 자동 수정 | `/gsd-code-review --fix` |
| 뭔가 깨졌음 | `/gsd-debug "설명"` |
| 워크플로우 자체가 이상 | `/gsd-forensics` |
| 보안 검증 | `/gsd-secure-phase N` |
| 프론트 UI 시각 검수 | `/gsd-ui-review N` |

### 릴리스

| 상황 | 커맨드 |
|------|--------|
| PR 만들기 | `/gsd-ship N` |
| 마일스톤 달성 확인 | `/gsd-audit-milestone` |
| 감사에서 갭 발견 | `/gsd-plan-milestone-gaps` |
| 릴리스 | `/gsd-complete-milestone` |
| 다음 버전 시작 | `/gsd-new-milestone` |

### 아이디어 관리

| 상황 | 커맨드 |
|------|--------|
| 아이디어 떠올랐음 (나중에) | `/gsd-add-todo "설명"` |
| 대규모 아이디어 (아직 준비 안됨) | `/gsd-add-backlog "설명"` |
| 미래 특정 시점에 할 일 | `/gsd-plant-seed "아이디어"` |
| 여러 세션에 걸친 작업 | `/gsd-thread "주제"` |
| 캡처한 아이디어 확인 | `/gsd-check-todos` |
| 백로그 정리 | `/gsd-review-backlog` |

### 탐색/스파이크 (v1.39.0+)

| 상황 | 커맨드 |
|------|--------|
| 가벼운 스케치/탐색 | `/gsd-sketch` |
| 본격 스파이크 (학습성 코드) | `/gsd-spike` |
| 스케치/스파이크 종료 + 정리 | `/gsd-sketch --wrap-up`, `/gsd-spike --wrap-up` |

---

## 8. 모델 프로파일

에이전트별로 다른 Claude 모델을 사용해서 품질과 비용의 균형을 맞춘다.

### 프로파일 종류

| 프로파일 | Planning | Execution | Research | Verification | 용도 |
|----------|----------|-----------|----------|--------------|------|
| `quality` | Opus | Opus | Opus | Sonnet | 중요한 프로덕션 작업 |
| `balanced` (기본) | Opus | Sonnet | Sonnet | Sonnet | 일반 개발 |
| `budget` | Sonnet | Sonnet | Haiku | Haiku | 대량 작업, 덜 중요한 Phase |
| `inherit` | 현재 모델 | 현재 모델 | 현재 모델 | 현재 모델 | 비-Anthropic 프로바이더, 로컬 모델 |

```bash
/gsd-set-profile quality     # 프로파일 변경
/gsd-set-profile budget      # 비용 절약
```

### 에이전트별 상세 모델

| 에이전트 | quality | balanced | budget | inherit |
|----------|---------|----------|--------|---------|
| gsd-planner | Opus | Opus | Sonnet | Inherit |
| gsd-roadmapper | Opus | Sonnet | Sonnet | Inherit |
| gsd-executor | Opus | Sonnet | Sonnet | Inherit |
| gsd-phase-researcher | Opus | Sonnet | Haiku | Inherit |
| gsd-debugger | Opus | Sonnet | Sonnet | Inherit |
| gsd-verifier | Sonnet | Sonnet | Haiku | Inherit |
| gsd-plan-checker | Sonnet | Sonnet | Haiku | Inherit |
| gsd-codebase-mapper | Sonnet | Haiku | Haiku | Inherit |

### 외부 review CLI별 모델 지정 (v1.39.0+)

`review.models.<cli>`로 codex/gemini 등 외부 review CLI마다 독립된 모델 지정 가능 (planner/executor 프로파일과 별개).

```json
{
  "review": {
    "models": {
      "codex": "gpt-5",
      "gemini": "gemini-2.5-pro"
    }
  }
}
```

### 속도 vs 품질 프리셋

| 시나리오 | mode | granularity | profile | research | plan_check | verifier |
|----------|------|-------------|---------|----------|------------|----------|
| 프로토타이핑 | `yolo` | `coarse` | `budget` | off | off | off |
| 일반 개발 | `interactive` | `standard` | `balanced` | on | on | on |
| 프로덕션 | `interactive` | `fine` | `quality` | on | on | on |

---

## 9. 설정 (Configuration)

설정은 `.planning/config.json`에 저장된다. `/gsd-settings`로 변경 가능.

### 전체 config.json 구조

```json
{
  "mode": "interactive",
  "granularity": "standard",
  "model_profile": "balanced",
  "planning": {
    "commit_docs": true,
    "search_gitignored": false
  },
  "workflow": {
    "research": true,
    "plan_check": true,
    "verifier": true,
    "nyquist_validation": true,
    "ui_phase": true,
    "ui_safety_gate": true,
    "research_before_questions": false,
    "discuss_mode": "standard",
    "skip_discuss": false,
    "auto_advance": false,
    "use_worktrees": true,
    "text_mode": false,
    "build_command": null
  },
  "hooks": {
    "context_warnings": true,
    "workflow_guard": false
  },
  "git": {
    "branching_strategy": "none",
    "phase_branch_template": "gsd/phase-{phase}-{slug}",
    "milestone_branch_template": "gsd/{milestone}-{slug}"
  },
  "review": {
    "models": {}
  },
  "agent_skills": {
    "executor": []
  }
}
```

### 주요 설정 항목

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `mode` | `interactive` | `yolo`=자동 승인, `interactive`=단계별 확인 |
| `granularity` | `standard` | Phase 세분화 정도 (`coarse`=3~5, `standard`=5~8, `fine`=8~12) |
| `workflow.research` | `true` | Phase 계획 전 도메인 리서치 실행 |
| `workflow.plan_check` | `true` | 계획 검증 루프 (최대 3회) |
| `workflow.verifier` | `true` | 실행 후 Phase 목표 달성 검증 |
| `workflow.skip_discuss` | `false` | discuss-phase 건너뛰기 (yolo 모드에서) |
| `workflow.auto_advance` | `false` | discuss → plan → execute 자동 체이닝 |
| `workflow.build_command` | `null` | post-merge build/test 커맨드 (지정 시 자동 감지보다 우선) |
| `parallelization.enabled` | `true` | 독립 플랜 병렬 실행 |
| `planning.commit_docs` | `true` | `.planning/`을 git에 커밋 |

### Git 브랜칭 전략

| 전략 | 동작 | 용도 |
|------|------|------|
| `none` (기본) | 현재 브랜치에 커밋 | 솔로 개발, 단순 프로젝트 |
| `phase` | Phase마다 브랜치 생성 | Phase별 코드 리뷰, 세밀한 롤백 |
| `milestone` | 마일스톤당 하나의 브랜치 | 릴리스 브랜치, 버전별 PR |

### Workstream 설정 상속 (v1.39.0+)

`GSD_WORKSTREAM` 환경 변수가 설정되면 root `.planning/config.json`을 먼저 로드한 뒤 workstream config로 deep-merge한다 (workstream이 우선). workstream config에 명시적 `null`을 두면 root 값을 덮어쓴다.

### 커스텀 Skill 주입

GSD executor가 프로젝트의 커스텀 skill을 참조하도록 설정:

```json
{
  "agent_skills": {
    "executor": [
      ".claude/skills/spring-conventions",
      ".claude/skills/ai-pipeline"
    ]
  }
}
```

---

## 10. GSD가 생성하는 파일 구조

> phase 폴더 내부 파일은 phase 번호 prefix를 붙이지 않는다 (PLAN/SUMMARY만 `{NN}-{MM}-` 형식 사용).

```
.planning/
├── PROJECT.md                    # 프로젝트 비전 (항상 로드)
├── REQUIREMENTS.md               # v1/v2 요구사항
├── ROADMAP.md                    # Phase 로드맵 + 상태
├── STATE.md                      # 결정/차단/위치 (세션 간 메모리)
├── config.json                   # 설정
├── MILESTONES.md                 # 완료된 마일스톤 아카이브
├── HANDOFF.json                  # 세션 핸드오프 (pause-work)
├── research/                     # 도메인 리서치 (new-project)
├── reports/                      # 세션 리포트
├── todos/
│   ├── pending/                  # 대기 중 아이디어
│   └── done/                     # 완료된 항목
├── debug/                        # 활성 디버그 세션
│   └── resolved/                 # 해결된 디버그
├── codebase/                     # Brownfield 분석 (map-codebase)
├── threads/                      # 크로스 세션 스레드
├── seeds/                        # 미래 아이디어
├── quick/                        # quick 모드 작업
├── phases/
│   └── 01-phase-name/
│       ├── CONTEXT.md            # 구현 결정사항
│       ├── RESEARCH.md           # 리서치 결과
│       ├── 01-01-PLAN.md         # atomic 태스크 플랜
│       ├── 01-02-PLAN.md
│       ├── 01-01-SUMMARY.md      # 실행 결과
│       ├── 01-02-SUMMARY.md
│       ├── VERIFICATION.md       # 자동 검증 결과
│       ├── UAT.md                # 사용자 수동 검증
│       ├── UI-SPEC.md            # UI 디자인 계약
│       ├── UI-REVIEW.md          # UI 시각 감사
│       └── VALIDATION.md         # 테스트 검증 계약
└── ui-reviews/                   # 스크린샷 (gitignored)
```

---

## 11. 트러블슈팅

| 문제 | 해결 |
|------|------|
| 컨텍스트 품질 저하 | `/clear` 후 `/gsd-resume-work`로 상태 복원 |
| 계획이 내 의도와 다름 | `/gsd-discuss-phase N`을 먼저 하고 다시 계획 |
| 실행이 스텁만 생성 | 플랜이 너무 큼 — 2~3 태스크로 재계획 |
| 현재 위치를 모르겠음 | `/gsd-progress` |
| 실행 후 변경 필요 | `/gsd-quick`으로 수정, 또는 `/gsd-verify-work`로 체계적 수정 |
| 비용이 너무 높음 | `/gsd-set-profile budget` + `/gsd-settings`에서 research/plan_check off |
| 워크플로우 상태 이상 | `/gsd-forensics` |
| 병렬 실행 시 빌드 에러 | 업데이트 또는 `parallelization.enabled: false` |
| 새 세션 시작 | `/gsd-resume-work` 또는 `/gsd-progress` |
| 업데이트 후 커스텀 변경 사라짐 | `/gsd-update --reapply` |
| 프로젝트 초기화가 이미 됨 | `.planning/` 삭제 후 다시 실행 |
| 시스템 프롬프트 토큰 너무 큼 | `--minimal` 프로파일로 재설치 |

### 복구 퀵 레퍼런스

| 상황 | 대응 |
|------|------|
| 컨텍스트/세션 잃음 | `/gsd-resume-work` |
| Phase가 잘못됨 | `git revert` 후 재계획 |
| 스코프 변경 | `/gsd-add-phase`, `/gsd-insert-phase`, `/gsd-remove-phase`, `/gsd-edit-phase` |
| 감사에서 갭 발견 | `/gsd-plan-milestone-gaps` |
| 뭔가 깨짐 | `/gsd-debug "설명"` |
| 빠른 수정 | `/gsd-quick` |
| 다음 단계가 뭔지 | `/gsd-next` |

---

## 12. 보안 기능

GSD v1.27부터 다단계 보안이 내장되어 있다.

| 보안 계층 | 설명 |
|-----------|------|
| **Path traversal 방지** | 파일 경로가 프로젝트 디렉토리 내로 제한 |
| **Prompt injection 탐지** | 사용자 텍스트가 planning artifact에 들어가기 전 패턴 검사 |
| **PreToolUse prompt guard** | `.planning/` 쓰기 시 injection 벡터 스캔 (advisory) |
| **Shell argument validation** | 셸 삽입 전 sanitize |
| **CI injection scanner** | 모든 agent/workflow/command 파일에서 injection 벡터 스캔 |
| **Safe JSON parsing** | 잘못된 `--fields` 인수가 상태를 손상시키지 않도록 방지 |

---

## 13. v1.39.0 주요 변경사항 (Skill 통합)

### Skill 86 → 59개로 통합

4개의 grouped skill이 31개 micro-skill을 흡수:
- `capture` — todo/backlog/seed/note 캡처 통합
- `phase` — phase 관련 sub-operation 통합
- `config` — 설정 관련 통합
- `workspace` — workspace 관련 통합

기존 skill에 sub-operation을 플래그로 흡수:
| 통합 후 | 흡수된 기능 |
|--------|------------|
| `update --sync` / `--reapply` | sync, reapply-patches |
| `sketch --wrap-up` | sketch wrap-up |
| `spike --wrap-up` | spike wrap-up |
| `map-codebase --fast` / `--query` | fast 모드, 쿼리 모드 |
| `code-review --fix` | review + auto-fix 통합 |
| `progress --do` / `--next` | do, next |

기능 손실 없음.

---

## 14. Run-AI 프로젝트에 적용하는 방법

### 설치

```bash
cd run-ai
npx get-shit-done-cc --claude --local
```

### 기존 프로젝트 문서 기반으로 시작

```bash
# 1. 이미 있는 코드가 있다면
/gsd-map-codebase

# 2. 프로젝트 초기화 (기존 Architecture, Feature Spec, ERD 문서 내용으로 답변)
/gsd-new-project

# 3. Phase 1: 인프라 + 기반
/gsd-discuss-phase 1       # "Spring Boot 4 + Next.js 16 모노레포, Docker Compose"
/gsd-plan-phase 1
/gsd-execute-phase 1
/gsd-verify-work 1

# 4. Phase 2: AI 파이프라인
/gsd-discuss-phase 2       # "Claude → 분석, Gemini Flash → 분류, Firecrawl → 스크래핑"
/gsd-plan-phase 2
/gsd-execute-phase 2
/gsd-verify-work 2
```

### 우리 Skills를 GSD executor에 주입

`.planning/config.json`:

```json
{
  "agent_skills": {
    "executor": [
      ".claude/skills/spring-conventions",
      ".claude/skills/ai-pipeline",
      ".claude/skills/point-role-system"
    ]
  }
}
```

이렇게 하면 GSD가 코드를 실행할 때 우리 프로젝트의 Spring Boot 패턴, AI 파이프라인 구조, 포인트/등급 규칙을 자동으로 참조한다.

### 기존 .claude/ 파일과의 관계

GSD는 `.planning/` 디렉토리를 사용하고, 우리 파일은 `.claude/`에 있으므로 **충돌 없이 공존**한다.

| | 우리의 `.claude/` 파일 | GSD `.planning/` |
|---|---|---|
| 역할 | 프로젝트 특화 도메인 지식 | 워크플로우 자동화 엔진 |
| 사용 시점 | 직접 `/command` 호출 또는 자동 skill 로드 | `/gsd-*` 커맨드 |
| 병행 사용 | 그대로 유지 | 추가 설치 |
