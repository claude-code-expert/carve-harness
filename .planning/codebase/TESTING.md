---
doc: TESTING
mapped: 2026-07-06
last_mapped_commit: (not a git repo)
---

# TESTING — 테스트

## 현황: 테스트 스위트 없음

이 저장소에는 **자동화된 테스트 스위트가 없다.** 테스트 프레임워크·테스트 파일·CI 설정 파일 부재. (앱이 아니라 설정/템플릿이므로 예상된 상태.)

## 이 저장소의 "검증" 수단 (테스트 대체물)

| 수단 | 무엇을 검증 | 근거 |
|------|------------|------|
| `bash -n` | 훅 4종 셸 문법 | `HARNESS-TEMPLATE-MANUAL.md §6` — "✅ bash -n 통과" |
| `json.load` | `settings.json` 유효성 | `HARNESS-TEMPLATE-MANUAL.md §6` |
| `/harness-audit` 커맨드 | 3기둥 구성(훅 등록·rules 로드·specs 존재) 자가 점검 | `.claude/commands/harness-audit.md` |
| frontmatter 점검 | 27파일 SKILL/agents/rules frontmatter | `HARNESS-TEMPLATE-MANUAL.md §6` |
| 수동 출처 검증 표 | 훅 문법·GSD repo·docs 대조 | `HARNESS-TEMPLATE-MANUAL.md §6` 할루시네이션 표 |

## 이 템플릿이 대상 프로젝트에 강제하는 테스트 규칙

`.claude/rules/common/testing.md` (`**/*`):
- **완료는 테스트로 증명한다.**
- **실패하는 테스트부터 (red→green).**
- `> [테스트 커버리지 기준 — 내용없음]` — 커버리지 임계값 미정의 (스텁).

## 대상 프로젝트에서 실행되는 게이트 (테스트 인접)

`stop-verify.sh`가 Stop 이벤트마다 실행 — 엄밀히는 테스트가 아니라 **빌드/타입 게이트**:
- Java: `./gradlew compileJava` (컴파일만, 테스트 태스크 아님)
- TS: `pnpm exec tsc --noEmit` (타입체크만)
- 실패 시 `exit 2`로 응답 종료 차단.

> ⚠️ 갭: `stop-verify.sh`는 컴파일·타입만 본다. `testing.md`가 요구하는 "테스트로 증명"을 실제로 실행하는 게이트는 없다. 대상 프로젝트에서 `./gradlew test` / `pnpm test`를 훅에 추가해야 규칙과 게이트가 일치한다. (→ CONCERNS.md 참조)

## 커버리지 / 모킹

- 해당 없음 (테스트 코드 없음).
