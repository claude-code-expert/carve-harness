# M11 — 비교·증명 벤치 완성 (개발 플랜)

> 상태: 🚧 **Phase A(측정 인프라) 완료** (Opus 4.8, 2026-06-15) · Phase B(라이브 캠페인) 대기.
> 상위 로드맵 [MS7-v2-roadmap.md](MS7-v2-roadmap.md) §M11. 두 레이어(A=리포 자체, B=대상 `.claude/`)와 모든 가드레일 준수.
>
> **Phase A 착지**: `bench/collect.mjs`(수집 파서)·`gen-fixture.mjs`(대형 fixture)·`test-trigger.sh`(트리거 결정적)
> ·`report.mjs` 축 3·4 확장·시드(`routing.tsv` 17 + `no-route.txt`)·`tasksets/explore.md`. 트리거 17/17·오발화 0/5,
> 287 테스트 통과·tsc clean·score 100/100. **Phase B(API·타 하네스 n≥5 실측)는 코드로 끝낼 수 없어 사용자 실행 대기.**

## 0. 이 마일스톤의 핵심 성격 (먼저 읽을 것)

**M11은 두 종류의 작업이 섞여 있다. 이 분리가 계획의 골격이다.**

| | Phase A — 측정 인프라 | Phase B — 측정 캠페인 |
|---|---|---|
| 누가 | **Fable이 코드로 구현** | **사용자가 라이브 실행**(API·타 하네스 필요) |
| 성격 | 결정론적·재현 가능·테스트 가능 | LLM 비결정·n≥5·중앙값 |
| 산출 | `bench/` 도구·시드·fixture·파서 | `bench/results/*.json` 실측 + 문서 갱신 |
| 게이트 | `npm run check`·`bash -n`·단위 테스트 | 추정 금지·보류 라벨 유지 |

> **왜 분리하나.** 벤치의 정직 정책(`carve-harness-benchmark-criteria.md` §0·§10: "측정 먼저, 주장 나중, 추정 금지")상
> 토큰·$·트리거·컨텍스트 점유율의 **cross-harness 수치는 라이브 LLM 없이는 만들 수 없다**. Fable이 할 수 있는 건
> "사용자가 키만 꽂으면 한 번에 돌아가는 측정 하니스"를 완성하는 것까지다. 그래서 M11의 **Fable 완료 정의 = Phase A**,
> M11의 **로드맵 완료 정의 = Phase A + Phase B(사용자 캠페인)**.

## 1. CHANGELOG 잔여 항목 → M11 매핑 (누락 방지)

`CHANGELOG.md` [Unreleased] "잔여(로드맵)"의 3줄 중 2줄이 M11이다:

- **"v1.0 토큰효율 절약 수치 검증 — 대형 fixture·탐색 태스크로 재측정"** → 태스크 **A1 + B1**.
- **"벤치 cross-harness 축 3(트리거 정확도)·축 4(컨텍스트 점유율) 라이브 미측정"** → 태스크 **A2/A4 + B1**.
- (나머지 1줄 "M12 피드백 루프"는 [M12-feedback-loop.md](M12-feedback-loop.md).)

## 2. 현재 상태 — 무엇이 있고 무엇이 없나

`bench/`를 실측 기준으로 점검한 결과(criteria §8 권장 구조 대비):

| 구성요소 | 상태 | 비고 |
|---|:--:|---|
| `bench/run.mjs` | ✅ | 결정적 자기측정(축 2·3·5·6 + 1·4 프록시). 라우팅은 **8케이스만** |
| `bench/run.sh` | ✅ | 자기측정 + 축2 carve↔no-harness 비교 + 라이브 **안내(텍스트)** |
| `bench/report.mjs` | ✅ | results 합산. 스키마 4필드: `tokensPerTask·costPerTask·e2ePass·blockLeak` → **축 3·4 열 없음** |
| `bench/results/*.json` | ◐ | carve·ecc·no-harness·squad 4개 존재하나 **v1.1.0 n=5 CRUD 구(舊)데이터** |
| `bench/seeds/` | ◐ | danger·safe·secret-bad/safe·routing(8줄). **오발화(no-route)·conflict/priority 시드 없음** |
| `bench/tasksets/` | ◐ | crud(2태스크)·multi·refactor. **탐색(explore) 태스크셋 없음** |
| `bench/harnesses/README.md` | ✅ | A~E 셋업 가이드 |
| `bench/labels/config-accuracy.json` | ✅ | 구성 정확도 라벨(축 6) |
| **`bench/collect.mjs`** | ❌ | criteria §8 권장 `collect.js` **미구축** — results를 손으로 작성 중 |
| **`bench/test-trigger.sh`** | ❌ | criteria §3 언급 **미구축** — 라우팅 전수 케이스 없음 |
| **대형 코드베이스 fixture** | ❌ | codesight/LSP "~11× 절감" 검증 대상 부재(소형 CRUD만 측정됨) |

