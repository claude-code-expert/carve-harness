# 하네스 사용 가이드 (GUIDE)

> Claude Code 드롭인 하네스 — 전체 사용 설명 + 설치 내역.
> 대상: 이 하네스를 쓰거나 다른 프로젝트에 이식하려는 사용자.
> 기준: 릴리스 **v0.0.8** (하드닝 v1 Phase 1–5 + 오프라인·크로스에이전트 + update/rollback/setup + 게이트웨이 검증 v2). `/harness-audit` = 40 PASS.
> 최종 갱신: 2026-07-09.

이 문서는 `docs/md/HARNESS-TEMPLATE-MANUAL.md`(초기 뼈대 매뉴얼)와 `docs/md/harness-install-list.md`(외부 도구 설치 리스트)를 대체·갱신한다. 초기 매뉴얼은 하드닝 이전 상태(훅 4종·프로즈 감사·빈 스텁)를 기술하므로, **현재 상태는 이 GUIDE를 정본으로 본다.**

---

## 1. 이 하네스가 하는 일

하네스의 **3기둥**을 파일로 구현하고, v1에서 각 기둥의 강제 누수를 막았다. 언어 무관(Java/Spring·React/Next·Python 등) — 훅이 파일 확장자/스택을 감지한다.

| 기둥 | 구현 | v1에서 강해진 점 |
|------|------|------------------|
| 제약(Constraints) | `CLAUDE.md` + `.claude/rules/*` + `pretool-guard.sh` | jq 부재/파싱실패 시 **fail-closed(exit 2)**, 전 쓰기도구+Bash-write 커버, **파일 내용 시크릿 스캔** |
| 피드백(Feedback) | `posttool-format.sh` + `stop-verify.sh` + `.claude/agents/*` | Stop 무한루프 차단, 포맷 실패 가시화, **변경 모듈만 증분 검증** |
| 상태(State) | `session-handoff.sh` + `log-event.sh` + `specs/` | **실제 TODO/결정 수집**(스텐티널 제거), `SessionEnd` 저장, **JSONL 이벤트 로그** |
| (관측) | `logs/*.jsonl` | 6개 훅 진입점 전부 구조화 JSONL 기록 |
| (자가감사) | `harness-audit.sh` | 프로즈 → **기계적 PASS/FAIL** |

핵심 불변식: **차단은 반드시 `exit 2`** (`exit 1`은 비차단으로 통과됨). 훅은 stdin JSON을 `jq`로 파싱한다(환경변수 방식 아님).

---

## 2. 설치 내역 (이 환경 검증 결과)

`harness-install-list.md`의 생태계는 이 환경에 **이미 설치돼 있다.** 위험·전역·중복 명령(`npx tweakcc --apply`=Claude Code 패치, `curl|bash`, 전역 `npm -g`/`pip`, `~/.claude`로 clone)은 **자동 실행하지 않았다**(리스트 자체의 "전체설치 금지" 지침 + `safety.md` 준수). 필요한 것만 아래 상태로 확인.

| 리스트 항목 | 상태 | 근거 |
|-------------|:----:|------|
| A. mattpocock 스킬 세트 | ✅ 레포 내장 | `.claude/skills/` 19종 (implement·teach·domain-modeling 등) — 2026-07-08 `.agents/skills`에서 이전, 기존 기능과 중복 5종 제외 |
| B. ECC 보안·평가 에이전트 | ✅ 설치됨 | 프로젝트 `.claude/agents/`: code-reviewer·evaluator·security-reviewer·silent-failure-hunter·state-reviewer |
| C. GSD (SDD 킷) | ✅ 설치됨 | `~/.claude/agents/` gsd-* 33종 + `/gsd:*` 커맨드 동작 |
| D-4. caveman (출력 압축) | ✅ 설치됨·활성 | 이 세션에서 caveman/ponytail 모드 동작 중 |
| 전제 도구 | ✅ jq·node·npm·pnpm·python3·pip·gradle | `command -v` 확인. jq·shellcheck는 `vendor/bin` 내장 — 오프라인 머신은 `install.sh`가 배치 |
| D-2 codesight | ✅ 설치됨 | `.codesight/CODESIGHT.md` + `skills.md` 생성됨 (2026-07-07 스캔) |
| D-3 superpowers | ✅ 설치됨·활성 | 플러그인 목록 확인 (`superpowers@superpowers-marketplace`), 세션에서 스킬 동작 |
| D-1 LSP / D-5 headroom | ⛔ 미설치(선택) | 토큰 절감용. 필요 시 §9 참고 — 전역/네트워크라 승인 후 수동 |
| `gh` (GitHub CLI) | ✅ 설치·인증됨 | `~/.local/bin/gh`, github.com 로그인 확인 (2026-07-08) |

