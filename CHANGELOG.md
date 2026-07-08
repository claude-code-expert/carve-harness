# Changelog

하네스 버전별 변경 기록. 형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 축약, 버전은 [SemVer](https://semver.org/lang/ko/).

> **규칙**: `VERSION` 파일이 바뀌는 커밋에는 반드시 해당 버전 항목(`[X.Y.Z]`)이 이 파일에 함께 스테이징되어야 한다 — `.githooks/pre-commit`이 기계적으로 차단, 작성은 `/version-changelog` 스킬. 배포 절차는 `RELEASE.md`.

## [0.0.2] - 2026-07-08

### Added
- `install.sh update` — CLI 버전 패치: 원격 `VERSION` 비교(같으면 no-op), manifest 범위만 갱신, 변경 파일은 `logs/harness-backup/v<이전>/` 자동 백업, 설치 때 SKIP된 사용자 파일 불가침, 신규 파일은 설치+manifest 기록.
- `install.sh rollback` — 직전 업데이트 되돌리기: 최신 백업 복원 + 버전 스탬프 복귀, 백업은 소비(연속 실행 시 그 이전 버전으로). 네트워크 불필요.
- 루트 `VERSION` 파일 + 설치 스탬프 `.claude/harness-version` (update 비교 기준).
- pre-commit 게이트 (3): `VERSION` 변경 커밋에 CHANGELOG 항목 누락 시 차단.
- `/version-changelog` 스킬 — VERSION·CHANGELOG.md·README 버전 이력 동시 갱신 절차.
- `RELEASE.md` — 배포 절차 문서.
- `CHANGELOG.md` (이 파일).

### Changed
- `remote-install.test.sh` 5→10케이스 (update no-op/패치/보존, rollback).
- `uninstall.sh` — 버전 스탬프 제거 포함.

## [0.0.1] - 2026-07-08

### Added
- 최초 완성본 — v1 하드닝 마일스톤(Phase 1–5) + 오프라인·크로스에이전트 확장:
  - fail-closed 가드: 전 쓰기도구 + Bash-write + 하드코딩 시크릿 내용 스캔(`pretool-guard.sh`), 차단은 `exit 2`.
  - Stop 게이트: 스택 감지 빌드·타입·테스트, 변경 모듈만 증분 검증, 무한루프 차단(`stop-verify.sh`).
  - 관측: 6개 훅 진입점 JSONL 이벤트 로그(`logs/*.jsonl`, PII 마스킹) + `logs-report.sh` 요약/회전.
  - 상태: 실데이터 핸드오프(STATE.md TODO·미완료 플랜·DECISIONS 최근5), `SessionEnd` 포함(`session-handoff.sh`).
  - 자가감사: `/harness-audit` 38개 기계 체크 (AUDIT-01~06).
  - 오프라인 설치기: `install.sh`(vendor jq/shellcheck, SHA256 검증, 멱등) + `uninstall.sh`(manifest 기반, 드라이런 기본).
  - 크로스에이전트: `AGENTS.md` 정본 + `.githooks/pre-commit` 커밋 게이트 (jq 불필요).
  - squad 커맨드/에이전트 8종 + mattpocock 파생 스킬 19종.
