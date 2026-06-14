# M12 — 피드백 루프 통합 / closed loop (개발 플랜)

> 상태: ✅ 구현 완료 (Opus 4.8, 2026-06-14). 상위 로드맵 [MS7-v2-roadmap.md](MS7-v2-roadmap.md) §M12.
> 이 문서는 원래의 구현 명세이며, 아래 "구현 결과"가 실제 착지 내용이다. 두 레이어와 모든 가드레일 준수.
>
> **구현 결과**: `src/metrics.ts`(집계 추출) + `designer.applyMetricsWeights`(demote 제안) + `cmdUpdate`/`cmdReport` 표면화.
> 279 테스트 통과·커버리지 ≥80·score 100/100·tsc strict clean. `weight-up` 규칙은 매핑 자의성으로 의도적 보류(타입 슬롯만).

## 0. 한 줄 요약

M10이 깐 로컬 텔레메트리(`.claude/.carve-metrics.jsonl`)를 **designer 추천·`carve update` 제안에 환류**한다.
"측정(M10) → 설계 반영(M12)"의 닫힌 고리. **단, 강제 변경은 없고 제안만** 한다(harness-architect 원칙).

## 1. 왜 이미 거의 다 깔려 있나 (환류 지점 지도)

M8~M10에서 닫힌 고리의 *양 끝*이 이미 존재한다. M12는 **그 사이를 잇기만** 한다.

| 끝 | 현재 위치 | M12에서 하는 일 |
|---|---|---|
| 데이터 생산(emit) | `assets/hooks/_metrics.sh` → `{ts,hook,event}` jsonl | 그대로 사용(변경 없음) |
| 데이터 집계(read) | `commands.ts:424-470` `cmdReport`의 **인라인** 집계 | 순수 함수로 **추출**(M12-1) |
| 추천 가중(hook) | `designer.ts:37-51` `applySignalWeights`(monorepo/CI 가중) | **같은 패턴으로** metrics 가중 추가(M12-2) |
| 사용자 표면화 | `commands.ts:289-368` `cmdUpdate`(carve-updated/new-recommended 안내) | metrics 제안 안내 추가(M12-3) |

> 핵심: 집계 로직은 이미 `cmdReport` 안에 있다(`parseMetricLine`·`INSTRUMENTED_HOOKS`·0-fire 판정).
> M12-1은 새 알고리즘이 아니라 **추출(DRY)** — designer가 같은 집계를 재사용하게 만드는 일이다.

## 2. 설계 결정 — "추천을 바꾼다" vs "제안만 한다" (★ 중요)

로드맵 §M12 본문은 *"designer가 metrics를 읽어 **추천 가중에 반영**"* 이라 적었지만, 같은 절이
*"제안만, 강제 금지"* 와 *"metrics 없을 때 기존 동작과 100% 동일"* 도 못박는다. 이 둘을 동시에 만족하는 안전한 해석을 택한다:

- **`design()`의 `recommended` 집합은 조용히 바꾸지 않는다.** 추천을 metrics로 흔들면 결정성·신뢰를 해치고,
  "같은 프로젝트인데 어제와 추천이 다른" 혼란을 부른다(harness-architect는 강제 설치를 금지).
- **대신 metrics는 별도 `suggestions`로 표면화**한다 — `carve update`/`carve report`가 "이렇게 바꾸는 걸 고려하라"고
  *안내만* 한다. 사용자가 `--only`/wizard로 직접 반영한다.
- `design()` 시그니처는 **옵셔널 파라미터로 확장**하되, `metrics`가 없으면(=대부분) **기존 코드 경로 그대로** 탄다
  → 스냅샷 테스트로 하위호환을 봉인.

> 즉 "닫힌 고리"는 **사람을 거치는** 고리다(measure → suggest → human decides → re-install). 이게 carve의 정체성
> ("추천만 하고 설치는 사용자가")에 맞고, 결정성·하위호환을 깨지 않는다. 대안(추천 집합 자동 변경)은 채택하지 않는다.

---

## M12-1. 텔레메트리 집계 추출 (`src/metrics.ts`)

