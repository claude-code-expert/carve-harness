# Claude 하네스 (언어 무관 드롭인)

[English](README.en.md) · 현재 버전 **v0.0.12** · 변경 내역 [CHANGELOG.md](CHANGELOG.md) · 강좌 [HARNESS_GUIDE.md](HARNESS_GUIDE.md)

코딩 에이전트의 규칙 위반을 "설득"이 아니라 **훅 exit 2로 차단**하는 가드레일 템플릿.
프로젝트 루트에 드롭인하면 즉시 동작한다.

## 특징

| 기둥 | 동작 |
|------|------|
| **제약** | 보호 경로(`.env`·prod·마이그레이션)·하드코딩 시크릿 쓰기를 PreToolUse 훅이 차단. jq 부재·JSON 파손 시 fail-closed |
| **피드백** | Stop 훅이 빌드·타입·린트·테스트 실패 시 완료 선언 차단 — 변경된 스택만 증분 검증(Node는 `lint`/`test` 스크립트 있을 때만, CI의 `npm run lint`를 로컬로 앞당김) |
| **상태** | 세션 종료·압축 시 핸드오프 자동 저장(실제 TODO·결정 수집), 시작 시 복원 |
| **관측** | 모든 훅 판정을 `logs/*.jsonl`에 기록 (PII 마스킹), 리포트·회전 지원. 세션 시작 배너가 로드된 전 구성을 표시하고, 훅 메시지는 `[carve-harness:<hook>]` 프리픽스로 통일 |
| **자가감사** | `/harness-audit` — 42개 기계 체크로 하네스 오구성 PASS/FAIL |

