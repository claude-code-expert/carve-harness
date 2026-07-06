# Claude 하네스 템플릿 (Harness Template)

## What This Is

언어무관 Claude Code 하네스 템플릿. 프로젝트 루트에 드롭인하면 **제약·피드백·상태** 3기둥이 파일(훅·규칙·에이전트·스킬)로 즉시 작동한다. Java/Spring 백엔드와 React/Next 프론트를 한 벌로 커버하며, 훅이 파일 확장자로 스택을 자동 감지한다. 대상 독자는 여러 프로젝트에 일관된 AI 작업 가드레일을 깔고 싶은 개발자.

## Core Value

**드롭인 즉시 게이트가 실제로 작동한다** — 위험동작 차단(exit 2), 포맷·빌드·테스트 게이트, 세션 상태 인계가 선언이 아니라 검증된 동작이어야 한다. 규칙만 있고 강제가 없는 하네스는 실패다.

## Requirements

### Validated

<!-- 코드베이스 맵(.planning/codebase/)에서 도출 + 이번 세션 검증 -->

- ✓ 3기둥 훅 4종(pretool-guard·posttool-format·stop-verify·session-handoff) 등록·동작 — existing + 세션 검증
- ✓ 언어 자동감지(`.java`/`.ts`/`gradlew`/`package.json`) — existing
- ✓ 경로 glob 규칙(common·java-spring·react-next) — existing
- ✓ 서브에이전트 5종(evaluator·code/security/silent-failure/state-reviewer) — existing
- ✓ 커맨드 5종(plan·verify·review·commit·harness-audit)·스킬 2종(handoff·changelog) — existing
- ✓ 차단 불변식(`exit 2`) + stdin JSON(jq) 파싱 — existing
- ✓ 보호패턴 우회 구멍 차단(.env.production·application-prod·루트 db/migration) — Phase 0(세션)
- ✓ Stop 게이트에 테스트 실행 + pipefail 근본수정(기존 게이트는 실패를 못 잡았음) — Phase 0(세션)
- ✓ PII 보안 베이스라인·라인 80% 커버리지 규칙 삽입 — Phase 0(세션)

### Active

<!-- 남은 CONCERNS. 모두 검증 가능한 SC로 완료. -->

- [ ] C1: `install.md` 빈 파일 — 설치 절차 채우거나 삭제
- [ ] C7: 핸드오프가 실제 TODO/다음단계를 수집(현재 하드코딩 `[내용없음]`)
- [ ] C8: 포맷 훅 에러 관측성(현재 `2>/dev/null`로 silent)
- [ ] C10: 버전 취약성 대응 — 핵심 규칙 CLAUDE.md 중복, 도입 시 `/hooks` 확인 가이드
- [ ] C11: 위생 파일(`.gitignore`, `LICENSE`) 추가
- [ ] 남은 스텁: `specs/README`·java/react `[추가 규칙]`·스킬 본문(범용 기본값 채움)
- [ ] `/harness-audit` 실효화 — 3기둥 구성 자동 점검이 실제로 통과/실패 판정

### Out of Scope

- 특정 프로덕트 도메인 규칙 하드코딩 — 범용 재사용 템플릿 유지(도메인은 드롭인 후 채움)
- 새 스택(Python·Go 등) 규칙·훅 — 지금은 Java+React만, 확장은 후속 마일스톤
- CI/CD 파이프라인 통합 — 하네스는 로컬 훅 계층, CI는 별도 관심사
- 시크릿 Bash 읽기 완전차단 — deny-list best-effort로 충분, 근본은 "시크릿 레포에 안 두기" 규칙

## Context

- **기반 분석**: `.planning/codebase/` 7문서 + `CONCERNS.md` 11건이 이 프로젝트의 요구 출처.
- **구성 스택 vs 대상 스택**: 이 레포는 Bash+jq+Markdown+JSON으로 만들어졌고, 겨냥 대상은 Java/Spring·React/Next.
- **핵심 자산**: `.claude/hooks/*.sh`(완성·검증됨). 스킬·에이전트 본문은 일부 스텁(`HARNESS-TEMPLATE-MANUAL.md §5`: ECC에서 본문 이식 가능).
- **알려진 취약성**: 훅/스킬/`rules` frontmatter 문법은 Claude Code 버전에 따라 변동(매뉴얼 §6이 명시).

## Constraints

- **Tech stack**: 런타임 의존성 없음. Bash+jq만으로 훅 동작(무거운 도구 도입 금지).
- **Compatibility**: Java+React 두 스택 동시 지원. 스택 감지는 확장자·마커파일로만.
- **Security**: 시크릿 하드코딩·커밋 금지. PII 베이스라인 강제. 차단은 반드시 `exit 2`.
- **Portability**: 범용 드롭인 — 특정 프로젝트 가정 금지. 도메인 규칙은 자리표시로.
- **Git**: Conventional Commits. force push·히스토리 재작성 금지.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 범용 재사용 템플릿 유지 | 여러 프로젝트 드롭인 목적 | — Pending |
| Java+React 두 스택 유지 | 대상 스택 둘 다 | ✓ Good |
| PII 베이스라인 + 라인 80% 커버리지 기본값 | 웹앱 공통 강한 기본값 | ✓ Good |
| Stop 게이트에 테스트 추가, pipefail 근본수정 | 게이트가 실패를 못 잡던 잠복버그 | ✓ Good |
| 코드베이스 맵을 4에이전트 대신 인라인 작성 | 498줄 소규모, 팬아웃 낭비 | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-07-06 after initialization*
