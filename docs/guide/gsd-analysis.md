# Get Shit Done (GSD) 분석

> 분석일: 2026-04-06
> GitHub: https://github.com/gsd-build/get-shit-done
> Stars: 47k | License: MIT | 성격: **설치형 워크플로우 엔진**

## 한줄 요약

Claude Code를 위한 경량 메타프롬프팅·컨텍스트 엔지니어링·스펙 기반 개발 시스템. 컨텍스트 윈도우가 차면서 품질이 떨어지는 "context rot" 문제를 해결한다.

---

## 설치

```bash
npx get-shit-done-cc@latest                  # 대화형 (런타임/위치 선택)
npx get-shit-done-cc --claude --local        # 현재 프로젝트에 설치
npx get-shit-done-cc --claude --global       # 전역 설치

# 확인
claude → /gsd:help

# 업데이트
npx get-shit-done-cc@latest

# 삭제
npx get-shit-done-cc --claude --local --uninstall
```

호환: Claude Code, OpenCode, Gemini CLI, Codex, Copilot, Cursor, Windsurf, Antigravity

---

## 핵심 워크플로우: 6단계 루프

```
/gsd:new-project          ← 1. 초기화 (질문 → 리서치 → 요구사항 → 로드맵)
    ↓
/gsd:discuss-phase 1      ← 2. 구현 결정 사전 토론 (회색 영역 해소)
    ↓
/gsd:plan-phase 1         ← 3. 리서치 → XML 태스크 플랜 → 검증
    ↓
/gsd:execute-phase 1      ← 4. Wave 병렬 실행 (fresh context + atomic commit)
    ↓
/gsd:verify-work 1        ← 5. 사용자 수동 검증 (실패 시 자동 디버그)
    ↓
/gsd:ship 1               ← 6. PR 생성
    ↓
(2~6 반복) → /gsd:complete-milestone → /gsd:new-milestone
```

### 각 단계 생성 파일

| 단계 | 생성 파일 | 역할 |
|------|-----------|------|
| new-project | `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md` | 프로젝트 전체 컨텍스트 |
| discuss-phase | `{N}-CONTEXT.md` | 구현 결정 사항 |
| plan-phase | `{N}-RESEARCH.md`, `{N}-{M}-PLAN.md` | 리서치 + XML 태스크 |
| execute-phase | `{N}-{M}-SUMMARY.md`, `{N}-VERIFICATION.md` | 실행 결과 + 검증 |
| verify-work | `{N}-UAT.md` + fix plans (문제 시) | 사용자 검증 결과 |

---

## Wave 실행 (병렬 처리)

의존성 기반 wave 그룹화. 같은 wave 내 병렬, wave 간 순차.

```
WAVE 1 (parallel)        WAVE 2 (parallel)        WAVE 3
┌──────┐ ┌──────┐       ┌──────┐ ┌──────┐       ┌──────┐
│User  │ │Product│  →   │Orders│ │Cart  │  →   │Check │
│Model │ │Model  │       │API   │ │API   │       │out UI│
└──────┘ └──────┘       └──────┘ └──────┘       └──────┘
```

각 executor: 독립된 200K 컨텍스트 → 메인 세션 30~40%만 사용.

---

## XML 플랜 구조

```xml
<task type="auto">
  <n>Create login endpoint</n>
  <files>src/app/api/auth/login/route.ts</files>
  <action>
    Use jose for JWT.
    Validate credentials against users table.
    Return httpOnly cookie on success.
  </action>
  <verify>curl -X POST localhost:3000/api/auth/login returns 200 + Set-Cookie</verify>
  <done>Valid credentials return cookie, invalid return 401</done>
</task>
```

---

## 모델 프로파일

| 프로파일 | Planning | Execution | Verification |
|----------|----------|-----------|--------------|
| `quality` | Opus | Opus | Sonnet |
| `balanced` (기본) | Opus | Sonnet | Sonnet |
| `budget` | Sonnet | Sonnet | Haiku |
| `inherit` | 현재 모델 | 현재 모델 | 현재 모델 |

```bash
/gsd:set-profile budget
```

---

## Quick Mode

