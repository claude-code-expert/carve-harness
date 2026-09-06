<p align="center">
  <img src="docs/carve-banner.svg" alt="carve-harness — carve away the excess, keep the craft" width="680">
</p>

<p align="center"><b>필요한 것만 남기고, 나머지는 깎아낸다.</b></p>

# Claude 하네스 (언어 무관 드롭인)

[English](README.en.md) · 현재 버전 **v0.10.1** ([변경 내역](CHANGELOG.md)) · [강좌](HARNESS_GUIDE.md)

코딩 에이전트의 규칙 위반을 "설득"이 아니라 **훅 exit 2로 차단**하는 가드레일 템플릿. 프로젝트 루트에 드롭인하면 즉시 동작한다.

## 특징

| 기둥 | 동작 |
|------|------|
| **제약** | 보호 경로(`.env`·prod·마이그레이션)·하드코딩 시크릿 쓰기를 PreToolUse 훅이 차단. jq 부재·JSON 파손 시 fail-closed. 설치본에서는 훅·`settings.json`·manifest 수정/삭제도 차단(에이전트가 게이트를 못 끈다) |
| **피드백** | Stop 훅이 빌드·타입·린트·테스트 실패 시 완료 선언 차단 — 변경된 스택만 증분 검증(툴체인이 있을 때만 실행) |
| **상태** | 세션 종료·압축 시 핸드오프 자동 저장(TODO·결정 수집), 시작 시 복원 |
| **관측** | 모든 훅 판정을 `logs/*.jsonl`에 기록(PII 마스킹). 세션 시작 배너가 로드 구성을 표시 |
| **자가감사** | `/harness-audit` — 77개 기계 체크로 하네스 오구성 PASS/FAIL |
| **언어팩** | 설치 시 감지된 팩만 — 규칙·검증 게이트·채점 어댑터·골든셋 스타터·LSP가 한 세트. 미선택 언어는 파일 자체가 없다 |
| **검증 루프** | `/verify-loop` — 구현 주장을 항목별 0~100 채점, 95점 미만은 재작업. 미달 잔존 시 Stop 훅이 완료 차단 |
| **정량 평가** | `/eval` — 고정 골든셋을 k회 재실행해 pass@k/pass^k·회귀를 산출 |