> **자동 실행하지 않은 이유**: `tweakcc`는 실행 중인 Claude Code 바이너리를 패치하고, `curl \| bash`는 원격 스크립트를 그대로 실행하며, 전역 설치는 이 프로젝트 밖(사용자 환경)을 바꾼다. 비가역·시스템 전역 작업은 명시 승인 후에만 실행한다. 원하는 항목을 지정하면 개별 실행한다.

---

## 3. 디렉토리 구조 (현재)

```
harness/
├── CLAUDE.md                 # 제약: 전역 가드레일 (3기둥·스택감지)
├── AGENTS.md                 # 에이전트 공통 표준 (크로스 에이전트 정본)
├── RULES.md                  # 룰 인덱스
├── GUIDE.md                  # (이 문서)
├── VERSION                   # 릴리스 버전 (update 비교 기준)
├── install.sh                # 설치기: curl 원격/오프라인 부트스트랩 + update/rollback/setup (멱등)
├── uninstall.sh              # 제거기: manifest 기반, 드라이런 기본
├── vendor/bin/               # 내장 정적 바이너리: jq·shellcheck + SHA256SUMS
├── .githooks/pre-commit      # 에이전트 무관 커밋 게이트 (jq 불필요)
├── .gitignore                # logs/ · 루트 .env* · specs/HANDOFF.md · .claude/bin/
├── specs/                    # 상태: SDD 산출물 (HANDOFF/DECISIONS는 훅·스킬이 생성)
│   └── README.md
├── logs/                     # 관측: 날짜별 JSONL 이벤트 로그 (gitignore)
├── docs/md/                  # 초기 매뉴얼·설치 리스트 (역사 보존용 — 정본은 이 GUIDE)
└── .claude/
    ├── settings.json         # 훅 6이벤트 + permissions.deny + $schema
    ├── bin/                  # install.sh가 vendor에서 배치 (gitignore)
    ├── hooks/                # 훅 스크립트 + 라이브러리 + 자가감사
    │   ├── pretool-guard.sh      # PreToolUse 차단
    │   ├── posttool-format.sh    # PostToolUse 포맷
    │   ├── stop-verify.sh        # Stop 증분 검증
    │   ├── session-handoff.sh    # SessionStart/PreCompact/SessionEnd 핸드오프
    │   ├── log-event.sh          # JSONL append 헬퍼 (PII 마스킹)
    │   ├── logs-report.sh        # JSONL 요약 리포트 + --rotate 회전
    │   ├── lib-protected.sh      # PROTECTED_RE + SECRETS_RE 단일 소스
    │   ├── harness-audit.sh      # 기계적 자가감사
    │   └── tests/*.test.sh       # 훅별 어서션 (11 스위트)
    ├── commands/             # /plan /verify /review /commit /harness-audit /squad*
    ├── agents/               # reviewer 5종 + tdd-guide·e2e-runner·pr-test-analyzer + squad 8종 (16)
    ├── skills/               # handoff · changelog · version-changelog · anti-ai-slop + mattpocock 파생 19종
    └── rules/
        ├── common/           # security·testing·git-workflow (항상 적용)
        ├── code-convention/  # 스택별 코딩 표준 8종
        ├── java-spring/      # patterns (**/*.java) · gateway-testing (게이트웨이 파일)
        ├── react-next/       # patterns (**/*.ts,tsx)
        └── safety.md · database.md · frontend.md · api-routes.md · testing.md
```

---

## 4. 훅 레퍼런스 (현재 동작)

`settings.json` 등록 이벤트: **PreToolUse · PostToolUse · Stop · SessionStart · PreCompact · SessionEnd** (6종). 모든 훅 명령은 `${CLAUDE_PROJECT_DIR}` 기준(서브디렉토리 안전).

