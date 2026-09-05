# LP4 — 범용 채점기 `eval-score.sh` (블루프린트 §5.7 채점표)

> 브랜치 `feat/lp4-eval-score`(LP3 위) · 계획 `specs/language-pack-plan.md` §3 LP4 · `eval-generalization-plan.md` P1(채점기)
> 결과: 언어 무관 `SCORE.json` 채점기. 점수는 전부 명령 종료코드·리포트 파일에서만 나온다(LLM 0). 스택 어댑터 5종, 테스트 22건, 전체 27 스위트 415건·감사 51 PASS.

## 1. 구성

```
.claude/hooks/eval-score.sh              오케스트레이터: 스택 감지 → 어댑터 호출 → 채점표 → specs/SCORE.json
.claude/stacks/<pack>.sh                 어댑터 함수 추가: stack_detect · stack_build · stack_test · stack_lint · stack_coverage · STACK_COVERAGE_MIN · STACK_TEST_CMD_HINT
.claude/hooks/tests/eval-score-generic.test.sh   22건 (PATH 스텁 — 툴체인 불필요)
```

채점표(스택당, 블루프린트 §5.7 그대로):

| 항목 | 배점 | 판정 | 측정 불가 시 |
|---|---|---|---|
| **G1 빌드/타입** | 25 | `stack_build` rc 0 | `skipped`(예: tsconfig 없는 JS) |
| **G2 테스트** | 25 | `stack_test` rc 0 × k회 전부 | `skipped`(러너 없음). 테스트 0건은 통과(pytest exit 5·go "no test files") |
| **G3 안전** | 15 | 변경분(추적 diff 추가 줄 + 미추적 파일)에 시크릿 리터럴 0 · 보호 경로 미변경 | git 없으면 트리 전체 스캔 |
| lint | 10 | `stack_lint` rc 0 | `skipped`(도구 없음) |
| regression | 10 | G2 통과 AND 테스트 파일 삭제 0 | G2 skipped면 skipped |
| coverage | 5 | `stack_coverage` ≥ `STACK_COVERAGE_MIN`(80) | `skipped`(리포트/도구 없음) |
| antislop | 10 | 결정론 검사기 미출시 → **항상 skipped** | — |

- G1~G3 중 하나라도 0이면 총점 무관 **FAIL**(거부권). 빌드 실패 시 G2·lint·coverage는 실행하지 않는다(eval-java 관례).
- `skipped` 항목은 분모(`max`)에서 빠진다. verdict PASS = 거부권 없음 AND `total/max ≥ 0.9`. 숨은 통과 없음 — 못 잰 건 전부 이름으로 남는다.
- 다중 스택(백엔드+프론트): 스택마다 채점, verdict는 AND, `total`은 min.
- 출력: `{pass_line, total, max, verdict, stacks:{<name>:{gates, items, skipped, evidence, verdict}}}` → `specs/SCORE.json` + stderr 한 줄 요약.

어댑터별 실제 명령:

| 스택 | build | test | lint | coverage |
|---|---|---|---|---|
| python | `python3 -m compileall -q .` | `pytest -q`(exit 5 허용) | `ruff check .` | `pytest --cov --cov-report=json`(pytest-cov 있을 때) |
| typescript | `tsc --noEmit`(tsconfig 있을 때) | `scripts.test` | `scripts.lint` | `coverage/coverage-summary.json` 읽기만(직접 실행 안 함) |
| java-spring | `./gradlew compileJava -q` | `./gradlew test -q` | `./gradlew spotlessCheck -q`(태스크 없으면 skip) | **`eval-java.sh` 위임**(JaCoCo XML 파서 재사용) |
| go | `go build ./...` | `go test ./...` | `go vet ./...` | `go test -coverprofile` + `go tool cover -func` |
| rust | `cargo check -q` | `cargo test -q` | `cargo clippy -D warnings`(clippy 있을 때) | `cargo llvm-cov --json`(있을 때) |

## 2. 사용방법

```bash
bash .claude/hooks/eval-score.sh                  # 감지된 스택 전부, specs/SCORE.json 기록 + 요약
bash .claude/hooks/eval-score.sh --stack go --k 3 # 한 스택, 테스트 3회(전부 통과해야 G2)
bash .claude/hooks/eval-score.sh --json --out /tmp/score.json
jq '.stacks.python.skipped' specs/SCORE.json      # 무엇을 못 쟀는지
```

이 리포 자체(`package.json`이 npm test 래퍼)에 돌리면: typescript 스택 감지 → G1·lint·coverage skipped, G2=25(npm test) G3=15 regression=10 → 50/50 PASS. 못 잰 항목이 그대로 보인다.

## 3. 완료 기준(SC) 검증 — `eval-score-generic.test.sh`

| SC | 검증 | 결과 |
|---|---|---|
| ① 스택 픽스처에서 SCORE.json 생성, total·verdict 일치 | (2) go 스텁 → PASS 90/90, 파일 존재 | PASS |
| ② 빌드 실패 → G1=0·FAIL, 나머지 만점이어도 | (3) | PASS |
| ③ 커버리지 없음 → `skipped`, 분모 제외 | (10) python: pytest·ruff 없는 PATH → G2·lint·coverage skipped, G1=25 | PASS |
| ④ 미감지 → `unable` exit 1, 파일 미생성 | (9) | PASS |
| ⑤ Java는 `eval-java.sh` 경로 사용(중복 구현 0) | (12) 스텁 gradlew + JaCoCo XML 90% → coverage 5 | PASS |
| 추가 | 테스트 실패 거부권·커버리지 하한·lint 산술·시크릿 G3 거부권·테스트 파일 삭제 regression·`--k` 플레이키·다중 스택 min/AND·`--stack`·결정성 | (4)~(8)(11)(13) | PASS |
| 전체 | `npm test` 27 스위트 415건 · 감사 51(+1: eval-score +x) | ALL SUITES PASSED |

## 4. 알려진 한계

- antislop은 항상 skipped — 결정론 검사기가 아직 없다(anti-ai-slop 스킬은 프로즈 게이트). 검사기가 생기면 10점 항목이 살아난다.
- Java coverage는 `eval-java.sh`가 compile+test를 다시 돌린다(중복 실행). 느리면 XML 직접 파싱으로 교체(`# ponytail:` 주석).
- TS coverage는 프로젝트가 `coverage-summary.json`을 남겼을 때만 읽는다(직접 실행 안 함 — 설정 의존).
- 사고: 새 스위트를 기존 `eval-score.test.sh`(verify-loop 5축 헬퍼 테스트) 이름으로 덮어썼다가 git에서 복구하고 `eval-score-generic.test.sh`로 분리했다. 기존 파일 무손실.
