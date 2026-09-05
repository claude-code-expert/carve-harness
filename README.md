<p align="center">
  <img src="docs/carve-banner.svg" alt="carve-harness — carve away the excess, keep the craft" width="680">
</p>

<p align="center"><b>필요한 것만 남기고, 나머지는 깎아낸다.</b></p>

# Claude 하네스 (언어 무관 드롭인)

[English](README.en.md) · 현재 버전 **v0.8.0** · 변경 내역 [CHANGELOG.md](CHANGELOG.md) · 강좌 [HARNESS_GUIDE.md](HARNESS_GUIDE.md)

코딩 에이전트의 규칙 위반을 "설득"이 아니라 **훅 exit 2로 차단**하는 가드레일 템플릿.
프로젝트 루트에 드롭인하면 즉시 동작한다.

## 특징

| 기둥 | 동작 |
|------|------|
| **제약** | 보호 경로(`.env`·prod·마이그레이션)·하드코딩 시크릿 쓰기를 PreToolUse 훅이 차단. jq 부재·JSON 파손 시 fail-closed. **게이트 자기보호** — 설치본에서는 훅·`settings.json`·manifest 수정/삭제도 차단(에이전트가 게이트를 끄지 못한다) |
| **피드백** | Stop 훅이 빌드·타입·린트·테스트 실패 시 완료 선언 차단 — 변경된 스택만 증분 검증(Java·Node/TS·Python·Go·Rust·bash. 각 스택 툴체인이 있을 때만 실행, CI의 `npm run lint`를 로컬로 앞당김) |
| **상태** | 세션 종료·압축 시 핸드오프 자동 저장(실제 TODO·결정 수집), 시작 시 복원 |
| **관측** | 모든 훅 판정을 `logs/*.jsonl`에 기록 (PII 마스킹), 리포트·회전 지원. 세션 시작 배너가 로드된 전 구성을 표시하고, 훅 메시지는 `[carve-harness:<hook>]` 프리픽스로 통일 |
| **자가감사** | `/harness-audit` — 67개 기계 체크로 하네스 오구성 PASS/FAIL (언어팩 무결성·Eval 성숙도 포함) |
| **언어팩** | 설치 시 typescript·java-spring·python·go·rust·database 중 감지된 팩만 — 규칙·검증 게이트·채점 어댑터·골든셋 스타터·LSP가 한 세트. 미선택 언어는 파일 자체가 없다 |
| **검증 루프** | `/verify-loop` — 구현 주장을 항목별로 코드 대조 0~100 채점, 95점 미만은 gap 되먹여 재작업, 전 항목 95점까지 루프. 미달 잔존 시 Stop 훅이 완료 차단 → [검증 루프 가이드](docs/md/verify-loop-guide.md) |
| **정량 평가** | `/eval` — 고정 골든셋을 k회 재실행해 pass@k/pass^k·점수 추이·회귀를 산출. 실행 전 `carve-validate`가 골든셋 설정 오류를 에이전트 0회로 분리 |

