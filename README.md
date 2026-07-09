# Claude 하네스 (언어 무관 드롭인)

[English](README.en.md) · 현재 버전 **v0.0.4** · 변경 내역 [CHANGELOG.md](CHANGELOG.md) · 강좌 [HARNESS_GUIDE.md](HARNESS_GUIDE.md)

코딩 에이전트의 규칙 위반을 "설득"이 아니라 **훅 exit 2로 차단**하는 가드레일 템플릿.
프로젝트 루트에 드롭인하면 즉시 동작한다.

## 특징

| 기둥 | 동작 |
|------|------|
| **제약** | 보호 경로(`.env`·prod·마이그레이션)·하드코딩 시크릿 쓰기를 PreToolUse 훅이 차단. jq 부재·JSON 파손 시 fail-closed |
| **피드백** | Stop 훅이 빌드·타입·테스트 실패 시 완료 선언 차단 — 변경된 스택만 증분 검증 |
| **상태** | 세션 종료·압축 시 핸드오프 자동 저장(실제 TODO·결정 수집), 시작 시 복원 |
| **관측** | 모든 훅 판정을 `logs/*.jsonl`에 기록 (PII 마스킹), 리포트·회전 지원 |
| **자가감사** | `/harness-audit` — 38개 기계 체크로 하네스 오구성 PASS/FAIL |

**구성 요소**: 훅 8종(Claude Code 전용, 6 이벤트) · 슬래시 커맨드 14종 · 에이전트 13종 · 스킬 22종 · 규칙 17종 · 테스트 10 스위트(106건)

**크로스 에이전트**: 훅 차단은 Claude Code 전용. Cursor/Codex 등은 `AGENTS.md` 정본 + `.githooks/pre-commit`이 커밋 시점에 최종 차단.

**오프라인 완결**: jq·shellcheck 정적 바이너리 내장(`vendor/bin`, SHA256 검증) — 인터넷 없이 설치 가능.

## 설치

```bash
cd /path/to/your-project
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash
```

오프라인: `HARNESS_SRC_DIR=/path/to/harness-copy bash /path/to/harness-copy/install.sh`

- 기존 파일은 건드리지 않는다(SKIP 보고) — 설치 목록은 `.claude/harness-manifest.txt`에 기록.
- 설치 끝에 `/harness-audit` 자동 실행 — 38 PASS면 전 게이트 활성.

**초기 설정** (선택, 모든 항목 엔터로 skip):

```bash
bash install.sh setup
```

git init · jq PATH · LICENSE 생성(MIT/Apache-2.0) · 보호 경로 추가 · 도메인 규칙 수집 · 스택 감지 리포트 · GSD 설치 제안.
도메인 규칙·스택 게이트 보강은 `GUIDE.md` §8 참고.

## 업데이트 / 롤백

```bash
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash -s -- update
bash install.sh rollback   # 직전 버전 복원 (네트워크 불필요)
```

- update: 원격 `VERSION` 비교(같으면 no-op) → manifest 범위만 패치, 변경 파일은 `logs/harness-backup/v<이전>/` 자동 백업, 사용자 파일 불가침.
- rollback: 최신 백업 복원 + 버전 스탬프 복귀. 백업은 소비 — 연속 실행 시 그 이전 버전으로.
- 배포 절차는 `RELEASE.md`.

## 제거

```bash
bash uninstall.sh          # 드라이런 — 삭제 목록만 출력
bash uninstall.sh --yes    # 실제 제거 (manifest 범위만, 원래 있던 파일 안전)
```

## 사용법

설치하면 게이트는 자동이다 — 보호 경로 쓰기 시도는 차단되고, 응답 종료 시 변경 스택만 검증되고, 세션 경계에서 상태가 저장된다. 수동 도구:

| 명령 | 용도 |
|------|------|
| `/harness-audit` | 하네스 구성 38체크 PASS/FAIL |
| `/plan` `/verify` `/review` `/commit` | SC 분해 · SC 검증 · 코드 검토 · 커밋 준비 |
| `/squad-*` (8종) | 기획→리뷰→QA→리팩토링→디버그→보안→문서→Git 파이프라인 |
| `bash .claude/hooks/logs-report.sh [days]` | 훅 판정 로그 요약 (`--rotate N` 회전) |

커스터마이징(보호 경로·포맷터·검증 명령·새 스택)·전체 레퍼런스는 **`GUIDE.md`** 참고.

## 구조

```
├── CLAUDE.md / AGENTS.md    # 규칙 정본 (Claude / 크로스 에이전트)
├── VERSION · CHANGELOG.md · RELEASE.md
├── install.sh / uninstall.sh   # 설치·update·rollback·setup / 제거
├── vendor/bin/              # 내장 jq·shellcheck (+ SHA256SUMS)
├── .githooks/pre-commit     # 에이전트 무관 커밋 게이트
├── specs/                   # 상태: 핸드오프·결정 기록
└── .claude/
    ├── settings.json        # 훅 6이벤트 등록
    ├── hooks/  (8종 + tests 10 스위트)
    ├── commands/ (14종) · agents/ (13종) · skills/ (22종) · rules/ (17종)
```

## 한계

- 훅 차단은 Claude Code 전용 — 타 에이전트는 pre-commit이 커밋 시점 차단.
- Bash 쓰기 가드는 best-effort: 파이프·heredoc 간접 우회 미탐 (pre-commit이 2차 차단).
- Stop 게이트 스택: Java/Node/Python/bash — 그 외는 미검증 통과.
- `rules/` 상시 로드로 세션 시작 토큰 증가.

## 로드맵

- [ ] 스택 게이트 확장: Go·Rust (감지→gofmt/vet/test, cargo)
- [ ] Bash 간접 쓰기(파이프·heredoc) 탐지 강화
- [ ] deny 패턴 변형 커버 (`rm -r -f` 등)
- [ ] rollback 시 신규 추가 파일 정리 (manifest diff)
- [ ] 시맨틱 버전 비교 (다운그레이드 방지)
- [ ] 스킬 트리거 문구(description) 수준 중복 검사

## 버전 이력

| 버전 | 날짜 | 요약 |
|------|------|------|
| v0.0.4 | 2026-07-09 | fix: 설치 목록에 VERSION 포함 — 설치본 셀프테스트 실패·체인 설치 버전 소실 수정 · 하네스 강좌(HARNESS_GUIDE.md) 추가 |
| v0.0.3 | 2026-07-08 | 대화형 설정 `setup` · update-안전 패턴 확장 파일 · LICENSE 자동 생성 |
| v0.0.2 | 2026-07-08 | `update`/`rollback` CLI · VERSION↔CHANGELOG pre-commit 게이트 · 배포 문서 |
| v0.0.1 | 2026-07-08 | 최초 완성본 — fail-closed 가드·Stop 게이트·JSONL 관측·핸드오프·자가감사·오프라인 설치기 |

상세는 [CHANGELOG.md](CHANGELOG.md).