**구성 요소**: 훅 9종(6 이벤트 + 수동 CLI 3) · 슬래시 커맨드 15종 · 에이전트 20종 · 스킬 26종 · 규칙 18종 · 워크플로 1종 · 테스트 14 스위트(172건) — 전체 목록은 [전체 구성](#전체-구성-스킬커맨드훅) 표 참고

**크로스 에이전트**: 훅 차단은 Claude Code 전용. Cursor/Codex 등은 `AGENTS.md` 정본 + `.githooks/pre-commit`이 커밋 시점에 최종 차단.

**오프라인 완결**: jq·shellcheck 정적 바이너리 내장(`vendor/bin`, SHA256 검증) — 인터넷 없이 설치 가능.

> **데모**: <a href="https://claude-code-expert.github.io/carve-harness/docs/html/harness-demo/index.html" target="_blank" rel="noopener noreferrer">하네스 적용 전/후 화면 비교 (새 창)</a> — 같은 프롬프트로 만든 미적용(slop) vs 적용(클린) HTML을 나란히 놓고, 어떤 규칙이 무엇을 바꿨는지 표로 정리.

## 설치

```bash
cd /path/to/your-project
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash
```

- **맞춤 구축 (권장)**: 설치 시작 시 `[1] 프로젝트 분석 후 맞춤 하네스 구축 / [2] 수동 컴포넌트 선택`을 묻는다. `[1]`은 전체 설치 후 세션에서 `/carve-harness-create`를 실행하면 프로젝트 스택을 분석해 맞지 않는 규칙·에이전트·스킬을 제안·정리(prune)한다 — 상시 로드 토큰 표면 축소(정리 전에도 전체 구성으로 동작). `[2]`는 아래 체크박스 선택. (env·비대화형은 이 질문 없이 기존 동작.)
- **구성 선택**: 설치 전 전체 항목이 섹션별(필수 md·훅·스킬·커맨드·오케스트레이터) 체크박스 목록으로 펼쳐진다. `↑↓`/`jk` 이동 · 스페이스 토글(섹션 행에서 누르면 하위 일괄) · `1`-`5` 섹션 점프 · `a` 전체 토글 · 엔터 설치. 기본은 전체 선택 — 엔터만 치면 전체 설치. 비대화형은 `HARNESS_COMPONENTS=md,hooks bash install.sh`. 선택은 `.claude/harness-components`에 기록돼 update의 신규 파일 필터로 작동하고, 재실행하면 빠진 항목을 추가할 수 있다.
- 기존 파일은 건드리지 않는다(SKIP 보고) — 설치 목록은 `.claude/harness-manifest.txt`에 기록.
- **예외: `.claude/settings.json`은 스킵이 아니라 병합**한다 — 기존 설정(`permissions`·`model`·자체 훅)을 보존하며 하네스 훅 6이벤트 + LSP/플러그인 선언을 jq로 등록(멱등). 이걸 스킵하면 훅이 미등록돼 배너·가드·검증이 전부 무력화되기 때문.
- **LSP·플러그인 자동 선언**: settings.json이 `vtsls`(TypeScript·React·JavaScript LSP)·`jdtls`(Java LSP)·`ponytail`·`frontend-design`(디자인 방향 스킬) 플러그인과 각 마켓플레이스(`claude-code-lsps`·`ponytail`·`claude-code-plugins`)를 선언한다 — 세션 시작 시 Claude Code가 신뢰 승인 후 자동 설치. 서버 실행 파일은 별도: vtsls는 `bash install.sh setup`에서 npm 전역 설치 제안, jdtls는 `brew install jdtls`(JDK 필요). 미설치면 install 끝에 NOTE로 안내된다.
- 설치 끝에 `/harness-audit` 자동 실행 — 42 PASS면 전 게이트 활성.

### 오프라인 / 로컬 클론 설치

```bash
HARNESS_SRC_DIR=/path/to/harness bash /path/to/harness/install.sh          # 설치
HARNESS_SRC_DIR=/path/to/harness bash /path/to/harness/install.sh update   # 업데이트
```

다른 소스에서 받으려면 `HARNESS_REPO=<owner>/<repo>` · `HARNESS_REF=<branch|tag>`로 바꾼다.

**초기 설정** (선택, 모든 항목 엔터로 skip):

```bash
bash install.sh setup
```

git init · jq PATH · LICENSE 생성(MIT/Apache-2.0) · 보호 경로 추가 · 도메인 규칙 수집 · 스택 감지 리포트 · GSD 설치 제안.
도메인 규칙·스택 게이트 보강은 `GUIDE.md` §8 참고.

## 업데이트 / 롤백

모든 명령은 **대상 프로젝트 루트에서** 실행.

```bash
# 현재 설치 버전 확인
cat .claude/harness-version

# 업데이트 — 온라인 (권장: 새 설치기 기준이라 신규 파일까지 수신)
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash -s -- update

# 업데이트 — 로컬 설치본의 설치기로
bash install.sh update

# 업데이트 — 오프라인 (새 버전 복사본 지정)
HARNESS_SRC_DIR=/path/to/new-harness bash install.sh update

# 특정 브랜치/태그 고정
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | HARNESS_REF=v0.0.4 bash -s -- update

# 같은 버전 강제 재패치 (파일 복구 용도)
HARNESS_FORCE=1 bash install.sh update

# 롤백 — 직전 버전 복원 (네트워크 불필요, 연속 실행 시 한 단계씩 과거로)
bash install.sh rollback
```

- update: 원격 `VERSION` vs 로컬 `.claude/harness-version` 비교(같으면 no-op) → manifest 범위만 패치, 변경 파일은 `logs/harness-backup/v<이전>/` 자동 백업, 사용자 파일(설치 때 SKIP분) 불가침.
- rollback: 최신 백업 복원 + 버전 스탬프 복귀. 백업은 소비 — 연속 실행 시 그 이전 버전으로.
- prune: `bash install.sh prune --keep-list <파일>` — 프로젝트에 불필요한 구성만 제거(코어·훅·크로스에이전트 진입 파일은 거부), 제거분은 `logs/harness-backup/`에 백업돼 `rollback`으로 복원. 보통 `/carve-harness-create` 스킬이 분석 후 자동 호출한다.
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
| `/harness-audit` | 하네스 구성 42체크 PASS/FAIL |
| `/plan` `/verify` `/review` `/commit` | SC 분해 · SC 검증 · 코드 검토 · 커밋 준비 |
| `/squad-*` (8종) | 기획→리뷰→QA→리팩토링→디버그→보안→문서→Git 파이프라인 |
| `bash .claude/hooks/logs-report.sh [days]` | 훅 판정 로그 요약 (`--rotate N` 회전) |
| `npm test` / `npm run test:install` | 전체 훅 테스트 14 스위트 / 설치 구성 선택 스위트 |

커스터마이징(보호 경로·포맷터·검증 명령·새 스택)·전체 레퍼런스는 **`GUIDE.md`** 참고.

## 전체 구성 (스킬·커맨드·훅)

### 스킬 (26종)

| 스킬 | 구분 | 용도 |
|------|------|------|
| `anti-ai-slop` | 코어 | 시각 산출물 생성 전 슬롭(그라데이션·글로우·장식) 차단 게이트 |
| `carve-guide` | 코어 | 하네스 HTML 산출물 작성 — 디자인 시스템·anti-slop·1000px 임베드 안전(§릴리스 갱신은 리포 전용) |
| `handoff` | 코어 | 세션 종료·압축 전 진행상황을 `specs/HANDOFF.md`로 인계 |
| `changelog` | 코어 | 되돌릴 수 없는 결정·근거를 `specs/DECISIONS.md`에 기록 |
| `version-changelog` | 코어 | 릴리스 시 VERSION·CHANGELOG·README 버전 이력 동기 갱신 |
| `carve-harness-create` | 코어 | 스택 감지 후 불필요 구성 prune → 맞춤 하네스 |
| `codebase-design` | 설계 | 깊은 모듈 설계 공용 어휘·심화 기회 |
| `design-an-interface` | 설계 | 병렬 서브에이전트로 인터페이스 안 여러 개 생성·비교 |
| `domain-modeling` | 설계 | 도메인 모델·유비쿼터스 언어 정립 |
| `improve-codebase-architecture` | 설계 | 딥모듈 기회 스캔 → HTML 리포트 → 반영 |
| `prototype` | 설계 | 설계 질문에 답하는 버리는(throwaway) 프로토타입 |
| `implement` | 구현 | PRD·이슈 기반 구현 |
| `qa` | 구현 | 대화형 QA → GitHub 이슈 등록 |
| `request-refactor-plan` | 구현 | 작은 커밋 단위 리팩터 계획을 이슈로 |
| `migrate-to-shoehorn` | 구현 | 테스트 `as` 단언 → `@total-typescript/shoehorn` 이관 |
| `resolving-merge-conflicts` | 구현 | 진행 중 머지/리베이스 충돌 해결 |
| `setup-pre-commit` | 구현 | Husky + lint-staged pre-commit 훅 셋업 |
| `teach` | 문서·교육 | 새 개념·스킬 교육 |
| `edit-article` | 문서·교육 | 글 구조·명확성 개선 편집 |
| `scaffold-exercises` | 문서·교육 | 연습문제 디렉토리 구조 생성 |
| `to-prd` | 문서·교육 | 대화를 PRD로 만들어 이슈 트래커에 발행 |
| `to-issues` | 문서·교육 | 계획·PRD를 독립적으로 잡을 수 있는 이슈로 분해 |
| `loop-me` | 문서·교육 | 만들 워크플로 스펙을 대화로 파고들기 |
| `ask-matt` | 문서·교육 | 상황에 맞는 스킬·플로우 안내 라우터 |
| `setup-matt-pocock-skills` | 셋업 | 이 리포에 엔지니어링 스킬 셋업(이슈 트래커·라벨) |
| `theme-factory` | 외부(벤더) | 산출물에 테마(색·폰트) 적용 — anti-slop 게이트 여전히 적용 |

> 벤더 스킬(`theme-factory`)은 `composiohq/awesome-claude-plugins`에서 SKILL.md만 벤더링. 플러그인 `frontend-design`(디자인 방향)·`ponytail`(간결화)은 스킬이 아니라 settings.json 선언으로 배포된다.

### 슬래시 커맨드 (15종)

| 커맨드 | 용도 |
|------|------|
| `/harness-audit` | 하네스 구성 42체크 PASS/FAIL |
| `/commit-branch` | 현재 브랜치에 Conventional Commits로 커밋 + 푸시(`main` 직접 금지) |
| `/plan` | 작업을 완료 기준(SC) 단위로 분해 → `specs/` |
| `/verify` | 현재 변경을 SC·빌드·타입·테스트로 검증 |
| `/review` | 변경분을 타입·보안·예외·상태관리 관점 검토 |
| `/commit` | commitlint 준수 메시지로 커밋 준비 |
| `/squad` | Squad 에이전트 호출 — `/squad <멤버> [작업]` |
| `/squad-plan` | 기능 기획 |
| `/squad-review` | 코드 리뷰 |
| `/squad-qa` | QA 테스트 실행 |
| `/squad-refactor` | 코드 리팩터 |
| `/squad-debug` | 이슈 디버깅 |
| `/squad-audit` | 보안 감사 |
| `/squad-docs` | 문서 생성 |
| `/squad-gitops` | Git 워크플로(커밋·PR·체인지로그) |

### 훅 (9종 — 이벤트 게이트 4 · 공유 헬퍼 2 · 수동 CLI 3)

| 훅 | 트리거 | 역할 |
|------|------|------|
| `pretool-guard` | PreToolUse | 보호 경로·시크릿·위험 git 쓰기 차단(exit 2), fail-closed |
| `posttool-format` | PostToolUse | 확장자 언어 감지 후 포맷(후처리, exit 0) |
| `stop-verify` | Stop | 변경 스택 빌드·타입·테스트 게이트(실패 exit 2) |
| `session-handoff` | SessionStart·PreCompact·SessionEnd | 핸드오프 복원·저장 + 구성 배너 |
| `log-event` | 서브프로세스 호출 | JSONL 관측 append — 스키마·PII 마스킹 단일 출처 |
| `lib-protected` | source 참조 | 보호 경로 정규식 단일 정의(순수 데이터) |
| `harness-audit` | 수동 `/harness-audit` | 42 체크 read-only PASS/FAIL |
| `logs-report` | 수동 CLI | JSONL 판정 요약 + N일 회전 |
| `eval-java` | 수동 스코어러 | Java/Spring 결정적 품질 확률 `P∈[0,1]`, LLM 없음 |

## 구조

```
├── CLAUDE.md / AGENTS.md    # 규칙 정본 (Claude / 크로스 에이전트)
├── VERSION · CHANGELOG.md · RELEASE.md
├── install.sh / uninstall.sh   # 설치·update·rollback·setup / 제거
├── vendor/bin/              # 내장 jq·shellcheck (+ SHA256SUMS)
├── .githooks/              # pre-commit·commit-msg (에이전트 무관 커밋 게이트)
├── specs/                   # 상태: 핸드오프·결정 기록
└── .claude/
    ├── settings.json        # 훅 6이벤트 등록
    ├── hooks/  (9종 + tests 14 스위트)
    ├── workflows/ (fable-team-pipeline)
    ├── commands/ (15종) · agents/ (20종) · skills/ (26종) · rules/ (18종)
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
| v0.0.13 | 2026-07-12 | `carve-guide` 범용 HTML 작성 스킬 + **배포 포함**(스킬 25→26종) · 임베드 안정화(1000px `!important` 폭 · SPA 목차 크래시 수정 · 데모 새 창) |
| v0.0.12 | 2026-07-11 | 프로젝트 맞춤 구축(맞춤/수동 선택 · `carve-harness-create` prune) · **훅 디렉토리 self-heal 수정**(부분설치→커밋 전면차단 버그) · **로컬 lint 게이트**(shift-left) · `theme-factory` 벤더링 + `frontend-design` 선언 · 구성 표·데모 · 스킬 25종·테스트 14 스위트(172건) |
| v0.0.11 | 2026-07-10 | 체크박스 TUI 구성 선택 · 세션 배너 인벤토리 + `[carve-harness:<hook>]` 프리픽스 통일 · LSP(vtsls·jdtls)·ponytail 플러그인 선언 배포 · 공개 레포 전환(토큰 불요) |
| v0.0.10 | 2026-07-10 | 설치 구성 선택(5구성 CLI + `HARNESS_COMPONENTS`) · fable 오케스트레이터 팀(워커 4종+워크플로+가이드) · npm test 러너 · macOS 이식성 수정 |
| v0.0.9 | 2026-07-09 | Java/Spring 결정적 출력검증 evaluator(`eval-java.sh` — LLM 없이 재현 가능한 P) · ArchUnit 규칙 승격 · AUDIT-08 |
| v0.0.8 | 2026-07-09 | 게이트웨이 검증 계층(룰+Stop 게이트 GATE-04/05+AUDIT-07) · commit-msg 규율 게이트 · 테스트 서브에이전트 3종 · anti-ai-slop 스킬 |
| v0.0.7 | 2026-07-09 | revert v0.0.6 (소스는 사설이 정상) + 사설 레포 토큰 안내 복원 (404 원인=인증 누락) |
| v0.0.6 | 2026-07-09 | ~~소스 레포 공개 전환~~ (0.0.7에서 원복 — 잘못된 수정) |
| v0.0.5 | 2026-07-09 | CLAUDE.md 응답 언어 프로토콜(영문 요약→한글 결론) 추가 |
| v0.0.4 | 2026-07-09 | fix: 설치 목록에 VERSION 포함 — 설치본 셀프테스트 실패·체인 설치 버전 소실 수정 · 하네스 강좌(HARNESS_GUIDE.md) 추가 |
| v0.0.3 | 2026-07-08 | 대화형 설정 `setup` · update-안전 패턴 확장 파일 · LICENSE 자동 생성 |
| v0.0.2 | 2026-07-08 | `update`/`rollback` CLI · VERSION↔CHANGELOG pre-commit 게이트 · 배포 문서 |
| v0.0.1 | 2026-07-08 | 최초 완성본 — fail-closed 가드·Stop 게이트·JSONL 관측·핸드오프·자가감사·오프라인 설치기 |

상세는 [CHANGELOG.md](CHANGELOG.md).
