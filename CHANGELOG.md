# Changelog

이 프로젝트의 모든 주요 변경사항을 기록한다.
포맷은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/)를 따르며,
[유의적 버전(SemVer)](https://semver.org/lang/ko/)을 준수한다.

## [Unreleased]

### 잔여
- v2.0 로드맵 **M11(비교·증명 벤치)·M12(피드백 루프)** 예정 — `docs/milestones/MS7-v2-roadmap.md`.
- v1.0 토큰효율 **절약 수치 검증**: 대형 fixture·탐색 태스크로 벤치 재측정 필요(소형 단발은 MCP 고정비용으로 효과 작음).
- 벤치 cross-harness **축 3(트리거 정확도)·축 4(컨텍스트 점유율)** 라이브 미측정(추가 LLM 필요).

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

## [1.0.0] — 2026-06-01

문서 정비 + 전체 설치 매뉴얼(한/영).

### Added
- **설치 매뉴얼 `INSTALL.md`(한글) + `INSTALL.en.md`(영문)**: 요구사항 · 풀 설치 3단계 흐름 · 설치 방식(npx/bash/로컬) · 설치 모드(대화형·`--only`·`--level`·`--lsp-servers`) · 설치 레벨 · 단계별 구성요소(토큰효율·6 핵심 스킬·7 필수 훅·Squad 9·anti-slop·추가 스킬) · `carve init-claude` · 생성 파일 구조 · 명령 레퍼런스 · 멱등/재설치 · 제거 · 점검 · 문제 해결.

### Changed
- **README** 재정비: 전체 설치 흐름·명령 레퍼런스·라이브 벤치마크 점수표·제거 절차를 정리하고 설치 매뉴얼 링크 추가. 현재 구현(`init-claude`·`--level`·토큰효율) 기준으로 갱신.
- 버전 표기·테스트 수(116) 등 문서 전반을 현재 구현 기준으로 동기화.

### Notes
- 코드 변경 없음(문서 릴리스). 116 테스트 / 커버리지 ~94% 유지.

---

CLAUDE.md 베이스라인 + 언어 스택별 `.claude/rules/*` 생성 (`carve init-claude`).

### Added
- **`carve init-claude`**: 작업 지침 베이스라인 `.claude/CLAUDE.md`(스택 무관 — 사고·단순함·외과적 변경·TDD·커밋 규율·응답 제어·할루시네이션 가드·안전 가드레일) + 탐지 언어의 규칙 6종(`.claude/rules/{techstack,project-structure,commands,code-style,safety,gotchas}.md`)을 생성.
- **언어 스택 자동 선택**: TypeScript/JavaScript·Python·Go·Rust·Java·Dart, 그 외 `_default`. 패키지매니저·테스트/린트 명령은 탐지값으로 치환(`{{PKG_MANAGER}}` 등).
- 루트 `CLAUDE.md`에 `@import` 블록을 멱등 추가(marker 기준) → 베이스라인+rules가 세션마다 로드. `installer.installClaudeBase()`가 기존 manifest.files를 union 보존(클린 제거 유지).
- harness-architect 스킬에 "CLAUDE.md 셋업" 단계 추가(세션 내 진입). flight-rules는 행동 원칙을 베이스라인으로 위임하고 하네스 강제만 남김(슬림).
- 내부 템플릿 `assets/claude-base/`(베이스라인 + 7 스택 × 6 규칙 파일) 신설.

### Notes
- 116 테스트 / 커버리지 ~94%. `init-claude` 테스트는 임시 디렉토리만 사용.

---

설치 레벨 강제 플래그(`--level`) 추가.

### Added
- **`carve install --level <minimal|standard|full>`**: 프로필 기반 자동 판정을 사용자가 수동으로 강제. `--level=full` 형태도 지원. 잘못된 값은 exit 1로 거부.
- `full` 강제 시 단일언어 프로젝트에도 멀티에이전트 병렬(`parallel-agents`)·조율(`coordinator`) 스킬 + 추가 스킬을 설치.
- `cli.ts`에 `parseLevel()`, `designer.design(p, levelOverride?)`, `cmdInstall(..., level?)` 와이어링.

### Notes
- 111 테스트 / 커버리지 ~94%. `--level` 테스트는 임시 디렉토리만 사용(리포 오염 없음).

---

토큰 효율 기본 탑재(codesight + LSP) + 벤치 라이브 실측.

### Added
- **토큰 효율 기본 탑재**: codesight(MCP `npx codesight --mcp` + git-commit `.codesight/` refresh 훅) · LSP(cclsp MCP `npx cclsp` + 탐지 언어서버 `npm i -g` 자동설치 — 대화형/`--lsp-servers`만). 카탈로그 **core** 등재(codesight 92·lsp 90).
- installer `mcpServers` 병합·멱등 + uninstall 제거(`manifest.mcps`).
- `flight-rules.md`·`CLAUDE.md`에 "탐색은 codesight·LSP 우선, grep 최소화" 지침. Squad review·refactor·audit·evaluator 프롬프트에도 반영.
- **벤치 `bench/`**: 스캐폴드(run.sh·seeds·labels·tasksets·harnesses·report.mjs) + **라이브 실측(n=5 CRUD)**.

### 측정 (라이브, n=5 CRUD)
- no-harness $0.101 · squad $0.148 · carve $0.159 · ecc $0.382 (전부 5/5 성공). 누출률 carve **0%** vs no-harness·squad 100%.
- **carve vs ECC: 비용 58%↓ · 토큰 47%↓** (효율 ★차별점).

### Notes
- 108 테스트 / 커버리지 ~94%. shellcheck 미설치 시 bash -n 폴백.

---


post-PoC COULD #8–12 추가 변경이며 **브레이킹 없음**.

### Added
- **harness-audit(#10)**: 설치된 하네스 자기 점검 스킬 + `carve doctor`가 설치 훅 셸 문법(`bash -n`/shellcheck)까지 검사.
- **coordinator(#8)**: 멀티에이전트 메일박스/TeamCreate 패턴 가이드 스킬.

### Out-of-fit / 보류 (정직 표기)
- **provider 추상화(#11)**: 런타임 LLM 백엔드 교체는 carve(.claude 자산 설치)의 모델 밖. carve는 Claude Code 타깃(requirement N3) → **out-of-fit**(구현 안 함).
- **TUI(#12)**: 대화형 설치가 이미 `@clack` UX 제공. 더 무거운 TUI는 가치<비용으로 **보류**.

---

post-PoC COULD #5–7 반영 — 스킬 3종(설치형).

### Added
- **parallel-agents(#5)**: 최소 병렬화(3~4 에이전트) + git worktree 격리 가이드.
- **evaluator-tuning(#6)**: squad-evaluator 오판 수집→few-shot 보정 루프(1~2주 운영).
- **model-route(#7)**: 작업→Haiku/Sonnet/Opus 3-Tier 라우팅(비용 최적화).
- 카탈로그 등록(점수 80·76·85) + `carve-*` 커맨드 shim. designer full 레벨 추천.

---

## [1.3.0] — 2026-05-31

post-PoC SHOULD #1–4 반영.

### Added
- **squad-evaluator 서브에이전트(#1)**: `evaluation-criteria.md`·Sprint Contract 대비 독립 평가(Self-Eval Blindspot 대응). Squad 합류(9종), 디스패처·커맨드 포함.
- **Sprint Contract 생성(#2)**: `sprint-contract.md` 템플릿 — 코딩 전 "완료" 합의. generator가 생성.
- **auditor 셸 문법 검증(#3·#4)**: 생성 훅을 `shellcheck`(있으면)·`bash -n`(폴백)으로 검사해 설치 전 차단.

### Notes
- 104 테스트 / 커버리지 ~95%. shellcheck 미설치 환경은 bash -n 폴백.

---

### Fixed
- **GAP-1**: 카탈로그에 등재됐으나 자산이 없던 스킬 `verify`(90)·`security-scan`(80)·`test-gen`(76)의
  `SKILL.md` + 커맨드 shim 작성 — full 레벨 설치 시 조용히 누락되던 문제 해소.

### Added
- 카탈로그↔자산 정합 가드 테스트(`test/unit/assets.test.ts`) — 자산 없는 등재 항목 회귀 방지.
- `docs/milestones/README.md` 인덱스 — 틱별 stale "다음:" 포인터를 역사 스냅샷으로 명시(GAP-3).

---


### Added
- 외부 큐레이션 스킬 도입 (mattpocock/skills, MIT — 출처 표기): `tdd`(88)·`caveman`(80)·`write-a-skill`(78)·`zoom-out`(76).
  carve-네이티브로 재작성, 카탈로그 등록 + `carve-*` 커맨드 shim. designer **full 레벨**에서 추천.

### Removed
- 중복 문서 `docs/requirement.md`·`docs/ARCHITECTURE.md` (루트 사본 유지, README·CLAUDE 참조 무손상).

---


MVP 구현 완료. TypeScript(ESM, 빌드 0) CLI로 분석→설계→생성→자기검증→멱등설치 파이프라인 동작.

### Added
- **CLI**: `carve install`(대화형 @clack 선택 + `--only` 명시 선택, 일괄 설치 없음)·`list`·`doctor`·`uninstall`.
- **파이프라인 모듈**: `analyzer`(프로젝트 타입·언어·도구 탐지)·`catalog`(점수≥75 레지스트리)·`designer`(슬롯 설계+하네스 레벨)·`generator`(자산 깎기+템플릿 치환)·`auditor`(생성물 보안 자기검증)·`installer`/`manifest`(멱등·`.bak` 보존·클린 uninstall).
- **핵심 스킬 6 + 진입 스킬**: handoff·memory·commit·changelog·review·pr + harness-architect(자연어 트리거) + `carve-*` 커맨드 shim.
- **필수 훅 7 + 선택 1**: 파괴적 명령 차단·비밀파일 보호(exit 2 결정적 차단)·커밋 전 린트·푸시 전 테스트·자동 포맷·Slack 알림·PreCompact 핸드오프(+자동 커밋 선택).
- **Squad 서브에이전트 8종 100% 보존**: 에이전트·커맨드·키워드 라우터(`squad-router.sh`)·체이닝/알림(`subagent-chain.sh`) 훅 vendoring + 등록.
- **anti-ai-slop 팩**: 마스터 스킬 + 포맷별(svg-image·card-news·html-report·html-presentation) + `clean-html` + `check-slop.mjs` 린터(HTML/CSS·SVG·Markdown 디스패치). PostToolUse 경고 훅(예외경로).
- **생성 문서**: `flight-rules.md`·`evaluation-criteria.md`·대상 `CLAUDE.md`·`HARNESS-GUIDE.md`.
- **배포**: npx(`carve-harness`) + `install.sh` bash 래퍼.
- **테스트**: 96개(단위+E2E), 커버리지 ~95%. PoC 합격 시나리오 E2E.
- **정량 평가표**: `docs/guide/carve-harness-benchmark-results.md`(6축 28지표, 한 줄 단위).

### Changed
- 언어 JS → TypeScript(빌드 0, Node ≥22.18 타입 스트리핑). `node --check` → `tsc --noEmit`.
- `vendor/`로 OpenHarness·subagents 이동(읽기 전용 원본 보존).

### Notes
- 정량 평가: 자기측정 축(제어·안전 / 기능 E2E / 구성 품질) 목표 달성. 비교 축(효율·트리거·컨텍스트)은 라이브 벤치 보류.