**구성 요소**: 훅 17종(이벤트 게이트 5 · 라이브러리 3 · CLI·헬퍼 9) · 스택 정의 6종(`.claude/stacks/`) · 언어팩 6종(`packs/`) · 슬래시 커맨드 14종 · 에이전트 7종 · 스킬 10종 · 규칙 11종(+스택 상세본 10, `docs/rules/`) · 워크플로 3종 · 골든셋 스타터 20건 · 테스트 26 스위트(419건) — 전체 목록은 [전체 구성](#전체-구성-스킬커맨드훅) 표 참고

**크로스 에이전트**: 훅 차단은 Claude Code 전용. Cursor/Codex 등은 `AGENTS.md` 정본 + `.githooks/pre-commit`이 커밋 시점에 최종 차단.

## 어떤 프로젝트에 맞나

이 하네스는 **훅으로 강제**한다. 강제 지점이 있는 환경에서만 제값을 한다.

| 조건 | 왜 필요한가 | 없으면 |
|---|---|---|
| **Claude Code**로 개발 | PreToolUse·Stop 훅이 exit 2로 차단하는 유일한 자리 | Cursor·Codex·Aider는 `AGENTS.md` 규칙 + `.githooks/pre-commit`만 — 커밋 시점 차단으로 후퇴 |
| **git 저장소** | 증분 검증(변경 스택 판별)·커밋 게이트·update/rollback 백업 | 전체 검증으로 후퇴, 커밋 게이트 없음 |
| **jq** | 모든 훅이 stdin JSON을 jq로 읽는다(부재 시 fail-closed) | 설치기가 `~/.local/bin/jq` 배치를 시도, 실패하면 설치 중단 |
| 지원 스택 + **툴체인** | Stop 게이트·채점기는 `tsc/npm`·`gradlew`·`ruff/pytest`·`go`·`cargo`를 **실제로 실행**한다 | 툴체인 없는 스택은 best-effort 스킵(차단 아님) — `eval-score`는 `skipped`로 명시 |
| 골든셋을 **유지할 사람** | `/eval`·CI 차단 모드는 케이스를 사람이 검수해야 의미가 있다 | 게이트·검증 루프까지만 쓰고 `/eval`은 보류 |

**잘 맞는 프로젝트** — TypeScript/React/Next · Java/Spring · Python/FastAPI · Go · Rust 중 하나 이상으로 된 서비스 코드베이스. 테스트 러너가 있고 PR 단위로 일하며 에이전트가 하루에도 여러 번 코드를 쓴다. 게이트웨이·결제·인증처럼 "틀리면 사고"인 경로가 있으면 검증 루프와 골든셋이 특히 값을 한다.

**부분 동작** — 툴체인이 CI에만 있고 로컬엔 없는 팀(로컬 게이트 스킵, `eval-gate`는 CI에서 동작) · 단일 스크립트·노트북 리포(보호 경로·시크릿·위험 명령 가드만 유효) · 모노레포(스택별 게이트는 되지만 감지는 루트와 `backend/`·`frontend/` 같은 한 단계 하위까지).

**맞지 않음** — Ruby·PHP·C#·Swift·Dart 주력(게이트 없음 — `GUIDE.md` §8.2대로 스택 파일 1개면 붙는다) · git 없는 디렉토리 · Windows 네이티브 셸(WSL 필요) · 에이전트가 코드를 거의 안 쓰는 리서치·문서 저장소(검증 루프·골든셋이 잴 게 없다).


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
- 설치 끝에 `/harness-audit` 자동 실행 — 0 failed면 전 게이트 활성(체크 수는 설치 팩에 따라 다르다).
- **언어팩 선택**: 대화형이면 구성 선택 뒤 한 줄 질문(감지된 팩이 기본, 엔터 = 감지분). 비대화형 `HARNESS_PACKS=auto|none|all|typescript,python`(미지정 = auto). 사후 `bash install.sh pack list|add <name>|remove <name>`.

### 언어팩

설치는 **감지된 언어만** 깐다. 팩 하나 = 규칙(`.claude/rules/<stack>/`) + 검증 게이트·포맷터·채점 어댑터(`.claude/stacks/<pack>.sh`) + 골든셋 스타터 4건(`specs/goldenset/starters/`) + LLM-judge 예시(`docs/evaluator/`) + LSP 플러그인 토글. 미선택 팩은 파일이 없으므로 규칙도 게이트도 로드되지 않는다.

| 팩 | 감지 마커 | 게이트·포맷 | LSP |
|---|---|---|---|
| `typescript` | `package.json` · `tsconfig.json` | `tsc --noEmit` · `lint`/`test` 스크립트 · prettier | vtsls |
| `java-spring` | `gradlew` · `build.gradle(.kts)` · `pom.xml` | gradle compile/test(게이트웨이 파일만 바뀌면 `*GatewayIntegration*` 증분) · spotless · `eval-java` 스코어러 | jdtls |
| `python` | `pyproject.toml` · `requirements.txt` · `setup.py/cfg` | ruff check · pytest · ruff format | pyright |
| `go` | `go.mod` | go build/vet/test · gofmt | gopls |
| `rust` | `Cargo.toml` | cargo check/test · rustfmt | rust-analyzer |
| `database` | 의존성 매니페스트의 ORM(prisma·drizzle·typeorm·sqlalchemy·JPA·gorm·diesel·sqlx…) | 규칙만(`database.md`·ORM 상세본) | — |

```bash
HARNESS_PACKS=auto bash install.sh                 # 감지분 (tty 없는 설치의 기본)
HARNESS_PACKS=typescript,python bash install.sh    # 지정
HARNESS_PACKS=none bash install.sh                 # 코어만 — 언어 게이트 없이 가드·핸드오프·감사만
bash install.sh pack list                           # 팩 | 설치 | 감지 | 요약 (누락 경로 표시)
bash install.sh pack add go                         # 나중에 추가 (온라인 또는 HARNESS_SRC_DIR)
bash install.sh pack remove java-spring             # 제거 → 백업, bash install.sh rollback 으로 복원
```

**전체 설치면**(맞춤 구축 `[1]` · `curl | bash`·env 비대화형 · 수동에서 전부 선택) 설치 끝에 아래 배너가 출력된다 — 세션에서 `/carve-harness-create` 실행을 안내한다(자연어 요청이 아니라 **슬래시 커맨드로만** 발동):

```text
┌─────────────────────────────────────────────────────────────┐
│  맞춤 하네스 구축 예약됨 — 전체 설치 완료, 지금 바로 동작    │
└─────────────────────────────────────────────────────────────┘
프로젝트를 분석해 이 스택에 맞는 하네스로 최적화하려면
Claude Code 세션에서 다음을 실행하세요:

    /carve-harness-create

스택을 감지해 맞지 않는 구성을 제안하고, 1회 확인 후 덜어내 최적화합니다.
최적화하지 않아도 하네스는 정상 동작합니다(전체 구성 유지).
```

`carve-harness-create` 스킬을 뺀 부분 설치면 이 배너 대신 `bash install.sh setup`(대화형 초기 설정) 안내가 출력된다.

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
| `/harness-audit` | 하네스 구성 PASS/FAIL (AUDIT-01~09, 이 리포 67체크) |
| `/plan` `/verify` `/review` `/commit` | SC 분해 · SC 검증 · 코드 검토 · 인자 메시지로 commit→pull→push |
| `/verify-loop <목표>` | 요구가 여러 개일 때 — 항목별 0~100 채점, 전 항목 95점까지 재작업 반복 |
| `/eval-init` | **설치 후 1회** — 프로젝트 분석 + 인터뷰로 평가·품질 게이트를 확정하고 골든셋을 만든다 |
| `/eval` | 골든셋 재채점 → pass@k/pass^k · 점수 추이 append · baseline 대비 회귀 판정 |
| `bash .claude/hooks/carve-validate.sh [--red]` | 골든셋 프리플라이트 — 구조 검증(에이전트 0회), `--red`는 "그 케이스가 실제로 무언가를 재는지"까지 확인 |
| `bash .claude/hooks/eval-gate.sh --mode report\|block [--delta N]` | 추이 파일만 읽어 회귀 판정(LLM 없음). `block`은 허용 하락폭 초과 시 exit 1 — CI가 이걸 호출한다 |
| `bash .claude/hooks/logs-report.sh [days]` | 훅 판정 로그 요약 (`--rotate N` 회전 · `--tokens N` 세션별 토큰 사용량) |
| `npm test` / `npm run test:install` | 전체 훅 테스트 26 스위트(419건) / 설치 구성 선택 스위트 |
| `bash install.sh pack list\|add\|remove` | 언어팩 상태표 / 추가 / 제거(백업 → `rollback`) |
| `bash .claude/hooks/eval-score.sh` | 빌드 건강도 채점표 `specs/SCORE.json` — G1 빌드·G2 테스트·G3 안전(거부권) + lint·회귀·커버리지, LLM 없음 |

커스터마이징(보호 경로·포맷터·검증 명령·새 스택)·전체 레퍼런스는 **`GUIDE.md`** 참고.

## 전체 워크플로 — 도구 세트를 언제 무엇으로 쓰나

| 단계 | 언제 | 무엇을 | 게이트 / 산출물 |
|---|---|---|---|
| 0 설치 | 처음 1회 | `curl … \| bash` → 언어팩 감지 → `harness-audit` 자동 | 훅 6이벤트 등록 · `.claude/harness-manifest.txt` · `harness-packs` |
| 1 맞춤 | 설치 직후 | `/carve-harness-create` — 감지 대조로 팩 add/remove 제안 + 불필요 에이전트·스킬 prune(1회 확인) | `install.sh pack …` / `prune` (백업 → `rollback`) |
| 2 도메인 규칙 | 설치 직후 | `bash install.sh setup` 또는 `CLAUDE.md` "도메인 규칙"에 불변식 3줄("주문 금액 음수 불가" 등) | 코드 패턴은 훅이 못 본다 — 규칙은 **테스트로 강제** |
| 3 일상 개발 | 매 응답 | 그냥 코딩. 보호 경로·시크릿·위험 명령은 PreToolUse가 차단, 저장 즉시 포맷, 응답 종료 시 **변경된 스택만** 빌드·린트·테스트 | exit 2 차단 · `logs/*.jsonl` 판정 기록 |
| 4 계획·검증 | 기능 단위 | `/plan` → 구현 → `/verify` · `/review`(security-reviewer 위임 가능) | `specs/` 완료 기준(SC) |
| 5 검증 루프 | 요구 항목이 많을 때 | `/verify-loop <목표>` — 항목별 코드 대조 0~100, 95 미만만 gap 되먹여 재작업 | `specs/checklist.json` · 미달 잔존 시 `checklist-gate`가 완료 차단 |
| 6 건강도 점수 | PR 전·리뷰 시 | `bash .claude/hooks/eval-score.sh` — 빌드·테스트·안전(거부권) + lint·회귀·커버리지 | `specs/SCORE.json` (못 잰 항목은 `skipped`) |
| 7 골든셋 셋업 | 1~2주 사용 뒤 1회 | `/eval-init` — 인터뷰 7문항, 설치 팩의 스타터를 시드로 궤적 검사 후 승인분만 편입 | `specs/goldenset/*.json` · `.github/workflows/eval-gate.yml`(report) |
| 8 회귀 추적 | 프롬프트·규칙·모델을 바꿀 때 | `carve-validate --red` → `/eval` → `eval-gate --mode report\|block` | `specs/eval-score.json` 추이 · `[REGRESSION]`·`[VERSION CHANGED]` |
| 9 운영 | 주기 | `logs-report.sh 7`로 차단·실패 이력 마이닝 → 케이스 증설 · `/harness-audit` · `install.sh update` | 실패가 골든셋 문항이 되는 복리 루프 |

세션 경계는 자동이다 — 종료·압축 시 `specs/HANDOFF.md` 저장, 시작 시 복원 + 로드 구성 배너. 단계 6~8은 없어도 0~5만으로 가드·게이트가 전부 동작한다.

## 오케스트레이션 · 검증 루프

단일 세션 가드 위에 세 상위 워크플로가 얹힌다. 여러 에이전트를 역할별로 나눠 굴리는 **Fable 팀**, 스펙 요구가 실제로 구현됐는지 항목별로 채점하는 **검증 루프(Eval)**, 고정 골든셋으로 산출물 품질을 시간축으로 추적하는 **골든셋 평가(carve-eval)**다. 셋 다 특정 모델에 묶이지 않는다 — Fable 5가 없어도 opus·sonnet 세션이나 Cursor·Codex에서 같은 절차(SOP)를 손으로 밟으면 동작한다. Fable 5는 이 절차를 기본 반사로 수행할 뿐이다.

### Fable 팀 — 멀티 에이전트 오케스트레이션

**무엇** — 메인 세션(오케스트레이터, Fable 5·xhigh 티어)이 작업을 태스크 3~5개로 쪼개 역할별 워커에게 맡기고 결과를 종합한다. 워커는 서로 겹치지 않는 파일 소유권(`owns` glob)을 갖고 격리 worktree에서 작업하므로 병렬로 돌려도 충돌하지 않는다. 생성(빌더)과 검증(evaluator)은 같은 에이전트가 절대 아니다.

| 역할 | 에이전트 | 담당 |
|------|----------|------|
| 지휘·분해·종합 | 메인 세션 | Phase 설계, 승인 게이트, 결과 종합 |
| 리서치 | `fable-researcher` | 공식 문서·근거 조사 → RESEARCH.md |
| 개발 | `fable-builder` | 구현 + 테스트 (worktree 격리) |
| 문서 | `fable-doc-writer` | README·가이드·API 문서 |
| 이미지 | `fable-visualizer` | 다이어그램·목업 |
| 검증 | `evaluator` | 완료기준(SC) 대비 통과/불통과 (read-only) |

4단계 흐름 (`fable-team-pipeline` 워크플로가 자동 실행):

```
P1 Spec      리서치 → 태스크 3~5개 분해 (owns·acceptance 필수)
P2 Build     태스크별 빌더(worktree) → 완료 즉시 evaluator 검증   [배리어 없는 파이프라인]
P3 Document  doc-writer + visualizer 병렬
P4 Verify    evaluator 최종 SC 판정
```

**어떻게 쓰나**

| 목적 | 발화 |
|------|------|
| 단건 위임 | "fable-researcher로 Next.js 16 캐시 조사해줘" / "fable-builder한테 src/api 맡겨줘" |
| 전체 파이프라인 | "fable-team-pipeline으로 '주문 취소 API + 문서 + 흐름도' 돌려줘" — 옵트인이라 `ultracode` 키워드나 워크플로 이름을 명시해야 실행 |
| 깊이 조절 | "+300k 예산으로 fable-team-pipeline 실행" — 예산에 맞춰 fan-out 자동 조절 |
| 워커 간 합의 | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` + "팀 만들어서" — 빌더끼리 계약이 어긋나면 서로 지적 |

**효과** — 병목은 코드 생성이 아니라 검증이다. 탐색·리뷰를 서브에이전트에 위임하면 메인 컨텍스트는 파일 덤프 대신 결론만 받아 오래 간다. 파일 소유권 분할 + worktree 격리로 빌더 3~5개가 서로 안 밟고 병렬 진행한다. 빌더가 끝나는 즉시 독립 evaluator가 판정하므로(P2가 파이프라인 구조) A를 검증하는 동안 B 빌드가 계속 돈다. 자세히: [Fable 팀 가이드](docs/md/fable-team-guide.md) · [오케스트레이션 규칙](docs/md/orchestration.md).

### 검증 루프 — 스펙 정합성 채점 (Eval)

**무엇** — "구현했다"는 주장(claim)을 하나씩 실제 코드와 대조해 0~100점으로 채점하고, 95점 미만 항목만 골라 gap을 되먹여 다시 고치는 루프. 전 항목이 95점을 넘을 때까지 돈다. `stop-verify` 훅이 빌드·타입·테스트 **통과 여부**만 보는 것과 달리, 이건 **스펙의 각 요구가 실제로 구현됐는지**를 항목 단위로 본다.

채점은 **교차검증**이다. 코드를 짠 빌더가 아니라 독립 evaluator가 항목마다:

1. **코드 대조** — claim이 acceptance를 문자 그대로 충족하는지 파일을 직접 Read/Grep으로 확인. 주장을 믿지 않는다.
2. **테스트 실행** — Bash로 돌려 통과/실패/스킵/미수집을 구분. 명령 성공 ≠ 결과 정확.
3. **감점·근거** — 미구현·부분구현·계약(스키마·시그니처) 위반·엣지 누락마다 감점하고, 파일:라인과 테스트 원문을 evidence로 남긴다.
4. **gap** — 95 미만이면 빌더가 바로 고칠 수 있게 "무엇을 어떻게"를 구체로 적는다.

생성자와 채점자를 분리해 Self-Eval Blindspot(자기 결과를 후하게 보는 편향)을 막는다.

5단계 흐름 (`carve-verify-loop` 워크플로):

```
P1 Checklist  목표 → 체크리스트 항목 분해 (claim·acceptance·owns) → specs/checklist.json
P2 Build      항목별 빌더(worktree 격리)
P3 Score      항목별 evaluator → 코드 대조 + 테스트 실행 → 5축 루브릭 채점(exists·match·test·contract·no_regress, 합100) + gap·evidence
P4 Loop       score<95 항목만 gap 되먹여 P2로 (항목당 최대 3회, 외곽 8회)
P5 Verify     전 항목 95↑ → 통합 최종 판정(계약 위반·회귀 점검)
```

**어떻게 쓰나**

```
/verify-loop 주문 취소 API 구현        # 커맨드 — 목표만 주면 항목 자동 분해(3~7개)
```

항목을 직접 지정하려면 워크플로로: 발화에 `carve-verify-loop 실행` 또는 `ultracode` + `{goal, threshold, tasks[]}` 인자.

**효과** — 미달·미채점 항목이 남으면 `checklist-gate` Stop 훅이 완료 선언을 **차단(exit 2)**한다. 워크플로 없이 손으로 돌려도 강제력이 걸린다. 재작업은 실패 항목만 외과적으로 고치지, 전수 재실행이 아니다. `specs/checklist.json` 하나를 빌더·채점자·게이트가 함께 읽어(파일 기반 통신) 상태가 한 곳에 모인다. checklist.json이 없으면 게이트는 무동작이라 일반 작업은 방해받지 않는다. 자세히: [검증 루프 가이드](docs/md/verify-loop-guide.md).

### 골든셋 평가 — carve-eval

**무엇** — 검증 루프가 *태스크당* 완성도를 본다면, 골든셋 평가는 고정된 케이스 집합의 품질을 *시간축으로* 추적한다. `specs/goldenset/*.json`의 케이스(입력→루브릭)를 케이스별 k회 실행해 채점하고, 프롬프트·에이전트·스킬·규칙을 바꾼 뒤 "더 나빠지지 않았는지"를 숫자로 확인한다.

```
Validate  carve-validate.sh 프리플라이트 — 설정 오류를 런 전에 분리 (에이전트 0회)
          실패 시 런을 시작하지 않는다(비용 보호)
Load      specs/goldenset/*.json → 케이스(입력·assert·k·version) 로드
Run       케이스별 k회 실행 → 텍스트 assert(contains·regex·부정형) + 상태 assert + llm-rubric 채점
          상태 assert·setup이 있으면 리포 밖 임시 디렉토리에서 실행(정답 비노출)
Score     pass@k(능력)·pass^k(일관성) 산출 → suiteScore를 specs/eval-score.json에 append(추이)
          → baseline 대비 delta(기본 3pt) 초과 하락 시 [REGRESSION]
          → 케이스 version이 직전 run과 다르면 [VERSION CHANGED]
```

**채점의 3계층** — 위로 갈수록 신뢰도가 높다. 원칙은 **"에이전트의 말이 아니라 환경의 상태를 채점한다"**.

| 계층 | assert 타입 | 채점 주체 |
|------|------------|-----------|
| 상태 | `file_exists` · `file_contains` · `cmd_exit0` · `git_diff_contains` | `eval-state.sh` (결정적, 실제 워크디렉토리) |
| 텍스트 | `contains` · `not_contains` · `regex` · `not_regex` | 워크플로 순수 함수 |
| 정성 | `llm-rubric` | `evaluator` 에이전트 (대체 가능하면 상태 assert로 대체) |

**어떻게 시작하나** — 설치 직후엔 골든셋이 비어 있어 `/eval`이 돌 게 없다. **`/eval-init`을 한 번 실행**하면 프로젝트를 분석해(진입점·수정 빈도 상위·차단 이력·커버리지 실측) 7문항 인터뷰로 평가·품질 게이트를 확정하고, 골든셋 초안을 만들어 **케이스마다 궤적을 검사한 뒤 승인분만 편입**한다. 이후 재채점은 `/eval`(또는 발화에 `carve-eval 실행`), 케이스 증설은 `eval-goldenset`의 트레이스 마이닝 절차로 한다.

> 케이스 자동 확정은 의도적으로 막아뒀다 — 에이전트가 혼자 만든 골든셋은 **자기가 이미 통과하는 것만** 담아(자기강화) 지표를 무의미하게 만든다. 크리티컬 경로·실패 소재·엄격도는 사람이 정한다.

**어떻게 쓰나**

```bash
bash .claude/hooks/carve-validate.sh --red   # 케이스를 쓰거나 고친 직후 — 구조 + 신호 확인
```
```
/eval                                        # 전수 재채점 → 추이 append → 회귀 판정
```

이 리포 자체의 골든셋 20건(`specs/goldenset/`)이 작성 예시다 — 가드 준수 5 · 작업 품질 5 · 고난도 5 · 하네스 자체 5. 케이스는 **양방향으로 검증**한다: 작업 전에는 실패해야 하고(`--red`), 정답 상태에서는 통과해야 한다.

**효과** — 채점이 "느낌"이 아니라 재현 가능한 숫자가 되고, 프롬프트/루브릭 변경도 회귀로 잡힌다. pass@k(한 번이라도 통과)와 pass^k(매번 통과)를 분리해 "가끔 되는 시스템"을 드러낸다. 프리플라이트가 **"골든셋이 깨졌다"와 "에이전트가 못했다"를 분리**하고(fail-closed 채점기에서 둘 다 0점으로 보이는 문제), `--red`는 아무 작업 없이도 green이 되는 무의미한 케이스(NO-SIGNAL)를 잡는다. CI 강제는 옵트인 — `/eval-init`이 `eval-gate.sh`(추이만 읽는 결정론 게이트)를 리포트/차단 모드로 배선한다. **차단 모드는 골든셋을 유지할 사람이 있을 때만** 권한다.

## 전체 구성 (스킬·커맨드·훅)

### 스킬 (10종)

> **발동 시점** = 스킬이 자동 트리거되는 상황(설명 매칭) 또는 `/스킬명`으로 수동 호출하는 시점. 코어 게이트(anti-ai-slop·carve-guide)는 조건 충족 시 자동, 나머지는 대개 해당 작업 신호에서 발동한다.

| 스킬 | 구분 | 발동 시점 | 용도 |
|------|------|------|------|
| `anti-ai-slop` | 코어 | 시각물·문서·카피를 생성/수정하기 **직전 자동** | 시각 산출물 생성 전 슬롭(그라데이션·글로우·장식) 차단 게이트 |
| `carve-guide` | 코어 | HTML 산출물을 작성·갱신할 때(“예쁘게/그럴듯하게” 순간) 자동 | 하네스 HTML 산출물 작성 — 디자인 시스템·anti-slop·1000px 임베드 안전(§릴리스 갱신은 리포 전용) |
| `handoff` | 코어 | 세션 종료·컨텍스트 압축 직전(또는 `/handoff`) | 세션 종료·압축 전 진행상황을 `specs/HANDOFF.md`로 인계 |
| `changelog` | 코어 | 아키텍처·의존성·API 계약 등 비가역 결정 시 | 되돌릴 수 없는 결정·근거를 `specs/DECISIONS.md`에 기록 |
| `version-changelog` | 코어 | 릴리스 버전 변경(버전 업) 준비 시 | 릴리스 시 VERSION·CHANGELOG·README 버전 이력 동기 갱신 |
| `carve-harness-create` | 코어 | 전체 설치 후 스택 맞춤 정리 시(`/carve-harness-create`) | 스택 감지 후 불필요 구성 prune → 맞춤 하네스 |
| `checklist-loop` | 검증·오케스트레이션 | 구현 주장을 코드 대조 채점하는 루프를 손으로 돌릴 때(워크플로 없이) | 스펙→개발→체크리스트→95점 채점→재작업 루프 SOP + checklist.json 스키마 |
| `eval-goldenset` | 검증·오케스트레이션 | 프롬프트·규칙 변경 후 골든셋으로 회귀 확인·pass@k/pass^k 측정 시 | 골든셋(입력→루브릭) 정량 채점·점수 추이·회귀 판정 SOP + 케이스 형식 |
| `eval-init` | 검증·오케스트레이션 | 설치 후 `/eval`을 쓸 수 있게 만드는 1회성 셋업(`/eval-init`) | 프로젝트 분석 → 대화형 인터뷰 7문항으로 평가·품질 게이트 확정 → 골든셋 초안 → **궤적 검사 후 승인분만 편입** → CI 배선 → baseline 기록 |
| `theme-factory` | 외부(벤더) | 산출물에 색·폰트 테마를 적용할 때 | 산출물에 테마(색·폰트) 적용 — anti-slop 게이트 여전히 적용 |

> 벤더 스킬(`theme-factory`)은 `composiohq/awesome-claude-plugins`에서 SKILL.md만 벤더링. 플러그인 `frontend-design`(디자인 방향)·`ponytail`(간결화)은 스킬이 아니라 settings.json 선언으로 배포된다.

### 슬래시 커맨드 (14종)

| 커맨드 | 용도 |
|------|------|
| `/harness-audit` | 하네스 구성 PASS/FAIL (AUDIT-01~09, 이 리포 67체크) |
| `/commit-branch` | 현재 브랜치에 Conventional Commits로 커밋 + 푸시(`main` 직접 금지) |
| `/plan` | 작업을 완료 기준(SC) 단위로 분해 → `specs/` |
| `/verify` | 현재 변경을 SC·빌드·타입·테스트로 검증 |
| `/verify-loop` | 스펙→개발→체크리스트→채점 루프 — 전 항목 95점까지 재작업 반복 ([가이드](docs/md/verify-loop-guide.md)) |
| `/eval` | 골든셋 재채점 → pass@k/pass^k·점수 추이(`specs/eval-score.json`)·baseline 대비 회귀 판정 |
| `/review` | 변경분을 타입·보안·예외·상태관리 관점 검토 |
| `/commit` | 인자를 메시지로 현재 브랜치에 commit→pull→push (문제 시 해결책 제시) |
| `/ponytail*` (6) | ponytail 모드 제어·audit·debt·gain·review·help |

### 훅 (17종 — 이벤트 게이트 5 · 라이브러리 3 · CLI·헬퍼 9)

| 훅 | 트리거 (언제 작동) | 역할 |
|------|------|------|
| `pretool-guard` | PreToolUse — Write·Edit·Bash 실행 **직전마다** | 보호 경로(쓰기·삭제 모두)·시크릿·위험 명령(force push·`reset --hard`·`curl\|sh`·파괴적 SQL·루트/홈 재귀 삭제) 차단 + 하네스 자기보호(GUARD-07, 설치본) + 동일 툴콜 5연속 루프 브레이크(exit 2), fail-closed |
| `posttool-format` | PostToolUse — 파일 쓰기·수정 성공 **직후** | 확장자 언어 감지 후 포맷(후처리, exit 0) |
| `stop-verify` | Stop — 응답 종료(완료 선언) **직전** | 변경 스택 빌드·타입·테스트 게이트(실패 exit 2) |
| `checklist-gate` | Stop — 응답 종료 **직전**(`stop-verify` 뒤) | `specs/checklist.json` 미달(<95)·미채점 항목 남으면 완료 차단(exit 2). 루프 미개시면 무동작. **자가 우회 차단** — 채점 파일을 지워도 tombstone(`specs/.checklist-active`)이 남아 계속 차단, threshold 하향은 하한 95로 무효화 |
| `session-handoff` | 세션 **시작·압축·종료** 시점(SessionStart·PreCompact·SessionEnd) | 핸드오프 복원·저장 + 구성 배너 |
| `log-event` | 다른 훅이 판정을 기록할 때(내부 서브프로세스 호출) | JSONL 관측 append — 스키마·PII 마스킹 단일 출처 |
| `lib-protected` | 훅 로드 시 `source`로 참조(직접 실행 안 함) | 보호 경로·시크릿·위험 명령 정규식 단일 정의(순수 데이터) |
| `lib-stop-guard` | Stop 훅 로드 시 `source`로 참조 | Stop 루프 가드 공유 라이브러리 |
| `config-doctor` | 설정 점검 시(수동/설치기) | settings·구성 파일 정합 진단 |
| `harness-audit` | `/harness-audit` 실행 시(수동) | read-only PASS/FAIL — AUDIT-01~09(언어팩 무결성·Eval 성숙도 포함) |
| `logs-report` | `logs-report.sh` 실행 시(수동 CLI) | JSONL 판정 요약 + N일 회전 + `--tokens` 세션별 토큰 회계 |
| `eval-java` | Java/Spring 품질 스코어가 필요할 때(수동 스코어러) | Java/Spring 결정적 품질 확률 `P∈[0,1]`, LLM 없음 |
| `eval-state` | carve-eval 상태 assert 채점 시(헬퍼) | 골든셋 상태 assert(파일·명령·diff)를 실상태로 결정적 채점 — 자기 보고 불신. `--case <id>`로 골든셋 원본에서 직접 읽어 값 전달 중 이스케이프 훼손 차단 |
| `eval-gate` | CI·로컬에서 골든셋 회귀 판정 시(수동 CLI) | `specs/eval-score.json` 추이만 읽어 직전 대비 하락폭 판정 — LLM 없음. `--mode block`이면 회귀 시 exit 1, 추이 없음·손상은 fail-closed |
| `carve-validate` | `/eval` Phase 0 자동 · 케이스 작성 후 수동 CLI | 골든셋 프리플라이트 — 필수 필드·id 중복·미지 assert 타입·정규식 컴파일·`k` 범위 검증. `--red`는 setup 실행 후 "에이전트 작업 없이 이미 green"인 NO-SIGNAL 케이스 탐지 |
| `eval-score` | 빌드 건강도 점수가 필요할 때(수동 CLI) | 언어 무관 채점표(블루프린트 §5.7) — `.claude/stacks/*.sh` 어댑터로 G1 빌드·G2 테스트·G3 안전(거부권)·lint·회귀·커버리지 산출, 못 잰 항목은 `skipped`로 명시. `specs/SCORE.json` |
| `lib-packs` | 설치기·감사가 `source`로 참조 | 언어팩 매니페스트(`packs/*.pack`) 리더 — 목록·경로·감지(마커 파일 + ORM 의존성 grep) |

## 구조

```
├── CLAUDE.md / AGENTS.md    # 규칙 정본 (Claude / 크로스 에이전트)
├── VERSION · CHANGELOG.md · RELEASE.md
├── install.sh / uninstall.sh   # 설치·update·rollback·setup / 제거
├── vendor/ponytail/         # ponytail 모드 벤더링
├── .githooks/              # pre-commit·commit-msg (에이전트 무관 커밋 게이트)
├── specs/                   # 상태: 핸드오프·결정 기록·골든셋(goldenset/)
└── .claude/
    ├── settings.json        # 훅 6이벤트 등록
    ├── hooks/  (17종 + tests 26 스위트)
    ├── stacks/ (6종 — 스택별 검증 게이트·포맷·채점 어댑터, 언어팩 단위로 설치)
    ├── workflows/ (fable-team-pipeline · carve-verify-loop · carve-eval)
    ├── commands/ (14종) · agents/ (7종) · skills/ (10종) · rules/ (11종)
├── packs/                   # 언어팩 정의 6종 (typescript · java-spring · python · go · rust · database)
├── specs/goldenset/starters/ # 팩별 골든셋 스타터 (5언어 × 4건 — /eval-init 시드)
# docs/rules/code-convention/   # 스택 상세본 10종 (자동 로드 아님 — 필요 시 참조)
# docs/evaluator/<lang>-example/ # LLM-judge 예시 5종 (java · python · typescript · go · rust)
```

## 한계

> 실측 기준이다 — 아래 항목은 적대적 감사(우회 시도 34종 실행)에서 **실제로 뚫린 것만** 적었다.

- 훅 차단은 Claude Code 전용 — 타 에이전트는 pre-commit이 커밋 시점 차단.
- Bash 쓰기 가드는 명령 표면만 본다. **변수 간접(`F=.env; echo x > $F`)·인터프리터 경유(`python3 -c "open('.env','w')"`)는 미탐** (pre-commit이 2차 차단). 리다이렉트·`tee`·`cp`/`mv`·`sed -i`·`rm`/`touch`는 차단됨.
- 시크릿 스캔은 **리터럴 매칭**이다. base64 인코딩·문자열 분할 조립(`"sk-"+"..."`)은 미탐 — 사람이 리뷰해야 한다.
- 위험 명령 차단은 명령 위치 기준. `env`/`sudo`/`VAR=` 접두는 커버하지만, **셸 alias·함수로 감싸면 미탐**, `curl -o file && bash file`(2단계 다운로드 실행)도 미탐.
- Stop 게이트 스택: Java·Node/TS·Python·Go·Rust·bash — 그 외(Ruby·PHP·C#·Swift·Dart 등)는 미검증 통과. **각 스택은 툴체인이 설치돼 있을 때만 문다**(`go`·`cargo`·`ruff`/`pytest` 부재 시 best-effort 스킵).
- 게이트 자기보호(GUARD-07)는 **설치본에서만** 활성(`.claude/harness-manifest.txt` 기준) — 하네스 소스 레포는 자기 훅을 편집해야 하므로 예외.
- 검증 루프 게이트는 checklist.json 삭제·threshold 하향을 막지만, **채점 내용 자체가 거짓이면** 막지 못한다(evaluator 분리로 완화).
- `rules/` 슬림본만 상시 로드(스택 상세본은 `docs/rules/`로 분리 — 필요 시 참조).

## 로드맵

- [x] 스택 게이트 확장: Go(build·vet·test)·Rust(cargo check·test) · Python 감지 확대(requirements.txt·setup.py)
- [x] 게이트 자기보호 — 훅·settings.json·manifest 수정/삭제 차단(GUARD-07)
- [x] deny 패턴 변형 커버 — `rm -r -f`·`--recursive`·`env`/`sudo`/`VAR=` 접두(GUARD-08)
- [ ] 스택 게이트 확장 2차: Ruby·PHP·C#·Swift·Dart
- [ ] Bash 간접 쓰기(변수·인터프리터 경유) 탐지 강화
- [ ] 시크릿 스캔 인코딩 변형(base64·분할 조립) 대응
- [ ] rollback 시 신규 추가 파일 정리 (manifest diff)
- [ ] 시맨틱 버전 비교 (다운그레이드 방지)
- [ ] 스킬 트리거 문구(description) 수준 중복 검사
- [x] 골든셋 첫 실측 run → baseline 확보 (`specs/eval-score.json` 4 run)
- [x] 언어팩 선택 설치(typescript·java-spring·python·go·rust·database) + `install.sh pack` + AUDIT-09
- [x] 언어 무관 빌드 건강도 채점표 `eval-score.sh`(블루프린트 §5.7)
- [ ] 추이 파일 결정론 append(`eval-trend.sh`) · target 어댑터(`claude -p`·`exec:`)로 CI 실채점 · required 태그·극단 점수·stale 판정
- [ ] 채점 축 분리 리포트 (상태·텍스트·루브릭 점수 병기 — 실패 층위 식별)
- [ ] 응답자 출력 원문 보존 (`specs/eval-runs/` — 회귀 사후 분석)
- [ ] 응답자 구성 파라미터화 (같은 골든셋으로 모델·구성 간 비교)
- [ ] CI 골든셋 회귀 게이트 (−3pt 초과 하락 시 실패, 추이 안정화 후 배선)

## 라이선스

MIT — 자세한 내용은 [LICENSE](LICENSE). 벤더링된 `ponytail`은 자체 라이선스를 따른다(`vendor/ponytail/LICENSE`).

## 버전 이력

| 버전 | 날짜 | 요약 |
|------|------|------|
| v0.8.0 | 2026-08-06 | interactive eval-init setup + deterministic regression gate |
| v0.7.0 | 2026-08-03 | harden gates after adversarial audit |
| v0.6.0 | 2026-07-23 | add per-session token usage report |
| v0.5.1 | 2026-07-21 | replace non-working npx command in banner with eval tagline |
| v0.5.0 | 2026-07-21 | carve-eval golden-set quantitative eval loop (Stage B) |
| v0.4.1 | 2026-07-17 | mark caveman-activate.sh executable for AUDIT-01 |
| v0.4.0 | 2026-07-16 | add spec-to-checklist verify loop with scored evaluator gate |
| v0.3.0 | 2026-07-14 | embed ponytail and caveman modes into harness |
| v0.2.0 | 2026-07-12 | 커밋 커맨드 수정 |
| v0.1.1 | 2026-07-12 | show create banner on non-interactive install |
| v0.1.0 | 2026-07-12 | auto-version release on merge to main |
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
