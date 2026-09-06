# 하네스 확장 4작업 — 분석 리포트 + 우선순위 PLAN

> 작성 2026-09-06 · 분석 전용(코드 변경 없음) · 브랜치 `docs/feature-expansion-analysis`
> 근거: `specs/fitness-assessment.md` §3 갭 4개 + read-only 코드 탐색(확장 슬롯·감사·설치·테스트·문서 표면) + 설계 검토.
> **구현은 이 문서 검토 후 별도 진행.** 착수 순서·게이트 판정·부수 비용은 아래 §3.

---

## 0. Context — 왜 이 4개인가

`specs/fitness-assessment.md`가 이 하네스를 "**과정 품질(process floor)** 강제 O, **도메인 정합성(correctness)** 보장 X"로 규정하고, 백엔드(특히 Java/Spring)+웹+DB엔 강하나 다음 4곳이 표준 게이트로 안 덮인다고 결론냈다:

1. **모바일 클라이언트** — Swift/Kotlin/Dart 스택 없음, RN도 TS 팩으로 반쪽 (M1·M3, 점수 0).
2. **API 계약(클라↔서버)** — 응답 스키마·에러 코드 계약 검증 규칙 없음 (M4·W7 일부, 점수 0~1).
3. **런타임/e2e** — 앱이 실제로 뜨는지 표준 게이트 없음 (W12·M 공통, 점수 0→1).
4. **네트워크 견고성** — 타임아웃·재시도·백오프·멱등 규칙 없음 (M5, 점수 0).

`fitness-assessment.md` §"다음(제안)"이 이 4개의 출처다. 요구: **"가장 가벼운 영역부터 우선순위"** → 각 작업이 실제로 건드리는 표면을 실측해 비용순 정렬 + 착수 순서 확정.

핵심 발견: **아무 확장이나 붙이면 설치기·감사(harness-audit)·테스트 열거·문서 카운트가 연쇄로 딸려온다.** 확장 슬롯마다 이 "부수 비용"이 크게 다르다. 그래서 기능 크기가 아니라 **부수 비용 순**으로 우선순위를 정한다.

---

## 1. 확장 슬롯 사실 (탐색 실측)

붙일 수 있는 슬롯은 3종 + e2e. 각각의 부수 비용:

### 1-A. common 규칙 — 가장 싼 슬롯
- **형태**: frontmatter 없는 `.claude/rules/common/<x>.md`. 항상 로드(`paths` glob 불요, 스택 무관).
- **설치기**: 무편집. `.claude/rules` 통짜 복사(md 컴포넌트), 코어 보호 경로(`install.sh:596`).
- **테스트 스캐폴딩**: **0.** 전용 `.test.sh` 없음.
- **감사**: AUDIT-05 위생만(파일 비어있지 않음·중복 아님). rule→gate 매핑(AUDIT-03) **대상 아님** — 권고 규칙이라 게이트 요구 없음.
- **문서 카운트**: `규칙 N종` 1곳 계열(README.md·README.en.md·GUIDE.md·HARNESS_GUIDE.md 각 ~4-5 사이트).
- 예: `security.md`·`testing.md`·`git-workflow.md`가 이미 이 형식.

### 1-B. 스택 파일 — 중간 비용
- **형태**: `.claude/stacks/<id>.sh` 1개. 3훅이 `stacks/*.sh` 자동 글롭(stop-verify:36-49·posttool-format:15-31·eval-score:151-163) — 훅 편집 불요.
- **계약**: `STACK_ID`·`STACK_CHANGE_RE`·`STACK_FORMAT_RE`/`TOOL`·`stack_format`(rc 0/1/2)·`stack_gate`(rc 0/1)·`stack_detect`/`build`/`test`/`lint`·`stack_coverage`·`STACK_COVERAGE_MIN`·`STACK_TEST_CMD_HINT`.
- **테스트**: `stacks.test.sh:17` 하드코딩 6-스택 리스트를 **깬다** → 편집 필수.
- **감사**: 스택 게이트가 하드 게이트로 잡히므로 AUDIT-03/07/08 대상.

