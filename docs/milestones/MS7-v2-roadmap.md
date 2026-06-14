# MS7 — carve-harness v2.0 로드맵: "하네스 엔지니어링 도구"로의 진화

> 상태: 🚧 진행 중. MS0~MS6(v1.x) 완료 · **M8·M9·M10 완료 (v1.2.0, 2026-06-05)** · **M12 완료 (피드백 루프 closed loop)** · **M11 Phase A(측정 인프라) 완료 · Phase B(라이브) 대기**. 본 문서는 v2.0까지의 단계별 개발 계획이다.
> 두 레이어(A=리포 자체, B=대상 `.claude/` 산출물) 구분과 carve의 모든 가드레일을 준수한다.

## Context (왜 이 작업인가)

carve-harness는 현재 v1.1.1에서 **analyze→design→generate→audit→install** 파이프라인,
40+ 컴포넌트 카탈로그, Squad 9 에이전트, anti-slop, CLAUDE.md/언어 rules 생성까지
"한 번 깎아 설치"하는 기능은 완성되어 있다 (118 테스트 / 커버 ~95%).

그러나 **"하네스 엔지니어링 도구"**로 불리려면 *설치기*를 넘어 다음 세 가지가 필요하다:

1. **효과를 증명하고 측정하는 루프** — 하네스가 실제로 무엇을 막고/도왔는지 데이터로 보인다.
   현재 라이브 크로스하네스 비교(축 1·4)와 대형 토큰효율 재측정은 보류 상태(README §정량평가).
2. **라이프사이클·유지보수** — carve가 진화하면 *이미 설치된* 하네스를 안전하게 갱신해야 한다.
   현재 재설치만 가능하고 `update`/`diff`/`migrate`가 없으며, manifest 스키마 마이그레이션도 미구현(gotcha 기록됨).
3. **분석·추천 지능화** — 모노레포·Docker 미탐지, 정적 score·단순 레벨 휴리스틱 때문에
   추천 정확도가 프로젝트 다양성을 못 따라간다.

**불변 가드레일 (사용자 명시 — "개발 코드/지침이 하네스 영향을 벗어나면 안 됨"):**
모든 신규 기능은 carve의 정체성 안에서만 동작한다.
- 쓰기는 `.claude/` + 지정 루트 가이드 + `carve-manifest.json`으로만 한정. **대상 소스 비수정.**
- **네트워크 전송 없음** (텔레메트리는 100% 로컬). secret 비기록.
- 런타임 의존성은 `@clack/prompts` 하나 유지 — 표준 라이브러리(`node:crypto`·`node:fs` 등)로 푼다.
- 멱등성·`.bak` 1회 보존·결정론적 차단 훅(exit 2) 약화 금지.
- auditor 통과 못 한 생성물은 설치 안 함.

---

## 의존성·순서 (sequencing)

```
M8 라이프사이클 기반 (자산 버전 + update/diff/migrate)
   └─ 선행: M9~M12가 새 자산을 배포하므로 "안전 갱신" 경로가 먼저 있어야 함
M9 분석·추천 지능화  ─┐ (M8과 병행 가능, 서로 독립)
M10 로컬 효과 텔레메트리 ─┤
M11 비교·증명 벤치 완성  ─┘
M12 피드백 루프 통합  ← M10(텔레메트리) + M11(벤치) 결과를 designer로 환류 (closed loop)
```

권장 진행: **M8 → (M9 ∥ M10) → M11 → M12**. M8이 토대, M12가 "하네스 엔지니어링"의 핵심 closed loop.

---

## M8 — 라이프사이클 기반: 자산 버전 + `update`/`diff`/`migrate` ✅ 완료 (v1.2.0)

**목표**: 설치된 하네스를 carve 신버전으로 *사용자 수정 보존하며* 안전 갱신. 부분 실패 시 불일치 방지.

