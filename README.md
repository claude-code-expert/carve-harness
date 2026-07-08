# Claude 하네스 템플릿 (언어 무관 드롭인)

Java/Spring · React/Next 공통으로 쓰는 하네스 뼈대. 프로젝트 루트에 그대로 복사해 사용한다.

## 버전 이력

| 버전 | 날짜 | 변경사항 |
|------|------|----------|
| v0.0.3 | 2026-07-08 | 대화형 초기 설정 `install.sh setup` — git init·jq PATH·LICENSE 생성(MIT/Apache-2.0)·보호경로·도메인 규칙·스택 감지·GSD 제안 · update-안전 패턴 확장(`protected-extra.regex`/`secrets-extra.regex`) · 설치 후 수동 TODO 10→3개 |
| v0.0.2 | 2026-07-08 | CLI 업데이트 패치 + 롤백 — `install.sh update`(VERSION 비교·manifest 범위 갱신·자동 백업·사용자 파일 불가침) · `install.sh rollback`(직전 버전 백업 복원) · VERSION 변경 시 CHANGELOG 강제(pre-commit) · `/version-changelog` 스킬 · `RELEASE.md`/`CHANGELOG.md` |
| v0.0.1 | 2026-07-08 | 최초 완성본 — fail-closed 가드(전 쓰기도구+Bash-write+시크릿 내용 스캔) · Stop 증분 검증 게이트 · JSONL 관측 · 실데이터 핸드오프(SessionEnd 포함) · 자가감사 38체크 · 오프라인 설치기(vendor jq/shellcheck, SHA256 검증)+uninstall · 크로스에이전트 pre-commit 게이트 · squad 커맨드/에이전트 · 테스트 10 스위트 95건 |

## 설치

**어느 방식이든 마지막은 동일**: `install.sh`가 vendor 체크섬 검증 → jq·shellcheck 배치 →
훅 권한 → git pre-commit 게이트 활성화 → `/harness-audit` 최종 보고까지 자동으로 수행한다 (멱등 — 재실행 안전).

### A. curl 원라이너 (대상 프로젝트 루트에서)
```bash
cd /path/to/your-project
curl -fsSL https://raw.githubusercontent.com/wevesolutions/harness/main/install.sh | bash
```
사설 레포면 토큰 포함:
```bash
curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
  https://raw.githubusercontent.com/wevesolutions/harness/main/install.sh \
  | GITHUB_TOKEN=$GITHUB_TOKEN bash
```
옵션 (환경변수):

| 변수 | 기본 | 용도 |
|------|------|------|
| `HARNESS_REPO` | `wevesolutions/harness` | 소스 레포 변경 |
| `HARNESS_REF` | `main` | 브랜치/태그 고정 |
| `HARNESS_FORCE=1` | off | 기존 파일 덮어쓰기 (기본은 SKIP + 경고) |
| `HARNESS_SRC_DIR` | — | 네트워크 대신 로컬 복사본에서 설치 (오프라인) |

### B. 오프라인 (에어갭)
```bash
# 온라인 머신에서 레포를 통째로 반입한 뒤:
cd /path/to/your-project
HARNESS_SRC_DIR=/path/to/harness-copy bash /path/to/harness-copy/install.sh
# 또는 그냥 내용물을 복사해 넣고:
cp -R /path/to/harness-copy/. . && bash install.sh
```
인터넷 불필요 — jq(amd64/arm64)·shellcheck 정적 바이너리 내장(`vendor/bin`, SHA256 검증).
jq 없는 머신이면 `~/.local/bin/jq`로 설치된다(sudo 불필요) — PATH 안내가 나오면 반영 후 재실행.

### 설치 동작 원칙
- **기존 파일 불가침**: 대상 프로젝트에 이미 있는 파일(예: 자체 `CLAUDE.md`)은 건드리지 않고 SKIP 보고. 실제 설치된 목록만 `.claude/harness-manifest.txt`에 기록.
- `.gitignore`에 마커 블록(`# >>> harness ... <<<`)으로 런타임 산출물(logs/, .claude/bin/ 등) 무시 규칙 추가.
- 스택 도구(pnpm/gradle/ruff)는 대상 프로젝트 소관 — 없으면 해당 게이트는 skip 기록 후 통과.

