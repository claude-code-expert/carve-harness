# 하네스 설치 매뉴얼 — 실측 인벤토리

> **이 문서는 "권장 목록"이 아니라 "현재 실제 설치본"이다.**
> `~/.claude`(전역)·`.claude`(이 레포)·claude.ai(원격 MCP)·호스트 툴을 전수 조사해 작성.
> 재조사: 2026-07-07 (실측) · 조사 방법: 파일시스템 + `~/.claude.json` + 툴 `--version`
> 이 저장소는 애플리케이션이 아니라 **Claude Code 하네스 템플릿**이다 (런타임·빌드파일 없음).

---

## 0. 설치 계층 한눈에

| 계층 | 위치 | 무엇이 있나 | 범위 |
|------|------|------------|------|
| 호스트 툴 | OS (`/usr/bin`, nvm) | node·pnpm·jq·git·python | 머신 전체 |
| 전역 자산 | `~/.claude/` | GSD·ECC선별·플러그인 | 모든 프로젝트 |
| 원격 MCP | claude.ai 계정 | Canva·Context7 | 계정 연동 |
| 레포 자산 | `<repo>/.claude/` | 훅·에이전트(+Squad)·커맨드·규칙 | 이 프로젝트만 |

명령 호출 규칙 (일관):
- **스킬** = `/이름` (플러그인은 `/plugin:이름`, GSD는 `/gsd:이름`)
- **에이전트** = 자동 위임 또는 "use the X agent" 명시
- **훅** = 자동 (이벤트 트리거, 수동 호출 없음)

---

## 1. 호스트 툴 (라이브러리·런타임)

실측 버전. 하네스 훅·전역 도구가 이들을 전제한다.

| 툴 | 버전 | 용도 | 상태 |
|----|------|------|:---:|
| node | v24.18.0 (nvm) | npx 기반 도구 실행 | ✅ |
| npm | 11.16.0 | 전역 패키지 | ✅ |
| pnpm | 11.10.0 | 프론트 포맷/타입체크 (`prettier`·`tsc`) | ✅ |
| jq | 1.8.1 | **모든 훅의 stdin JSON 파싱** (필수) | ✅ |
| git | 2.53.0 | 버전관리·워크플로 훅 | ✅ |
| python3 | 3.14.4 | 보조 스크립트 | ✅ |
| pip3 | 25.1.1 | python 패키지 | ✅ |
| bash | 5.3.9 | 훅 실행 셸 | ✅ |
| vtsls | 0.3.0 | TS/JS LSP 서버 (코드 탐색 토큰 절감) | ✅ 2026-07-07 설치 |
| tsc / tsserver | 6.0.3 | TypeScript 컴파일러·언어서버 | ✅ 2026-07-07 설치 |

**전역 npm 패키지:** `@alibaba-group/open-code-review@1.7.0` · `corepack@0.35.0` · `typescript@6.0.3` · `@vtsls/language-server@0.3.0`

**미설치 (사유 명시):**
- `gh`(GitHub CLI) — apt 설치가 sudo 필요, 비번없는 sudo 없음 → 니 터미널에서 설치
- `headroom`(pip) — PEP 668(externally-managed) 차단. `--break-system-packages`는 시스템 python 3.14 손상 위험이라 강행 안 함 → 원하면 `pipx install headroom`
- `codesight` — 미설치(선택)

---

## 2. 전역 플러그인 (`~/.claude/plugins`)

세션 시작 시 자동 활성. marketplace 경유 설치.

### 2-1. caveman — 출력 압축
- **역할:** 응답을 telegraphic하게 압축, 토큰 ~75% 절감. 기술 정확도는 유지.
- **소스:** marketplace `caveman` (installer 0.1.0)
- **명령:**

| 명령 | 용도 |
|------|------|
| `/caveman lite\|full\|ultra` | 압축 레벨 설정 (기본 full) |
| `/caveman-commit` | 압축 커밋 메시지 생성 |
| `/caveman-review` | 압축 코드리뷰 코멘트 |
| `/caveman-compress <file>` | 메모리 파일 압축 |
| `/caveman-stats` | 세션 토큰 절감 통계 |
| `/caveman-help` | 명령 카드 |
- 해제: "normal mode" 또는 "stop caveman"
- 서브에이전트: `cavecrew-investigator`(코드 위치) · `cavecrew-builder`(1~2파일 편집) · `cavecrew-reviewer`(diff 리뷰)