| 훅 | 이벤트 | 동작 | 종료코드 |
|----|--------|------|----------|
| `pretool-guard.sh` | PreToolUse (Write/Edit/MultiEdit/NotebookEdit/Bash) | ① jq 부재·JSON 파싱실패 → **차단**(fail-closed) ② 보호경로(`.env`·prod·시크릿·마이그레이션) 수정 차단 ③ Bash 쓰기명령이 보호경로 대상 시 차단 ④ **파일 내용 하드코딩 시크릿**(AKIA/sk-/ghp_/PEM/JWT) 차단 | 차단 **exit 2** / 허용 0 |
| `posttool-format.sh` | PostToolUse (Write/Edit) | 확장자 감지 포맷(spotless/prettier 등); 포맷터 미설치·오류를 **JSONL에 기록**(삼키지 않음) | 0 (비차단) |
| `stop-verify.sh` | Stop | 스택 감지 후 빌드/타입/테스트; `stop_hook_active` **루프 차단**; jq 부재 시 best-effort 스킵; **변경 모듈만 증분**(git diff) | 실패 **exit 2** / 통과 0 |
| `session-handoff.sh` | SessionStart / PreCompact / SessionEnd | start=핸드오프 복원, save=**실제 수집**(STATE.md TODO·미완료 플랜·git 카운트·DECISIONS 최근5) → `specs/HANDOFF.md` | 0 |
| `log-event.sh` | (서브프로세스 헬퍼) | 6훅 진입점의 이벤트를 `logs/*.jsonl`에 1줄 append; 보호경로/PII는 `<masked>` | 항상 0 |
| `lib-protected.sh` | (데이터) | `PROTECTED_RE`(보호경로) + `SECRETS_RE`(시크릿) 단일 정의 — 재정의 금지. `protected-extra.regex`/`secrets-extra.regex` OR-병합(업데이트 보존) | — |
| `logs-report.sh` | (수동 CLI) | `logs/*.jsonl` 요약 리포트; `--rotate N`으로 N일 이전 로그 삭제 | 0 |
| `harness-audit.sh` | (수동 CLI / `/harness-audit`) | 하네스 구성 40체크 PASS/FAIL (§7) | 실패 시 비영 |

**게이트웨이 확장** (게이트웨이 파일 변경 시): `stop-verify.sh`가 `*Gateway*/*Filter*/*Auth*/*RateLimit*.java` 변경을 감지하면 전체 대신 `*GatewayIntegration*` 통합 테스트만 증분 실행(GATE-04), 실패 시 exit 2(GATE-05).

**git 훅** (`.githooks/`, `core.hooksPath`로 활성 — 에이전트 무관, jq 불필요):

| 훅 | 시점 | 동작 | 종료코드 |
|----|------|------|----------|
| `pre-commit` | git commit(내용) | 스테이징된 보호경로·하드코딩 시크릿 차단. 새 마이그레이션은 허용(승인 경로) | 차단 1 / 허용 0 |
| `commit-msg` | git commit(메시지) | 제목 Conventional Commits 형식(`type(scope): subject`, ≤72자) 검증. merge/revert/fixup 면제 | 위반 1 / 통과 0 |

관측: 훅 발화 1건 = JSONL 1줄(`{ts,event,tool,decision,...}`). `jq . logs/$(date -u +%F).jsonl`로 확인.

---

## 5. 전체 인벤토리 (누락 없는 전량 리스트)

> 이 절은 하네스가 동작하는 **모든** 커맨드·에이전트·스킬·룰의 완전한 목록이다. 훅은 §4 참조.
> 호출 방식: **커맨드** = 슬래시 `/이름` · **에이전트** = description 자동위임 또는 `"use the X agent"` (squad는 트리거 키워드) · **스킬** = `/이름`(사용자 호출) 또는 description 자동발동.

### 5.1 커맨드 (`.claude/commands/`, 14종)

| 파일 | 호출 | 용도 · 사용법 · 예시 |
|------|------|----------------------|
| `plan.md` | `/plan` | 작업을 완료기준(SC) 단위로 분해 → `specs/`. 예: `/plan "OAuth 구글 로그인 추가"` |
| `verify.md` | `/verify` | 현재 변경을 SC·빌드·타입·테스트로 검증. 예: `/verify` |
| `review.md` | `/review` | 변경분을 타입·보안·예외·상태관리 관점 검토. 예: `/review` |
| `commit.md` | `/commit` | commitlint 준수 커밋 메시지 준비. **자동호출 비활성**(`disable-model-invocation`) — 사용자만. 예: `/commit` |
| `harness-audit.md` | `/harness-audit` | 하네스 구성 40체크 PASS/FAIL(§7). 예: `/harness-audit` |
| `squad.md` | `/squad <member> [task]` | Squad 에이전트 디스패처. 예: `/squad review 이 diff` |
| `squad-plan.md` | `/squad-plan <feature>` | 기능 기획·유저스토리·와이어프레임. 예: `/squad-plan 결제 모듈` |
| `squad-review.md` | `/squad-review [scope]` | 코드 리뷰(보안·성능·유지보수). 예: `/squad-review src/auth` |
| `squad-qa.md` | `/squad-qa [scope]` | QA·테스트 실행·리포트. 예: `/squad-qa` |
| `squad-refactor.md` | `/squad-refactor [scope]` | 중복·긴 함수·네이밍 리팩토링. 예: `/squad-refactor UserService` |
| `squad-debug.md` | `/squad-debug <error>` | 근본 원인 분석(수정 제안만). 예: `/squad-debug "NPE at line 42"` |
| `squad-audit.md` | `/squad-audit [scope]` | 보안 감사(OWASP·시크릿). 예: `/squad-audit` |
| `squad-docs.md` | `/squad-docs [type]` | 문서 생성(README·API·JSDoc). 예: `/squad-docs api` |
| `squad-gitops.md` | `/squad-gitops [type]` | 커밋 메시지·PR·체인지로그. 예: `/squad-gitops pr` |