### 설치 후 설정 — 대화형 (`install.sh setup`)

설치기가 `/harness-audit`(38체크)까지 자동 실행한다. 프로젝트 맞춤 설정은 대화형으로 — 모든 항목 엔터로 skip:
```bash
bash install.sh setup
```

| 항목 | setup이 하는 일 |
|------|-----------------|
| git 레포 아님 | `git init` + pre-commit 게이트 활성 제안 |
| jq PATH 미반영 | 셸 rc에 1줄 추가 제안 |
| LICENSE 없음 | MIT(내장, 연도·이름 자동) / Apache-2.0(공식 원문 다운로드) 선택 생성 |
| 보호 경로 추가 | 정규식 입력 → `protected-extra.regex` — 가드·pre-commit 즉시 반영, **업데이트에도 보존** |
| 도메인 규칙 | 입력 → `CLAUDE.md`에 축적 (예: "주문 금액 음수 불가") |
| 스택 감지 | Node/Java/Python 게이트 상태 + 미설치 도구·미지원 스택 리포트 |
| GSD (SDD 킷) | `npx get-shit-done-cc --local` 설치 제안 |

시크릿 패턴 추가도 같은 방식: `.claude/hooks/secrets-extra.regex`에 1줄 1정규식 (수동).

> 도메인 규칙 보강, 언어별 스택 게이트 추가, 팀 공지 등은 `GUIDE.md` §8을 참고하여 프로젝트에 맞게 추가로 보강해주십시오.

> Windows는 WSL 필수 (훅이 bash).

### 업데이트 (버전 패치)

새 버전이 나오면 재설치 없이 변경분만 패치:
```bash
curl -fsSL https://raw.githubusercontent.com/wevesolutions/harness/main/install.sh | bash -s -- update
# 오프라인: cd /path/to/your-project && HARNESS_SRC_DIR=/path/to/new-harness bash install.sh update
```
- **버전 비교**: 원격 `VERSION` vs 로컬 `.claude/harness-version` — 같으면 no-op ("이미 최신"). 강제 재패치는 `HARNESS_FORCE=1`.
- **갱신 범위 = manifest만**: 설치 때 SKIP된 사용자 파일(자체 `CLAUDE.md` 등)은 업데이트에서도 불가침. 관리 디렉토리 안에 사용자가 추가한 파일도 보존(오버레이 복사).
- **자동 백업**: 내용이 바뀌는 파일은 교체 전 `logs/harness-backup/v<이전버전>/`에 백업 — 커스터마이징(`lib-protected.sh` 패턴 등)을 덮어썼으면 백업에서 복원해 병합.
- **신규 파일**: 새 릴리스에 추가된 파일은 설치 + manifest 기록. 신규 경로까지 받으려면 `curl | bash -s -- update`(새 설치기 기준) 사용 권장.
- 패치 후 부트스트랩(권한·바이너리)·`/harness-audit`까지 자동 재실행.

**롤백** (직전 업데이트 되돌리기 — 네트워크 불필요):
```bash
bash install.sh rollback
```
- 최신 백업(`logs/harness-backup/v<이전>/`) 복원 + 버전 스탬프 복귀. 백업은 소비 — 연속 실행 시 그 이전 버전으로 내려간다.
- 업데이트로 새로 추가된 파일은 남는다(무해) — 필요 시 수동 삭제.
- 검증: `remote-install.test.sh` — 동일버전 no-op / 패치+백업+스탬프 / 사용자 파일 보존 / 롤백 복원·소비 / 백업 없으면 clean FAIL.

버전별 변경 내역은 `CHANGELOG.md`, 새 버전 배포 절차는 `RELEASE.md` 참고.

