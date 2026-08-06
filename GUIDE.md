# 하네스 사용 가이드 (GUIDE)

> Claude Code 드롭인 하네스 — 전체 사용 설명 + 설치 내역.
> 대상: 이 하네스를 쓰거나 다른 프로젝트에 이식하려는 사용자.
> 기준: 릴리스 **v0.8.0** (v1 하드닝 + 크로스에이전트 + update/rollback/setup + 게이트웨이 검증 v2 + Java/Spring 결정적 evaluator v3 + 설치 구성 선택·fable 오케스트레이터 팀 + verify-loop·carve-eval + 강한 모델 기준 감량 + 적대적 감사 게이트 경화 + `/eval-init` 평가 게이트 셋업). `/harness-audit` = 47 PASS.
> 최종 갱신: 2026-08-06.

초기 뼈대 매뉴얼·외부 도구 설치 리스트(구 `docs/md/`)는 v0.6.x에서 제거됐다(git 히스토리 보존). **현재 상태는 이 GUIDE를 정본으로 본다.**

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

설치 리스트의 생태계는 이 환경에 **이미 설치돼 있다.** 위험·전역·중복 명령(`npx tweakcc --apply`=Claude Code 패치, `curl|bash`, 전역 `npm -g`/`pip`, `~/.claude`로 clone)은 **자동 실행하지 않았다**(리스트 자체의 "전체설치 금지" 지침 + `safety.md` 준수). 필요한 것만 아래 상태로 확인.

| 리스트 항목 | 상태 | 근거 |
|-------------|:----:|------|
| A. mattpocock 스킬 세트 | ⛔ 제거됨 | 하네스 무관 개인 스킬로 판단, 2026-07-23 배포물에서 제외 (히스토리에서 복구 가능) |
| B. ECC 보안·평가 에이전트 | ✅ 설치됨 | 프로젝트 `.claude/agents/`: evaluator·security-reviewer (단일 관점 리뷰어 5종은 2026-07-28 제거 — /review가 다관점 커버) |
| C. GSD (SDD 킷) | ✅ 설치됨 | `~/.claude/agents/` gsd-* 33종 + `/gsd:*` 커맨드 동작 |
| D-4. caveman (출력 압축) | ⛔ 제거됨 | ponytail과 역할 중복 — 2026-07-23 ponytail로 일원화 (사용자 전역 플러그인은 별개) |
| 전제 도구 | ✅ jq·node·npm·pnpm·python3·pip·gradle | `command -v` 확인. jq·shellcheck는 시스템 PATH 전제 (`vendor/bin` 내장 바이너리는 v0.6.x에서 제거) |
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
├── GUIDE.md                  # (이 문서)
├── VERSION                   # 릴리스 버전 (update 비교 기준)
├── install.sh                # 설치기: curl 원격/오프라인 부트스트랩 + update/rollback/setup (멱등)
├── uninstall.sh              # 제거기: manifest 기반, 드라이런 기본
├── vendor/ponytail/          # ponytail 모드 벤더링
├── .githooks/pre-commit      # 에이전트 무관 커밋 게이트 (jq 불필요)
├── .gitignore                # logs/ · 루트 .env* · specs/HANDOFF.md · .claude/bin/
├── specs/                    # 상태: SDD 산출물 (HANDOFF/DECISIONS는 훅·스킬이 생성)
│   └── README.md
├── logs/                     # 관측: 날짜별 JSONL 이벤트 로그 (gitignore)
├── docs/md/                  # 오케스트레이션·fable 팀·verify-loop 가이드
├── docs/rules/
│   └── code-convention/      # 스택별 코딩 표준 상세본 8종 (자동 로드 아님 — 필요 시 참조)
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
    │   ├── eval-java.sh          # Java/Spring 결정적 출력검증 스코어러 (P±오차)
    │   ├── eval-state.sh         # 골든셋 상태 assert 채점기 (carve-eval 헬퍼)
    │   ├── eval-gate.sh          # 골든셋 회귀 게이트 (추이 비교, CI용 결정론)
    │   └── tests/*.test.sh       # 훅별 어서션 (20 스위트)
    ├── commands/             # /plan /verify /review /commit /harness-audit /eval /verify-loop /ponytail*
    ├── agents/               # evaluator·security-reviewer·pr-test-analyzer + fable 4종 (7)
    ├── skills/               # handoff · changelog · version-changelog · anti-ai-slop · carve* · checklist-loop · eval-goldenset · eval-init · theme-factory (10)
    └── rules/
        ├── common/           # security·testing·git-workflow (항상 적용)
        ├── java-spring/      # patterns (**/*.java) · gateway-testing (게이트웨이 파일)
        ├── react-next/       # patterns (**/*.ts,tsx)
        └── safety.md · database.md
