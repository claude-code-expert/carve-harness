# Changelog

하네스 버전별 변경 기록. 형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 축약, 버전은 [SemVer](https://semver.org/lang/ko/).

> **규칙**: `VERSION` 파일이 바뀌는 커밋에는 반드시 해당 버전 항목(`[X.Y.Z]`)이 이 파일에 함께 스테이징되어야 한다 — `.githooks/pre-commit`이 기계적으로 차단, 작성은 `/version-changelog` 스킬. 배포 절차는 `RELEASE.md`.

## [0.10.1] - 2026-09-05

### Fixed
- fix(pages): add .nojekyll so hand-written HTML serves raw
- fix(docs): link published HTML pages, add .claude subdir READMEs

## [0.10.0] - 2026-09-05

### Added
- feat(eval): deterministic guardrail self-test redteam.sh (P3)
- feat(eval): domain_safety veto (GATE-C7) and SUCCESS-CRITERIA (P2)
- feat(eval): required tags, suspicious and stale gate verdicts (P1)
- feat(eval): eval-run.sh target adapter + log_contains (P1a)
- feat(eval): deterministic trend read/append via eval-trend.sh (P0)

## [0.9.0] - 2026-09-05

### Added
- feat(audit): pack integrity AUDIT-09, skill wiring, doc sync (LP5)
- feat(eval): language-agnostic scorecard eval-score.sh (LP4)
- feat(packs): golden-set starters, slim rules, judge examples (LP3)
- feat(install): language-pack selection, pack subcommand (LP2)
- feat(packs): add language-pack manifests and reader (LP0)
- feat(eval): add golden-set preflight validator

### Fixed
- fix(eval): restore lost run 1 in score trend
- fix(eval): make golden-set preflight machine-portable

### Changed
- refactor(hooks): move stack gates into .claude/stacks/*.sh (LP1)

## [0.8.0] - 2026-08-06

### Added
- feat(eval): interactive eval-init setup + deterministic regression gate

### Fixed
- fix(tests): isolate hook side effects from the repo's observability log

## [0.7.0] - 2026-08-03

### Added
- feat(hooks): harden gates after adversarial audit

## [0.6.0] - 2026-07-23

### Added
- feat: add per-session token usage report
- feat: add state-based eval asserts
- feat: add danger-command and loop guards

### Changed
- refactor: dedup agents, skills, modes and rules

## [0.5.1] - 2026-07-21

### Fixed
- fix: replace non-working npx command in banner with eval tagline

## [0.5.0] - 2026-07-21

### Added
- feat: carve-eval golden-set quantitative eval loop (Stage B)
- feat: 5-axis rubric scoring in verify loop (Stage A)

### Fixed
- fix: align custom harness banner box border

## [0.4.1] - 2026-07-17

### Fixed
- fix: mark caveman-activate.sh executable for AUDIT-01

### Changed
- refactor: dedupe Stop loop-guard into shared lib

## [0.4.0] - 2026-07-16

### Added
- feat: add spec-to-checklist verify loop with scored evaluator gate
- feat: expand carve-harness-create with config-doctor and reinforcements

### Fixed
- fix(install): ship verify-loop guide to new installs
- fix: co-locate interdependent files in one checklist item

## [0.3.0] - 2026-07-14

### Added
- feat: embed ponytail and caveman modes into harness

## [0.2.0] - 2026-07-12

### Added
- feat: 커밋 커맨드 수정
- feat: 커밋 슬래시 명령어 변경

## [0.1.1] - 2026-07-12

### Fixed
- fix(install): show create banner on non-interactive install

## [0.1.0] - 2026-07-12

### Added
- feat: auto-version release on merge to main

## [0.0.13] - 2026-07-12

### Added
- **`carve-guide` 범용 HTML 작성 스킬 + 배포 포함**: 단일 문서 갱신기에서 하네스의 모든 HTML 산출물(문서·랜딩·리포트·데모)을 만드는 범용 스킬로 확장. 디자인 도구 오케스트레이션(하드 게이트 `anti-ai-slop` > `theme-factory`(색·폰트)·`frontend-design`(레이아웃 방향)) + 1000px 반응형 + SPA 임베드 안전 + 실측 검증을 기본 탑재. `install.sh`의 `DEV_SKILLS`에서 빼 **v0.0.13부터 배포 포함**(§7 릴리스 인벤토리 갱신 모드만 이 리포 전용). `DEV_SKILLS` 메커니즘(build_items 숨김 + coarse strip)은 공백 목록으로 유지.

- **`/commit-branch` 커맨드**: 현재 브랜치에 Conventional Commits 규칙(commit-msg 게이트)으로 커밋하고 푸시한다. `main`/`master` 직접 푸시·`--no-verify` 우회 거부, 무관 파일·시크릿 스테이징 금지.

### Fixed
- **임베드 안정화(run-ai.kr)**: 호스트 iframe이 `.wrap{max-width:80%!important}`를 주입해 폭이 막히던 것을 파일 `.wrap`의 `!important`(소스 순서상 뒤라 승 — 실측 computed max-width=1000px)로 이겨 1000px 강제(print는 `none !important`). TOC·본문 내부 앵커가 URL 해시를 바꿔 호스트 SPA(React) 라우터를 크래시시키던 것을 `preventDefault`+`scrollIntoView`(해시 미변경)로 수정. 데모 링크는 GitHub Pages 절대 URL + `class="ext"`·`window.open`으로 새 탭 강제(마크다운 `target` sanitize·SPA 가로채기 우회).
- 가이드 인벤토리 stale 테스트 카운트(167→172) 수정.

### Changed
- 인벤토리: 슬래시 커맨드 14→**15종**(`/commit-branch`) · 스킬 25→**26종**(`carve-guide` 배포 포함).

## [0.0.12] - 2026-07-11

### Added
- **프로젝트 맞춤 구축**: 설치 시작 시 `[1] 프로젝트 분석 후 맞춤 하네스 구축 / [2] 수동 컴포넌트 선택` 질문(`choose_setup_mode`). `[1]`은 전체 설치 후 세션에서 `/carve-harness-create`를 실행하도록 안내 + `.claude/harness-create-pending` 마커를 남긴다. env·비대화형은 이 질문 없이 기존 동작(회귀 없음).
- **`carve-harness-create` 스킬**: 프로젝트 스택(Java/Spring·TS/React/Next·Python/FastAPI·ORM)·역할·규모를 분석해 맞지 않는 규칙·에이전트·스킬을 KEEP/PRUNE 표로 제안하고, 1회 확인 후 `install.sh prune`을 호출한다. `disable-model-invocation`(파괴 인접 → 명시 호출만). ALWAYS-KEEP 코어와 의존성 간선(eval-java↔archunit·squad 커맨드↔에이전트·fable 워크플로↔에이전트)을 절대 끊지 않는다. 모델 무관.
- **`install.sh prune` 모드**: `bash install.sh prune --keep-list <파일>`(또는 `--keep-file`·`--remove-file`·`--dry-run`) — manifest를 파일 단위로 확장 후 KEEP 밖 비보호 파일을 `logs/harness-backup/v<현재>/`에 백업하고 제거, manifest·harness-components 재계산. PROTECTED 코어(훅·settings·크로스에이전트 진입·vendor·스크립트·safety/common 규칙)는 제거 거부. 빈 keep-list는 전체 제거 방지 차단. `rollback`이 백업을 그대로 복원(신규 롤백 코드 0).

- **로컬 lint 게이트(shift-left)**: `stop-verify.sh`가 Node/TS의 `lint` 스크립트(package.json에 있을 때만)를 Stop에서 실행 — CI `npm run lint`를 로컬로 앞당겨 타입체크가 못 잡는 정적 규칙(`react-hooks`·`set-state-in-effect` 등)의 CI 유출을 차단, 실패 시 exit 2. `lint` 스크립트 없는 프로젝트는 무영향(false fail 방지).
- **`theme-factory` 스킬 벤더링 + `frontend-design` 플러그인 선언**: 시각 산출물용 `theme-factory`(SKILL.md, 출처 `composiohq/awesome-claude-plugins`)를 `.claude/skills/`에 벤더링 → 스킬 TUI가 자동 노출. `frontend-design`(디자인 방향) 플러그인을 `settings.json`에 선언(`claude-code-plugins` 마켓플레이스 = `anthropics/claude-code`, ponytail과 동일한 항상-선언 방식). `settings`·`remote-install` 테스트가 선언 존속을 가드.
- **전체 구성 표 + 데모**: README 한/영에 스킬 25·커맨드 14·훅 9 전체 표 추가. `docs/html/harness-demo/`(적용 전/후 화면 비교 `index` + `without/with-harness`) + `docs/html/carve-workflow-guide.html`(개요) 추가, README·`HARNESS_GUIDE.md`에 새 창 데모 링크.

- **유지보수 스킬 `carve-guide` + 배포 제외 메커니즘**: run-ai.kr 게시용 `docs/html/carve-workflow-guide.html`을 릴리스마다 실측(파일시스템·`npm test`)으로 갱신하는 스킬. `install.sh`의 `DEV_SKILLS`로 소비자 설치에서 제외 — TUI 목록에서 숨기고 coarse `cp -R` 후 strip. 배포 스킬 25종은 불변(이 스킬은 이 repo 전용).

### Fixed
- **부분 훅 디렉토리 자가복구(치명)**: 기존/외래 `.claude/hooks`가 남아 있으면 install이 coarse 경로를 통째 SKIP해 `lib-protected.sh`가 미복구 → `pre-commit`이 fail-closed로 **모든 커밋을 차단**하던 버그. 통째 SKIP 대신 누락된 자식 파일만 채우도록 수정(`.claude/hooks`·`.githooks` 스코프, self-heal). `install-components.test.sh` 회귀 케이스 추가.
- **`stop-verify.sh` tsc 이식성**: 타입체크가 `pnpm exec` 하드코딩이라 npm 전용 프로젝트에서 false fail → 단일 PM 감지(pnpm→npm 폴백)로 tsc·lint·test가 공유.
- **prune `--dry-run` 카운트**: dry 분기의 `continue`가 `removed++`를 건너뛰어 요약이 항상 "0 개 제거 예정"으로 오표시되던 버그 → 제거 예정 파일 수를 정확히 카운트. 회귀 테스트(출력 캡처 후 카운트 검증) 추가.
- **테스트 tty hang 방지**: `choose_setup_mode`가 인터랙티브 터미널에선 `/dev/tty` 입력을 대기 → 설치 fixture 테스트를 `HARNESS_COMPONENTS=all`/`HARNESS_SETUP_STDIN` 주입으로 비대화형 고정(개발자 터미널에서 테스트 hang 방지). 제품 동작 무변경.

### Changed
- 인벤토리: 스킬 23→**25**종(배포 기준 — 유지보수용 `carve-guide`는 제외), 테스트 13→14 스위트·152→**172**건(prune 15+dry-run 1 + hook self-heal 1 + lint 게이트 2 + dev-skill 제외 1 + frontend-design assertion 강화).
- `eval-java.sh`는 Java 전용 스코어러라 prune의 PROTECTED에서 carve-out(Java 미감지 시 archunit과 묶여 제거, AUDIT-08 green 유지). 나머지 8개 훅은 언어 무관 코어로 계속 보호.

## [0.0.11] - 2026-07-10

### Added
- **체크박스 TUI 구성 선택**: 설치 구성 선택을 5구성 번호 입력에서 **항목 단위 체크박스 TUI**로 교체 — 전 항목이 섹션별(필수 md·훅·스킬·커맨드·오케스트레이터)로 펼쳐지고 `↑↓`/`jk` 이동 · 스페이스 토글(섹션 행은 하위 일괄) · `1`-`5` 섹션 점프 · `a` 전체 토글 · 엔터 설치. 비대화형/`HARNESS_COMPONENTS` env는 기존 구성 단위 폴백 유지.
- **세션 배너 인벤토리 + 메시지 프리픽스 통일**: SessionStart 배너가 로드된 전 구성(훅·git훅·스킬·커맨드·에이전트·워크플로·문서·규칙)을 항목명까지 표시. 모든 훅 메시지를 `[carve-harness:<hook>]` 프리픽스로 통일 — 어느 게이트가 차단·경고했는지 즉시 식별.
- **LSP·ponytail 플러그인 선언 배포**: `.claude/settings.json`이 `claude-code-lsps` 마켓플레이스와 `vtsls`(TypeScript·React·JavaScript LSP)·`jdtls`(Java LSP)·`ponytail` 플러그인을 선언 — 세션 시작 시 신뢰 승인 후 자동 설치. 서버 바이너리는 별도: `install.sh setup`이 vtsls npm 전역 설치 제안, jdtls는 `brew install jdtls`, 미설치는 install 끝 NOTE로 안내.

### Fixed
- **공개 레포 전환**: `GITHUB_TOKEN` 요구 제거 — 기본 설치 소스를 공개 `claude-code-expert/carve-harness`로 변경, 사설 레포 토큰 안내 절 삭제(README·GUIDE·RELEASE).

### Changed
- 인벤토리: 테스트 13 스위트 147→152건(TUI 선택·settings LSP 선언·remote-install NOTE 케이스 추가).

## [0.0.10] - 2026-07-10

### Added
- **설치 구성 선택**: `install.sh`가 설치 전 5구성(필수 md·훅·스킬·커맨드·오케스트레이터) 선택 창을 표시 — 대화형 번호 선택 또는 `HARNESS_COMPONENTS=md,hooks,...` env(엔터=전체, core는 항상 설치). 선택은 `.claude/harness-components`에 기록되어 update의 신규 파일 필터로 작동, 재실행으로 구성 추가 가능(선택 합집합·manifest 보존). 훅 미선택 시 jq fail-closed 검사·최종 audit는 자동 생략.
- **fable 오케스트레이터 에이전트 팀**: 워커 4종(`fable-builder`·`fable-doc-writer`·`fable-researcher`·`fable-visualizer`) + `fable-team-pipeline` 워크플로(Spec→Build+Verify→Document→Verify, worktree 격리·evaluator 즉시 검증) + `docs/md/orchestration.md`·`fable-team-guide.md`(호출법·모델 무관 SOP). 설치 시 orchestrator 구성으로 선택.
- **npm 테스트 진입점**: 의존성 0 `package.json` — `npm test`(전 스위트, `tests/run-all.sh` 집계 러너)·`npm run test:install`·`test:guard`·`test:audit`.
- `tests/install-components.test.sh` — 구성 선택 13케이스(env/대화형/무효 입력 폴백/재실행 합집합/update 필터/부분 uninstall).

### Fixed
- **macOS(BSD) 이식성**: `uninstall.sh`의 `sed -i`(BSD는 suffix 필요 → `-i.hbak`)·logs-report 테스트의 `touch -d '30 days ago'`(GNU 전용 → `date -v`/`-d` 겸용) 수정. 훅·git훅·테스트 스크립트 실행 비트(+x)를 git에 커밋(AUDIT-01이 요구 — 미부트스트랩 클론에서 audit FAIL 방지).
- `stop-verify.sh` run_node: package.json 존재 ≠ TS 프로젝트 — `tsconfig.json` 있을 때만 tsc 실행, pnpm 부재 시 npm 폴백(셸 전용 리포 false fail 방지).

### Changed
- 인벤토리: 에이전트 16→20 · 테스트 12→13 스위트(134→147건) · 워크플로 디렉토리(`.claude/workflows/`) 신설 · 설치 대상에 orchestrator 구성(agents·workflows·오케스트레이션 가이드 2종) 추가.

## [0.0.9] - 2026-07-09

### Fixed (critical)
- **기존 `settings.json`이 있는 프로젝트에서 하네스가 통째로 무력화되던 근본 버그** — `install.sh`가 `.claude/settings.json`을 no-clobber로 SKIP해, 소비자 프로젝트에 이미 settings.json이 있으면(=실제 프로젝트의 표준) 훅 6이벤트(SessionStart 배너·PreToolUse 가드·Stop 검증·핸드오프)가 **등록되지 않아** 배너 미표시 + 전 게이트 조용히 무력화. 증상은 "배너 안 나옴", 실체는 하네스 전면 inert. 이제 SKIP 대신 **jq로 훅을 병합**(사용자 `permissions.allow`·`model`·자체 훅 보존, `$schema`·`deny` 합집합, 재실행 멱등). 회귀 테스트 2건 추가(기존 테스트가 빈 디렉토리에만 설치해 못 잡던 케이스).

### Added
- **Java/Spring 결정적 출력검증 evaluator** (milestone v3, `edd-complete-guide.html` LV2 기반): 같은 입력이면 같은 확률 `P ∈ [0,1] ± 오차`를 LLM judge 없이 산출.
  - `.claude/hooks/eval-java.sh` — gradle grader 실행 → XML 리포트 파싱 → 6 metric(compile·pass^k·coverage·violation density·archrules·nplus1) 합성 P, jq -cn JSON emit. jq/gradle 부재 시 "unable"(fail-closed), 도구 미배선 metric은 skip+명시(은폐 없음).
  - `.claude/rules/java-spring/archunit/HarnessArchRulesTest.java` — patterns.md `[MUST]` 규칙(계층·필드주입·LAZY·트랜잭션·SQL·Entity반환)을 ArchUnit 실행 테스트로 승격("설득"→결정적 검증).
  - `.claude/rules/java-spring/archunit/build-eval.gradle.kts` — JaCoCo(XML)·ArchUnit·PMD·Checkstyle·SpotBugs 리포트 배선 스니펫.
  - `harness-audit.sh` AUDIT-08 — 스코어러↔ArchUnit 템플릿/build 스니펫 매핑 점검(orphan tool 방지).
  - `tests/eval-java.test.sh` 7케이스 — 결정성(2회 동일 P)·XML 파싱·no-gradle unable·compile-fail P=0·도구부재 skip.

### Changed
- 인벤토리: 훅 8→9 · 테스트 11→12 스위트(125→134건) · audit 40→42. 규칙 .md는 18 유지(archunit 템플릿·스니펫은 glob 룰이 아니라 eval 자산).

## [0.0.8] - 2026-07-09

### Added
- **게이트웨이 검증 계층** (milestone v2, `harness-research.html` 갭 분석 ⑧):
  - `.claude/rules/java-spring/gateway-testing.md` — 5기능(라우팅·인증·인가·API키·레이트리미트) 합격기준(SC) · 테스트 피라미드(통합 최두껍) · 도구 스택(WireMock·Testcontainers·WebTestClient·Spring Cloud Contract). 게이트웨이 파일에만 로드되는 좁은 glob.
  - `stop-verify.sh` GATE-04/05 — 게이트웨이 파일만 변경 시 `*GatewayIntegration*` 타깃 증분 실행(전체 회피), 혼합 변경은 full, 실패 시 exit 2. `harness-audit.sh` AUDIT-07(룰↔게이트 매핑 점검).
- **커밋 규율** (③): `.githooks/commit-msg` — Conventional Commits 형식 게이트(bash+git, ≤72자, merge/revert 면제). AUDIT-04 확장, install.sh가 `.githooks/*` 전부 +x.
- **테스트 서브에이전트** (④): `tdd-guide`(red→green) · `e2e-runner`(walking skeleton) · `pr-test-analyzer`(테스트 충분성) 신설, `security-reviewer`에 게이트웨이 인증/인가/레이트리미트 우회 점검 확장.
- `anti-ai-slop` 스킬 — 시각 산출물(이미지·HTML·SVG) 생성 전 slop(그라데이션·글로우·장식 모션) 차단 게이트.

### Changed
- 인벤토리: 에이전트 13→16 · 스킬 22→23 · 규칙 17→18 · 테스트 10→11 스위트(106→125건) · audit 38→40.

## [0.0.7] - 2026-07-09

### Reverted
- v0.0.6의 소스 레포 교체를 되돌림 — 소스는 **의도적으로 사설(`wevesolutions/harness`)**이 맞다. 404의 근본 원인은 레포 위치가 아니라 **인증 누락**: private 레포는 GitHub이 토큰 없는 raw/codeload 접근에 404를 반환한다. `install.sh` 기본 `HARNESS_REPO`와 예시 URL 4곳을 사설 레포로 원복.

### Fixed (docs)
- README(한/영)에 "사설 소스 레포 토큰" 절 추가 — 토큰 발급·사용 3방법(① `gh auth token` ② PAT classic/fine-grained ③ 오프라인 `HARNESS_SRC_DIR`) + SSO 인가·토큰 이중 전달·최소권한·노출금지 주의. install·online update 공통. (v0.0.2 concise 재작성 때 삭제됐던 안내를 되살려 확장.)

## [0.0.6] - 2026-07-09

### Fixed (reverted in 0.0.7 — 잘못된 수정)
- ~~`install.sh` 기본 소스 레포를 사설 `wevesolutions/harness`에서 다른 공개 레포로 교체.~~ 지시 없이 소스 레포를 바꾼 잘못된 수정. 사설 레포는 정상이고 토큰이 정답 — 0.0.7에서 원복.

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