### 5.2 에이전트 (`.claude/agents/`, 16종)

**하네스 검증 에이전트** (생성/검증 분리 — Evaluator 축):

| 파일 | 모델 | 설명 · 호출 |
|------|------|-------------|
| `evaluator.md` | sonnet | 생성물을 완료기준(SC)·타입 안전성으로 독립 검증. `"use the evaluator agent"` |
| `code-reviewer.md` | sonnet | 가독성·구조·중복·에러 처리 리뷰. `"use the code-reviewer agent"` |
| `security-reviewer.md` | sonnet | 시크릿 노출·인증/인가 누락·인젝션 + **게이트웨이 인증/인가/레이트리미트 우회**. `"use the security-reviewer agent"` |
| `silent-failure-hunter.md` | haiku | 삼켜진 예외·빈 catch·무시된 에러 반환값 탐지. `"use the silent-failure-hunter agent"` |
| `state-reviewer.md` | sonnet | 프론트 상태관리(전역/서버/로컬 경계)·트랜잭션 경계 검증. `"use the state-reviewer agent"` |
| `tdd-guide.md` | sonnet | 게이트웨이·백엔드 기능을 red→green TDD 루프로 유도, GSD `<verify><done>` 연결. `"use the tdd-guide agent"` |
| `e2e-runner.md` | sonnet | 게이트웨이 Walking Skeleton(전 구간 관통 e2e) 세우고 실행. `"use the e2e-runner agent"` |
| `pr-test-analyzer.md` | sonnet | 변경분(PR/diff)의 테스트 충분성 평가(커버리지·SC매핑·스텁괴리). `"use the pr-test-analyzer agent"` |

**Squad 파이프라인 에이전트** (트리거 키워드로 자동위임):

| 파일 | 모델 | 설명 · 트리거 키워드 |
|------|------|----------------------|
| `squad-plan.md` | opus | 기획·브레인스토밍. 키워드: "기획","planning","브레인스토밍","유저스토리","와이어프레임","설계","스펙" |
| `squad-review.md` | opus | 코드 리뷰. 키워드: "리뷰","review","코드 리뷰","PR 리뷰","코드 봐줘" (코드 변경 후 PROACTIVELY) |
| `squad-qa.md` | sonnet | QA·테스트. 키워드: "테스트","test","QA","검증","동작 확인","돌려봐" |
| `squad-refactor.md` | opus | 리팩토링. 키워드: "리팩토링","refactor","정리","클린업","추출","중복 제거","DRY" |
| `squad-debug.md` | opus | 디버깅. 키워드: "디버깅","debug","에러","버그","왜 안 돼","안됨","크래시" |
| `squad-audit.md` | opus | 보안 감사. 키워드: "보안","security","취약점","vulnerability","audit","OWASP","시크릿 검사" |
| `squad-docs.md` | sonnet | 문서. 키워드: "문서","README","docs","API 문서","JSDoc","아키텍처 문서","주석" |
| `squad-gitops.md` | haiku | Git 워크플로. 키워드: "커밋 메시지","commit message","PR 작성","체인지로그","릴리즈 노트" |

### 5.3 스킬 (`.claude/skills/`, 23종)

**하네스 코어 스킬** (자동발동):

| 파일 | 호출 | 설명 |
|------|------|------|
| `handoff/` | 자동/`/handoff` | 세션 종료·압축 직전 진행 상황을 `specs/HANDOFF.md`로 인계 |
| `changelog/` | 자동/`/changelog` | 되돌릴 수 없는 결정·근거를 `specs/DECISIONS.md`에 시간순 기록(append-only) |
| `version-changelog/` | 자동/`/version-changelog` | 릴리스 시 VERSION·CHANGELOG·README 버전이력 동시 갱신. **VERSION만 바꾸면 pre-commit 차단** |
| `anti-ai-slop/` | 자동/`/anti-ai-slop` | 이미지·HTML·SVG 생성 전 발동 — 그라데이션·글로우·장식 모션 차단 게이트 |