**목표**: `cmdReport`에 박혀 있는 집계를 **순수 read-only 모듈**로 빼서 designer·report·update가 공유한다.
`prefs.ts`(사용자 데이터, 손상 시 graceful null)와 같은 결을 따른다.

**구현**
- `src/metrics.ts`(신규):
  - `interface MetricsAggregate { perHook: Map<string,{total:number;blocks:number}>; zeroFire: string[]; totalFires:number; totalBlocks:number; parsedLines:number }`
  - `aggregateMetrics(root: string, manifest: Manifest | null): MetricsAggregate | null`
    — `.claude/.carve-metrics.jsonl` 없으면 `null`(opt-in 미사용). 손상 줄은 줄 단위 skip(throw 없음).
  - `parseMetricLine`·`INSTRUMENTED_HOOKS`를 **이 모듈로 이동**(현재 `commands.ts:392-417`). 0-fire 판정도 여기로
    (manifest의 `carve-<id>.sh` 역매핑 — 현 `cmdReport` 로직 그대로 옮김).
- `commands.ts`의 `cmdReport`를 `aggregateMetrics()` 호출로 **축소**(출력 문자열은 한 글자도 안 바뀌게 — 회귀 0).

**코드 위치**: `src/metrics.ts`(신규), `src/commands.ts`(`cmdReport` 리팩터·import 정리).

**검증**
- `aggregateMetrics` 단위 테스트(`test/unit/metrics.test.ts`): 정상 집계·손상 줄 skip·0-fire 판정·파일 부재 시 null.
- **회귀 봉인**: `cmdReport` 출력 스냅샷이 추출 전후 동일(IO 캡처 비교) — 동작 불변 증명.

## M12-2. designer 메트릭 가중/제안 (`applyMetricsWeights`)

**목표**: metrics 집계 → **제안(suggestions)** 산출. 결정론·하위호환. metrics 없으면 `design()` 결과 100% 불변.

**구현**
- `designer.ts`에 `applySignalWeights`(거울 패턴)로 추가:
  - `interface MetricsSuggestion { kind:'demote'|'weight-up'; id:string; reason:string }`
  - `applyMetricsWeights(p, design, metrics: MetricsAggregate | null): MetricsSuggestion[]`
    — `metrics===null`이면 **빈 배열** 반환(분기 종료, 부작용 0).
  - 규칙(최소·명시 — 과설계 금지):
    1. **발화 0회 계측 훅** → `{kind:'demote', id, reason:'설치됐지만 한 번도 발화 안 함'}`.
       (안전: 추천에서 빼지 않고 "다음 설치에서 제외 고려" 제안만.)
    2. **(선택, 작게) 차단 빈발 훅** → 관련 컴포넌트 `weight-up`. **매핑은 명시 테이블 1개**로 고정하고
       자명한 것만 — 예: `block-destructive` 차단 多 → `harness-audit` 가중. 매핑이 애매하면 이 규칙은 **보류**(1번만으로도 닫힌 고리 성립). 과설계 주의(CLAUDE.md 작업원칙 §2).
- `design()` 시그니처: `design(p, levelOverride?, metrics?)` — `metrics` 미전달이면 기존 경로 그대로.
  추천 집합은 metrics로 **바꾸지 않는다**(§2 결정). `design()`은 `suggestions`를 `HarnessDesign`에 옵셔널 필드로 실어 보내거나,
  호출부가 `applyMetricsWeights`를 따로 부른다(후자가 더 순수 — 권장).

**코드 위치**: `src/designer.ts`.

**검증**
- metrics 주입 → 0-fire 훅이 `demote` 제안에 등장(단위).
- **하위호환 스냅샷**: `metrics` 없는 `design(p)` 결과가 M12 전후 byte-identical(기존 designer.test.ts 스냅샷 유지).
- **결정성**: 같은 metrics 2회 → 같은 suggestions(정렬 안정, Map 순회 결정적으로).

## M12-3. `carve update`/`carve report` 제안 표면화

**목표**: `carve update`가 텔레메트리 기반 제안을 포함한다(제안만). metrics 없으면 무출력(기존 동작 불변).