### 2-2. ponytail — 게으른 시니어 모드 (v4.8.4)
- **역할:** YAGNI·stdlib 우선·최소 코드 강제. 불필요한 추상화·의존성 차단.
- **소스:** marketplace `ponytail`
- **명령:**

| 명령 | 용도 |
|------|------|
| `/ponytail lite\|full\|ultra` | 강도 설정 (기본 full) |
| `/ponytail-review` | 오버엔지니어링 전용 리뷰 (diff) |
| `/ponytail-audit` | 레포 전체 오버엔지니어링 감사 |
| `/ponytail-debt` | 코드의 `ponytail:` 주석을 부채 대장으로 수집 |
| `/ponytail-gain` | 절감 스코어보드 |
| `/ponytail-help` | 명령 카드 |
- 해제: "normal mode" 또는 "stop ponytail"

### 2-3. claude-hud — 상태줄 HUD (v0.3.0)
- **역할:** 실시간 상태줄 — 컨텍스트 잔량·툴 활동·에이전트·todo 진행.
- **소스:** marketplace `claude-hud`
- **명령:** `/claude-hud:setup` (상태줄 구성) · `/claude-hud:configure` (레이아웃·언어·표시 요소)

**설치된 marketplace:** `caveman` · `ponytail` · `claude-hud` · `claude-plugins-official`
(참고: `superpowers`는 official marketplace에 있으나 **미설치**.)

---

## 3. GSD — SDD 킷 (전역, v1.42.3)

명세 주도 개발 프레임워크. 스펙→로드맵→플랜→구현→검증 전 과정을 스킬·에이전트로 자동화.

- **위치:** `~/.claude/get-shit-done/` + `~/.claude/skills/gsd-*`(67종) + `~/.claude/agents/gsd-*`(33종)
- **호출:** `/gsd:이름` (전체 목록 `/gsd:help`)

**핵심 라이프사이클 (순서대로):**

| 단계 | 명령 | 역할 |
|------|------|------|
| 1. 시작 | `/gsd:new-project` | PROJECT.md·컨텍스트 초기화 |
| 2. 로드맵 | `/gsd:new-milestone` → roadmap | 마일스톤·페이즈 분해 |
| 3. 명세 | `/gsd:spec-phase` | 페이즈가 뭘 만드는지 확정 |
| 4. 논의 | `/gsd:discuss-phase` | 계획 전 컨텍스트 수집 |
| 5. 계획 | `/gsd:plan-phase` | PLAN.md 작성 + 검증 루프 |
| 6. 실행 | `/gsd:execute-phase` | 원자 커밋 기반 구현 |
| 7. 검증 | `/gsd:verify-work` | UAT·완료기준 대비 검증 |
| 8. 배포 | `/gsd:ship` | PR 생성·리뷰·머지 준비 |

**보조 명령 (자주 씀):** `/gsd:progress`(상황·다음 액션) · `/gsd:code-review` · `/gsd:debug` · `/gsd:secure-phase` · `/gsd:map-codebase` · `/gsd:resume-work` · `/gsd:pause-work` · `/gsd:health` · `/gsd:config`

**네임스페이스 묶음:** `/gsd:ns-workflow` · `ns-context` · `ns-review` · `ns-project` · `ns-ideate` · `ns-manage` (관련 명령 그룹 진입점)

**에이전트 33종** (자동 위임): planner·executor·verifier·code-reviewer·security-auditor·debugger·roadmapper·doc-writer 등. 직접 부르지 않고 위 명령이 내부에서 스폰.

⚠️ ponytail/caveman과 통제권 철학이 다름. 프로세스 자동화가 필요한 중대형 작업에 쓰고, 소작업엔 `/gsd:fast`·`/gsd:quick`.

---

## 4. Squad — 에이전트 팀 (로컬 · 이 레포 `.claude/`)

역할별 전문 에이전트 8종 + 파이프라인. `/squad-*` 명시 호출.

- **위치:** `.claude/agents/squad-*.md`(8) + `.claude/commands/squad-*.md`(9) — **2026-07-08 전역 → 로컬 이전**(git 추적). 소스 github.com/claude-code-expert/subagents v1.3.2
- **훅:** 미설치 — 강제 라우터(`UserPromptSubmit → squad-router.sh`)·체이닝(`SubagentStart/Stop`) 안 깔음. 자동 위임 강제 없이 `/squad-*`로 직접 호출.