### 1-C. 언어팩 — 가장 비싼 슬롯
- **형태**: `packs/<name>.pack`(평문 매니페스트) + 5요소(규칙 dir·상세본 `docs/rules/code-convention/`·스택 파일·골든셋 스타터·judge 예시·LSP 플러그인 토글).
- **설치기**: 데이터 주도(무편집) — `.pack` 읽어서 처리.
- **감사**: **AUDIT-09가 팩 무결성 풀 강제** — 경로 실재·stack_gate 포함·스타터 carve-validate 통과·LSP 토글 일치.
- **테스트**: `lib-packs.test.sh:19-20` + `stacks.test.sh:17` 하드코딩 리스트 **2곳** 편집 + detect 픽스처(예: `pubspec.yaml`) 추가.
- **문서 카운트**: 최대 blast — `팩 N종`·`스택 N종`·`규칙 N종`·상세본·스타터·`26 스위트`·`67체크` 전부.

### 1-D. e2e — 이미 존재, 신규 슬롯 불필요
- `cmd_exit0`(`eval-state.sh:61-62`, 워크디렉토리서 `bash -c "$value"`) + `exec:`/`claude` target(`eval-run.sh:122-139`)이 **이미 앱 부팅+프로브 개념**을 커버.
- `example-harness-e2e.json`(eval-goldenset 스킬)이 샘플. `stack_e2e` 추상화는 **없음** — 만들면 6→7 스택·3훅·전 팩을 다 고쳐야 함.

### 1-E. 교차 제약 (설계 규칙)
- **D-09/D-12 (블루프린트)**: 안전 필수 정책만 훅 게이트. **스타일/코드컨벤션 규칙은 게이트 금지.** API 계약을 하드 게이트로 걸면 이 원칙 위반 + openapi 없는 리포 전부 false-fail.
- **AUDIT-03 (orphan policy)**: 규칙/도구가 있으면 강제 게이트가 있어야 FAIL을 면함 — 단 **권고 규칙(common)은 매핑 대상 제외**. 그래서 권고형은 안전.
- **도구 의존**: openapi/swagger/springdoc 의존 **0**. `jq`만 무의존 JSON 도구. macOS bash 3.2(`declare -A`·`mapfile` 불가).

### 1-F. 비용 순위 (실측 결론)
```
common 규칙  <  스택 파일  <  언어팩 (≒ e2e 어댑터 신설)
(테스트 0)     (테스트 1곳)   (테스트 2곳 + AUDIT-09 + 최대 문서)
```

---

## 2. 작업별 상세 분석

### F1. 네트워크 견고성 규칙 — 크기 XS (가장 가벼움)

**목표**: 분산 호출(API·DB·외부 서비스)의 실패 모드를 규칙으로 다룬다. `fitness-assessment.md` M5(점수 0) 해소.

**접근**: `.claude/rules/common/network-resilience.md` 1파일. 언어 무관 교차 관심사 → common.
내용 골자(권고):
- 모든 외부 호출에 타임아웃(무한 대기 금지).
- 재시도 + 지수 백오프 + jitter. 재시도 상한.
- 비멱등 쓰기엔 멱등키(idempotency key) — 재시도 중복 방지.
- 실패 폴백/서킷브레이커 개념(장애 전파 차단).
- 오프라인/부분 실패 시 사용자 대면 상태 처리.

**게이트 판정**: **권고(rule-only).** 근거 — D-09(안전 필수 아님), 하드 게이트 걸면 AUDIT-03 역충돌 + 언어·프레임워크마다 재시도 관용구가 달라 결정적 검사 불가.

**부수 비용**:
| 항목 | 비용 |
|---|---|
| 테스트 스캐폴딩 | 0 |
| 감사 | AUDIT-05 위생만(자동) |
| 설치기 | 무편집 |
| 문서 카운트 | `규칙 N종` +1 (~4-5 사이트) |