**구현**
- `cmdUpdate`(`commands.ts:289`)에 metrics 단계 추가(write 경로는 **안 건드림** — 안내 출력만):
  - `const metrics = aggregateMetrics(root, m)` → `applyMetricsWeights(profile, d, metrics)` → 제안 출력.
  - 예: `io.log('텔레메트리 제안: precompact-handoff 발화 0회 — 다음 설치에서 제외 고려.')`
  - metrics `null`이면 아무것도 출력 안 함. 자산 write·manifest 갱신 로직은 **변경 없음**(원자성·멱등 불변).
- `cmdReport`에도 동일 제안 섹션을 한 줄 추가(선택) — 이미 0-fire를 보고하므로 "→ 제외 고려" 문구만 덧댐.

**코드 위치**: `src/commands.ts`(`cmdUpdate`·`cmdReport`).

**검증**
- metrics 있는 설치 → `cmdUpdate`가 제안 출력(IO 캡처). metrics 없으면 제안 무출력.
- **강제 변경 없음**: update의 `toWrite`/`writeManifest` 경로가 metrics 유무와 무관하게 동일(자산 변형 0) — 회귀 테스트.

## M12-4. 문서·봉인

- `MS7-v2-roadmap.md` §M12 상태 ✅ + `docs/milestones/README.md` v2.0 표의 M12 → ✅.
- `docs/lifecycle.md`(존재) 또는 README에 closed-loop 한 줄: "measure → suggest → 사용자 결정".
- `CHANGELOG.md` [Unreleased]에 항목 추가(release-notes 스킬로).

---

## 3. 의존성·순서

```
M12-1 (집계 추출)  ← 토대. designer가 재사용할 순수 함수.
   └─ M12-2 (designer 제안)  ← M12-1의 MetricsAggregate 소비
        └─ M12-3 (update/report 표면화)  ← M12-2의 suggestions 출력
              └─ M12-4 (문서·봉인)
```

순서대로. M12-1을 먼저 하면 `cmdReport`가 깨지지 않게 추출(스냅샷)부터 잠그고 위로 쌓는다.

## 4. 검증 게이트 (Fable 완료 기준)

- `npm run check`(tsc strict, `any` 금지·non-null `!` 금지).
- `npm test` — 신규: `metrics.test.ts`, designer 제안·하위호환 스냅샷, update 제안 출력·write 불변.
- 커버리지 ≥80 유지(현 ~88).
- `npm run score` 게이트 PASS(축 회귀 없음).
- 런타임 의존성 불변(`@clack` 하나, `node:fs`만 추가 사용).

## 5. 가드레일 (불변)

- **로컬 데이터만 입력** — `.claude/.carve-metrics.jsonl`만 읽는다. **네트워크 전송 절대 없음**.
- **결정론** — 같은 (profile, metrics) → 같은 추천·제안.
- **하위호환 100%** — metrics 없으면(=opt-out 기본값) M12 이전과 byte-identical 동작.
- **제안만, 강제 금지** — 추천 집합·자산 write를 metrics로 바꾸지 않는다. 사용자가 결정한다.
- 쓰기는 `.claude/`+루트 가이드+manifest로 한정. 대상 소스 비수정.

## 6. 핵심 변경 파일 요약

| 태스크 | 신규 | 수정 |
|---|---|---|
| M12-1 | `src/metrics.ts`·`test/unit/metrics.test.ts` | `src/commands.ts`(cmdReport 추출) |
| M12-2 | — | `src/designer.ts`·`test/unit/designer.test.ts` |
| M12-3 | — | `src/commands.ts`(cmdUpdate·cmdReport) |
| M12-4 | — | `MS7-v2-roadmap.md`·`docs/milestones/README.md`·`CHANGELOG.md`·`docs/lifecycle.md` |

> 이 계획은 두 레이어 구분과 모든 가드레일을 준수한다. 네트워크 전송·신규 런타임 의존성을 도입하지 않으며,
> metrics 부재 시 기존 동작과 100% 동일함을 스냅샷으로 봉인한다.