**구현**
- **자산 해시·버전**: 생성 시 각 artifact의 content hash(`node:crypto`) 계산 → manifest에 `files: [{path, hash, assetVersion}]`로 기록 (현 `string[]`에서 확장).
- **`carve diff [dir]`**: 3-way 분류 — (원본 hash) vs (설치본 현재 내용) vs (현 carve 자산).
  → `unchanged / carve-updated / user-modified / new-recommended`로 분류해 출력.
- **`carve update [dir]`**: 사용자 미수정 자산만 in-place 갱신. 사용자 수정 자산은 diff 제시 후 확인, 원본 `.bak` 1회. 신규 추천 자산은 제안만(강제 설치 금지 — harness-architect 원칙).
- **`carve migrate`**: manifest 스키마 v1→v2 마이그레이션 (gotcha "version migration logic 없음" 해소). 구버전 manifest를 손실 없이 승격.
- **원자적 설치**: 임시 디렉토리에 전량 쓰고 audit 통과 후 swap. 식별된 gap "partial failure leaves inconsistent state" 해소.

**코드 위치**
- `src/manifest.ts` — 스키마 v2(`files` 객체화, `schemaVersion`), `migrateManifest()`.
- `src/installer.ts` — atomic write/rollback, 3-way merge 헬퍼.
- `src/commands.ts` — `cmdUpdate`, `cmdDiff`.
- `src/cli.ts` — `update`/`diff` 디스패치 + USAGE 갱신.
- (자산 hash 산출은 `src/generator.ts` Artifact 생성 직후)

**검증**
- update 후 사용자 수정 자산 보존 + carve 자산만 갱신 (e2e roundtrip).
- v1 manifest → migrate → v2 무손실 단위 테스트.
- atomic rollback: audit 실패 주입 시 기존 설치 무변화 테스트.

**가드레일**: `.claude/`+manifest만 씀. 의존성 추가 없음(`node:crypto`). `.bak`·멱등 규칙 유지.

---

## M9 — 분석·추천 지능화 ✅ 완료 (v1.2.0)

**목표**: 모노레포·Docker 등 현실 신호를 반영하고, 정적 score를 가중치 점수로 바꿔 추천 정확도를 올린다.

**구현**
- **analyzer 시그널 확장**: 모노레포(pnpm workspaces·turborepo·nx·lerna·cargo workspaces) → `ProjectProfile.workspaces[]`. `Dockerfile`/`docker-compose`/`Makefile` 시그널 추가. 프레임워크 세분(이미 일부 — 보강).
- **designer 가중치 스코어링**: 현재 정적 `catalog.score` + 단순 레벨 휴리스틱을 → profile 시그널 기반 동적 가중으로 교체. 예: CI+멀티랭귀지→full 상향, 모노레포→parallel-agents·coordinator 가중↑.
- **사용자 선호 영속화**: wizard에서 선택/해제한 이력을 `.claude/` 내 로컬 파일(또는 manifest 필드)에 저장 → 재실행/`update` 시 기본 선택 반영.

**코드 위치**
- `src/analyzer.ts`, `src/types.ts` (`ProjectProfile` 확장: `workspaces`, `container`, signals).
- `src/designer.ts` (scoring 함수 분리·테스트), `src/catalog.ts` (가중 메타 필드).
- `src/wizard.ts` (선호 round-trip).

**검증**
- 모노레포 fixture·Docker fixture 추가 → 탐지 단위 테스트.
- scoring 단위 테스트(시그널→추천 변화), 선호 저장/복원 round-trip 테스트.

**가드레일**: 읽기 전용 스캔(대상 소스 비수정). 선호 파일은 `.claude/` 내부. 의존성 무추가.

---

## M10 — 로컬 효과 텔레메트리 (opt-in) ✅ 완료 (v1.2.0)

**목표**: 하네스가 *실제로* 무엇을 했는지 로컬 기록 → 증명·피드백의 데이터 원천.