**리스크**: 없음(순수 가산). 규칙이 항상 로드되므로 즉효.

---

### F4. e2e/런타임 게이트 표준화 — 크기 S/XS

**목표**: "앱이 실제로 뜨나"를 표준 골든셋 컨벤션으로 명명. `fitness-assessment.md` W12(0→1) 해소.

**접근**: **새 `stack_e2e` 함수 만들지 않는다(YAGNI).** 기존 `cmd_exit0` + `exec:` target이 이미 그 기능. 할 일은 **문서화 + 정본 레퍼런스 지정**:
- 골든셋 컨벤션 명문화: "e2e 케이스 = 앱 부팅 + 헬스 프로브를 `cmd_exit0` assert로." (예: `docker compose up -d && curl -f localhost:PORT/health`).
- `example-harness-e2e.json`을 e2e 정본 예시로 링크(GUIDE/eval-goldenset 스킬 문서).
- 선택: 이 예시를 `specs/goldenset/starters/`로 승격 여부는 열린 결정(§4-4).

**게이트 판정**: 기존 옵트인 골든셋 assert 재사용. **신규 게이트 0.**

**부수 비용**:
| 항목 | 비용 |
|---|---|
| 신규 코드 | 0 |
| 테스트 | 0 (기존 eval-state 경로) |
| 문서 | e2e 컨벤션 문단 + 예시 링크 (GUIDE·eval-goldenset README) |

**왜 `stack_e2e`를 안 만드나**: 스택 계약에 `stack_e2e`를 추가하면 6(→7) 스택 파일 전부 + 3훅 + 스택 테스트 + 전 팩 AUDIT-09를 고쳐야 함. blast radius가 F3(팩)급인데 얻는 건 이미 `cmd_exit0`로 되는 것. **YAGNI, 문서화로 대체.**

---

### F2. API 계약 규칙 — 크기 S

**목표**: 클라↔서버 계약(응답 스키마·에러 코드·over-fetch)을 규칙화 + openapi 있는 리포엔 결정적 대조. `fitness-assessment.md` M4·W7(0~1) 해소.

**접근**: 두 층.
1. **권고 규칙** `.claude/rules/common/api-contract.md` — java-spring/patterns.md:15-18(DTO 응답·@Valid·ErrorResponse)의 서버 한정 지침을 **크로스 스택으로 일반화**:
   - 응답은 DTO/스키마 고정형(엔티티 직노출 금지).
   - 에러는 계약된 코드·형식(임의 500 금지).
   - over-fetch 금지(필요 필드만) — `security.md` PII 절과 정합.
   - 클라: 응답 파싱 시 스키마 검증(신뢰 경계).
2. **옵트인 골든셋 컨벤션** — 프로젝트에 `openapi.json`/`swagger.json`이 있을 때만 `cmd_exit0`로 `jq` 대조(엔드포인트·응답 필드 존재 확인). 결정적 이빨을 원하는 팀만.

**게이트 판정**: **권고 규칙 + 옵트인 assert. 하드 게이트 아님.** 근거 — D-09 준수, openapi 없는 리포(대다수)에서 오탐 방지. `contract`는 이미 evaluator.md:18의 LLM 루브릭 축 — **거긴 손대지 않는다**(스키마 검증과 별개 축).

**부수 비용**:
| 항목 | 비용 |
|---|---|
| 테스트 | 0 |
| 감사 | AUDIT-05 위생 |
| 설치기 | 무편집 |
| 문서 | `규칙 N종` +1 + assert 컨벤션 문단 1개 |

**리스크**: 낮음. 옵트인 jq 대조는 선택 사항이라 기본 설치엔 영향 0.

---

### F3. 모바일 스택 팩 (Flutter/Dart) — 크기 L (가장 무거움)

**목표**: 모바일 클라이언트 게이트. `fitness-assessment.md` M1·M3(점수 0) 해소.