```

---

## 4. 훅 레퍼런스 (현재 동작)

`settings.json` 등록 이벤트: **PreToolUse · PostToolUse · Stop · SessionStart · PreCompact · SessionEnd** (6종). 모든 훅 명령은 `${CLAUDE_PROJECT_DIR}` 기준(서브디렉토리 안전).

| 훅 | 이벤트 | 동작 | 종료코드 |
|----|--------|------|----------|
| `pretool-guard.sh` | PreToolUse (Write/Edit/MultiEdit/NotebookEdit/Bash) | ① jq 부재·JSON 파싱실패 → **차단**(fail-closed) ② 보호경로(`.env`·prod·시크릿·마이그레이션) 수정 차단 ③ Bash 쓰기명령이 보호경로 대상 시 차단 ④ **파일 내용 하드코딩 시크릿**(AKIA/sk-/ghp_/PEM/JWT) 차단 ⑤ **위험 명령**(force push·`reset --hard`·`--no-verify`·히스토리 재작성·`docker … down -v`·`curl\|sh`·DB 클라이언트의 DROP/TRUNCATE/WHERE 없는 DELETE) 차단 ⑥ **루프 브레이크**: 동일 툴+동일 인자 5회 연속 시 차단(다른 호출이 끼면 리셋, `logs/.recent-calls`) ⑦ **GUARD-07 자기보호**: 설치본(`harness-manifest.txt` 존재)에서 `.claude/hooks/`·`settings.json`·manifest 수정/삭제 차단 — 소스 레포는 예외 ⑧ **GUARD-08**: 보호경로 삭제(`rm`·`touch`·`shred`)와 루트/홈/프로젝트 재귀 삭제 차단, `env`/`sudo`/`VAR=` 접두 우회 커버 | 차단 **exit 2** / 허용 0 |
| `posttool-format.sh` | PostToolUse (Write/Edit) | 확장자 감지 포맷(spotless/prettier 등); 포맷터 미설치·오류를 **JSONL에 기록**(삼키지 않음) | 0 (비차단) |
| `stop-verify.sh` | Stop | 스택 감지 후 빌드/타입/린트/테스트 — Java(gradle)·Node/TS(tsc·lint·test)·Python(ruff·pytest, `pyproject.toml`/`requirements.txt`/`setup.py` 중 하나면 활성)·**Go**(build·vet·test)·**Rust**(cargo check·test)·bash(shellcheck·훅 자가테스트); 각 스택은 툴체인 있을 때만 실행; `stop_hook_active` **루프 차단**; jq 부재 시 best-effort 스킵; **변경 모듈만 증분**(git diff) | 실패 **exit 2** / 통과 0 |
| `checklist-gate.sh` | Stop (`stop-verify` 뒤) | `specs/checklist.json` 미달(<임계)·미채점 잔존 시 완료 차단. 루프 미개시면 무동작. **자가 우회 차단**: 채점 파일 삭제 시 tombstone(`specs/.checklist-active`)이 계속 차단, threshold는 하한 95로 클램프(`CARVE_CHECKLIST_FLOOR`로만 변경) | 미완 **exit 2** / 완료 0 |
| `session-handoff.sh` | SessionStart / PreCompact / SessionEnd | start=핸드오프 복원, save=**실제 수집**(STATE.md TODO·미완료 플랜·git 카운트·DECISIONS 최근5) → `specs/HANDOFF.md` | 0 |
| `log-event.sh` | (서브프로세스 헬퍼) | 6훅 진입점의 이벤트를 `logs/*.jsonl`에 1줄 append; 보호경로/PII는 `<masked>` | 항상 0 |
| `lib-protected.sh` | (데이터) | `PROTECTED_RE`(보호경로) + `SECRETS_RE`(시크릿) 단일 정의 — 재정의 금지. `protected-extra.regex`/`secrets-extra.regex` OR-병합(업데이트 보존) | — |
| `logs-report.sh` | (수동 CLI) | `logs/*.jsonl` 요약 리포트; `--rotate N` N일 이전 로그 삭제; `--tokens [N]` 세션별 토큰 사용량(트랜스크립트 usage 합산 — 비용 폭주 사후 인지 방지) | 0 |
| `harness-audit.sh` | (수동 CLI / `/harness-audit`) | 하네스 구성 47체크 PASS/FAIL (§7) | 실패 시 비영 |
| `eval-java.sh` | (수동 CLI) | Java/Spring 결정적 출력검증 — gradle grader(compile·pass^k·JaCoCo·정적분석·ArchUnit·N+1) 파싱 → 재현 가능한 `P±오차` JSON emit. LLM 없음, jq/gradle 부재 시 "unable"(fail-closed) | 0 (unable=1) |
| `eval-state.sh` | (carve-eval 헬퍼) | 골든셋 **상태 assert**(`file_exists`·`file_contains`·`cmd_exit0`·`git_diff_contains`)를 워크디렉토리 실상태로 결정적 채점 — 에이전트 자기 보고 불신(리워드 해킹 방지). 불능 입력 fail-closed | 0 (unusable=1) |
| `eval-gate.sh` | (수동 CLI / CI) | 골든셋 **회귀 판정** — `specs/eval-score.json` 추이만 읽어 직전 대비 하락폭을 본다. 채점은 carve-eval, 강제는 이 스크립트로 분리해 **CI가 모델 판단에 의존하지 않는다**. 추이 없음·손상·미채점은 `unable`(조용한 통과 금지) | report=항상 0 / block=회귀·unable 시 1 |

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
> 호출 방식: **커맨드** = 슬래시 `/이름` · **에이전트** = description 자동위임 또는 `"use the X agent"` · **스킬** = `/이름`(사용자 호출) 또는 description 자동발동.

### 5.1 커맨드 (`.claude/commands/`, 14종)

| 파일 | 호출 | 용도 · 사용법 · 예시 |
|------|------|----------------------|
| `plan.md` | `/plan` | 작업을 완료기준(SC) 단위로 분해 → `specs/`. 예: `/plan "OAuth 구글 로그인 추가"` |
| `verify.md` | `/verify` | 현재 변경을 SC·빌드·타입·테스트로 검증. 예: `/verify` |
| `review.md` | `/review` | 변경분을 타입·보안·예외·상태관리 관점 검토. 예: `/review` |
| `commit.md` | `/commit` | commitlint 준수 커밋 메시지 준비. **자동호출 비활성**(`disable-model-invocation`) — 사용자만. 예: `/commit` |
| `commit-branch.md` | `/commit-branch` | 현재 브랜치에 Conventional Commits로 커밋 + 푸시. `main` 직접·`--no-verify` 금지. 자동호출 비활성. 예: `/commit-branch` |
| `harness-audit.md` | `/harness-audit` | 하네스 구성 47체크 PASS/FAIL(§7). 예: `/harness-audit` |
| `eval.md` | `/eval` | carve-eval 워크플로 실행(골든셋 채점). 예: `/eval` |
| `verify-loop.md` | `/verify-loop` | carve-verify-loop 워크플로(수정→검증 반복). 예: `/verify-loop` |
| `ponytail*.md` (6) | `/ponytail…` | ponytail 모드 제어·audit·debt·gain·review·help |

### 5.2 에이전트 (`.claude/agents/`, 7종)

**하네스 검증 에이전트** (생성/검증 분리 — Evaluator 축):

| 파일 | 모델 | 설명 · 호출 |
|------|------|-------------|
| `evaluator.md` | sonnet | 생성물을 완료기준(SC)·타입 안전성으로 독립 검증. `"use the evaluator agent"` |
| `security-reviewer.md` | sonnet | 시크릿 노출·인증/인가 누락·인젝션 + **게이트웨이 인증/인가/레이트리미트 우회**. `"use the security-reviewer agent"` |
| `pr-test-analyzer.md` | sonnet | 변경분(PR/diff)의 테스트 충분성 평가(커버리지·SC매핑·스텁괴리). `"use the pr-test-analyzer agent"` |

> 단일 관점 리뷰어 5종(code-reviewer·silent-failure-hunter·state-reviewer·tdd-guide·e2e-runner)은
> 2026-07-28 제거 — `/review` 한 번이 다관점을 커버(강한 모델 기준, git 히스토리에서 복구 가능).

**fable 오케스트레이터 팀** (Agent Teams·Workflow 슬롯 전용 — 호출법·모델 무관 SOP는 `docs/md/fable-team-guide.md`):

| 파일 | 모델 | 설명 · 호출 |
|------|------|-------------|
| `fable-builder.md` | sonnet | 배정 태스크를 격리 worktree에서 코드+테스트로 구현. `"fable-builder로 구현"` |
| `fable-doc-writer.md` | sonnet | 빌드 결과 근거로 문서 작성/갱신(`docs/**` 소유). `"fable-doc-writer로 문서화"` |
| `fable-researcher.md` | sonnet | 구현 전 리서치 → 출처 포함 RESEARCH.md. `"fable-researcher로 조사"` |
| `fable-visualizer.md` | sonnet | 다이어그램·목업 전담(시각 게이트 준수). `"fable-visualizer로 다이어그램"` |

> 파이프라인 전체는 `.claude/workflows/fable-team-pipeline.js` — `"fable-team-pipeline 실행"`(옵트인)으로 Spec→Build+Verify→Document→Verify 4-Phase 자동 실행.
> (squad 파이프라인 에이전트 8종+커맨드 9종은 전문 리뷰어·fable 팀과 역할이 중복되어 제거됨 — v0.5.1 이후.)

### 5.3 스킬 (`.claude/skills/`, 10종)

**하네스 코어 스킬** (자동발동):

| 파일 | 호출 | 설명 |
|------|------|------|
| `handoff/` | 자동/`/handoff` | 세션 종료·압축 직전 진행 상황을 `specs/HANDOFF.md`로 인계 |
| `changelog/` | 자동/`/changelog` | 되돌릴 수 없는 결정·근거를 `specs/DECISIONS.md`에 시간순 기록(append-only) |
| `version-changelog/` | 자동/`/version-changelog` | 릴리스 시 VERSION·CHANGELOG·README 버전이력 동시 갱신. **VERSION만 바꾸면 pre-commit 차단** |
| `anti-ai-slop/` | 자동/`/anti-ai-slop` | 이미지·HTML·SVG 생성 전 발동 — 그라데이션·글로우·장식 모션 차단 게이트 |
| `carve-guide/` | `/carve-guide` | 하네스 HTML 산출물 작성(디자인 시스템·anti-slop 게이트·theme-factory/frontend-design 검토·1000px 임베드 안전). §릴리스 인벤토리 갱신 모드는 리포 전용. v0.0.13부터 배포 |
| `carve-harness-create/` | `/carve-harness-create` | 프로젝트 스택 분석 → 맞지 않는 규칙·에이전트·스킬을 KEEP/PRUNE 표로 제안, 1회 확인 후 `install.sh prune` 실행. 명시 호출 전용(`disable-model-invocation`). 의존성 간선(eval-java↔archunit·fable↔워크플로) 미분리 |
| `checklist-loop/` | 자동 | Stop 게이트(checklist-gate.sh)와 연동되는 체크리스트 작성·소진 루프 |
| `eval-goldenset/` | 자동/`/eval-goldenset` | 골든셋 형식·리워드 해킹 점검표·트레이스 마이닝 **절차 정본**(SOP). carve-eval의 채점 기준 |
| `eval-init/` | `/eval-init` | 그 SOP의 **실행기** — 프로젝트 분석 → 인터뷰 7문항으로 평가·품질 게이트 확정 → 골든셋 초안 → 궤적 검사 후 승인분만 편입 → CI 배선 → baseline 기록. 설치 후 1회성, 명시 호출 전용 |

**벤더 스킬 1종** (외부 출처 벤더링, SKILL.md만):

| 파일 | 호출 | 설명 |
|------|------|------|
| `theme-factory/` | 자동/`/theme-factory` | 산출물에 테마(색·폰트) 적용. 출처 `composiohq/awesome-claude-plugins` — anti-slop 게이트 여전히 적용 |

> 플러그인 `frontend-design`(디자인 방향)·`ponytail`(간결화)은 스킬이 아니라 `settings.json` 선언으로 배포된다(§5.1 참고).

### 5.4 룰 (`.claude/rules/` 8파일 자동적용 + `docs/rules/` 상세본 8파일 수동 참조)

| 경로 | glob | 내용 |
|------|------|------|
| `common/security.md` | 항상 | 시크릿·PII 취급, 입력 신뢰 금지 |
| `common/testing.md` | 항상 | red→green, 커버리지 80% |
| `common/git-workflow.md` | 항상 | Conventional Commits, force push 금지 |
| `safety.md` | 항상 | 위험동작(DB 파괴·git·프로덕션) 승인 게이트 |
| `database.md` | 항상 | id/타임스탬프·soft delete·N+1·마이그레이션 |
| `docs/rules/code-convention/dev-stack-*.md` (8) | 수동 참조 | java-spring·react·nextjs·typescript·javascript·python·fastapi·orm 스택 표준(상세본 — `.claude/rules/` 밖이라 자동 로드 안 됨, 필요 시 Read) |
| `java-spring/patterns.md` | `**/*.java` | 계층 분리·생성자 주입·LAZY·트랜잭션 |
| `java-spring/gateway-testing.md` | 게이트웨이 파일 | 5기능 검증 SC·테스트 피라미드·도구 스택 (GATE-04가 강제) |
| `react-next/patterns.md` | `**/*.ts,tsx` | Hooks·key·서버상태 분리 |

> 룰 상세본: `docs/rules/code-convention/dev-stack-*.md`. 파일 판별·게이트 매핑은 `harness-audit`(AUDIT-03/07)이 점검.

---

## 6. 사용 워크플로

**드롭인 설치** (다른 프로젝트로 이식) — `install.sh`가 체크섬 검증→jq/shellcheck 배치→권한→pre-commit 게이트→audit까지 자동 (상세: README):
```bash
cd /path/to/your-project
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash
# 오프라인: HARNESS_SRC_DIR=/path/to/harness-copy bash /path/to/harness-copy/install.sh
```

**프로젝트 맞춤 구축** (설치 후 스택에 맞게 절단):
```
설치 시작 → [1] 맞춤 구축(권장) 선택 → 전체 설치 + 안내
세션에서 → /carve-harness-create        → 스택 분석 → KEEP/PRUNE 표 → 1회 확인
                                        → install.sh prune → harness-audit 검증
되돌리기 → bash install.sh rollback      (제거분 백업에서 복원)
```
- 전체 설치 후 동작하므로 절단은 선택 — 상시 로드 규칙(rules/)이 세션 시작 토큰을 늘리는 걸 스택 맞춤으로 줄인다.
- 절단 단위·의존성 간선(eval-java↔archunit·squad 커맨드↔에이전트·fable 워크플로↔에이전트)·ALWAYS-KEEP 코어는 `.claude/skills/carve-harness-create/SKILL.md` 참조. 코어(훅·settings·크로스에이전트 진입·safety/common 규칙)는 `prune`이 제거 거부.

**GSD SDD 흐름** (설치돼 있음):
```
/gsd:new-project → /gsd:plan-phase N → /gsd:execute-phase N → /gsd:verify-work
```
(이 프로젝트 자체가 이 흐름의 산출물 — 페이즈 기록(구 `.planning/`)은 git 히스토리 보존.)

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

Claude Code 업그레이드마다 재실행해 게이트가 여전히 작동하는지 증명. 현재: **47 PASS, 0 FAIL**.

테스트 스위트도 함께:
```bash
npm test   # 20 스위트 전부 green (= bash .claude/hooks/tests/run-all.sh)
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

### 8.2 미지원 스택 게이트 추가 — Ruby 예시 (그대로 복붙 후 치환)

Java·Node/TS·Python·Go·Rust·bash는 내장이다. 그 외(Ruby·PHP·C#·Swift·Dart)는 3파일 수정이면 붙는다.

**① 규칙 파일** — `.claude/rules/ruby/conventions.md` 생성 (`paths` glob이 자동 로드 트리거):

```markdown
---
paths: ["**/*.rb"]
---
# Ruby 규칙 (자동 로드)
- rubocop 통과 필수. 예외를 삼키지 않는다(`rescue nil` 금지).
- 메서드는 한 가지 일만. 파일당 클래스 1개.
```

**② Stop 게이트** — `.claude/hooks/stop-verify.sh`의 변경 감지부와 게이트부에 각각 추가:

```bash
# 감지부 — 기존 java/node/py/go/rs/sh 라인 아래에:
rb_changed=1
[ -n "$CHANGED" ] && { printf '%s\n' "$CHANGED" | grep -Eq '\.rb$|Gemfile' && rb_changed=1 || rb_changed=0; }

