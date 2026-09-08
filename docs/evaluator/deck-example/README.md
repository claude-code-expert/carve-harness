# deck-example — 발표자료 기준 Evaluator 참조 구현

세미나 자료 *「바이브 코딩에서 검증된 코딩으로 — 하네스 엔지니어링과 Evaluator 제어」* 에서
설명하는 채점 모델을 **실제로 돌아가는 코드**로 옮긴 것이다. 슬라이드의 숫자와 코드의 숫자가
같도록 맞췄고, 테스트가 그 일치를 검증한다.

기존 `java-example` · `python-example` 은 **LLM-Judge 한 층**의 샘플이다.
이 디렉토리는 그 위에 **채점표 전체(결정론 채점 + 5축 루브릭 + 게이트 판정)** 를 보여준다.
둘은 대체 관계가 아니다.

## 실행

의존성이 없다. 빌드 도구도, 테스트 프레임워크도, API 키도 필요 없다.

```bash
cd java   && java ScoreCardTest.java      # JDK 11+ 단일 파일 실행
cd python && python3 test_scorecard.py    # 표준 라이브러리만
```

둘 다 실패가 있으면 **exit 1** 로 끝난다. CI 게이트에 그대로 걸 수 있다.

## 구성

| 파일 | 역할 |
|---|---|
| `goldenset/coupon-api.json` | 발표자료 워크스루의 그 케이스. 항목 4개, 합격선 95 |
| `{java,python}/ScoreCard` | 빌드 건강도 채점표 — 100점 만점, G1~G3 거부권 |
| `{java,python}/RubricJudge` | 5축 루브릭 — exists·match·test·contract·no_regress |
| `{java,python}/ScoreCardTest` | **채점기를 채점하는 테스트** |

## 슬라이드 ↔ 코드 대응

| 슬라이드 | 개념 | 구현 |
|---|---|---|
| 66~68 | 100점 만점 · 90점 합격 | `ScoreCard.WEIGHTS` (합 100), `PASS_RATIO = 0.9` |
| 66~68 | G1·G2·G3 거부권 | `ScoreCard.VETO_ITEMS` — 하나라도 0이면 총점 무관 FAIL |
| 66 | 못 잰 항목은 `skipped`, 분모에서 제외 | `Measurement.value == null` → `skipped`, `max` 축소 |
| 62~64 | 결정론 층을 먼저 두껍게 | `ScoreCard` 는 LLM 을 호출하지 않는다 |
| 68 | 5축 루브릭, 임계 95 | `RubricJudge.AXES`, `DEFAULT_THRESHOLD` |
| 72~73 | 거짓 완료 차단 | `test` 축은 실행 출력으로만 채움 → 미실행 시 상한 75 |
| 74~75 | 쿠폰 API 워크스루 | 테스트가 `97/70/92/100` → `97/96/97/100` 을 재현 |
| 75 | 통과 항목은 건드리지 않는다 | `loopStatus().rework` 에 미달 항목만 |
| 87 | 채점기부터 의심 | 채점기 버그 재현 테스트 (`96.12` vs `96.120`) |
| 87 | 극단 점수는 경보 | `alarm()` — 전원 0% / 전원 100% 판정 |

## 설계에서 눈여겨볼 세 가지

### 1. 거부권은 한 줄이다

```java
boolean veto = items.get("g1_build") == 0 || items.get("g2_test") == 0 || items.get("g3_safety") == 0;
verdict = veto ? FAIL : (total / max >= 0.9 ? PASS : FAIL);
```

총점 85점이어도 안전 항목이 0이면 실패다. "거의 다 됐다"를 산술적으로 없애는 자리다.

### 2. `test` 축이 거짓 완료를 막는다

`test` 는 실행 출력에서만 채워진다. 테스트를 돌리지 않으면 0점이고,
나머지 네 축을 만점 받아도 **합이 75** 라 임계 95를 넘을 수 없다.

게이트에 "테스트를 돌렸는지 확인하라"는 규칙을 따로 넣지 않아도 **배점 자체가 막는다.**
규칙을 늘리는 대신 구조로 강제하는 예다.

### 3. 못 잰 것과 나쁜 것은 다르다

커버리지 리포트가 없을 때 0점을 주면 억울한 감점이 되고, 만점을 주면 조용한 통과가 된다.
그래서 **분모에서 뺀다**. `skipped` 목록에 남으므로 무엇을 못 쟀는지도 드러난다.

```
전 항목 측정  → 100/100 PASS
커버리지 없음 →  95/95  PASS   (coverage 는 skipped)
아무것도 없음 →   0/0   UNABLE (PASS 아님 — fail-closed)
```

## 자기 프로젝트에 옮기는 법

1. `goldenset/coupon-api.json` 을 복사해 **자기 도메인의 케이스**로 바꾼다.
   케이스는 사람이 검수한다 — 에이전트가 만들면 자기가 통과하는 것만 담는다.
2. `Measurement.fromExitCode(...)` 에 자기 툴체인 명령을 연결한다
   (`gradle test`, `pytest`, `npm run build` 등).
3. 못 돌리는 항목은 **`null` 을 넘겨** `skipped` 로 보낸다. 0점으로 깎지 않는다.
4. 루프는 `loopStatus()` 가 `RELEASED` 를 돌려줄 때까지 미달 항목만 재작업한다.

정량 평가 파이프라인 전체(`/eval`, 골든셋 추이, 회귀 게이트)는
저장소 루트의 `README.md` 와 `docs/md/verify-loop-guide.md` 를 참고한다.