| 멤버 | 명령 | 역할 | 파이프라인 위치 |
|------|------|------|----------------|
| plan | `/squad-plan <기능>` | 유저스토리·와이어프레임·구현계획 | START |
| review | `/squad-review [범위]` | 보안·성능·유지보수 코드리뷰 | 구현 후 |
| refactor | `/squad-refactor [범위]` | 중복·긴함수·네이밍 정리 | review→REQUEST_CHANGES 시 |
| qa | `/squad-qa [범위]` | 테스트 실행·검증·리포트 | review→APPROVE 후 |
| debug | `/squad-debug <에러>` | 로그분석·재현·근본원인 | 버그 발생 시 |
| audit | `/squad-audit [범위]` | 보안 감사·OWASP·시크릿 | 배포 전 |
| docs | `/squad-docs [타입]` | README·API문서·주석 | 상시 |
| gitops | `/squad-gitops [타입]` | 커밋메시지·PR·체인지로그 | qa→PASS 후 |

- 통합 진입점: `/squad <멤버> [작업]`
- 표준 흐름: `plan → 구현 → review → (refactor) → qa → gitops`

---

## 4.5 ECC 서브에이전트·스킬 (선별 설치, 2026-07-07)

ECC(github.com/affaan-m/ECC)는 에이전트 67·스킬 **277**의 대형 생태계. 전체 설치는 매 세션 컨텍스트를 폭증시켜 **금지** — 검증된 보안·평가 셋만 전역(`~/.claude`)에 선별 설치.

- **소스:** `git clone --depth 1 https://github.com/affaan-m/ECC` → 선별 파일 `cp`
- **설치 위치:** `~/.claude/agents/` · `~/.claude/skills/`

| 에이전트 | 역할 | 호출 |
|----------|------|------|
| security-reviewer | 시크릿·인증/인가·인젝션 | "use security-reviewer" |
| agent-evaluator | SC·타입/계약 독립 검증 | "use agent-evaluator" |
| silent-failure-hunter | 삼켜진 예외·빈 catch 탐지 | "use silent-failure-hunter" |
| code-reviewer | 가독성·구조 리뷰 | "use code-reviewer" |
| react-reviewer | React 상태관리 검증 | "use react-reviewer" |

| 스킬 | 역할 | 호출 |
|------|------|------|
| hookify-rules | hookify 훅 규칙 작성 가이드 | `/hookify-rules` |
| strategic-compact | 논리적 구간마다 수동 컨텍스트 압축 제안 | `/strategic-compact` |

> ⚠️ 전체(277 스킬·67 에이전트) 설치가 필요하면 명시 요청 — 세션 부하 감수 확인 후 진행.

---

## 5. MCP 서버 (원격, claude.ai 연동)

로컬 설정 아님 — claude.ai 계정에 연동된 원격 MCP. 도구는 필요 시 자동 로드.

| 서버 | 역할 | 트리거 |
|------|------|--------|
| Context7 | 라이브러리·프레임워크 **최신 공식 문서** 조회 | 라이브러리/API 질문 시 (React·Next·Spring 등) — 기억 대신 이걸 우선 |
| Canva | 디자인 생성·편집·내보내기 | 디자인 작업 시 |

⚠️ 헤드리스/크론 실행에선 계정 인증 MCP가 없을 수 있음.

---

## 6. 이 레포 하네스 자산 (`<repo>/.claude`)

이 템플릿이 직접 담고 있는 실행 자산. git 추적됨(전역과 달리 프로젝트에 종속).

### 6-1. 훅 (자동, `settings.json`이 배선)

| 이벤트 | 훅 | 역할 |
|--------|-----|------|
| PreToolUse | `pretool-guard.sh` | 위험 작업 차단 (시크릿·force push·rm -rf 등) |
| PostToolUse | `posttool-format.sh` | 저장 후 포맷 (spotless/prettier 자동 분기) |
| Stop | `stop-verify.sh` | 종료 시 빌드·타입·테스트 검증 (timeout 900s) |
| SessionStart | `session-handoff.sh start` | 세션 시작 핸드오프 로드 |
| PreCompact/SessionEnd | `session-handoff.sh save` | 컨텍스트 압축·종료 전 상태 저장 |
| (보조) | `lib-protected.sh`·`log-event.sh`·`harness-audit.sh` | 보호경로·이벤트로그·자가감사 |

### 6-2. 서브에이전트 5 (`.claude/agents`, ECC 파생 선별)

