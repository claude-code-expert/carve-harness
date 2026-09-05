# Evaluator 기능 TODO — 하네스 강화 백로그

> 출처: `docs/claude-code-harness-evaluator.html` (강의 "하네스 엔지니어링과 Evaluator 제어", 5장) 분석.
> 방법: 덱이 서술하는 기능을 현재 리포 실제 구성(`.claude/**`, `install.sh`)과 대조해 **미구현 항목만** 백로그화.
> 작성일: 2026-07-20. 각 항목은 검증 가능한 완료 기준(SC)을 가진다 — SC 미충족은 완료 아님.

## 범례
- 우선순위: **P1**(게이트 신뢰성 직결) · **P2**(성숙도 상승) · **P3**(운영/드리프트)
- 상태: `[ ]` 미착수 · `[~]` 부분 존재(보강) · `[x]` 완료

---

## 이미 구현됨 — TODO 아님 (근거)

덱이 다루지만 carve-harness에 **이미 있는** 기능. 백로그에서 제외한다(구현된 걸 gap으로 오판하면 퇴행).

| 덱 개념 | 현재 구현 위치 |
|---------|----------------|
| 3기둥(제약·피드백·상태) | `CLAUDE.md`, `.claude/hooks/*`, `settings.json`, `session-handoff.sh` |
| Pre/PostToolUse·Stop 훅, exit 2 차단 | `pretool-guard.sh`, `posttool-format.sh`, `stop-verify.sh` |
| Generator ≠ Evaluator | `agents/evaluator.md`, `skills/checklist-loop` |
| Evaluator Driven 95점 게이트 루프 | `workflows/carve-verify-loop.js` + `skills/checklist-loop` + `checklist-gate.sh` |
| 결정론 게이트(빌드·타입·테스트·린트) | `stop-verify.sh`(증분 검증) |
| 권한 경계 allow/ask/deny | `settings.json` permissions |
| 토큰 축약(caveman)·LSP 심볼 탐색 | `vendor/caveman`, settings.json LSP 선언 |
| 위반 차단 회귀 테스트(S1·S2·S4·S6 계열) | `hooks/tests/pretool-guard.test.sh` |

---

## P1 — 게이트 신뢰성

### 1. 2렌즈 5축 루브릭 채점 (`carve-verify-loop` 보강) `[x]`
- **덱 근거**: §4 "5축 100점, 2렌즈 min" — `exists 25 / match 25 / test 25 / contract 15 / no-regress 10`, `min(code-match, test-pass)`.
- **완료**(2026-07-26 확인): `carve-verify-loop.js:77` `AXIS_MAX` 5축 + 축별 클램프, `test` 축 미실행 0점 → 최대 75점.
- **SC**:
  - [x] `SCORE_SCHEMA`에 5축 배점 필드 추가, 항목 점수 = `min(codeMatchLens, testPassLens)`.
  - [x] `test` 축 미실행 시 항목 최대 75점(95 게이트 자동 미달)임을 테스트로 증명.
  - [x] `checklist-loop` SKILL의 수동 SOP도 동일 루브릭으로 갱신(도구·수동 정합).

### 2. 유형별 허용 실패율 게이트 `[ ]`
- **덱 근거**: §4 3계층 게이트 — `convention 5% / correctness 3% / domain_safety 0%`(불변식 위반 무조건 차단).
- **현재**: `stop-verify.sh`/`checklist-gate.sh`는 단일 임계(95)만. 위반 유형 분류·유형별 허용치 없음.
- **SC**:
  - [ ] 체크리스트 항목에 `type: convention|correctness|domain_safety` 라벨 필드 추가.
  - [ ] `domain_safety` 항목이 1건이라도 fail이면 총점 무관 게이트 차단(fail-closed) — 테스트로 증명.
  - [ ] 허용치는 설정으로 표현(하드코딩 금지).

---

## P2 — 성숙도(EDD Lv1→Lv3)

