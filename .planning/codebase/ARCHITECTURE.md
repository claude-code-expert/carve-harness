---
doc: ARCHITECTURE
mapped: 2026-07-06
last_mapped_commit: (not a git repo)
---

# ARCHITECTURE — 아키텍처

## 한 줄 요약

파일로 구현한 **AI 에이전트 하네스**. 핵심 조직 원리는 **3기둥**(제약·피드백·상태). 앱이 아니라 Claude Code에 드롭인하는 규칙·훅·에이전트 집합이다.

## 지배적 패턴 — 3기둥 (Three Pillars)

`CLAUDE.md`와 `HARNESS-TEMPLATE-MANUAL.md §0`이 정의하는 중심 아키텍처:

| 기둥 | 구현 파일 | 역할 |
|------|----------|------|
| **제약 (Constraints)** | `CLAUDE.md` + `.claude/rules/*` + `pretool-guard.sh` | 위험·금지 동작 사전 차단 |
| **피드백 (Feedback)** | `posttool-format.sh` + `stop-verify.sh` + `.claude/agents/*` | 포맷·빌드·검증 사후 개입 |
| **상태 (State)** | `session-handoff.sh` + `specs/` | 세션 인계 + SDD 산출물 축적 |

## 제어 흐름 (훅 라이프사이클)

`settings.json` → 훅 등록 → Claude Code 이벤트마다 발화. `HARNESS-TEMPLATE-MANUAL.md §3`에 PlantUML 시퀀스 존재.

```
SessionStart → session-handoff start   (HANDOFF.md 복원 → 이전 맥락 주입)
     ↓
PreToolUse(Write|Edit) → pretool-guard  (보호파일? → exit 2 차단 / 아니면 exit 0)
     ↓ (허용 시)
PostToolUse(Write|Edit) → posttool-format (확장자 감지 → spotless/prettier)
     ↓
Stop → stop-verify   (gradle compile + tsc --noEmit → 실패 시 exit 2 종료차단)
     ↓
PreCompact → session-handoff save   (HANDOFF.md 저장)
```

**핵심 불변식**: 차단은 반드시 `exit 2`. `exit 1`은 비차단으로 처리되어 위험 동작이 통과한다 (`HARNESS-TEMPLATE-MANUAL.md §2.2`).

## 계층 / 추상화

전통적 SW 계층은 없다. 대신 **역할 분리** 추상화:

- **결정성(훅) vs 판단(에이전트)**: 훅은 셸로 결정적 게이트. 에이전트는 LLM 판단.
- **생성 vs 검증 분리**: `AGENTS.md` — Generator(구현)와 Evaluator(검증) 분리로 Self-Eval Blindspot 방지.
- **경로 기반 규칙 로딩**: `.claude/rules/*/`가 frontmatter `paths:` glob으로 대상 파일에만 자동 적용 (java → `**/*.java`, react → `**/*.ts,tsx`).
- **언어 자동 감지**: 훅이 확장자·마커파일(`gradlew`, `package.json`)로 스택 판별 → 한 벌로 다중 스택 커버.

## 진입점 (Entry Points)

| 진입점 | 트리거 |
|--------|--------|
| `.claude/settings.json` | Claude Code 세션 시작 시 훅 등록 로드 |
| `CLAUDE.md` / `AGENTS.md` / `.claude/rules/*` | 컨텍스트로 자동 주입 (제약 기둥) |
| `.claude/commands/*.md` | 사용자 `/plan`·`/verify`·`/review`·`/commit`·`/harness-audit` 호출 |
| `.claude/skills/*/SKILL.md` | `handoff`·`changelog` 트리거 |
| `.claude/hooks/*.sh` | 위 라이프사이클 이벤트 |

## 확장 방향

새 스택 추가 = `.claude/rules/<stack>/` + 훅 case 분기 추가 (`HARNESS-TEMPLATE-MANUAL.md §5`). 규칙은 hookify로 결정적 훅 승격 권장 (`RULES.md`).