**mattpocock 파생 스킬 19종** (대부분 `/이름` 사용자 호출 전용 = `disable-model-invocation`):

| 파일 | 호출 | 설명 |
|------|------|------|
| `ask-matt/` | `/ask-matt` | 상황에 맞는 스킬·플로우를 라우팅 |
| `implement/` | `/implement` | PRD·이슈 기반으로 작업 구현 |
| `teach/` | `/teach` | 새 스킬·개념을 가르침 |
| `edit-article/` | `/edit-article` | 아티클 초안 구조·명료성·문장 개선 |
| `to-prd/` | `/to-prd` | 현재 대화를 PRD로 합성해 이슈 트래커에 발행 |
| `to-issues/` | `/to-issues` | 계획·스펙·PRD를 독립 이슈(트레이서 불릿)로 분해 |
| `loop-me/` | `/loop-me` | 만들 워크플로 스펙을 심문식으로 다듬음 |
| `improve-codebase-architecture/` | `/improve-codebase-architecture` | 심화(deepening) 기회를 HTML 리포트로 스캔 후 선택 심문 |
| `setup-matt-pocock-skills/` | `/setup-matt-pocock-skills` | 리포에 이슈트래커·라벨·도메인 문서 레이아웃 최초 세팅 |
| `codebase-design/` | 자동 | 깊은 모듈 설계 공용 어휘(인터페이스·seam·테스트 가능성) |
| `design-an-interface/` | 자동 | 병렬 서브에이전트로 여러 인터페이스 설계안 생성("design it twice") |
| `domain-modeling/` | 자동 | 프로젝트 도메인 모델·유비쿼터스 언어 구축·정련 |
| `prototype/` | 자동 | 설계 질문에 답하는 일회용 프로토타입 |
| `qa/` | 자동 | 대화형 QA — 버그 리포트를 GitHub 이슈로 발행 |
| `request-refactor-plan/` | 자동 | 인터뷰로 tiny-commit 리팩터 계획 → GitHub 이슈 |
| `migrate-to-shoehorn/` | 자동 | 테스트의 `as` 단언을 @total-typescript/shoehorn으로 이전 |
| `resolving-merge-conflicts/` | 자동 | 진행 중인 git merge/rebase 충돌 해결 |
| `scaffold-exercises/` | 자동 | 연습문제 디렉토리 구조(문제·해답·해설) 스캐폴딩 |
| `setup-pre-commit/` | 자동 | Husky + lint-staged pre-commit(Prettier·타입체크·테스트) 세팅 |

### 5.4 룰 (`.claude/rules/`, 18파일, glob 자동적용)

| 경로 | glob | 내용 |
|------|------|------|
| `common/security.md` | 항상 | 시크릿·PII 취급, 입력 신뢰 금지 |
| `common/testing.md` | 항상 | red→green, 커버리지 80% |
| `common/git-workflow.md` | 항상 | Conventional Commits, force push 금지 |
| `safety.md` | 항상 | 위험동작(DB 파괴·git·프로덕션) 승인 게이트 |
| `database.md` | 항상 | id/타임스탬프·soft delete·N+1·마이그레이션 |
| `frontend.md` · `api-routes.md` · `testing.md` | 항상 | 프론트·API·테스트 공통 |
| `code-convention/dev-stack-*.md` (8) | 항상 | java-spring·react·nextjs·typescript·javascript·python·fastapi·orm 스택 표준 |
| `java-spring/patterns.md` | `**/*.java` | 계층 분리·생성자 주입·LAZY·트랜잭션 |
| `java-spring/gateway-testing.md` | 게이트웨이 파일 | 5기능 검증 SC·테스트 피라미드·도구 스택 (GATE-04가 강제) |
| `react-next/patterns.md` | `**/*.ts,tsx` | Hooks·key·서버상태 분리 |

> 룰 상세본: `code-convention/dev-stack-*.md`. 파일 판별·게이트 매핑은 `harness-audit`(AUDIT-03/07)이 점검.

---

## 6. 사용 워크플로

**드롭인 설치** (다른 프로젝트로 이식) — `install.sh`가 체크섬 검증→jq/shellcheck 배치→권한→pre-commit 게이트→audit까지 자동 (상세: README):
```bash
cd /path/to/your-project
# 사설 레포 — 토큰 필요(README "사설 소스 레포 토큰" 참조)
curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
  https://raw.githubusercontent.com/wevesolutions/harness/main/install.sh | GITHUB_TOKEN=$GITHUB_TOKEN bash
# 오프라인(토큰 불필요): HARNESS_SRC_DIR=/path/to/harness-copy bash /path/to/harness-copy/install.sh
```

