# Phase 2: Observability Keystone (JSONL Event Log) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-07
**Phase:** 2-Observability Keystone (JSONL Event Log)
**Areas discussed:** 로그 파일 레이아웃, 훅 커버리지 + 공유 헬퍼
**Areas deferred to Claude's discretion:** 이벤트 스키마 + PII, OBS-02 실패 레코드

---

## 로그 파일 레이아웃

| Option | Description | Selected |
|--------|-------------|----------|
| 일별 파일 | `logs/YYYY-MM-DD.jsonl` — SC glob 일치, 무한 성장 방지, 회전 로직 불필요 | ✓ |
| 단일 파일 | `logs/events.jsonl` — 가장 단순, 무한 성장 | |
| 세션별 파일 | `logs/<session>.jsonl` — session id 필요, 파일 다수 | |

**User's choice:** 일별 파일 (권장)

| Option | Description | Selected |
|--------|-------------|----------|
| gitignore + 상한 없음 | `logs/` gitignore, 회전/정리는 Phase 5 | ✓ |
| gitignore + 회전 지금 | 이번 phase에서 회전까지 | |
| 커밋에 포함 | 로그를 git에 커밋 | |

**User's choice:** gitignore + 상한 없음 (권장)
**Notes:** 리포에 `.gitignore` 부재 → Phase 2가 새로 생성. `.env*` gitignore는 별도 보안 갭으로 deferred 기록.

---

## 훅 커버리지 + 공유 헬퍼

| Option | Description | Selected |
|--------|-------------|----------|
| 5개 훅 전부 | guard/format/stop/handoff×2 모두 기록 — SC1 "every hook fire" 일치 | ✓ |
| 쓰기 경로만 | guard+format만 — SC1과 상충 | |

**User's choice:** 5개 훅 전부 (권장)

| Option | Description | Selected |
|--------|-------------|----------|
| 공유 헬퍼, best-effort | `log-event.sh` 단일 출처, 로그 실패가 훅 exit code 불변 | ✓ |
| 인라인 per-hook | 각 훅에 append 직접 삽입 — 중복/드리프트 | |

**User's choice:** 공유 헬퍼, best-effort (권장)
**Notes:** fail-safety가 핵심 — 로깅이 Phase 1 fail-closed 불변식을 깨면 안 됨.

---

## Claude's Discretion

- **이벤트 스키마 + PII:** `{ts, event, tool, decision, target}`, ts=ISO8601 UTC, target은 PROTECTED_RE 매치 부분 마스킹(security.md 준수).
- **OBS-02 실패 레코드:** 포맷터 missing/error 감지 → `format-fail` 레코드({formatter, file, reason}); 정상 stdout은 계속 침묵.
- **동시성:** 단일 짧은 라인 `>>` append 원자성(PIPE_BUF) 신뢰, 락 없음 — documented ceiling.

## Deferred Ideas

- 로그 회전·보관 상한·정리 → Phase 5 hardening.
- `.gitignore`에 `.env*` 추가(Phase 1 보안 천장 근본방어, 현재 부재) — Phase 2 범위 밖, 관측된 갭.
- >4096B 이벤트 라인 원자성 → 미발생 가정, 필요 시 flock (Phase 5).
