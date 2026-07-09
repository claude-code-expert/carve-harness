# 하네스 사용 가이드 (GUIDE)

> Claude Code 드롭인 하네스 — 전체 사용 설명 + 설치 내역.
> 대상: 이 하네스를 쓰거나 다른 프로젝트에 이식하려는 사용자.
> 기준: 릴리스 **v0.0.8** (하드닝 v1 Phase 1–5 + 오프라인·크로스에이전트 + update/rollback/setup + 게이트웨이 검증 v2). `/harness-audit` = 40 PASS.
> 최종 갱신: 2026-07-08.

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
| `lib-protected.sh` | (데이터) | `PROTECTED_RE`(보호경로) + `SECRETS_RE`(시크릿) 단일 정의 — 재정의 금지 | — |

관측: 훅 발화 1건 = JSONL 1줄(`{ts,event,tool,decision,...}`). `jq . logs/$(date -u +%F).jsonl`로 확인.

---

## 5. 커맨드 · 에이전트 · 스킬 · 룰

**커맨드** (`.claude/commands/`, 슬래시 호출):

| 커맨드 | 용도 |
|--------|------|
| `/plan` | 작업을 완료기준(SC) 단위로 분해 → `specs/` |
| `/verify` | SC·빌드·타입·테스트 대조 검증 |
| `/review` | 타입·보안·예외·상태 관점 검토 |
| `/commit` | Conventional Commits 메시지 준비 (자동호출 비활성) |
| `/harness-audit` | 3기둥 구성 기계적 PASS/FAIL (§7) |
| `/squad <member>` | Squad 에이전트 디스패처 |
| `/squad-plan` `/squad-review` `/squad-qa` `/squad-refactor` `/squad-debug` `/squad-audit` `/squad-docs` `/squad-gitops` | 기획→리뷰→QA→리팩토링→디버그→보안감사→문서→Git 파이프라인 전담 8종 |

**에이전트** (`.claude/agents/`, description 자동위임 또는 "use the X agent"): evaluator(SC·타입/계약), code-reviewer(가독성·구조), security-reviewer(시크릿·인가·인젝션), silent-failure-hunter(삼켜진 예외), state-reviewer(상태·트랜잭션 경계) + squad 8종(plan·review·qa·refactor·debug·audit·docs·gitops). 생성(Generator)과 검증(Evaluator)은 분리 운용.

**스킬** (`.claude/skills/`, 23종): handoff(→`specs/HANDOFF.md`), changelog(→`specs/DECISIONS.md`, append-only), version-changelog(→`CHANGELOG.md`, 버전 변경 시 필수), anti-ai-slop(시각 산출물 slop 차단 게이트) + mattpocock 파생 19종(implement·qa·teach·domain-modeling·codebase-design·prototype·to-prd·to-issues 등 — 대부분 `disable-model-invocation`이라 `/이름` 사용자 호출 전용).

**룰** (`.claude/rules/`, glob 자동적용): `common/**`(항상), `code-convention/*`(스택 표준), `java-spring/`(`**/*.java`), `react-next/`(`**/*.ts,tsx`), `safety.md`(위험동작 승인 게이트).

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

## 9. 외부 도구 생태계 (선택, 미설치분)

`harness-install-list.md` 중 이 환경에 없는 토큰 절감 도구. **전역/네트워크 작업이므로 승인 후 수동 실행** 권장.
(gh CLI·codesight·superpowers는 설치 완료 — §2 표 참조.)

| 도구 | 용도 | 설치(수동) | 위험 |
|------|------|-----------|------|
| LSP | 코드탐색 토큰 절감 | `npx tweakcc --apply` + `npm i -g @vtsls/language-server` | **높음** — Claude Code 바이너리 패치 |
| headroom | API 페이로드 압축 | `pip install --user headroom` | 중간 (전역 pip) |

> 필요한 도구를 지정하면 개별 승인 후 설치한다. `tweakcc`는 실행 환경을 패치하므로 특히 신중히.

---

## 10. 검증 / 한계

- 훅 8개 `bash -n` clean · 테스트 11 스위트(125건) 전부 통과 · `/harness-audit` 40 PASS. (2026-07-09 실검증)
- **한계(문서화된 천장)**: Bash 파이프/heredoc 간접 쓰기의 시크릿 스캔은 best-effort; 코드 `TODO/FIXME` 스캔은 범위 밖; `LICENSE` 미추가(보류). 추적: `.planning/REQUIREMENTS.md`.
- 훅/스킬 규약은 Claude Code 버전에 따라 바뀔 수 있음 — 도입 전 `/hooks`·`/plugins`로 현행 확인, `code.claude.com/docs` 대조.

---

*근거: 이 리포의 `.planning/`(Phase 1–5 산출물), `.claude/` 실제 파일, `/harness-audit` 실행 결과. 초기 매뉴얼/설치리스트는 `docs/md/`에 보존.*
</content>