**GSD SDD 흐름** (설치돼 있음):
```
/gsd:new-project → /gsd:plan-phase N → /gsd:execute-phase N → /gsd:verify-work
```
(이 프로젝트 자체가 이 흐름의 산출물 — `.planning/`에 5개 페이즈 기록.)

**실제 시나리오 — "로그인 폼 추가"(Java+React)**:
```
1) /plan "OAuth 구글 로그인 폼 추가"       → specs/에 SC (유효토큰=200, 무효=401)
2) 구현: backend/*.java → posttool-format spotless
        frontend/*.tsx → prettier
        .env 수정 시도 → pretool-guard exit 2 차단
        코드에 sk-... 하드코딩 → GUARD-04 내용 스캔 exit 2 차단
3) 응답 종료: stop-verify 가 변경된 스택만 빌드/타입체크 (증분)
4) /review → security-reviewer 인가·시크릿 점검
5) /verify → specs/ SC 대조
6) 세션 종료/압축 → session-handoff 가 실제 TODO·결정 담아 HANDOFF.md 저장
```

---

## 7. 자가 점검 — `/harness-audit`

프로즈 체크리스트가 아니라 **기계적 PASS/FAIL 스크립트**(`exit 0`=정상, 비영=누수).

```bash
bash .claude/hooks/harness-audit.sh      # 또는 슬래시 /harness-audit
```

점검 항목:
- **AUDIT-01**: jq 존재 · 6개 훅 이벤트 등록 · 참조 훅 `+x` · 전 훅 `bash -n` clean.
- **AUDIT-02**: 쓰기 매처(`Write|Edit|MultiEdit|NotebookEdit|Bash`) · Bash-write 검사 존재.
- **AUDIT-03**: 안전규칙(safety.md/security.md)→게이트 매핑 · `[내용없음]` 스텐티널 핸드오프 거부.
- **AUDIT-04**: 크로스 에이전트 — AGENTS.md 포인터(`.cursorrules`/`codex.md`) · pre-commit 게이트 `+x` · `core.hooksPath` · vendor 체크섬.
- **AUDIT-05**: 규칙 위생 — 빈 파일 · ' copy' 파일 · 바이트 동일 중복.
- **AUDIT-06**: 스킬 — 프런트매터 검증 · repo↔전역 이름 충돌.

Claude Code 업그레이드마다 재실행해 게이트가 여전히 작동하는지 증명. 현재: **40 PASS, 0 FAIL**.

테스트 스위트도 함께:
```bash
for t in .claude/hooks/tests/*.test.sh; do bash "$t"; done   # 11 스위트 전부 green
```

---

## 8. 커스터마이징

| 하고 싶은 것 | 수정 위치 |
|-------------|-----------|
| 도메인 금지 규칙 추가 | `CLAUDE.md` "절대 금지" / `.claude/rules/*` |
| 보호 경로·시크릿 패턴 추가 | `.claude/hooks/protected-extra.regex` / `secrets-extra.regex` (1줄 1정규식, 업데이트에도 보존 — lib 직접 수정은 update 시 덮임) 또는 `install.sh setup` |
| 포맷터 변경 | `.claude/hooks/posttool-format.sh` case |
| 검증 명령 변경 | `.claude/hooks/stop-verify.sh` (증분 스코프 유지) |
| 새 스택 추가(예: Python) | `.claude/rules/<stack>/` + 훅 case |
| settings.json 변경 | **safety.md 승인 게이트** — 임의 변경 금지 |

### 8.1 도메인 규칙 보강 — 어떻게 쌓나

**언제**: 코드리뷰·대화에서 같은 지적이 2번 나오면 그 즉시 규칙화한다 (AGENTS.md §1). "그때그때 말해주지"는 3번째 위반을 못 막는다.

**어디에·어떤 형식으로**: `CLAUDE.md`의 `## 도메인 규칙` 섹션(`install.sh setup`이 생성)에 1줄 1규칙, **검증 가능한 금지/필수 문장**으로:

```markdown
## 도메인 규칙
- 주문 금액 음수 불가 — Order.amount 검증은 도메인 계층에서
- 결제 승인 없이 배송상태 변경 금지
- 회원 삭제는 soft delete만 (deletedAt) — 물리 DELETE 금지
```

나쁜 예: "금액 처리 조심" (검증 불가). 좋은 예: "X 불가 / Y 없이 Z 금지" (위반 판별 가능).