→ **갭 = 5개**: collect 파서, 트리거 하니스, 대형 fixture+탐색 태스크셋, report 축3·4 확장, results 재측정(B).

---

## Phase A — 측정 인프라 (Fable 구현)

### A1. 대형 코드베이스 fixture + 탐색 태스크셋

**목표**: 토큰효율(codesight·LSP의 grep 재탐색 대체) 이점은 **탐색 비용이 큰 중·대형 코드베이스**에서만 드러난다
(소형 단발은 MCP 고정비용으로 역전 — `carve-harness-benchmark-results.md` §토큰 효율). 그 구간을 만들 fixture가 필요하다.

**구현**
- `bench/gen-fixture.mjs`(신규): **결정적** 대형 fixture 생성기. 고정 시드로 N개 모듈(상호 import·심볼 참조가 깊은) 트리를 만든다.
  - `Math.random()` 금지 — 인덱스 기반 결정적 생성(파일명·참조를 `i % k`로). 같은 인자 → 같은 트리(재현성).
  - 규모 파라미터(예: `--modules 200`)로 "grep이 비싼" 규모를 만든다. 출력은 `bench/fixtures/large/`(gitignore 또는 생성형).
- `bench/tasksets/explore.md`(신규): "함수 X의 모든 호출처를 찾아 시그니처를 바꿔라" 류 **탐색 지배 태스크** 3~5개.
  codesight/LSP가 grep을 대체하는 시나리오를 명시(findReferences·구조 맵 의존).

**코드 위치**: `bench/gen-fixture.mjs`, `bench/tasksets/explore.md`, `.gitignore`(fixtures/large 제외 시).

**검증**: `gen-fixture.mjs`를 같은 시드로 2회 실행 → 디렉토리 트리 동일(결정성 단위 테스트, `test/unit/`에 작은 규모로). `bash -n`·`tsc` 무관(`.mjs`라 `node --check`).

> **주의**: 이 fixture 위 실제 토큰 수치는 라이브(B1)다. A1은 "측정 가능한 무대"까지만 만든다.

### A2. 트리거 정확도 결정적 하니스 (`bench/test-trigger.sh`)

**목표**: criteria §3·결과문서 지표 3.1/3.3이 가리키는 미구축 `bench/test-trigger.sh`. 현 `run.mjs`는 라우팅 **8케이스**만 본다.
Squad 라우터의 키워드 위임은 **결정적**이라 Fable이 전수 측정할 수 있다(자연어→스킬 description 발화만 라이브 = B).

**구현**
- `bench/seeds/routing.tsv` 확장: 현 8줄(정상 라우팅)에 **conflict**(2개 키워드 충돌 시 우선순위)·**priority**·**동의어** 케이스 추가. 형식 유지(`prompt\t기대에이전트`).
- `bench/seeds/no-route.txt`(신규): 오발화 시드 — 라우팅되면 안 되는 일상 프롬프트셋(현 `run.mjs`의 3개를 파일로 외부화·확장).
- `bench/test-trigger.sh`(신규): `assets/squad/hooks/squad-router.sh`에 두 시드셋을 전수 입력 → **라우팅 정확도**(정상 일치율)·**오발화율**(no-route 발화율) 카운트 출력. `run.mjs` 축3과 동일 파싱(`/squad-[a-z]+/`) 재사용, `jq` 부재 시 graceful skip(현 run.mjs 관례).

**코드 위치**: `bench/test-trigger.sh`, `bench/seeds/routing.tsv`(확장), `bench/seeds/no-route.txt`.

**검증**: `bash -n bench/test-trigger.sh`. 기대값 회귀(현 8케이스는 그대로 8/8). `run.mjs` 축3이 같은 시드 파일을 읽도록 통일하면 단일 출처(중복 제거) — 선택.

### A3. 라이브 수집 파서 (`bench/collect.mjs`)

**목표**: criteria §8이 권장한 유일한 미구축 도구. 지금은 `bench/results/<harness>.json`을 **손으로** 쓴다(carve.json은 1줄 수기). 이를 자동화해 캠페인(B)의 마찰·오류를 없앤다.

**구현**
- `bench/collect.mjs`(신규): **순수 파서** 2종(라이브 호출은 하지 않음 — 입력은 stdin/파일).
  - `ccusage` JSON 출력 → `{tokensPerTask[], costPerTask[]}` 추출.
  - `/context` 텍스트 출력 → 컨텍스트 점유율(%) 추출(축 4). 점유 토큰/총 토큰 파싱.
  - 출력: `report.mjs`가 읽는 results 스키마로 머지(아래 A4 확장 필드 포함).
- 파서를 **순수 함수로 export**(`parseCcusage(json)`·`parseContext(text)`) → fixture 입력으로 단위 테스트 가능(결정론).

