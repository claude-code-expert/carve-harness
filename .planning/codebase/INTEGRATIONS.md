---
doc: INTEGRATIONS
mapped: 2026-07-06
last_mapped_commit: (not a git repo)
---

# INTEGRATIONS — 외부 연동

> 이 템플릿 자체는 네트워크 서비스·DB·인증 제공자와 직접 연동하지 않는다.
> "연동"은 대부분 **로컬 도구 호출**과 **Claude Code 플랫폼 훅** 형태다.

## 데이터베이스 / 외부 API / 인증 제공자

**없음.** 이 저장소에는 DB 연결, 외부 HTTP 클라이언트, OAuth/인증 제공자 설정이 존재하지 않는다. (대상 프로젝트가 가지는 것이지 템플릿이 가지는 것이 아니다.)

- 단, `pretool-guard.sh`가 대상 프로젝트의 시크릿/prod 설정/마이그레이션 파일 수정을 **차단**한다: `*.env`, `*/application-prod.yml`, `*secret*`, `*/db/migration/*`.
- `settings.json`의 `permissions.deny`가 `.env`·`*secret*` 파일 **읽기**를 차단한다.

## 플랫폼 통합 — Claude Code 훅

`settings.json`에 등록된 이벤트 훅이 이 저장소의 핵심 "연동 지점"이다:

| 이벤트 | 훅 | matcher | 동작 |
|--------|----|---------|------|
| PreToolUse | `pretool-guard.sh` | `Write\|Edit` | 보호 파일 수정 차단 (`exit 2`) |
| PostToolUse | `posttool-format.sh` | `Write\|Edit` | 언어 감지 포맷 (spotless/prettier) |
| Stop | `stop-verify.sh` | (전체) | 빌드/타입 게이트 (`exit 2`) |
| SessionStart | `session-handoff.sh start` | (전체) | `specs/HANDOFF.md` 복원 |
| PreCompact | `session-handoff.sh save` | (전체) | `specs/HANDOFF.md` 저장 |

## 로컬 도구 호출 (훅 → 셸)

| 대상 | 호출 | 위치 |
|------|------|------|
| Spotless (Java 포맷) | `./gradlew spotlessApply -PspotlessFiles=$f` | `posttool-format.sh` |
| Prettier (TS 포맷) | `pnpm exec prettier --write $f` | `posttool-format.sh` |
| Gradle 컴파일 | `./gradlew compileJava` | `stop-verify.sh` |
| TypeScript 체크 | `pnpm exec tsc --noEmit` | `stop-verify.sh` |
| Git | `git branch --show-current` | `session-handoff.sh` |

## 외부 프로젝트 참조 (문서상)

`HARNESS-TEMPLATE-MANUAL.md §5·§6`이 자산 본문 채우기용으로 참조하는 외부 저장소 (코드 의존성 아님, 복사 출처):

- GSD — `github.com/gsd-build/get-shit-done` (`npx get-shit-done-cc`)
- ECC — `github.com/affaan-m/ECC` (MIT, 스킬·에이전트 본문 출처)
- Claude Code 공식 docs — `code.claude.com/docs/en/hooks`