**강제 승격** — 규칙(md)은 설득이고, 훅은 차단이다. 규칙이 아래 형태로 표현되면 게이트로 올려라:

| 규칙 유형 | 승격 위치 | 예 |
|-----------|-----------|-----|
| 특정 파일/경로 수정 금지 | `.claude/hooks/protected-extra.regex` 1줄 | `deploy/prod/` |
| 특정 문자열 커밋 금지 | `.claude/hooks/secrets-extra.regex` 1줄 | `INTERNAL_API_KEY_[A-Z0-9]{8}` |
| 특정 명령 실행 금지 | `settings.json` `permissions.deny` (safety.md 승인 필요) | `Bash(kubectl delete*)` |
| 코드 패턴 (음수 금액 등) | 훅으로 못 잡음 — **테스트로 강제** (`.claude/rules/common/testing.md`) | 도메인 단위 테스트 |

### 8.2 미지원 스택 게이트 추가 — Go 예시 (그대로 복붙 후 치환)

3파일 수정이면 끝. Rust/Ruby도 명령만 바꿔 동일.

**① 규칙 파일** — `.claude/rules/go/conventions.md` 생성 (`paths` glob이 자동 로드 트리거):

```markdown
---
paths: ["**/*.go"]
---
# Go 규칙 (자동 로드)
- gofmt 통과 필수. 에러는 반드시 처리 (`_ =` 무시 금지).
- 패키지명 소문자 단수. context.Context는 첫 파라미터.
```

**② Stop 게이트** — `.claude/hooks/stop-verify.sh`의 변경 감지부(30행 부근)와 게이트부에 각각 추가:

```bash
# 감지부 — 기존 java/node/py/sh 라인 아래에:
go_changed=1
[ -n "$CHANGED" ] && { printf '%s\n' "$CHANGED" | grep -Eq '\.go$|go\.mod' && go_changed=1 || go_changed=0; }

# 게이트부 — 기존 스택 블록들 아래에 (도구 없으면 skip = 기존 관례):
if [ "$go_changed" -eq 1 ] && [ -f go.mod ]; then
  if command -v go >/dev/null 2>&1; then
    test -z "$(gofmt -l . 2>/dev/null)" || { echo "gofmt 미준수"; fail=1; }
    go vet ./... 2>&1 | tail -20 || fail=1
    go test ./... 2>&1 | tail -20 || fail=1
  fi
fi
```

**③ 검증** — 게이트가 진짜 무는지 확인하고 끝:

```bash
bash -n .claude/hooks/stop-verify.sh                    # 문법
echo 'package main' > /tmp/bad.go                        # 일부러 gofmt 위반 파일로
CLAUDE_PROJECT_DIR=$PWD bash .claude/hooks/stop-verify.sh # exit 2 나오면 성공
bash .claude/hooks/harness-audit.sh                      # 40 PASS 유지 확인
```

> 주의: `stop-verify.sh`는 manifest 파일 — 하네스 `update` 시 덮이고 백업(`logs/harness-backup/`)에 남는다. 업데이트 후 커스텀 case를 백업에서 재적용하라 (UPDATED 로그에 표시됨).

### 8.3 팀 공지 — 복붙용

Slack/위키에 그대로:

```
[공지] 이 레포는 코딩 에이전트 하네스가 적용되어 있습니다.

- Claude Code 사용자: 할 일 없음 — 훅이 자동으로 차단·검증합니다.
- Cursor / Codex / Aider 등: 레포 루트 AGENTS.md가 규칙 정본입니다.
  (.cursorrules와 codex.md가 자동으로 가리키므로 대부분 자동 인식)
- 전원 공통: 커밋 시 .githooks/pre-commit이 보호경로·시크릿·버전정합을
  검사합니다. git commit --no-verify 우회는 금지 (AGENTS.md §0).
- 규칙 추가 제안: CLAUDE.md 도메인 규칙 또는
  .claude/hooks/protected-extra.regex 수정 PR로 올려주세요.
```

신규 입장 확인법: `bash .claude/hooks/harness-audit.sh` 가 40 PASS면 정상 세팅.

---

## 9. 사용자가 별도로 설치해야 하는 것

하네스는 **번들하지 않는 전제 도구**가 있다. jq·shellcheck는 `vendor/bin` 내장이라 `install.sh`가 배치하지만, 아래는 **사용자/프로젝트가 직접** 설치한다. 필수(하네스 게이트 동작 전제)와 선택(워크플로 강화)으로 나눈다.

### 9.1 필수 — 하네스 동작 전제