| 에이전트 | 역할 |
|----------|------|
| security-reviewer | 시크릿·인증/인가·인젝션 |
| evaluator | 완료기준(SC)·타입 안전성 독립 검증 |
| silent-failure-hunter | 삼켜진 예외·빈 catch·무시된 에러 |
| code-reviewer | 가독성·구조·중복·에러처리 |
| state-reviewer | 프론트 상태관리·트랜잭션 경계 |

### 6-3. 커맨드 5 (`.claude/commands`)

| 명령 | 역할 |
|------|------|
| `/plan` | 작업을 SC 있는 단위로 분해, `specs/`에 계획 |
| `/review` | 타입·보안·예외·상태 관점 변경분 검토 |
| `/verify` | SC·빌드·타입·테스트로 현재 변경 검증 |
| `/commit` | 커밋 (가드 적용) |
| `/harness-audit` | 하네스 구성 PASS/FAIL 기계 검증 |

### 6-4. 스킬 2 (`.claude/skills`, mattpocock 파생)
- `/changelog` — 비가역 결정·근거를 `specs/DECISIONS.md`에 시간순 기록
- `/handoff` — 세션 종료·압축 직전 `specs/HANDOFF.md`로 인계

### 6-5. 규칙 (`.claude/rules`, glob 자동 로드)
- `common/` (git-workflow·security·testing) — 항상 적용
- `code-convention/` (java-spring·python·typescript·react·nextjs·fastapi·orm·javascript)
- `java-spring/`·`react-next/` — 확장자 감지 시 로드
- `api-routes`·`database`·`frontend`·`safety`·`testing`

---

## 7. 빠른 참조 (치트시트)

```
# 모드 제어
/caveman full        출력 압축 on      /ponytail full     게으른 모드 on
normal mode          둘 다 해제

# 하네스 (이 레포)
/plan  /review  /verify  /commit  /harness-audit

# GSD 라이프사이클
/gsd:progress                     지금 상황·다음 액션
/gsd:plan-phase → execute-phase → verify-work → ship
/gsd:help                         전체 명령

# Squad 파이프라인
/squad-plan → /squad-review → /squad-qa → /squad-gitops

# 문서·리뷰 (내장/플러그인)
/code-review   /ponytail-review   /squad-review
```

---

## 8. 실측 vs 기존 문서 갭

이전 판(권장 목록)과 현재 실측의 차이:

| 기존 문서 항목 | 실측 상태 |
|----------------|-----------|
| mattpocock/skills 37종 | ⏳ **설치 권장** — `npx skills add`가 대화형이라 자동 불가 → 니 터미널 (아래 §9) |
| ECC 에이전트 (github) | ✅ **선별 설치** (전역 에이전트 5·스킬 2, 2026-07-07). 전체 277은 세션 부하로 제외 |
| GSD | ✅ 설치됨 (v1.42.3) — 기존 문서엔 "선택"이었으나 실제 주력 |
| superpowers | ⏳ **설치 권장** — `/plugin install`이 CC 커맨드라 셸 불가 → 니 터미널 (아래 §9) |
| LSP (vtsls+tsc) | ✅ **2026-07-07 설치** |
| codesight / headroom | ❌ 미설치 (headroom = PEP668 차단, codesight = 선택) |
| SuperClaude | ❌ 미설치 — 큐레이션 결정으로 **의도적 제외** (GSD와 `/sc:workflow` 목적 중복·충돌, `superclaude-framework-guide.md §5` 경고). 도입 시 GSD와 택일 |
| caveman | ✅ 설치됨 |
| **ponytail·claude-hud·Squad** | ✅ 설치됐으나 **기존 문서에 없음** (신규 반영) |

**결론:** 실제 스택 = GSD(주력) + Squad + caveman/ponytail/claude-hud 플러그인 + 이 레포 하네스 자산. 기존 문서의 mattpocock·ECC·토큰플러그인 계열은 대부분 미설치 상태다.

---

## 9. 니 터미널 설치 (대화형·자동 불가 항목)

아래는 설치 **권장**이나 셸 비대화형/sudo/CC커맨드라 자동화 불가 → 니 실제 터미널에서 실행.

```bash
# mattpocock/skills 37종 (대화형 선택 — /setup-matt-pocock-skills 포함해 설치)
npx skills@latest add mattpocock/skills

# superpowers (Claude Code 안에서 실행 — 셸 아님)
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace

# headroom (PEP668 차단 → pipx 경로)
sudo apt-get install -y pipx && pipx install headroom
headroom wrap claude        # claude 실행을 감쌀 때만 효과 (선택)

# gh (sudo 필요)
sudo apt-get install -y gh

# codesight (프로젝트별, 선택)
npx codesight --init
```