**구성 요소**: 훅 22종 · 스택 정의 6종 · 언어팩 6종 · 슬래시 커맨드 14종 · 에이전트 7종 · 스킬 10종 · 규칙 11종 · 워크플로 3종 · 골든셋 스타터 20건 · 테스트 31 스위트(545건). 전체 목록은 [전체 구성](#전체-구성-스킬커맨드훅) 표.

**크로스 에이전트**: 훅 차단은 Claude Code 전용. Cursor/Codex 등은 `AGENTS.md` 정본 + `.githooks/pre-commit`이 커밋 시점에 최종 차단.

## 어떤 프로젝트에 맞나

이 하네스는 **훅으로 강제**한다. 강제 지점이 있는 환경에서만 제값을 한다.

- **잘 맞음** — TypeScript/React/Next · Java/Spring · Python/FastAPI · Go · Rust 중 하나 이상의 서비스 코드베이스. **Claude Code**로 개발, **git 저장소**, **jq**·스택 툴체인 존재, 테스트 러너가 있고 PR 단위로 일한다. 게이트웨이·결제·인증처럼 "틀리면 사고"인 경로가 있으면 검증 루프·골든셋이 특히 값을 한다.
- **부분 동작** — 툴체인이 CI에만 있는 팀(로컬 게이트 스킵) · 단일 스크립트·노트북 리포(가드만 유효) · 모노레포(루트와 한 단계 하위까지 감지).
- **맞지 않음** — Ruby·PHP·C#·Swift·Dart 주력(`GUIDE.md` §8.2대로 스택 파일 1개면 붙는다) · git 없는 디렉토리 · Windows 네이티브 셸(WSL 필요) · 코드를 거의 안 쓰는 리서치·문서 저장소.

> **데모**: <a href="https://claude-code-expert.github.io/carve-harness/docs/html/ohpen-demo/index.html" target="_blank" rel="noopener noreferrer">하네스 적용 전/후 화면 비교 (새 창)</a> — 같은 프롬프트로 만든 미적용(slop) vs 적용(클린) 비교.

## 설치

```bash
cd /path/to/your-project
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash
```

- 설치 시작 시 `[1] 맞춤 구축(권장) / [2] 수동 선택`을 묻는다. `[1]`은 전체 설치 후 세션에서 `/carve-harness-create`로 스택에 안 맞는 구성을 정리(prune)한다. 비대화형은 이 질문 없이 전체 설치.
- 기존 파일은 건드리지 않는다(SKIP). 단 `.claude/settings.json`은 **병합** — 기존 설정을 보존하며 하네스 훅 6이벤트 + LSP/플러그인 선언을 jq로 등록(멱등). 스킵하면 게이트가 전부 무력화된다.
- 설치 끝에 `/harness-audit` 자동 실행 — `0 failed`면 전 게이트 활성.
- `bash install.sh setup` (선택) — git init · jq PATH · LICENSE · 보호 경로 · 도메인 규칙 수집 · 스택 감지 리포트.

### 언어팩

설치는 **감지된 언어만** 깐다. 팩 하나 = 규칙(`.claude/rules/<stack>/`) + 검증 게이트·채점 어댑터(`.claude/stacks/<pack>.sh`) + 골든셋 스타터 + LSP 토글. 미선택 팩은 파일이 없다.

| 팩 | 감지 마커 | 게이트·포맷 | LSP |
|---|---|---|---|
| `typescript` | `package.json` · `tsconfig.json` | `tsc --noEmit` · `lint`/`test` · prettier | vtsls |
| `java-spring` | `gradlew` · `build.gradle(.kts)` · `pom.xml` | gradle compile/test · spotless · `eval-java` 스코어러 | jdtls |
| `python` | `pyproject.toml` · `requirements.txt` · `setup.py/cfg` | ruff check · pytest · ruff format | pyright |
| `go` | `go.mod` | go build/vet/test · gofmt | gopls |
| `rust` | `Cargo.toml` | cargo check/test · rustfmt | rust-analyzer |
| `database` | ORM 의존성(prisma·drizzle·typeorm·sqlalchemy·JPA·gorm…) | 규칙만(`database.md`) | — |

```bash
HARNESS_PACKS=auto bash install.sh                 # 감지분 (tty 없는 설치의 기본)
HARNESS_PACKS=typescript,python bash install.sh    # 지정
HARNESS_PACKS=none bash install.sh                 # 코어만 (가드·핸드오프·감사만)
bash install.sh pack list|add <name>|remove <name> # 사후 조정 (remove는 백업 → rollback)
```

## 시작 순서

설치 후 아래 순서로 한 번 훑으면 하네스가 이 프로젝트에 맞게 선다. 3번까지만 해도 가드·게이트는 전부 동작한다.

1. **설치** — `curl … | bash`. 시작 질문에서 `[1] 맞춤 구축(권장)`.
2. **언어팩 확정** — 설치 중 감지된 팩이 기본. `bash install.sh pack list|add|remove`로 조정.
3. **머신 준비** — `jq`·`git`과 스택 툴체인(`tsc`·`gradlew`·`ruff/pytest`·`go`·`cargo`)이 있어야 게이트가 실제로 문다. `bash install.sh setup`.
4. **스택 맞춤(선택)** — 세션에서 `/carve-harness-create`. 1회 확인 후 불필요한 팩·에이전트·스킬 prune.
5. **도메인 규칙** — `CLAUDE.md`에 프로젝트 불변식 3줄(예: "주문 금액 음수 불가"). 코드 패턴은 훅이 못 보므로 **테스트로 강제**.
6. **검증** — `/harness-audit`가 `0 failed`면 전 게이트 활성.
7. **사용** — 보호 경로·시크릿·위험 명령 자동 차단, 응답 종료 시 변경 스택만 검증, 세션 경계에서 상태 저장·복원.
8. **(1~2주 뒤) 골든셋** — 실패가 쌓인 뒤 `/eval-init` 1회 → 이후 `/eval`로 회귀 추적.

## 업데이트 / 롤백 / 제거

대상 프로젝트 루트에서 실행.

```bash
cat .claude/harness-version    # 현재 설치 버전
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash -s -- update   # 업데이트
bash install.sh rollback       # 직전 버전 복원 (백업 소비 — 연속 실행 시 더 과거로)
bash uninstall.sh --yes        # 제거 (manifest 범위만, 원래 있던 파일 안전)
```

- update: 원격 `VERSION` vs 로컬 비교(같으면 no-op) → manifest 범위만 패치, 변경 파일은 `logs/harness-backup/`에 자동 백업, 사용자 파일 불가침. 같은 버전 강제 재패치는 `HARNESS_FORCE=1 bash install.sh update`.
- prune: `bash install.sh prune --keep-list <파일>` — 불필요 구성만 제거(코어·훅 거부), 백업 → `rollback`. 보통 `/carve-harness-create`가 자동 호출.

## 사용법

설치하면 게이트는 자동이다 — 보호 경로 쓰기는 차단, 응답 종료 시 변경 스택 검증, 세션 경계에서 상태 저장. 수동 도구:

| 명령 | 용도 |
|------|------|
| `/harness-audit` | 하네스 구성 PASS/FAIL (AUDIT-01~10, 이 리포 77체크) |
| `/plan` `/verify` `/review` `/commit` | SC 분해 · SC 검증 · 코드 검토 · commit→pull→push |
| `/verify-loop <목표>` | 요구가 여러 개일 때 — 항목별 0~100 채점, 전 항목 95점까지 재작업 |
| `/eval-init` · `/eval` | **설치 후 1회** 골든셋 셋업 · 재채점 → pass@k/pass^k·회귀 판정 |
| `bash install.sh pack list\|add\|remove` | 언어팩 상태표 / 추가 / 제거 |
| `bash .claude/hooks/eval-score.sh` | 빌드 건강도 채점표 `specs/SCORE.json` (LLM 없음) |
| `bash .claude/hooks/logs-report.sh [days]` | 훅 판정 로그 요약 (`--tokens` 세션별 토큰) |
| `npm test` | 전체 훅 테스트 31 스위트(545건) |

커스터마이징(보호 경로·포맷터·검증 명령·새 스택)·전체 레퍼런스는 **`GUIDE.md`**.

## 전체 워크플로 — 도구를 언제 무엇으로

| 단계 | 언제 | 무엇을 | 게이트 / 산출물 |
|---|---|---|---|
| 0 설치 | 처음 1회 | `curl … \| bash` → 언어팩 감지 → `harness-audit` | 훅 6이벤트 등록 · manifest |
| 1 맞춤 | 설치 직후 | `/carve-harness-create` — 팩 add/remove + prune(1회 확인) | 백업 → `rollback` |
| 2 도메인 규칙 | 설치 직후 | `CLAUDE.md`에 불변식 3줄 | 규칙은 **테스트로 강제** |
| 3 일상 개발 | 매 응답 | 그냥 코딩 | PreToolUse 차단 · 변경 스택만 검증 · `logs/*.jsonl` |
| 4 계획·검증 | 기능 단위 | `/plan` → 구현 → `/verify`·`/review` | `specs/` 완료 기준(SC) |
| 5 검증 루프 | 요구 항목 다수 | `/verify-loop <목표>` — 95 미만만 재작업 | 미달 잔존 시 완료 차단 |
| 6 건강도 점수 | PR 전 | `eval-score.sh` | `specs/SCORE.json` |
| 7 골든셋 | 1~2주 뒤 1회 | `/eval-init` | `specs/goldenset/*.json` |
| 8 회귀 추적 | 프롬프트·규칙 변경 시 | `/eval` → `eval-gate --mode report\|block` | 추이 · `[REGRESSION]` |

세션 경계는 자동. 6~8은 없어도 0~5만으로 가드·게이트가 전부 동작한다.

## 오케스트레이션 · 검증 루프

단일 세션 가드 위에 세 상위 워크플로가 얹힌다. 셋 다 특정 모델에 묶이지 않는다 — 같은 절차(SOP)를 손으로 밟으면 opus·sonnet·Cursor·Codex에서도 동작한다.

- **Fable 팀** ([가이드](docs/md/fable-team-guide.md)) — 메인 세션이 작업을 태스크 3~5개로 쪼개 역할별 워커(`fable-researcher`·`fable-builder`·`fable-doc-writer`·`fable-visualizer`·`evaluator`)에게 맡기고 종합. 워커는 겹치지 않는 파일 소유권 + worktree 격리로 병렬 진행. 생성과 검증은 절대 같은 에이전트가 아니다. 옵트인 — `ultracode` 키워드나 워크플로 이름 명시 시 실행.
- **검증 루프** ([가이드](docs/md/verify-loop-guide.md)) — "구현했다"는 주장을 독립 evaluator가 코드 대조 + 테스트 실행으로 0~100 채점(exists·match·test·contract·no_regress). 95 미만만 gap 되먹여 재작업, 전 항목 95까지 루프. 미달·미채점 잔존 시 `checklist-gate` Stop 훅이 완료를 **차단**. `/verify-loop <목표>`.
- **골든셋 평가(carve-eval)** — 고정 케이스 집합(`specs/goldenset/*.json`, 입력→루브릭)을 케이스별 k회 실행해 pass@k(능력)·pass^k(일관성) 산출, 추이 append, baseline 대비 하락 시 `[REGRESSION]`. **"에이전트의 말이 아니라 환경의 상태를 채점한다"** — 상태 assert(`file_exists`·`cmd_exit0`·`git_diff_contains`)가 텍스트·LLM 루브릭보다 우선. 케이스 자동 확정은 막아뒀다(자기강화 방지) — 크리티컬 경로·엄격도는 사람이 정한다. 셋업은 `/eval-init` 1회, 이후 `/eval`.

## 전체 구성 (스킬·커맨드·훅)

### 스킬 (10종)

> **발동 시점** = 자동 트리거(설명 매칭) 또는 `/스킬명` 수동 호출.

| 스킬 | 구분 | 용도 |
|------|------|------|
| `anti-ai-slop` | 코어 | 시각 산출물 생성 전 슬롭(그라데이션·글로우·장식) 차단 게이트 (자동) |
| `carve-guide` | 코어 | 하네스 HTML 산출물 작성 — 디자인 시스템·anti-slop·1000px 임베드 안전 (자동) |
| `handoff` | 코어 | 세션 종료·압축 전 진행상황을 `specs/HANDOFF.md`로 인계 |
| `changelog` | 코어 | 비가역 결정·근거를 `specs/DECISIONS.md`에 기록 |
| `version-changelog` | 코어 | 릴리스 시 VERSION·CHANGELOG·README 버전 동기 |
| `carve-harness-create` | 코어 | 스택 감지 후 불필요 구성 prune → 맞춤 하네스 |
| `checklist-loop` | 검증 | 구현 주장 코드 대조 채점 루프 SOP + checklist.json 스키마 |
| `eval-goldenset` | 검증 | 골든셋 정량 채점·회귀 판정 SOP + 케이스 형식 |
| `eval-init` | 검증 | 설치 후 1회 셋업 — 인터뷰로 평가·품질 게이트 확정 → 골든셋 초안 |
| `theme-factory` | 외부(벤더) | 산출물에 테마(색·폰트) 적용 — anti-slop 게이트 여전히 적용 |

> 벤더 스킬(`theme-factory`)은 SKILL.md만 벤더링. 플러그인 `frontend-design`·`ponytail`은 스킬이 아니라 settings.json 선언으로 배포.

### 슬래시 커맨드 (14종)

| 커맨드 | 용도 |
|------|------|
| `/harness-audit` | 하네스 구성 PASS/FAIL (AUDIT-01~10, 77체크) |
| `/plan` `/verify` `/review` | SC 분해 → `specs/` · SC·빌드·타입·테스트 검증 · 타입·보안·예외·상태 검토 |
| `/verify-loop` | 스펙→개발→체크리스트→채점 루프, 전 항목 95점까지 ([가이드](docs/md/verify-loop-guide.md)) |
| `/eval` | 골든셋 재채점 → pass@k/pass^k·추이·회귀 판정 |
| `/commit` `/commit-branch` | commit→pull→push (인자=메시지) · Conventional Commits 커밋+푸시(`main` 금지) |
| `/ponytail*` (6) | ponytail 모드 제어·audit·debt·gain·review·help |

### 훅 (20종 — 이벤트 게이트 5 · 라이브러리 3 · CLI·헬퍼 12)

| 훅 | 트리거 | 역할 |
|------|------|------|
| `pretool-guard` | PreToolUse (Write·Edit·Bash 직전) | 보호 경로·시크릿·위험 명령 차단 + 자기보호(GUARD-07) + 루프 브레이크(exit 2), fail-closed |
| `posttool-format` | PostToolUse (쓰기 직후) | 확장자 언어 감지 후 포맷(exit 0) |
| `posttool-slop` | PostToolUse (`.html·.htm·.css·.svg` 쓰기 직후) | anti-slop 린터 요약 1줄 리포트(비차단 exit 0). 상세는 JSONL·수동 실행 |
| `check-slop.mjs` | 수동 CLI · `posttool-slop` 호출 | 시각·문서 슬롭 결정론 린터 34룰(HTML/CSS·SVG·MD 디스패치, WCAG 대비 계산). `0` 통과 · `1` ERROR · `2` 호출 오류 |
| `stop-verify` | Stop (완료 선언 직전) | 변경 스택 빌드·타입·테스트 게이트(실패 exit 2) |
| `checklist-gate` | Stop (`stop-verify` 뒤) | `checklist.json` 미달(<95)·미채점 시 완료 차단. `domain_safety`는 100 필수. 자가 우회 차단(tombstone) |
| `session-handoff` | SessionStart·PreCompact·SessionEnd | 핸드오프 복원·저장 + 구성 배너 |
| `log-event` | 다른 훅이 판정 기록 시 | JSONL 관측 append — 스키마·PII 마스킹 단일 출처 |
| `lib-protected` · `lib-stop-guard` · `lib-packs` | `source` 참조(직접 실행 안 함) | 보호 경로·위험 명령 정규식 / Stop 루프 가드 / 언어팩 매니페스트 리더 |
| `config-doctor` | 설정 점검 시 | settings·구성 정합 진단 |
| `harness-audit` | `/harness-audit` | read-only PASS/FAIL — AUDIT-01~09 |
| `logs-report` | 수동 CLI | JSONL 판정 요약 + 회전 + `--tokens` 토큰 회계 |
| `eval-java` | Java 품질 스코어 (수동) | Java/Spring 결정적 품질 확률 `P∈[0,1]`, LLM 없음 |
| `eval-state` | carve-eval 상태 assert 채점 | 파일·명령·diff를 실상태로 결정적 채점 — 자기 보고 불신 |
| `eval-gate` | CI·로컬 회귀 판정 | 추이만 읽어 `unable→stale→suspicious→regressed→ok`. `--mode block`은 ok 외 exit 1 |
| `carve-validate` | `/eval` Phase 0 · 수동 | 골든셋 프리플라이트. `--red`는 NO-SIGNAL 케이스 탐지 |
| `redteam` | 가드레일 정기 점검 | 공격 34·정상 19를 exit 코드로 채점(LLM 0). 차단율·과잉차단율. `--strict` |
| `eval-run` | `/eval` 케이스 실행(헬퍼) | 케이스 1건 setup→응답→채점. `--target session\|claude\|exec:` |
| `eval-trend` | `/eval` 추이 읽기·쓰기(헬퍼) | `eval-score.json` 결정론 append — `prevHash` 변조 시 거부 |
| `eval-score` | 빌드 건강도 점수 (수동) | 언어 무관 채점표(§5.7) — G1 빌드·G2 테스트·G3 안전(거부권) + lint·회귀·커버리지 |

## 구조

각 디렉토리에 역할을 적은 `README.md`가 있다.

```
├── CLAUDE.md / AGENTS.md       # 규칙 정본 (Claude / 크로스 에이전트)
├── VERSION · CHANGELOG.md · RELEASE.md
├── install.sh / uninstall.sh   # 설치·update·rollback·setup / 제거
├── .githooks/                  # pre-commit·commit-msg (에이전트 무관 커밋 게이트)
├── packs/                      # 언어팩 정의 6종
├── specs/                      # 상태: 핸드오프·결정 기록·골든셋(goldenset/)
└── .claude/
    ├── settings.json           # 훅 6이벤트 등록
    ├── hooks/  (22종 + tests 31 스위트)
    ├── stacks/ (6종 — 스택별 게이트·포맷·채점 어댑터)
    ├── workflows/ (fable-team-pipeline · carve-verify-loop · carve-eval)
    └── commands/ (14) · agents/ (7) · skills/ (10) · rules/ (11)
```

## 한계

> 실측 기준 — 적대적 감사(우회 시도 34종)에서 **실제로 뚫린 것만** 적었다.

- 훅 차단은 Claude Code 전용 — 타 에이전트는 pre-commit이 커밋 시점 차단.
- Bash 쓰기 가드는 명령 표면만 본다. **변수 간접(`F=.env; echo x > $F`)·인터프리터 경유는 미탐**(pre-commit이 2차 차단).
- 시크릿 스캔은 **리터럴 매칭** — base64·문자열 분할 조립은 미탐.
- 위험 명령 차단은 `env`/`sudo`/`VAR=` 접두는 커버하지만 **alias·함수 래핑·2단계 다운로드는 미탐**.
- Stop 게이트 스택: Java·Node/TS·Python·Go·Rust·bash — 그 외는 미검증 통과. **툴체인이 있을 때만 문다**.
- 게이트 자기보호(GUARD-07)는 **설치본에서만** 활성. 검증 루프는 채점 내용 자체가 거짓이면 못 막는다(evaluator 분리로 완화).

## 라이선스

MIT — [LICENSE](LICENSE). 벤더링된 `ponytail`은 자체 라이선스(`vendor/ponytail/LICENSE`).

## 버전 이력

현재 **v0.10.1**. 전체 이력은 [CHANGELOG.md](CHANGELOG.md).
