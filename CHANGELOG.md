# Changelog

이 프로젝트의 모든 주요 변경사항을 기록한다.
포맷은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/)를 따르며,
[유의적 버전(SemVer)](https://semver.org/lang/ko/)을 준수한다.

> 릴리스 태그: `v1.1.0`·`v1.1.1`(2026-06-02). `1.2.0`·`1.3.0`은 develop에서 준비 중(미태깅).

## [Unreleased]

### 잔여
- v2.0 로드맵 **M11(비교·증명 벤치)·M12(피드백 루프)** 예정 — `docs/milestones/MS7-v2-roadmap.md`.
- v1.0 토큰효율 **절약 수치 검증**: 대형 fixture·탐색 태스크로 벤치 재측정 필요(소형 단발은 MCP 고정비용으로 효과 작음).
- 벤치 cross-harness **축 3(트리거 정확도)·축 4(컨텍스트 점유율)** 라이브 미측정(추가 LLM 필요).

---

## [1.3.4] — 2026-06-11

설치된 훅이 실행되지 않던 치명 버그 수정 + 기존 설치 자동 교정.

### Fixed
- **생성 훅 명령을 `$CLAUDE_PROJECT_DIR` 절대경로로 등록(치명)**: `generator.ts`의 `hookRegsFor()`가 settings.json 훅 `command`를 상대경로(`bash .claude/hooks/carve-*.sh`)로 기록해, Claude Code가 프로젝트 루트가 아닌 cwd에서 훅을 실행하면 `No such file or directory`로 전부 실패하던 문제를 수정. 모든 훅(generic·anti-slop·codesight-refresh·squad-router·subagent-chain)을 `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/...`로 등록한다(리포 자신의 settings.json·설치 스크립트가 이미 쓰던 규약과 일치).

### Added
- **`carve update`에 훅 경로 1회 자동 교정(마이그레이션)**: 구버전으로 이미 설치한 프로젝트도 재설치 없이 `carve update`만으로 settings.json의 `_carve` 훅을 상대→절대경로로 제자리 교정한다(`installer.migrateHookPaths`). 멱등이며 사용자 훅은 건드리지 않고, manifest의 훅 기록도 함께 동기화한다.

### Notes
- 테스트 206개 통과(신규 회귀 가드 2개: 절대경로 등록·마이그레이션 왕복), 커버리지 약 95.8%. 런타임 의존성 불변(@clack 하나). 자산 `.sh` 내용은 변경 없음 — settings.json의 명령 등록만 수정.
- 기존 사용자 조치: ① **CLI 갱신** `npm i -g carve-harness@latest` → ② 프로젝트 루트에서 `carve update`(권장) 또는 `carve uninstall && carve install` 재설치.

---

## [1.3.3] — 2026-06-10

빠른 시작(설치)을 라이프사이클 4단계로 재구성.

### Changed
- **README 빠른 시작 4단계 재구성(한/영)**: 설치 흐름을 ①첫 설치 ②설치 후 옵션 ③업데이트 ④삭제 소제목으로 분리. `npm i -g carve-harness`(carve CLI 도구, 머신당 한 번)와 `carve install`(프로젝트 하네스, 프로젝트마다)을 구분하는 안내를 추가하고, 업데이트·삭제도 도구(`npm`)/하네스(`carve`) 두 레이어로 명령을 나눴다. "설치 레벨" 섹션의 중복 옵션 블록은 제거하고 새 "설치 후 옵션"으로 포인터 연결.

### Notes
- 문서 전용 — 코드·테스트 변경 없음(204 테스트 유지).

---

## [1.3.2] — 2026-06-08

설치 가이드를 글로벌 설치(`npm i -g`) 기준으로 정리.

### Changed
- **README·INSTALL(한/영) 글로벌 설치 우선**: 표준 설치를 `npm i -g carve-harness`로 안내(전체 기능·반복 CLI `update`/`diff`/`doctor` 사용 권장). npx는 "한 번만 써보기/CI" 대안으로 강등하고, 문서의 `carve <명령>` 예시가 글로벌 설치 기준임을 명시. npx 일회성 설치는 `carve`가 PATH에 안 남아 반복 명령이 막히던 혼란 해소.

### Notes
- 문서 전용 — 코드·테스트 변경 없음(204 테스트 유지).

---

## [1.3.1] — 2026-06-08

init-claude 공용 규칙 추가 + README 가이드 재편 + 내부 정리.

### Added
- **`init-claude` anti-ai-slop 공용 규칙**: `carve init-claude`가 스택 무관 `.claude/rules/anti-ai-slop.md`(시각·문서 산출물 슬롭 방지)를 함께 생성하고 루트 `CLAUDE.md` `@import`에 연결한다. 스택별 6규칙과 달리 **단일 소스**(`assets/claude-base/rules/anti-ai-slop.md`)에서 모든 언어 공통 설치(`SHARED_RULES`).
- **릴리스 스크립트 `scripts/release.sh`**: main에서 `package.json` 버전으로 `vX.Y.Z` 태그를 만들어 push(게시 트리거). 가드 — main 브랜치·클린 트리·원격 동기·태그/npm 중복·로컬 게이트(`check`+`test`), `--dry-run`·`--yes`.

### Changed
- **README 명령어 가이드 단계형 재편(한/영)**: 빠른 시작(설치 3줄) → 일상 워크플로우 → 시나리오별 고급 → 설치 레벨. 누락됐던 `iterate` 스킬 추가, Squad 호출법(`/squad <멤버>`·`/squad-<멤버>`, 에이전트명 `squad-<멤버>`) 명시.

### Internal
- `manifest.level`을 `string`→`HarnessLevel`로 끝까지 타입화하고 `normalizeManifest`에서 union 검증(불안전 `as HarnessLevel` 캐스트 2곳 제거). `generator`의 1회용 `has()` 클로저 인라인.

### Fixed
- **라이선스 정합**: `LICENSE` 파일이 Apache-2.0인데 `package.json`·README(한/영)는 MIT여서 GitHub가 Apache-2.0로 인식하던 불일치 → `LICENSE`를 MIT로 교체(의도=MIT 확정).
- **INSTALL 끊긴 링크**: 명령어 가이드 재편으로 사라진 README "구성요소 카탈로그" 앵커를 가리키던 `INSTALL.md` 링크를 현행 절("일상 워크플로우"·"더 깊게 — 시나리오별 명령")로 수정.
- **벤치 측정 버전 명시**: README(한/영) 정량 평가가 v1.1.0 측정값이며 이후 버전 미재측정임을 명시(측정 축은 아키텍처 수준이라 대체로 유효).
- **(중요) npx 환경 명령 안내 정합**: `update`/`doctor`/`diff`/`migrate`/`install` 안내가 글로벌 `carve`를 가정해, npx 사용자에겐 `carve migrate`가 "command not found"로 막히던 문제. 모든 안내를 `cmdHint`로 통일 — `npx carve-harness@latest <cmd>`(글로벌 설치 시 `carve <cmd>`). 특히 v1 매니페스트 `update` 차단 메시지가 캐시된 옛 버전(`migrate` 없음)이 아닌 `@latest`를 안내한다.
- **글로벌 설치 문서화**: README(한/영) 빠른 시작에 `npm i -g carve-harness`(영구 `carve` 명령) 옵션 + "npx는 일회성이라 PATH에 `carve`가 안 남는다"는 주의 추가(`bin.carve` 제공).

### Notes
- **204 테스트 / 커버리지 ~95.7%**. tsc strict clean, auditor·`bash -n`·shellcheck 통과, 런타임 의존성 불변(`@clack/prompts`).

---

## [1.3.0] — 2026-06-06

운용 3대 조건(샌드박스 피드백 루프·계획 분리/검증·컨텍스트 다이어트) 보강 + 전수 감사 기반 결함 패치.

### Added
- **자율 수렴 루프(iterate)**: `assets/skills/iterate/` + `carve-iterate` shim — green까지 실행→진단→수정→재실행, 최종 결과만 보고(최대 N회·무진전 시 중단). 카탈로그 등재. 루프 pass/fail는 기존 `{ts,hook,event}` 스키마로 텔레메트리.
- **계획 분리·검증**: `squad-plan`에 구현 전 승인 게이트 + Plan Quality Score(★ 루브릭), `sprint-contract.md`에 Plan Gate 섹션, `squad-evaluator`가 산출물뿐 아니라 계획도 채점. `CLAUDE.md`/`flight-rules.md`에 "계획 우선" 규칙.
- **컨텍스트 다이어트**: 생성 가이드에 40% 컨텍스트 예산 + "편집 중인 파일만 로드" 규칙(`TOKEN_EFFICIENCY` 단일 출처), `memory` 스킬에 컴포넌트별 세션 분리 트리거, `precompact-handoff`가 압축 빈도를 proxy로 계측.
- **`auto-commit` 훅 구현**: 카탈로그에만 있고 자산이 없어 선택해도 무동작이던 문제 해소 — 이중 옵트인(`CARVE_AUTO_COMMIT=on`) 게이트로 베이스라인 가드레일과 충돌 없이 동작.

### Fixed
- **(치명) `carve update`/`diff`/`doctor` 데드락**: 루트 `CLAUDE.md`의 append-merge 센티넬(`hash:''`)을 v1 미마이그레이션 신호와 혼동해, 문서화된 `install → init-claude` 흐름 후 `carve update`가 영구 차단되던 문제(`carve migrate`로도 복구 불가). 센티넬을 v1 판정에서 제외(`isUnmigrated`)하고 `classify`가 비소유 파일로 처리.
- **재설치 시 claude-base 고아화**: `install()`이 `manifest.files`를 union 보존하지 않아 `init-claude` 산출물이 매니페스트에서 누락→클린 제거 실패. `installClaudeBase`와 동일한 union 적용.
- **비Node 프로젝트 푸시 전면 차단**: `pre-push-test` 훅의 `npm test` 하드코딩 기본값 제거(미탐지 시 빈 값→스킵).
- **`--level` 무시/검증 우회**: TTY에서 `carve install --level <x>`가 대화형으로 빠지며 무시·검증 누락되던 문제 — `--level`을 대화형 추천에 반영하고 잘못된 값은 검증·거부. 설치 레벨을 `manifest.level`에 영속해 `update`/`diff`가 동일 레벨로 재현.
- **`squad-evaluator` 자동 파이프라인 누락**: 라우터 키워드(`평가`/`evaluate`/`완료 기준` 등)·체이닝(`squad-qa → squad-evaluator`) 연결, 파이프라인 문서 정합.
- **`carve report` 0-fire 오탐**: 비계측 훅(`slack-notify`·`codesight-refresh`)을 노이즈 후보로 잘못 보고하던 문제 — 계측 훅만 판정.
- **Python `commands.md` 무효 명령**: `pip run dev`/`pip run start`/`pip build` → 유효한 Python 명령으로 교체.
- 그 외: `_metrics.sh` 경로를 `$CLAUDE_PROJECT_DIR` 기준으로 통일, squad 훅의 존재하지 않는 `install.sh`/`SQUAD-ROUTER-KEYWORDS.md` 참조 제거, `flight-rules`의 잘못된 CLAUDE.md 참조 수정, `handoff` 설명에서 미존재 SessionStart 훅 표기 제거, 미설치 컴포넌트를 무조건 문서화하던 가이드 조건부화.

### Notes
- **204 테스트 / 커버리지 ~95.7%**(라인). tsc strict clean, auditor·`bash -n` 통과, 런타임 의존성 불변(`@clack/prompts`만).
- 35건 확정 결함은 8개 영역 finder + 3-렌즈 적대적 검증(≥2/3 표결)으로 식별.
- CHANGELOG 구조 정정: 비-SemVer 라벨(`[1.0.0]`·중복 `[1.3.0]`)과 헤더 누락 섹션을 실제 태그(`v1.1.0`·`v1.1.1`) 기준으로 재편(이력 내용 보존).

---

## [1.2.0] — 2026-06-05

v2.0 1차 — 설치기에서 **라이프사이클 도구**로. M8(라이프사이클)·M9(분석 지능화)·M10(opt-in 텔레메트리) 완료. GSD로 계획·실행(`.planning/`).

### Added
- **라이프사이클 명령(M8)**: `carve diff`(설치본 vs 현 자산 3-way 분류 — unchanged/carve-updated/user-modified/new-recommended), `carve update`(사용자 수정 보존하며 carve 자산만 제자리 갱신, `--force`·`--yes`, audit 게이트, `.bak` 1회), `carve migrate`(manifest 스키마 v1→v2 무손실 승격).
- **manifest 스키마 v2**: `files`가 `{path, hash, assetVersion}[]`로 확장 + `schemaVersion`. 자산 content-hash(`node:crypto` sha256)는 installer가 쓰기 시점에 산출. `normalizeManifest`로 v1을 단일 지점에서 흡수(uninstall·doctor 비파괴). 원자성 = pre-write audit + manifest-last(부분 실패 시 이전 상태 보존).
- **분석·추천 지능화(M9)**: analyzer가 모노레포(pnpm-workspace·turbo·nx·lerna·cargo·npm workspaces)·컨테이너(Dockerfile·docker-compose·Makefile) 시그널을 `ProjectProfile`에 채움. designer가 모노레포/CI 시그널로 조정 컴포넌트(parallel-agents·coordinator)를 가중(`applySignalWeights`). wizard 선택을 `.claude/.carve-prefs.json`에 영속화(`prefs.ts`).
- **로컬 효과 텔레메트리(M10, opt-in)**: `assets/hooks/_metrics.sh` emit 헬퍼(기본 OFF — `CARVE_METRICS=on` 또는 `.claude/.carve-metrics.enabled`). 6개 효과 훅이 `{ts, hook, event}`만 `.claude/.carve-metrics.jsonl`에 append(명령·경로·secret 비기록, **네트워크 없음**, 차단 exit-2 로직 byte-for-byte 불변). `carve report`로 발화·차단·0-fire 훅 집계.

### Notes
- **191 테스트 / 커버리지 ~95.6%**(라인). tsc strict clean, auditor·`bash -n` 통과, 런타임 의존성 불변(`@clack/prompts`만, `node:crypto` 등 표준만 추가).
- 가드레일 준수: 쓰기는 `.claude/`+루트 가이드+manifest만, 대상 소스 비수정, 멱등·`.bak` 1회. `.carve-prefs.json`·`.carve-metrics.jsonl`은 사용자 데이터라 설치 manifest에서 제외(uninstall이 지우지 않음).

---

## [1.1.1] — 2026-06-02

### Fixed
- bare `carve` 대화형 진입 수정(인자 없이 실행 시 wizard 선택 설치로 진입).
- `subagent-chain.sh` shebang 보정 — CI shellcheck 게이트 통과(v1.1.0 재배포).

---

## [1.1.0] — 2026-06-02

첫 공개 릴리스. 분석→설계→생성→자기검증→멱등설치 파이프라인이 동작하는 CLI. 아래는 1.1.0에 번들된 개발 마일스톤(시간순)이다.

### Added — MVP 파이프라인
- **CLI**: `carve install`(대화형 @clack 선택 + `--only` 명시 선택, 일괄 설치 없음)·`list`·`doctor`·`uninstall`.
- **파이프라인 모듈**: `analyzer`(프로젝트 타입·언어·도구 탐지)·`catalog`(점수≥75 레지스트리)·`designer`(슬롯 설계+하네스 레벨)·`generator`(자산 깎기+템플릿 치환)·`auditor`(생성물 보안 자기검증)·`installer`/`manifest`(멱등·`.bak` 보존·클린 uninstall).
- **핵심 스킬 6 + 진입 스킬**: handoff·memory·commit·changelog·review·pr + harness-architect(자연어 트리거) + `carve-*` 커맨드 shim.
- **필수 훅 7 + 선택 1**: 파괴적 명령 차단·비밀파일 보호(exit 2 결정적 차단)·커밋 전 린트·푸시 전 테스트·자동 포맷·Slack 알림·PreCompact 핸드오프(+자동 커밋 선택).
- **Squad 서브에이전트 8종 100% 보존**: 에이전트·커맨드·키워드 라우터(`squad-router.sh`)·체이닝/알림(`subagent-chain.sh`) 훅 vendoring + 등록.
- **anti-ai-slop 팩**: 마스터 스킬 + 포맷별(svg-image·card-news·html-report·html-presentation) + `clean-html` + `check-slop.mjs` 린터. PostToolUse 경고 훅(예외경로).
- **생성 문서**: `flight-rules.md`·`evaluation-criteria.md`·대상 `CLAUDE.md`·`HARNESS-GUIDE.md`.
- **배포**: npx(`carve-harness`) + `install.sh` bash 래퍼. 테스트 96개(단위+E2E), 커버리지 ~95%.

### Added — post-PoC SHOULD #1–4
- **squad-evaluator 서브에이전트(#1)**: `evaluation-criteria.md`·Sprint Contract 대비 독립 평가(Self-Eval Blindspot 대응). Squad 합류(9종).
- **Sprint Contract 생성(#2)**: `sprint-contract.md` 템플릿 — 코딩 전 "완료" 합의. generator가 생성.
- **auditor 셸 문법 검증(#3·#4)**: 생성 훅을 `shellcheck`(있으면)·`bash -n`(폴백)으로 검사해 설치 전 차단.
- **GAP-1 정합**: 카탈로그에 등재됐으나 자산이 없던 `verify`(90)·`security-scan`(80)·`test-gen`(76)의 SKILL.md+shim 작성, 카탈로그↔자산 정합 가드 테스트(`assets.test.ts`).
- **외부 큐레이션 스킬**: `tdd`(88)·`caveman`(80)·`write-a-skill`(78)·`zoom-out`(76) — mattpocock/skills(MIT) 패턴 재작성.

### Added — post-PoC COULD #5–12
- **parallel-agents(#5)**: 최소 병렬화(3~4 에이전트) + git worktree 격리 가이드.
- **evaluator-tuning(#6)**: squad-evaluator 오판 수집→few-shot 보정 루프.
- **model-route(#7)**: 작업→Haiku/Sonnet/Opus 3-Tier 라우팅(비용 최적화).
- **coordinator(#8)**: 멀티에이전트 메일박스/TeamCreate 패턴 가이드.
- **harness-audit(#10)**: 설치 하네스 자기 점검 스킬 + `carve doctor` 셸 문법 검사.
- Out-of-fit(정직 표기): provider 추상화(#11) 미구현, TUI(#12) 보류.

### Added — 토큰 효율 · 레벨 · CLAUDE.md 베이스라인
- **토큰 효율 기본 탑재**: codesight(구조 맵 MCP)·LSP(cclsp MCP) 카탈로그 core 등재(92·90), installer `mcpServers` 병합·멱등 + uninstall 제거. `bench/` 스캐폴드 + 라이브 실측(n=5 CRUD).
- **`carve install --level <minimal|standard|full>`**: 프로필 자동 판정을 수동 강제(`parseLevel`).
- **`carve init-claude`**: 작업 지침 베이스라인 `.claude/CLAUDE.md` + 언어 스택 규칙 6종 생성, 루트 `CLAUDE.md` `@import` 멱등 연결. 내부 템플릿 `assets/claude-base/`(7 스택 × 6 규칙).
- **문서 정비**: `INSTALL.md`/`INSTALL.en.md` 설치 매뉴얼(한/영), README 재정비.

### 측정 (라이브 cross-harness, n=5 CRUD)
- no-harness $0.101 · squad $0.148 · **carve $0.159** · ecc $0.382 (전부 5/5 성공). 누출률 carve **0%** vs no-harness·squad 100%.
- carve vs ECC: 비용 **58%↓** · 토큰 **47%↓** (효율 ★차별점).

### Changed
- 언어 JS → TypeScript(빌드 0, Node ≥22.18 타입 스트리핑). `node --check` → `tsc --noEmit`.
- `vendor/`로 OpenHarness·subagents 이동(읽기 전용 원본 보존; 이후 `assets/`로 melt-in).