# 게이트부 — 기존 스택 블록들 아래에 (도구 없으면 skip = 기존 관례):
if [ "$rb_changed" -eq 1 ] && [ -f Gemfile ]; then
  command -v rubocop >/dev/null 2>&1 && { rubocop 2>&1 | tail -20 || fail=1; }
  command -v rspec   >/dev/null 2>&1 && { rspec   2>&1 | tail -20 || fail=1; }
fi
```

**③ 검증** — 게이트가 진짜 무는지 확인하고 끝. 툴체인이 없는 머신에서도 증명하려면 스텁을 PATH에 얹는다(내장 스택 테스트가 쓰는 방식):

```bash
bash -n .claude/hooks/stop-verify.sh                       # 문법
S=$(mktemp -d); printf '#!/bin/sh\nexit 1\n' > "$S/rubocop"; chmod +x "$S/rubocop"
W=$(mktemp -d); (cd "$W" && git init -q && touch Gemfile app.rb && git add -A \
  && git -c user.email=t@t -c user.name=t commit -qm i && printf 'x\n' >> app.rb \
  && printf '{}' | PATH="$S:$PATH" bash "$OLDPWD/.claude/hooks/stop-verify.sh"; echo "exit=$?")  # 2면 성공
bash .claude/hooks/harness-audit.sh                        # 47 PASS 유지 확인
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