> 설치 후 `install-list.md`의 §1·§8 상태표를 실측 재갱신할 것.

---

## 부록 A. 전체 자산 인벤토리 (큐레이션 후, 용도·호출)

> 큐레이션(2026-07-07) 반영 최종 상태. §2~6이 요약이면 여기는 **전수 열거**.
> 호출 규칙: **스킬** = `/gsd:이름` · **에이전트** = 명령이 내부 스폰(직접 호출 아님).

### A-0. 자산 카운트 요약

| 유형 | 레포 `.claude` | 전역 GSD | Squad(로컬) | 플러그인 | 합계 |
|------|:---:|:---:|:---:|:---:|:---:|
| 스킬 | 2 | 67 | — | caveman 6·ponytail 6·claude-hud 2 | 83 |
| 에이전트 | 5 | 33 | 8 | cavecrew 3 | 49 |
| 커맨드 | 5 | (스킬로) | 9 | — | 14 |
| 훅 | 7 | — | — | — | 7 |

> Squad(에이전트 8·커맨드 9)는 **2026-07-08 전역 → 레포 `.claude/` 로컬 이전** (§4). 훅 미설치.
> + **전역 ECC 선별(2026-07-07):** 에이전트 5·스킬 2 (§4.5) → 스킬 합 85·에이전트 합 54.

### A-1. GSD 스킬 67종 (`/gsd:*`)

**라이프사이클 (12)**

| 스킬 | 용도 |
|------|------|
| new-project | 새 프로젝트 초기화·PROJECT.md |
| new-milestone | 새 마일스톤 사이클 시작 |
| spec-phase | 페이즈가 뭘 delivering하는지 SPEC.md |
| discuss-phase | 계획 전 적응형 질문으로 컨텍스트 수집 |
| plan-phase | 상세 PLAN.md + 검증 루프 |
| mvp-phase | 수직 MVP 슬라이스로 페이즈 계획 |
| execute-phase | 웨이브 병렬로 페이즈 실행 |
| verify-work | 대화형 UAT로 기능 검증 |
| ship | PR 생성·리뷰·머지 준비 |
| progress | 진행 확인·워크플로 전진 (통합 상황 명령) |
| phase | ROADMAP.md 페이즈 CRUD |
| autonomous | 남은 페이즈 전부 자율 실행 |

**리뷰·품질·보안 (11)**

| 스킬 | 용도 |
|------|------|
| code-review | 페이즈 변경 소스 버그·보안·품질 리뷰 |
| secure-phase | 완료 페이즈 위협 완화 검증 |
| ui-phase | 프론트 UI-SPEC 설계 계약 |
| ui-review | 구현 프론트 6기둥 시각 감사 |
| eval-review | AI 페이즈 평가 커버리지 감사 |
| ai-integration-phase | AI 시스템 AI-SPEC.md 설계 |
| validate-phase | Nyquist 검증 갭 채움 |
| add-tests | UAT 기준 기반 테스트 생성 |
| review | 외부 AI CLI 교차 피어리뷰 |
| plan-review-convergence | 교차 AI 플랜 수렴 루프 |
| review-backlog | 백로그 항목 마일스톤 승격 |

**디버그·감사 (5)**

| 스킬 | 용도 |
|------|------|
| debug | 컨텍스트 리셋 넘어 상태 유지 체계적 디버깅 |
| forensics | 실패한 GSD 워크플로 포스트모템 |
| audit-fix | 발견→분류→수정→테스트→커밋 자율 파이프라인 |
| audit-milestone | 마일스톤 완료 원의도 대비 감사 |
| audit-uat | 전 페이즈 미해결 UAT·검증 교차 감사 |

**컨텍스트·상태·문서 (11)**

| 스킬 | 용도 |
|------|------|
| map-codebase | 병렬 매퍼로 `.planning/codebase/` 생성 |
| graphify | 프로젝트 지식 그래프 구축·질의 |
| docs-update | 코드베이스 검증 기반 문서 생성/갱신 |
| extract-learnings | 완료 페이즈서 결정·교훈·패턴 추출 |
| thread | 크로스세션 컨텍스트 스레드 관리 |
| pause-work | 중단 시 컨텍스트 핸드오프 생성 |
| resume-work | 이전 세션서 컨텍스트 복원 |
| capture | 아이디어·태스크·노트 목적지로 캡처 |
| import | 외부 플랜 충돌 감지 후 수용 |
| ingest-docs | 기존 ADR/PRD/SPEC서 `.planning` 부트스트랩 |
| milestone-summary | 마일스톤 산출물서 프로젝트 요약 |