### 3. 골든셋 + 점수 시계열 `[~]`
- **덱 근거**: §4 "골든셋 고정 + 재채점 → 점수 시계열", §5 Step 0 "실패 20~50건으로 골든셋 v1".
- **현재**: 골든셋 v1 10건 작성(`specs/goldenset/harness-guard.json` 5 · `harness-craft.json` 5), 전건 구조 검증 + `--red` 신호 검증 통과. 재채점은 `/eval`(carve-eval). **미실행** — 첫 실측 run이 아직 없어 `specs/eval-score.json`은 미생성.
- **SC**:
  - [~] `specs/goldenset/`에 실패 케이스(입력+기대) 20~50건 스키마 정의 + 예시 5건 → 스키마·예시 완료, 케이스는 10/20건.
  - [x] 재채점 커맨드/스킬: 골든셋 전수 실행 → 케이스별 점수 기록(append-only 시계열 파일).
  - [x] 케이스 추가는 인간 검수 필수임을 절차에 명시(자기강화 방지).
  - [x] 프리플라이트 검증기(`carve-validate.sh`) — 설정 오류를 런 전에 분리, `--red`로 NO-SIGNAL 케이스 탐지.
  - [x] 케이스 `version` 필수화 + 추이에 `caseVersion` 기록 + 직전 run과 다르면 `[VERSION CHANGED]` 경고.
  - [x] 첫 실측 run(`/eval`) 수행 → baseline 확보. run#1 60점(채점기 결함값, 기준 부적합) → run#2 **100점**(채점기 수정 후, 실질 baseline). `specs/eval-score.json` 2 run 기록.
  - [~] **골든셋 난이도 보강** — `harness-hard.json` 5건 추가(총 15건). 소재는 이번 세션에서 실제 관측된 실패: 이스케이프 파손 전송 · 소스 grep 위장 테스트 · `mv`로 실행권한 소실 · 비멱등 스크립트 · 빈 입력 처리. 전건 양방향 검증(사전 red · 정답 green) 통과. **난이도는 run#3 실측 전까지 미확인** — 만점이면 더 보강해야 한다.

### 4. LLM-as-Judge 루브릭 그레이더 `[ ]`
- **덱 근거**: §4 채점기 3종 — 모델형(G-Eval 루브릭, `guided_json` 스키마 강제, temperature 0, 다중 Judge 합의).
- **현재**: `evaluator` 에이전트가 자연어 채점은 하나, 루브릭·스키마 강제·temperature 0·Judge-인간 일치율(κ) 보정 절차 없음.
- **SC**:
  - [ ] 루브릭 스키마(축·배점·판정 사유) 정의 + 출력 스키마 강제(`guided_json` 등가).
  - [ ] Judge-인간 일치율 측정 절차 문서화(κ≥0.6 통과 지표에만 단계 도입).
  - [ ] "경로가 아니라 결과를 채점" 원칙 반영(유효 변형에 감점 금지, 다구성 태스크 부분점수).

### 5. pass@k / pass^k 일관성 측정 `[x]`
- **덱 근거**: §4 "능력과 일관성을 분리" — `pass@k = 1−(1−p)^k`(상한), `pass^k = p^k`(하한).
- **완료**: `carve-eval.js`가 케이스별 k회(상한 10) 독립 실행 → `pass_at_k`·`pass_pow_k`·`caseScore`(green/k) 동시 산출, 리포트에 `passAtK`/`passPowK` 집계.
- **SC**:
  - [x] 지정 케이스를 k회 반복 실행 → pass@k·pass^k 동시 산출하는 스크립트/커맨드.
  - [x] 두 곡선 간극을 리포트("가끔 되는 시스템" 탐지).

---

## P3 — 운영/드리프트(EDD Lv4→Lv5)

