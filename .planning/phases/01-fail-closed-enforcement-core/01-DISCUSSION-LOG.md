# Phase 1: Fail-Closed Enforcement Core - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-06
**Phase:** 1-Fail-Closed Enforcement Core
**Areas discussed:** Fail-closed 폭발반경, Always-on 규칙 범위, Stop 타임아웃 대응

---

## 회색지대 선택 (present_gray_areas)

| Gray area | Description | Selected |
|-----------|-------------|----------|
| Bash-write 커버리지 (GUARD-03) | 어떤 셸 쓰기패턴 차단, 무엇을 out-of-scope 천장으로 | |
| Fail-closed 폭발반경 (GUARD-01) | jq 부재/JSON 깨짐 hard-fail을 어디까지 확장 | ✓ |
| Always-on 규칙 범위 (CFG-01) | 어떤 rules가 `paths:` 제거 | ✓ |
| Stop 타임아웃 대응 (GATE-02) | 60s 침묵 무력화 방지 전략 | ✓ |

**Notes:** Bash-write 커버리지 미선택 → Claude 재량 기본값으로 CONTEXT에 기록(리다이렉트/`sed -i`/`cp`·`mv` 보호경로 대상만 차단, 나머지 문서화된 천장).

---

## Fail-closed 폭발반경 (GUARD-01)

| Option | Description | Selected |
|--------|-------------|----------|
| 가드+Bash만 | 쓰기경로(pretool-guard, Bash-write)만 exit 2. Stop은 jq 없으면 테스트 스킵+stderr 경고(비차단). jq 없는 환경서도 완료 가능. 차단 시 사유 명시. | ✓ |
| 전 훅 hard-fail | Stop 게이트도 jq 부재 시 exit 2. 최고 엄격, 단 jq 미설치면 완료 불가. | |

**User's choice:** 가드+Bash만 (권장)
**Notes:** 쓰기 차단만 fail-closed, 검증은 best-effort 유지 — jq 미설치 환경 작업 마비 회피.

---

## Always-on 규칙 범위 (CFG-01)

| Option | Description | Selected |
|--------|-------------|----------|
| common/ 3개 전부 | git-workflow·security·testing `paths:` 키 제거 → 항상 주입. java/react는 확장자 scoped 유지. | ✓ |
| security+git만 | testing은 코드 있을 때만 필요 → `paths:["**/*"]` 유지. | |

**User's choice:** common/ 3개 전부 (권장)
**Notes:** 셋 다 현재 `paths:["**/*"]` — glob 로딩 자체가 C10 버전 드리프트 대상이라 키 제거로 면역화.

---

## Stop 타임아웃 대응 (GATE-02)

| Option | Description | Selected |
|--------|-------------|----------|
| 명시 timeout + 경량 유지 | settings.json Stop 훅에 timeout 명시. 검증 compile+test 경량, 증분화는 Phase 5 GATE-03로. | ✓ |
| 증분화 앞당김 | 변경모듈만 검증(GATE-03을 Phase 5→1). 근본해결이나 Phase 경계 흐림. | |
| 문서화만 | 리스크 주석/규칙 기록, 설정 변경 없음. 실효 차단 없음. | |

**User's choice:** 명시 timeout + 경량 유지 (권장)
**Notes:** 침묵 무력화만 이번 Phase에서 제거, 증분화는 경계 넘지 않고 Phase 5로.

---

## Claude's Discretion

- Bash-write 커버리지(GUARD-03) 기본값: 리다이렉트(`>`/`>>`/`tee`) + in-place(`sed -i`/`perl -i`) + `cp`/`mv`/`install`이 보호패턴 대상일 때 차단, 탐지는 `.tool_input.command` 문자열 매치. 파이프/난독화/읽기경로는 문서화된 out-of-scope 천장. 보호패턴은 `pretool-guard.sh`와 단일 출처 공유.
- GATE-01 루프 방지 문구/exit 처리, CFG-02/03/04 기계적 적용은 SC대로.

## Deferred Ideas

- 변경모듈 증분 검증 → Phase 5 GATE-03.
- 시크릿 내용 스캔(파일 내용 패턴) → Phase 5 GUARD-04.
- Bash 읽기경로 완전차단 → REQUIREMENTS Out of Scope(deny-list best-effort).
