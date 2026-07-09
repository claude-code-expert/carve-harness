# Changelog

하네스 버전별 변경 기록. 형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 축약, 버전은 [SemVer](https://semver.org/lang/ko/).

> **규칙**: `VERSION` 파일이 바뀌는 커밋에는 반드시 해당 버전 항목(`[X.Y.Z]`)이 이 파일에 함께 스테이징되어야 한다 — `.githooks/pre-commit`이 기계적으로 차단, 작성은 `/version-changelog` 스킬. 배포 절차는 `RELEASE.md`.

## [0.0.7] - 2026-07-09

### Reverted
- v0.0.6의 소스 레포 교체를 되돌림 — 소스는 **의도적으로 사설(`wevesolutions/harness`)**이 맞다. 404의 근본 원인은 레포 위치가 아니라 **인증 누락**: private 레포는 GitHub이 토큰 없는 raw/codeload 접근에 404를 반환한다. `install.sh` 기본 `HARNESS_REPO`와 예시 URL 4곳을 사설 레포로 원복.

### Fixed (docs)
- README(한/영)에 "사설 소스 레포 토큰" 절 추가 — 토큰 발급·사용 3방법(① `gh auth token` ② PAT classic/fine-grained ③ 오프라인 `HARNESS_SRC_DIR`) + SSO 인가·토큰 이중 전달·최소권한·노출금지 주의. install·online update 공통. (v0.0.2 concise 재작성 때 삭제됐던 안내를 되살려 확장.)

## [0.0.6] - 2026-07-09

### Fixed (reverted in 0.0.7 — 잘못된 수정)
- ~~`install.sh` 기본 소스 레포를 사설 `wevesolutions/harness`에서 공개 `claude-code-expert/carve-harness`로 교체.~~ 지시 없이 소스 레포를 바꾼 잘못된 수정. 사설 레포는 정상이고 토큰이 정답 — 0.0.7에서 원복.

## [0.0.5] - 2026-07-09

### Added
- `CLAUDE.md` 응답 언어 프로토콜: 영문 작업 요약 먼저 → 한글 최종 결론(무엇을/왜/주의점 1블록), 각 1회. 인용된 영문·에러 출력엔 해당 부분만 한글 주석. 배포 파일이라 신규 설치 시 함께 전파(대상에 자체 CLAUDE.md가 있으면 기존 SKIP 시맨틱으로 미적용 — 수동 병합 필요).

## [0.0.4] - 2026-07-09

### Fixed
- `VERSION`을 `HARNESS_PATHS`에 추가 — 설치본에 루트 VERSION이 빠져서 생기던 두 버그 수정:
  1. 설치본 셀프테스트 실패: 함께 실리는 `remote-install.test.sh`가 자기 루트를 설치 소스로 재사용하는데 update 모드가 `$SRC/VERSION`을 요구 → 모든 설치본에서 update/rollback 4케이스 연쇄 실패.
  2. 체인 설치 버전 소실: 설치본 A를 `HARNESS_SRC_DIR` 소스로 프로젝트 B에 설치하면 B에 버전 스탬프가 안 생겨 B가 영원히 update 불가("unknown").
  대상 프로젝트에 자체 `VERSION`이 이미 있으면 기존 SKIP 시맨틱이 보호(불가침).

### Added
- `HARNESS_GUIDE.md` — 하네스 엔지니어링 강좌 (개념·구조·단계별 구축·실증·워크플로우).

## [0.0.3] - 2026-07-08

### Added
- `install.sh setup` — 대화형 초기 설정 (전 항목 엔터 skip, tty 없으면 안전 통과): git init 제안 · jq PATH 셸 rc 반영 · LICENSE 생성(MIT 내장 템플릿 / Apache-2.0 공식 원문 다운로드) · 보호 경로 추가 · 도메인 규칙 CLAUDE.md 축적 · 스택 감지 리포트 · GSD 설치 제안.
- `protected-extra.regex` / `secrets-extra.regex` — 프로젝트별 패턴 확장 파일: `lib-protected.sh`가 OR-병합, 가드·pre-commit 즉시 반영, manifest 밖이라 **업데이트에도 보존** (기존 lib 직접 수정 방식은 update 시 덮임).
- `vendor/licenses/MIT.txt` — LICENSE 생성용 내장 템플릿.

### Changed
- 설치 후 사용자 TODO 10항목 → 대화형 setup 7항목 자동화 + 수동 3항목(도메인 지식·미지원 스택 게이트·팀 공지)으로 축소. `/harness-audit` 실행 항목 제거 — 설치기가 원래 자동 실행.
- `remote-install.test.sh` 10→13케이스 (setup 위저드 / extra-regex 가드 반영 / 비대화형 안전).
- GUIDE §8.1–8.3 — 수동 3항목 실행 레시피: 도메인 규칙 형식·훅 승격 매핑, Go 스택 게이트 복붙 워크스루, 팀 공지문 템플릿.

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