**구현**
- **훅 이벤트 emit**: 공통 헬퍼 `assets/hooks/_metrics.sh`. block-destructive/protect-secrets 차단, pre-commit-lint/pre-push-test fire, auto-format 실행 등 → `.claude/.carve-metrics.jsonl`에 append. **opt-in** (설치 시 동의 또는 `CARVE_METRICS=on`), 기본 off.
- **기록 범위 최소화**: 이벤트 타입·타임스탬프·훅 id만. **명령 본문·경로·secret 비기록**(또는 redaction). auditor가 신규 훅을 검증.
- **`carve report [dir]`**: jsonl 집계 → 차단 횟수, 훅별 발화 빈도, 발화 0회 훅(노이즈 후보) 요약.

**코드 위치**
- `assets/hooks/_metrics.sh` (+ 기존 9개 훅에 emit 1줄 추가), `assets/hooks/` 렌더 변수.
- `src/commands.ts` (`cmdReport`), `src/cli.ts` (디스패치).

**검증**
- 훅 emit 단위 테스트(이벤트 라인 형식), redaction 테스트, opt-out 시 무동작 테스트.
- report 집계 정확도 테스트, `bash -n`·auditor 통과.

**가드레일 (핵심)**: **네트워크 전송 절대 없음**, 로컬 `.claude/`만, opt-in, secret 비기록 — 사용자 강조 "하네스 영향 이탈 금지" 직접 충족. 결정론적 차단 훅 동작 불변(emit은 부수효과로만, 차단 로직 미변경).

---

## M11 — 비교·증명 벤치 완성 🚧 Phase A 완료 · Phase B 대기

> 구현 명세·갭 분석: [M11-bench-completion.md](M11-bench-completion.md). M11은 성격상 2단 — Phase A(측정 인프라, 코드)/Phase B(라이브 캠페인, API).

**목표**: 보류된 라이브 크로스하네스 비교(축 1·3·4)와 대형 토큰효율 재측정을 마무리, 정직 라벨 유지.

**Phase A — 측정 인프라 (구현됨, Opus 4.8)**
- `bench/collect.mjs` — ccusage(토큰·$)·`/context`(점유율 축4) 순수 파서(라이브 호출 안 함 → 결정적·테스트 가능).
- `bench/gen-fixture.mjs` — 대형 코드베이스 fixture 결정적 생성기(codesight/LSP vs grep 측정 무대). 유효 TS, 같은 시드→같은 트리.
- `bench/test-trigger.sh` + 시드(`routing.tsv` 17 + `no-route.txt` 5) — 트리거 정확도/오발화 결정적 측정. **17/17·0/5**.
- `bench/report.mjs` — 축 3(트리거)·4(컨텍스트) 열 추가 + `summarize` 순수화(하위호환: 구 4필드 → `—`).
- `bench/tasksets/explore.md` — 탐색 지배 태스크(findReferences·구조맵 의존). `run.sh`에 트리거 단계·collect 파이프 안내.
- 검증: 신규 `test/unit/bench.test.ts`(8) 서브프로세스 테스트. 287 통과·tsc clean·score 100/100.

**Phase B — 측정 캠페인 (대기, 코드 외)**
- A~E 하네스 n≥5 실행 → `collect.mjs` 수집 → `results/*.json` → `report.mjs`. 대형 fixture로 토큰효율 재측정.
- `docs/guide/carve-harness-benchmark-results.md` ⏳ 행 갱신. **API·타 하네스 필요 — Fable/코드로 끝낼 수 없음.**

**코드 위치**: `bench/` (리포 내, 런타임 외부), `docs/guide/`.

**가드레일**: 측정 전용. 추정 금지·보류 라벨 유지. 의존성 무추가(ccusage는 `npx`).

---

## M12 — 피드백 루프 통합 (closed loop) — "하네스 엔지니어링"의 핵심 ✅ 완료

> 구현 명세: [M12-feedback-loop.md](M12-feedback-loop.md). M10 텔레메트리만 입력원으로 사용(M11 벤치 환류는 후속 슬롯).

**목표**: M10 텔레메트리(`.claude/.carve-metrics.jsonl`)를 designer 추천·`carve update`/`report` 제안에 환류. measure→suggest→사용자 결정의 닫힌 고리.