**코드 위치**: `bench/collect.mjs`, `bench/run.sh`(수집 단계 호출 추가 — 라이브 절차 안내를 실제 파이프로).

**검증**: `parseCcusage`·`parseContext`에 **고정 샘플 출력**(`test/fixtures/bench/`)을 넣어 추출값 단위 테스트. 라이브 부분은 안내만(현 run.sh §3 거울).

### A4. `report.mjs` 축 3·4 확장 (스코어카드 완성)

**목표**: 현 스코어카드는 토큰·$·E2E·누출 4열뿐. **축 3(트리거 정확도)·축 4(컨텍스트 점유율)** 열을 추가해 6축 표를 완성한다(criteria §7 템플릿 충족).

**구현**
- results 스키마에 **옵셔널** 필드 추가: `triggerAccuracy[]`(%)·`contextOccupancy[]`(%). 기존 4필드 파일도 그대로 동작(필드 없으면 `—`).
- `report.mjs` 표에 2열 추가, `median()` 재사용. 해석 규칙 문구(§7: "carve가 모든 축 1위일 필요 없음") 유지.

**코드 위치**: `bench/report.mjs`(확장), `bench/README.md`(스키마 문서 갱신).

**검증**: 구(4필드) `results/*.json`로 `node bench/report.mjs` → 신규 열 `—`로 무손상 출력(하위호환). 신필드 포함 fixture → 중앙값 정확.

---

## Phase B — 측정 캠페인 (사용자 라이브 실행)

> Fable이 코드로 끝낼 수 없는 부분. A의 도구가 완성되면 **사용자가 API·타 하네스 환경에서** 실행한다.
> 이 단계는 플랜에 "절차"로만 남긴다(수치 추정·선기재 금지 — criteria §10).

- **B1. A~E 하네스 n≥5 실행**: `bench/harnesses/README.md`로 A~E 셋업 → `tasksets/{crud,multi,explore}`를 각 n≥5 →
  `collect.mjs`로 `results/<id>.json` 생성(토큰·$·트리거·컨텍스트). 대형 fixture(A1)로 토큰효율 carve(적용) vs carve(미적용) 재측정.
- **B2. 문서 재생성**: `docs/guide/carve-harness-benchmark-results.md`의 ⏳ 보류 행(축 1·3·4, 지표 1.1~1.5·3.2·3.4·4.1~4.3)을 실측으로 갱신.
  미측정 항목은 **⏳ 유지**(거짓 충족 금지). "X배" 주장은 실측 후에만.
- **B3. README 정량평가 절 갱신**: v1.1.0 측정값 표기 → 신측정 반영. 측정 버전·날짜 명시.

---

## 3. 검증 게이트 (Phase A 한정 — Fable 완료 기준)

- `npm run check`(tsc) — `.ts` 무변경이면 통과 유지(`bench/*`는 `.mjs`라 영향 없음, fixture 생성기만 `node --check`).
- 신규 셸: `bash -n bench/test-trigger.sh`.
- 신규 `.mjs` 파서 단위 테스트: `bench/collect.mjs`의 `parseCcusage`·`parseContext`, `gen-fixture.mjs` 결정성.
- `node bench/run.mjs`·`node bench/report.mjs`·`bash bench/run.sh` 무회귀(기존 출력 보존, 신규는 추가만).
- 커버리지 게이트 ≥80 유지(`bench/`는 보통 커버리지 제외 — 파서를 `src/`에 두지 않는 한. 단위 테스트는 `test/`에서 import).

## 4. 가드레일 (불변)

- **측정 전용** — `bench/`는 리포 내·런타임 외부. 대상 프로젝트 소스·`.claude/` 비수정.
- **추정 금지·보류 라벨 유지** — 라이브 미측정은 ⏳로 남긴다(criteria §0·§10).
- **의존성 무추가** — ccusage는 `npx`로 호출(런타임 의존 아님). 새 라이브러리 도입 시 명시 승인.
- **결정성** — fixture 생성·파서는 `Math.random()`/`Date.now()` 비의존(시드·입력 기반).

## 5. 핵심 변경 파일 요약

| 태스크 | 신규 | 수정 |
|---|---|---|
| A1 | `bench/gen-fixture.mjs`·`bench/tasksets/explore.md` | `.gitignore`(선택) |
| A2 | `bench/test-trigger.sh`·`bench/seeds/no-route.txt` | `bench/seeds/routing.tsv` |
| A3 | `bench/collect.mjs` | `bench/run.sh` |
| A4 | — | `bench/report.mjs`·`bench/README.md` |
| B1~B3 | `bench/results/*.json`(실측) | `docs/guide/carve-harness-benchmark-results.md`·`README.md` |

> 이 계획은 두 레이어 구분과 모든 가드레일을 준수한다. Phase A는 네트워크·신규 런타임 의존성을 도입하지 않으며,
> Phase B의 라이브 수치는 실측 전까지 문서에 기재하지 않는다.