**접근**: **Flutter/Dart 1개 먼저.** 단일 툴체인이라 rc가 명확:
- detect = `pubspec.yaml`.
- format = `dart format --set-exit-if-changed`.
- lint = `flutter analyze` (또는 `dart analyze`).
- test = `flutter test`.
- build = `flutter build`(무거움 — CI 전용, stack_build는 analyze로 대체 검토).

신규 산출물(팩 5요소, 총 ~7파일):
1. `packs/dart.pack` (매니페스트).
2. `.claude/stacks/dart.sh` (스택 계약 — java-spring.sh 템플릿).
3. `.claude/rules/dart/patterns.md` + `README.md` (규칙 슬림본).
4. `docs/rules/code-convention/dev-stack-dart.md` (상세본).
5. `specs/goldenset/starters/dart.json` (골든셋 스타터).
6. judge 예시 (evaluator 예시).
7. LSP 토글(`dart` LSP 플러그인) settings.json.

**RN 처리**: **별도 팩 불필요.** RN/Expo는 이미 typescript 스택(tsc/eslint/jest)을 탐(M2, 부분 커버). react-next 규칙에 **RN 절만 보강**(네이티브 모듈·플랫폼 분기 주의) 권고. Swift(macOS 전용 xcodebuild)·Kotlin(`.kt`는 이미 java-spring 변경 정규식 포함) — 무겁고 플랫폼 종속 → **보류.**

**게이트 판정**: **하드 게이트.** 빌드+테스트 스택 게이트는 기존 6스택과 동급 — 정당(AUDIT-03 충돌 없음, 스택은 안전/품질 필수 축).

**부수 비용 (최대)**:
| 항목 | 비용 |
|---|---|
| 신규 파일 | ~7 |
| 테스트 열거 편집 | `stacks.test.sh:17` + `lib-packs.test.sh:19-20` (2곳) |
| detect 픽스처 | `pubspec.yaml` 테스트 픽스처 |
| 감사 | **AUDIT-09 풀 세트**(경로·stack_gate·carve-validate·LSP 토글) |
| 문서 카운트 | 최대 — 팩·스택·규칙·상세본·스타터·스위트·체크 전부(~5 문서 × 다수 사이트) |

**리스크**: 높음(부수 비용). 반드시 단독 PR. Flutter 툴체인이 CI에 없으면 스택 게이트가 `stack_detect` 미탐으로 self-skip해야 함(설치 검증 시 PATH 스텁 필요).

---

## 3. 우선순위 PLAN (부수 비용·레버리지순)

| 순 | 작업 | 크기 | 게이트 | 부수 비용 요약 | 이유 |
|---|---|---|---|---|---|
| **1** | **F1 네트워크 견고성 규칙** | XS | 권고 | 테스트 0·문서 카운트만 | 스캐폴딩 0·게이트 위험 0·항상 로드 즉효. 순수 이득 |
| **2** | **F4 e2e 표준화** | S/XS | 재사용 | 신규 코드 0·문서만 | 바이트당 레버리지 최고. 잠재 기능을 명명된 컨벤션으로 |
| **3** | **F2 API 계약 규칙** | S | 권고+옵트인 | 테스트 0·문서+assert 문단 | F1과 같은 common 표면. 게이트 얽힘 없음, openapi 대조는 옵트인 |
| **4** | **F3 Dart 스택+팩** | L | 하드 | 테스트 2곳·AUDIT-09·최대 문서 | 유일하게 테스트 열거·감사·LSP·전 문서를 건드림. 마지막 단독 |

**순서 노트**: F1을 F2보다 먼저 머지해 `규칙 N종` 카운터를 한 번씩 깔끔히 증가(현재 common 4종 → +network-resilience → +api-contract). 카운트 grep 충돌 방지.

### PR 묶음
- **PR-A (F1 + F2, 옵션으로 F4 문서)**: 전부 `.claude/rules/common/` + 문서만. `.test.sh` 편집 0. AUDIT-05 위생이 한 번에 두 규칙 커버. F4(문서 전용)는 함께 태우거나 초소형 별도 PR.
  - Conventional Commit: `feat: add network-resilience and api-contract common rules` (feat → minor).