**구현됨**
- **집계 추출**: `src/metrics.ts`(신규) — `aggregateMetrics(root, manifest)` 순수 read-only 함수. `cmdReport`의 인라인 집계(`parseMetricLine`·`INSTRUMENTED_HOOKS`·0-fire 역매핑)를 이리로 빼 report·update·designer가 단일 출처로 공유. `cmdReport`는 호출로 축소(출력 byte-identical).
- **designer 제안**: `designer.applyMetricsWeights(metrics)` — 발화 0회 계측 훅 → `demote` 제안(정렬·결정적). **추천 집합(`design().recommended`)은 바꾸지 않는다** — measure→suggest→사용자 결정(harness-architect: 강제 금지). metrics null이면 빈 배열.
- **표면화**: `carve update`·`carve report`가 제안을 안내 출력(제안만 — write 경로 불변). metrics opt-out(기본)이면 무출력 → 기존 동작 100% 동일.
- **보류(슬롯만)**: "차단 빈발 훅 → 컴포넌트 weight-up"은 매핑이 자의적이라 의도적 미구현(`kind: 'weight-up'` 타입 슬롯만 열어둠). demote 한 규칙으로 closed loop 성립.

**코드 위치**: `src/metrics.ts`(신규), `src/designer.ts`(`applyMetricsWeights`·`MetricsSuggestion`), `src/commands.ts`(`cmdReport` 추출·`cmdUpdate`/`cmdReport` 제안 표면화).

**검증됨**: `aggregateMetrics`/`parseMetricLine` 단위(`metrics.test.ts`), `applyMetricsWeights` 제안·결정성·하위호환(`designer.test.ts`), `cmdUpdate` 제안 표면화 + write 경로 불변 + metrics 부재 시 무출력(`update.e2e.test.ts`). 279 테스트 통과·커버리지 ≥80·score 100/100.

**가드레일**: 로컬 데이터만 입력, 네트워크 없음, 결정론(같은 입력→같은 제안), metrics 부재 시 byte-identical 동작, 제안만(강제 변경 없음).

---

## 명시적 보류 (이번 v2.0 범위 밖)

우선순위에서 제외한 **확장성·커버리지**는 v2.0 이후로 미룬다:
- 플러그인/커스텀 카탈로그, 추가 스택(C++·Kotlin·Swift·C#·PHP·Ruby), 추가 Squad 에이전트(devops·perf·a11y).
- 단, M9의 catalog 가중 메타와 M8의 자산 버전 구조는 이후 확장의 *토대*가 되도록 설계한다(과설계는 금지 — 슬롯만 열어둠).

---

## 전체 검증 전략

- 단위·e2e는 기존 방식 유지: `node --test`로 `.ts` 직접 실행, fixtures 확장(모노레포·Docker·대형).
- 커밋 전 게이트: `npm run check`(tsc) · `npm test` · `bash -n`(신규 훅) · `JSON.parse`(manifest v2).
- 커버리지 ≥80 게이트 유지(현 ~95 수준 비퇴행).
- 신규 생성 훅·커맨드는 **auditor 통과 필수**(secret·과도권한·hook injection·셸 문법).
- 각 마일스톤 종료 시 e2e roundtrip(install→report→update→diff→uninstall) 통과.

## 핵심 변경 파일 요약

| 마일스톤 | 주요 파일 |
|---|---|
| M8 | `src/manifest.ts`, `src/installer.ts`, `src/commands.ts`, `src/cli.ts` |
| M9 | `src/analyzer.ts`, `src/types.ts`, `src/designer.ts`, `src/catalog.ts`, `src/wizard.ts` |
| M10 | `assets/hooks/_metrics.sh`(+기존 훅), `src/commands.ts`, `src/cli.ts` |
| M11 | `bench/run.mjs`, `docs/guide/carve-harness-benchmark-results.md` |
| M12 | `src/designer.ts`, `src/commands.ts` |

> 이 계획은 carve의 두 레이어 구분과 모든 가드레일을 준수한다.
> 어느 마일스톤도 대상 프로젝트 소스를 수정하지 않으며, 네트워크 전송·신규 런타임 의존성을 도입하지 않는다.