### 6. CI eval 게이트 + 버전 비교 `[ ]`
- **덱 근거**: §5 "회귀 게이트 — 매 PR 골든셋 실행, 핵심 지표 ±3% 초과 하락 시 빌드 실패", 부트스트랩 짝지은 측정(90% CI), 카나리 5%.
- **현재**: 없음. `.githooks/pre-commit`은 정적 차단만, 골든셋 회귀 게이트 아님.
- **SC**:
  - [ ] CI(또는 pre-push) 단계에서 골든셋 실행 → 이전 버전 대비 델타 계산.
  - [ ] 핵심 지표 −3% 초과 하락 시 실패(exit 1). 부트스트랩 90% CI가 0 포함이면 "판정 불가"로 보류.
  - [ ] 프롬프트/`CLAUDE.md` 변경도 같은 게이트를 통과하도록 배선(프롬프트=코드).

### 7. 런타임/온라인 가드레일 eval + 드리프트 `[ ]`
- **덱 근거**: §4 "배포 후 무방비 → 온라인 모니터링 + 런타임 blocking eval", §5 `proceed / refuse / update` 3중 판정 + 구조화 피드백 폐쇄 루프.
- **현재**: 없음(전부 배포 전 게이트). 드리프트 미측정.
- **SC**:
  - [ ] 이진 allow/deny 대신 `proceed|refuse|update` 3중 판정 인터페이스 설계(스킬 또는 훅).
  - [ ] update 시 구조화 피드백을 컨텍스트에 주입해 계획 수정(정상 과제 보존).
  - [ ] 비가역 행동(삭제·전송·결제) 직전 중간 검사 지점 명시.

### 8. 가드레일 자기평가(공격셋) `[ ]`
- **덱 근거**: §5 "가드레일 자체를 공격 데이터셋으로 정기 평가" — 탐지 recall·차단률 분리 측정(TRIAD 실측: recall 58.57% → 차단 <37.26%).
- **현재**: 없음. 프롬프트 인젝션 공격셋·recall 측정 부재(`injection`은 규칙 문서에만 언급).
- **SC**:
  - [ ] 프롬프트 인젝션/위반 유도 공격 케이스셋(S0–S6 확장) 정의.
  - [ ] recall(탐지)과 차단 성공률을 **분리** 측정해 리포트.
  - [ ] "달았다 ≠ 막힌다" — 설치 후 방치 금지, 정기 재측정 절차.

---

## P3 — 보조(선택)

### 9. A/B 하네스 위반 매트릭스 리포트 (S0–S6 재현) `[~]`
- **덱 근거**: §2 실증 A/B — CONTROL vs HARNESS 행동 매트릭스(결정적 4건: S1·S2·S4·S6).
- **현재**: 차단 로직 회귀 테스트는 `pretool-guard.test.sh`에 있으나, CONTROL/HARNESS 대조 **리포트 산출물**은 없음.
- **SC**:
  - [ ] S0–S6를 하네스 유무로 대조 실행 → PASS/FAIL 매트릭스 md/표 생성 커맨드.

### 10. EDD 성숙도 자가진단 `[ ]`
- **덱 근거**: §4 EDD 성숙도 Lv0–5, §5 도입 자가 점검 6문항.
- **현재**: 없음. `harness-audit`는 구성 PASS/FAIL만, EDD 성숙도 위치 진단 아님.
- **SC**:
  - [ ] 6문항 자가점검 → 현재 EDD 레벨과 "다음 행동" 출력하는 커맨드/스킬.

---

## 착수 순서 제안
1. **P1(1·2)** — 이미 있는 게이트의 신뢰성을 먼저 올린다(2렌즈·유형별 임계). 최소 변경, 최대 효과.
2. **P2(3·4·5)** — 골든셋을 만들면 4·5·6이 위에 얹힌다(덱: "하네스 없는 EDD는 측정할 파이프라인이 없다").
3. **P3(6·7·8)** — 골든셋 확보 후 CI 게이트 → 런타임 → 공격셋 순.

> 원칙(덱 §3): 한 번에 다 하지 말 것. 같은 실수 2회 = 규칙 후보. '반드시' 수준이면 요청 층이 아니라 보증 층(훅/게이트)으로 승격.