- **PR-B (F3 Dart)**: **반드시 단독.** `stacks.test.sh:17`·`lib-packs.test.sh:19-20`를 깨고 픽스처 추가·AUDIT-09 풀 체크·최대 문서 카운트. 규칙 PR과 묶으면 green 규칙 변경이 대형 열거 변경에 커플링됨.
  - Conventional Commit: `feat: add dart (flutter) language pack` (feat → minor).

---

## 4. 열린 결정 (구현 착수 시 확정 — 현재 권고안)

각 항목 권고안이 있으니 개발은 진행 가능. 다만 확정은 사용자 몫:

1. **모바일 스택 1순위**: **Flutter/Dart 먼저** (사용자가 이전에 Flutter/Dart 선호 표명). Kotlin/Swift 보류.
2. **RN 처리**: **별도 팩 대신 typescript/react-next 규칙에 RN 절 보강** (RN이 이미 TS 스택을 탐 — 팩 중복 회피).
3. **API 계약 강제 수준**: **하드 게이트 아님 — 권고 규칙 + 옵트인 골든셋 jq assert** (D-09 준수·오탐 방지).
4. **e2e 스타터 승격**: `example-harness-e2e.json`을 `specs/goldenset/starters/`로 올릴지 — **문서화만 권고** (스타터 카운트 안 늘림, 유지 부담 회피).

---

## 5. 검증 (구현 단계에서 — 지금은 실행 안 함)

- **F1/F2/F4**:
  - `bash .claude/hooks/harness-audit.sh` → ` 0 failed` (AUDIT-05 위생 green).
  - 문서 카운트 grep 일치(`규칙 N종`·`26 스위트`·`67체크` 전 사이트 동기).
  - `npm test` 전체 스위트 무회귀.
- **F3 (Dart)**:
  - 갱신된 `stacks.test.sh`·`lib-packs.test.sh` 리스트 green.
  - `bash .claude/hooks/carve-validate.sh specs/goldenset/starters/dart.json --red` 통과.
  - `eval-score.sh --stack dart` (dart/flutter PATH 스텁으로).
  - AUDIT-09 dart 팩 PASS.
  - `HARNESS_PACKS=dart bash install.sh` (temp target) 후 dart 경로만 설치·타 팩 부재 확인 (install-packs.test.sh 패턴).

---

## 6. 착수 시 참조 파일

| 용도 | 경로 |
|---|---|
| 스택 템플릿 | `.claude/stacks/java-spring.sh` |
| 팩 매니페스트 템플릿 | `packs/java-spring.pack` |
| common 규칙 형식 | `.claude/rules/common/security.md`·`testing.md` |
| e2e/assert 경로 | `.claude/hooks/eval-state.sh`(cmd_exit0 L61-62) · `.claude/skills/eval-goldenset/example-harness-e2e.json` |
| 테스트 열거(편집 대상) | `.claude/hooks/tests/stacks.test.sh:17` · `lib-packs.test.sh:19-20` |
| 설치 팩 테스트 패턴 | `.claude/hooks/tests/install-packs.test.sh` |
| 팩 무결성 감사 | `.claude/hooks/harness-audit.sh` AUDIT-09 |
| 문서 카운트 사이트 | `README.md`·`README.en.md`·`docs/md/GUIDE.md`·`docs/md/HARNESS_GUIDE.md` (`규칙 N종`·`스택 N종`·`팩 N종`·`26 스위트`·`67체크`) |
| API 계약 참조 규칙 | `.claude/rules/java-spring/patterns.md:15-18` · `docs/md/harness-eval-gate-blueprint.md` D-09/D-12 |

---

## 7. 이 문서 이후

승인 시: `specs/DECISIONS.md`에 결정(우선순위·게이트 판정 근거) append, 그 다음 F1부터 브랜치 단위 구현. **지금은 분석까지만.**