신규 입장 확인법: `bash .claude/hooks/harness-audit.sh` 가 47 PASS면 정상 세팅.

---

## 9. 사용자가 별도로 설치해야 하는 것

하네스는 도구를 번들하지 않는다. jq·shellcheck 포함 아래는 **사용자/프로젝트가 직접** 설치한다. 필수(하네스 게이트 동작 전제)와 선택(워크플로 강화)으로 나눈다.

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
| Java/Spring evaluator | JaCoCo·ArchUnit·PMD·Checkstyle·SpotBugs | `.claude/rules/java-spring/archunit/build-eval.gradle.kts` 배선 + `HarnessArchRulesTest.java` 복사 | `eval-java.sh`가 리포트 파싱 → 결정적 P±오차 (LLM 없음). ArchUnit이 patterns.md 규칙을 실행 검증화 |

> 스택 도구가 없으면 게이트는 **조용히 통과**(best-effort) — 하네스가 없는 도구를 강요하지 않는다. 있으면 자동으로 문다.

### 9.2 선택 — 워크플로 강화 (전역/네트워크 → 승인 후 수동)

| 도구 | 용도 | 설치 방법 | 사용 방법 |
|------|------|-----------|-----------|
| **GSD** (SDD 킷) | 스펙 주도 개발 오케스트레이션(`.planning/`) | `npx get-shit-done-cc --local` (`install.sh setup`이 제안) | `/gsd:new-project` → `/gsd:plan-phase N` → `/gsd:execute-phase N` → `/gsd:verify-work` |
| **gh CLI** | PR·이슈·원격 인증 | 배포판 패키지매니저(`brew/apt install gh`) | `gh auth login` → `gh pr create` (사설 레포 하네스 update 토큰도 `gh auth token`) |
| **codesight** | 세션 시작 구조맵으로 탐색 토큰 절감 | `npx codesight --init` | `.codesight/CODESIGHT.md` 자동 참조 |
| **superpowers** | 프로세스 스킬 프레임워크(brainstorming·systematic-debugging) | `/plugin install superpowers@superpowers-marketplace` | 스킬 자동 발동 |
| **ponytail** | 과잉설계 억제 | `/plugin install ponytail@ponytail` | `/ponytail lite\|full\|ultra` |
| **LSP** | 코드탐색 토큰 대폭 절감 | `npx tweakcc --apply` + `npm i -g @vtsls/language-server` | ⚠️ **Claude Code 바이너리 패치** — 위험 높음, 신중히 |
| **headroom** | API 페이로드 압축 | `pip install --user headroom` → `headroom wrap claude` | ⚠️ 전역 pip — 중간 위험 |