### 제거 (uninstall)
```bash
bash uninstall.sh          # 드라이런 — 삭제될 목록만 출력
bash uninstall.sh --yes    # 실제 제거
```
- 제거 범위 = 설치 시 manifest에 기록된 것**만**. 설치 때 SKIP된 원래 파일은 안전.
- `core.hooksPath` 해제 + `.gitignore` 하네스 블록 제거까지 원복.
- `logs/`(감사 기록)·`specs/` 산출물은 사용자 데이터로 남긴다 — 필요 없으면 직접 삭제.
- 검증: `.claude/hooks/tests/remote-install.test.sh` (설치→보존→업데이트→롤백→드라이런→제거 10케이스).

## GSD로 하네스 구성 (SDD)
```bash
# 프로젝트 루트에서 GSD 설치 (온라인)
npx get-shit-done-cc --local
# 워크플로우
/gsd:new-project → /gsd:create-roadmap → /gsd:plan-phase → /gsd:execute-plan → /gsd:verify
# 산출물은 specs/ 에 축적 (핸드오프/결정기록과 함께 상태 기둥 형성)
```

## 구조
```
├── CLAUDE.md            # 제약: 전역 가드레일
├── AGENTS.md            # 에이전트 표준 (크로스 에이전트 정본)
├── RULES.md             # 룰 인덱스
├── VERSION              # 릴리스 버전 (update가 비교, 변경 시 CHANGELOG 강제)
├── CHANGELOG.md         # 버전별 변경 기록 (/version-changelog 스킬로 작성)
├── RELEASE.md           # 배포 절차
├── install.sh           # 설치기: curl 원격 fetch + 로컬 부트스트랩 + update/rollback (멱등)
├── uninstall.sh         # 제거기: manifest 기반, 드라이런 기본
├── vendor/bin/          # 내장 정적 바이너리: jq(amd64/arm64)·shellcheck + SHA256SUMS
├── .githooks/pre-commit # 에이전트 무관 커밋 게이트 (jq 불필요, bash+git만)
├── specs/               # 상태: SDD 산출물 + HANDOFF/DECISIONS
└── .claude/
    ├── settings.json    # 훅 등록 (Pre/Post/Stop/Session/PreCompact)
    ├── bin/             # install.sh가 vendor에서 배치 (gitignore)
    ├── hooks/           # 가드·검증·핸드오프·감사·로그리포트 + tests/
    ├── skills/          # handoff, changelog, version-changelog + mattpocock 파생 19종
    ├── commands/        # plan, verify, review, commit, harness-audit, squad*
    ├── agents/          # evaluator, code/security/silent-failure/state reviewer, squad 8종
    └── rules/           # common + java-spring + react-next (paths glob)
```

## 3기둥 매핑
- 제약: CLAUDE.md + rules/ + pretool-guard.sh
- 피드백: posttool-format.sh + stop-verify.sh + agents/
- 상태: session-handoff.sh + specs/

> ⚠️ 훅 문법·이벤트는 Claude Code 버전에 따라 바뀔 수 있으니 도입 시 `/hooks`로 확인.

## 장점 (왜 이 하네스인가)

- **결정적 강제**: 규칙 위반을 모델의 "자발적 준수"가 아니라 PreToolUse 훅 `exit 2`로 차단. jq 부재·JSON 파손 시 fail-closed(쓰기 전면 차단) — 설득으로 뚫리는 가드레일이 아니다.
- **완료 게이트**: Stop 훅이 빌드·타입·테스트 실패 시 완료 선언을 차단. 변경된 스택만 검증(증분)해 불필요한 대기 없음.
- **상태 연속성**: PreCompact/SessionEnd에 `specs/HANDOFF.md` 자동 저장, SessionStart에 복원 — 컨텍스트 리셋·세션 교체에도 작업이 이어진다.
- **관측성**: 모든 가드 판정이 `logs/*.jsonl`에 남고, 보호 경로는 `<masked>` 처리 — 차단·허용 이력을 사후 감사 가능.
- **자가 검증**: `/harness-audit` 38개 기계 체크 — 하네스 자체의 오구성(훅 미등록·권한 누락·정책-게이트 미매핑)을 PASS/FAIL로 탐지.
- **언어 무관 드롭인**: 파일 복사만으로 이식, 스택은 확장자(glob)로 자동 감지·자동 로드.
- **크로스 에이전트 정본**: 규칙은 `AGENTS.md` 한 곳에 집약, `.cursorrules`·`codex.md`는 포인터만 — 규칙 이중화 없음.