| 도구 | 왜 필요 | 설치 방법 | 사용/확인 |
|------|---------|-----------|-----------|
| **bash + git** | 훅·설치기·핸드오프가 bash, 상태/커밋 게이트가 git | Linux/macOS 기본. **Windows는 WSL 필수** | `bash --version` · `git --version` |
| **스택 도구** (프로젝트별) | Stop 게이트가 이 도구로 빌드·검증 — 없으면 해당 게이트는 skip 통과(차단 아님) | 아래 9.1.1 | `bash install.sh setup`이 감지 리포트 |

#### 9.1.1 스택별 검증 도구 (프로젝트에 하나라도 있으면 그 게이트 활성)

| 스택 | 도구 | 설치 | Stop 게이트가 하는 일 |
|------|------|------|------------------------|
| Node/TS | prettier·eslint·tsc·vitest/jest | `pnpm add -D prettier eslint typescript vitest` | 포맷 + `tsc --noEmit` + 테스트 |
| Java/Spring | gradle(+spotless·jacoco) | 프로젝트 `gradlew` 동봉(Gradle wrapper) | `./gradlew compileJava test` (게이트웨이는 `*GatewayIntegration*` 증분) |
| Python | ruff·pytest | `pip install ruff pytest` (또는 `uv`) | `ruff check` + `pytest` |
| 게이트웨이(Java) | WireMock·Testcontainers | `build.gradle`에 의존성 추가 (룰 `gateway-testing.md` 참조) | 통합 테스트 실 컨테이너 검증 |

> 스택 도구가 없으면 게이트는 **조용히 통과**(best-effort) — 하네스가 없는 도구를 강요하지 않는다. 있으면 자동으로 문다.

### 9.2 선택 — 워크플로 강화 (전역/네트워크 → 승인 후 수동)

| 도구 | 용도 | 설치 방법 | 사용 방법 |
|------|------|-----------|-----------|
| **GSD** (SDD 킷) | 스펙 주도 개발 오케스트레이션(`.planning/`) | `npx get-shit-done-cc --local` (`install.sh setup`이 제안) | `/gsd:new-project` → `/gsd:plan-phase N` → `/gsd:execute-phase N` → `/gsd:verify-work` |
| **gh CLI** | PR·이슈·원격 인증 | 배포판 패키지매니저(`brew/apt install gh`) | `gh auth login` → `gh pr create` (사설 레포 하네스 update 토큰도 `gh auth token`) |
| **codesight** | 세션 시작 구조맵으로 탐색 토큰 절감 | `npx codesight --init` | `.codesight/CODESIGHT.md` 자동 참조 |
| **superpowers** | 프로세스 스킬 프레임워크(brainstorming·systematic-debugging) | `/plugin install superpowers@superpowers-marketplace` | 스킬 자동 발동 |
| **caveman / ponytail** | 출력 압축 / 과잉설계 억제 | `/plugin install caveman@caveman` · `ponytail@ponytail` | `/caveman lite\|full\|ultra` · `/ponytail lite\|full\|ultra` |
| **LSP** | 코드탐색 토큰 대폭 절감 | `npx tweakcc --apply` + `npm i -g @vtsls/language-server` | ⚠️ **Claude Code 바이너리 패치** — 위험 높음, 신중히 |
| **headroom** | API 페이로드 압축 | `pip install --user headroom` → `headroom wrap claude` | ⚠️ 전역 pip — 중간 위험 |

> **설치 원칙**: 전역 설치·네트워크 실행·바이너리 패치(`tweakcc`)는 프로젝트 밖(사용자 환경)을 바꾸므로 **명시 승인 후 수동**. `install.sh setup`은 git·PATH·LICENSE·GSD만 대화형으로 다루고, 나머지 선택 도구는 위 표대로 개별 설치한다.

---

## 10. 검증 / 한계

- 훅 8개 `bash -n` clean · 테스트 11 스위트(125건) 전부 통과 · `/harness-audit` 40 PASS. (2026-07-09 실검증)
- **한계(문서화된 천장)**: Bash 파이프/heredoc 간접 쓰기의 시크릿 스캔은 best-effort; 코드 `TODO/FIXME` 스캔은 범위 밖; `LICENSE` 미추가(보류). 추적: `.planning/REQUIREMENTS.md`.
- 훅/스킬 규약은 Claude Code 버전에 따라 바뀔 수 있음 — 도입 전 `/hooks`·`/plugins`로 현행 확인, `code.claude.com/docs` 대조.

---

*근거: 이 리포의 `.planning/`(Phase 1–5 산출물), `.claude/` 실제 파일, `/harness-audit` 실행 결과. 초기 매뉴얼/설치리스트는 `docs/md/`에 보존.*
</content>