```bash
/gsd:quick                           # 기본 (계획→실행)
/gsd:quick --discuss                 # 토론 후 실행
/gsd:quick --research                # 리서치 후 실행
/gsd:quick --full                    # 전체 파이프라인
```

---

## 주요 커맨드

### 코어

| 커맨드 | 용도 |
|--------|------|
| `/gsd:new-project` | 프로젝트 초기화 |
| `/gsd:map-codebase` | 기존 코드 분석 (brownfield) |
| `/gsd:discuss-phase N` | 구현 전 결정사항 토론 |
| `/gsd:plan-phase N` | 리서치 + 계획 + 검증 |
| `/gsd:execute-phase N` | Wave 병렬 실행 |
| `/gsd:verify-work N` | 사용자 수동 검증 |
| `/gsd:ship N` | PR 생성 |
| `/gsd:next` | 다음 단계 자동 감지 |
| `/gsd:complete-milestone` | 마일스톤 완료 + 태그 |
| `/gsd:new-milestone` | 다음 버전 시작 |

### 유틸리티

| 커맨드 | 용도 |
|--------|------|
| `/gsd:progress` | 현재 진행 상황 |
| `/gsd:fast <text>` | 즉시 실행 (계획 없이) |
| `/gsd:review` | 크로스 AI 코드 리뷰 |
| `/gsd:debug <desc>` | 체계적 디버깅 |
| `/gsd:pause-work` / `resume-work` | 세션 중단/복원 |
| `/gsd:ui-phase N` | UI 디자인 계약서 생성 |
| `/gsd:secure-phase N` | 보안 검증 |
| `/gsd:health --repair` | `.planning/` 무결성 검증 |

---

## 멀티 에이전트 오케스트레이션

| 단계 | Orchestrator | Agents |
|------|-------------|--------|
| Research | 조율, 결과 제시 | 4개 병렬 리서처 |
| Planning | 검증, 이터레이션 | Planner + Checker 루프 |
| Execution | Wave 그룹화, 추적 | 각 Executor가 fresh 200K에서 병렬 |
| Verification | 결과 제시, 라우팅 | Verifier + Debugger |

---

## 설정

### 워크플로우 에이전트

| 설정 | 기본값 | 역할 |
|------|--------|------|
| `workflow.research` | `true` | 페이즈별 도메인 리서치 |
| `workflow.plan_check` | `true` | 플랜 목표 달성 검증 |
| `workflow.verifier` | `true` | 실행 후 must-have 확인 |
| `workflow.auto_advance` | `false` | discuss→plan→execute 자동 |
| `workflow.discuss_mode` | `discuss` | `discuss`(인터뷰) / `assumptions`(코드 분석 우선) |

### Git 브랜칭

| 전략 | 동작 |
|------|------|
| `none` (기본) | 현재 브랜치에 커밋 |
| `phase` | 페이즈별 브랜치 |
| `milestone` | 마일스톤별 브랜치 |

---

## Run-AI 적용 방법

### 설치
```bash
cd run-ai
npx get-shit-done-cc --claude --local
```

### 초기화
```bash
claude
/gsd:new-project    # 기존 프로젝트 문서 내용으로 답변
```

### 개발 루프
```bash
/gsd:discuss-phase 1       # Spring Boot + React 모노레포 환경 결정
/gsd:plan-phase 1          # XML 태스크 플랜
/gsd:execute-phase 1       # Wave 병렬 실행
/gsd:verify-work 1         # 수동 확인
/gsd:ship 1                # PR
```

### 우리 Skills를 GSD에 주입
```json
// .planning/config.json
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

---

## GSD vs 우리 `.claude/` 비교

| | 우리 `.claude/` | GSD |
|---|---|---|
| 성격 | 수동 커맨드/에이전트/스킬 | 자동화 워크플로우 엔진 |
| 충돌 | ❌ 없음 | `.planning/` 별도 디렉토리 |
| 강점 | 프로젝트 특화 도메인 지식 | 컨텍스트 관리, 병렬 실행, 자동 검증 |
| 약점 | 수동 오케스트레이션 | 프로젝트 도메인 지식 없음 |
| **결론** | **둘 다 같이 사용** — GSD가 워크플로우 관리, 우리 skills가 도메인 지식 제공 |
