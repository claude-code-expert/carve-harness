---
doc: STACK
mapped: 2026-07-06
last_mapped_commit: (not a git repo)
---

# STACK — 기술 스택

> ⚠️ 이 저장소는 **애플리케이션이 아니라 Claude Code 하네스 템플릿**이다.
> "이 저장소를 구성하는 스택"과 "이 템플릿이 겨냥하는 대상 프로젝트의 스택"을 구분해야 한다.

## 이 저장소를 구성하는 스택 (실제 실행 자산)

| 계층 | 기술 | 근거 파일 |
|------|------|----------|
| 훅 스크립트 | Bash (`#!/usr/bin/env bash`) | `.claude/hooks/*.sh` |
| JSON 파싱 | `jq` (훅 stdin 파싱, 환경변수 방식 아님) | `.claude/hooks/pretool-guard.sh`, `posttool-format.sh` |
| 설정 | JSON | `.claude/settings.json` |
| 문서·규칙·에이전트·스킬·커맨드 | Markdown (+ YAML frontmatter) | `CLAUDE.md`, `.claude/**/*.md` |
| 플랫폼 | Claude Code (hooks / agents / skills / commands / rules) | `.claude/` 전체 |

**런타임 없음.** `package.json`·`build.gradle`·`requirements.txt` 등 빌드 파일 부재. 컴파일·테스트 대상 소스코드 없음. 이 저장소의 "실행"은 Claude Code가 훅·에이전트를 로드하는 것이 전부다.

## 이 템플릿이 겨냥하는 대상 프로젝트 스택

훅이 파일 확장자로 언어를 자동 감지해 대상 프로젝트에 개입한다:

| 대상 스택 | 감지 트리거 | 도구 (대상 프로젝트에 설치 전제) |
|-----------|------------|-------------------------------|
| Java/Spring | `**/*.java`, `gradlew` 존재 | `./gradlew spotlessApply`, `./gradlew compileJava` |
| React/Next/TS | `**/*.ts`, `**/*.tsx`, `package.json` 존재 | `pnpm exec prettier`, `pnpm exec tsc --noEmit` |

근거: `.claude/hooks/posttool-format.sh` (spotless/prettier case 분기), `.claude/hooks/stop-verify.sh` (gradle/tsc case 분기), `.claude/rules/java-spring/`, `.claude/rules/react-next/`.

## 전제 도구 (호스트에 필요)

| 도구 | 용도 | 근거 |
|------|------|------|
| `jq` | 훅의 stdin JSON 파싱 | `README.md` 설치 3단계, 모든 훅 |
| `pnpm` | 프론트 포맷/타입체크 | `posttool-format.sh`, `stop-verify.sh` |
| `./gradlew` | 백엔드 빌드/포맷 | `posttool-format.sh`, `stop-verify.sh` |
| `git` | 핸드오프 브랜치 기록 | `session-handoff.sh` (`git branch --show-current`) |
| GSD (`npx get-shit-done-cc`) | SDD 워크플로우 (선택) | `README.md`, `HARNESS-TEMPLATE-MANUAL.md §4.2` |

## 버전·의존성 관리

- 잠금 파일 없음(런타임 의존성 없음).
- 유일한 외부 의존성은 **Claude Code 자체의 훅/스킬 문법** — 버전에 따라 바뀔 수 있음. 매뉴얼이 명시적으로 `/hooks`·`/skills`로 현행 확인을 권고한다 (`HARNESS-TEMPLATE-MANUAL.md §6`).