**아이디에이션 (3)**

| 스킬 | 용도 |
|------|------|
| explore | 소크라테스식 아이디어 발상·라우팅 |
| sketch | throwaway HTML 목업 UI 스케치 |
| spike | 체험적 탐색 스파이크 |

**관리·설정·유틸 (19)**

| 스킬 | 용도 |
|------|------|
| manager | 다중 페이즈 관리 커맨드센터 |
| config / settings | 워크플로 토글·모델 프로필 |
| surface | 노출 스킬 토글 |
| workspace | 격리 워크스페이스 관리 |
| workstreams | 병렬 워크스트림 관리 |
| health | 플래닝 디렉토리 건강 진단·복구 |
| stats | 프로젝트 통계 |
| update | GSD 최신 업데이트 |
| help | 명령 가이드 |
| profile-user | 개발자 행동 프로필 생성 |
| complete-milestone | 완료 마일스톤 아카이브 |
| cleanup | 완료 마일스톤 페이즈 디렉토리 아카이브 |
| undo | git revert 안전 롤백 |
| pr-branch | `.planning` 커밋 걸러낸 PR 브랜치 |
| inbox | GitHub 이슈·PR 트리아지 |
| fast | 트리비얼 작업 인라인 실행 |
| quick | GSD 보증 유지한 빠른 작업 |
| ultraplan-phase | [BETA] 클라우드 ultraplan 오프로드 |

**네임스페이스 묶음 6 (진입점):** `ns-context`(맵/그래프/문서/학습) · `ns-ideate`(explore/sketch/spike/spec/capture) · `ns-manage`(config/workspace/thread/ship/inbox) · `ns-project`(마일스톤/감사/요약) · `ns-review`(리뷰/디버그/감사/보안/eval/ui) · `ns-workflow`(discuss/plan/execute/verify/phase/progress)

### A-2. GSD 에이전트 33종 (자동 스폰)

| 그룹 | 에이전트 | 용도 |
|------|----------|------|
| 리서치 (6) | advisor·ai·domain·phase·project-researcher, research-synthesizer | 결정·프레임워크·도메인·페이즈 리서치 + 종합 |
| 계획 (7) | planner, plan-checker, pattern-mapper, roadmapper, assumptions-analyzer, framework-selector, eval-planner | 플랜 작성·검증·패턴매핑·로드맵·가정분석 |
| 실행 (3) | executor, code-fixer, nyquist-auditor | 플랜 실행·리뷰수정·검증갭 |
| 검증·리뷰 (8) | verifier, code-reviewer, security-auditor, integration-checker, doc-verifier, eval-auditor, ui-checker, ui-auditor | 목표달성·보안·통합·문서·UI 검증 |
| 디버그 (2) | debugger, debug-session-manager | 버그 조사·세션 관리 |
| 문서·분석 (6) | doc-classifier, doc-synthesizer, doc-writer, codebase-mapper, intel-updater, user-profiler | 문서 분류·합성·작성, 코드맵, 프로필 |
| UI (1) | ui-researcher | UI-SPEC 설계 |

### A-3. 플러그인 서브에이전트 — cavecrew 3종 (caveman)

| 에이전트 | 용도 | 호출 |
|----------|------|------|
| cavecrew-investigator | 읽기전용 코드 위치 탐색 (file:line 표) | "use cavecrew-investigator" |
| cavecrew-builder | 1~2파일 외과 편집 | "use cavecrew-builder" |
| cavecrew-reviewer | diff/브랜치 리뷰 (한줄/심각도) | "use cavecrew-reviewer" |

> Squad 에이전트 8·레포 에이전트 5·플러그인 스킬(caveman/ponytail/claude-hud)은 §2·§4·§6 참조 (중복 열거 생략).

---

*출처: `~/.claude/` 파일시스템 전수 · `~/.claude.json` · 플러그인 `plugin.json` · 툴 `--version` · 이 레포 `.claude/` · 세션 스킬/에이전트 권위 목록 (2026-07-07 실측).*