> **설치 원칙**: 전역 설치·네트워크 실행·바이너리 패치(`tweakcc`)는 프로젝트 밖(사용자 환경)을 바꾸므로 **명시 승인 후 수동**. `install.sh setup`은 git·PATH·LICENSE·GSD만 대화형으로 다루고, 나머지 선택 도구는 위 표대로 개별 설치한다.

---

## 10. 검증 / 한계

- 훅 14개 `bash -n` clean · 테스트 20 스위트(283건) 전부 통과(`npm test`) · `/harness-audit` 47 PASS. (2026-08-06 실검증)
- **한계(적대적 감사로 실측한 천장, 2026-08-03)**: ① Bash 쓰기 가드는 명령 표면만 — 변수 간접(`F=.env; … > $F`)·인터프리터 경유(`python3 -c`) 미탐 ② 시크릿 스캔은 리터럴 매칭 — base64·분할 조립 미탐 ③ 위험 명령은 셸 alias/함수로 감싸면 미탐, `curl -o f && bash f` 미탐 ④ Stop 게이트는 6스택(Java·Node·Python·Go·Rust·bash)만, 각 스택 툴체인 설치 시에만 작동 ⑤ checklist 게이트는 삭제·threshold 하향은 막지만 **거짓 채점 내용**은 못 막음 ⑥ 코드 `TODO/FIXME` 스캔 범위 밖 ⑦ `LICENSE` 미추가(보류). 재현: 우회 프로브 34종(`redteam-probe.sh`), 추적: `specs/HANDOFF.md`.
- 훅/스킬 규약은 Claude Code 버전에 따라 바뀔 수 있음 — 도입 전 `/hooks`·`/plugins`로 현행 확인, `code.claude.com/docs` 대조.

---

*근거: `.claude/` 실제 파일, `/harness-audit` 실행 결과. Phase 1–5 산출물(구 `.planning/`)·초기 매뉴얼·설치리스트는 git 히스토리에 보존.*
</content>