## 한계 (알고 써라)

- **훅 차단은 Claude Code 전용.** 다른 에이전트(Cursor·Codex·Aider)는 AGENTS.md 자율 준수 + **git pre-commit 게이트**(`.githooks/`)가 커밋 시점에 최종 차단 — 커밋 전 단계의 실시간 차단은 없다.
- **런타임 의존**: bash 필수(Windows는 WSL). jq는 `vendor/bin` 내장 + `install.sh`가 배치하므로 오프라인에서도 해결 — 단 install.sh를 안 돌리면 jq 없는 머신에서 fail-closed로 쓰기 전면 차단.
- **Bash 쓰기 가드는 best-effort**: 리다이렉트·sed -i·cp/mv는 잡지만 파이프·변수·heredoc 간접 우회는 미탐(문서화된 상한). 우회분은 pre-commit이 2차 차단.
- **deny 프리픽스 매칭 한계**: `rm -rf*`는 막아도 `rm -r -f` 변형은 패턴 밖.
- **Stop 게이트 스택 커버리지**: Java/Node/Python/bash. Python은 ruff·pytest가 프로젝트 환경에 있을 때만(best-effort), 그 외 스택은 미검증 통과.
- **컨텍스트 비용**: `rules/` 상시 로드 + 스킬 22종 목록으로 세션 시작 토큰 증가.
- **정책↔게이트 이중 관리**: 규칙(md) 추가 시 훅(sh) 반영은 수동. `/harness-audit`은 안전 핵심 항목 + 위생(중복·빈 파일·프런트매터)만 기계 검사.
- **스킬 충돌 검사는 이름 수준**: repo↔전역 같은 이름만 탐지. 트리거 문구(description) 수준 중복은 미탐.

## 디벨롭 이력 (v0.0.1 상세 — 2026-07-08 전부 구현·오프라인화)

| # | 항목 | 구현 | 검증 |
|---|------|------|------|
| 1 | 에이전트 무관 강제 | `.githooks/pre-commit` — 보호경로·시크릿을 커밋 시점 차단 (jq 불필요) | `tests/pre-commit.test.sh` 6건 |
| 2 | Stop 게이트 확장 | Python(ruff·pytest)·bash(shellcheck `-S error` + 훅 자가테스트) 추가 | `tests/stop-verify.test.sh` 9건 |
| 3 | audit 크로스 에이전트 체크 | AUDIT-04: AGENTS.md 포인터·pre-commit·hooksPath·vendor 체크섬 | `tests/harness-audit.test.sh` 14건 |
| 4 | 로그 회전·리포트 | `hooks/logs-report.sh [days]` 요약 · `--rotate N` 삭제 | `tests/logs-report.test.sh` 4건 |
| 5 | 규칙 정합 린트 | AUDIT-05: 빈 파일·' copy'·바이트 동일 중복 탐지 | 동상 |
| 6 | install.sh 부트스트랩 | vendor 검증→바이너리 배치→권한→hooksPath→audit, 오프라인·멱등 | jq 없는 머신 시뮬 통과 |
| 7 | 스킬 충돌 점검 | AUDIT-06: 프런트매터 검증 + repo↔전역 이름 충돌 탐지 | 동상 |

오프라인 자산: `vendor/bin/`(jq 1.8.2 amd64/arm64 · shellcheck 0.11.0, SHA256SUMS 검증) — 상세는 `vendor/README.md`.
