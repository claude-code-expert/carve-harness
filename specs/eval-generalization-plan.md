# 평가 체계 범용화 계획 — 블루프린트 대조 갭 분석 + 개발 단계

> 상태: **계획(승인 대기)** · 작성 2026-09-05 · 기준 문서 `docs/md/harness-eval-gate-blueprint.md` v1.0
> 목표: 골든셋·Evaluator 검증·평가 게이트를 **언어 선택과 무관하게** 같은 스키마·같은 게이트로 돌린다.
> 원칙: 블루프린트 R2(한 단씩)·R5(증거)·R6(fail-closed)·R10(채점기부터 의심). AGENTS.md §4 외과적 변경.

## 0. 현황 판정 (블루프린트 §7.1 인벤토리 축약)

| 축 | 판정 | 근거 |
|---|---|---|
| 하네스 Lv | **Lv.4 + Lv.5 습관** | 훅 exit 2 · reviewer 분리(`evaluator` read-only) · HANDOFF/DECISIONS · 48 audit |
| Eval Lv | **LV2~3 사이** | 골든셋 20건 + 자동 채점(`carve-eval`) + CI 게이트(`eval-gate.yml`, report 모드). LV3 DoD(차단 + 극단점수·required 판정)는 미달 |
| 언어 범용성 | **부분** | 상태 assert·워크플로·게이트는 언어 무관. **정량 채점기(`eval-java.sh`)만 Java 전용**, 다른 스택은 pass/fail(`stop-verify`)뿐 = "정도를 모른다"(§5.1 ①) |

`specs/evaluator-feature-todo.md` §3의 상태 문장(“10/20건”, “run#3 실측 전”)은 실측(20건, run 4회)과 어긋난다 — 이 문서가 최신 상태다.

## 1. 갭 목록 (블루프린트 항목 ↔ 현재 구현)

| # | 블루프린트 | 현재 | 갭 | 우선 |
|---|---|---|---|---|
| G1 | §5.7 채점표 100점(G1 빌드 25·G2 테스트 25·G3 안전 15·린트 10·회귀 10·커버리지 5·antislop 10), 전부 명령 결과 | `eval-java.sh`(Java 전용, 가중 P 0..1, 다른 어휘) · 타 스택은 `stop-verify` pass/fail | **언어별 정량 점수 없음.** 스택 어댑터 + 공통 SCORE 스키마 필요 | P1 |
| G2 | R5·R10: 점수 파일은 증거. 채점기부터 의심 | `carve-eval.js`가 추이 파일 읽기/append를 **LLM 에이전트에게 위임** → 이번 패치에서 run1 유실·version 오기록 실제 발생 | 추이 읽기·append를 결정론 스크립트로. append-only를 기계 강제 | **P0** |
| G3 | §6.5 관문①: required 태그 1건 실패 → 실패 · 극단 점수(0%/100%) 경보 | `eval-gate.sh`는 suite 평균 delta만 | 케이스 `tags`(required·category) + required 실패 즉시 regressed + 극단점수 `suspicious` | P1 |
| G4 | R8: 프롬프트·CLAUDE.md 변경도 같은 게이트 | `eval-gate.yml` 트리거 = `specs/eval-score.json`·`specs/goldenset/**`만 | CLAUDE.md·`.claude/**` 변경 PR에 추이 갱신 없으면 `stale` 판정(block 모드 실패) | P1 |
| G5 | §5.5 유형별 허용 실패율(domain_safety 0%) | checklist 항목 단일 임계 95, 유형 없음(todo #2) | 항목 `type` + `domain_safety` 거부권 | P2 |
| G6 | §7.4 verify-blueprint(골든셋 ≥20·required·Stop 게이트·eval-gate 동작·3문항) · §5.12 Eval LV 판정 | `harness-audit` 48체크에 eval 항목 0건(AUDIT-08은 Java 배선만) | AUDIT-09 eval 절 + Eval LV/다음 한 단 출력(todo #10) | P2 |
| G7 | §6.1 SUCCESS-CRITERIA.md(기준/지시문/검사문 3줄) — Q1 "성공 기준이 문장으로 있는가" | 없음. 기준은 goldenset `llm-rubric` 값과 checklist `acceptance`에 흩어짐 | 템플릿 + `eval-init` 단계에서 작성 + audit 존재 검사 | P2 |
| G8 | §6.6 레드팀: 탐지율·차단율·과잉차단율 분리 측정 | `pretool-guard.test.sh`(회귀 테스트) — 비율·정상요청 대조 없음(todo #8) | 공격 40 + 정상 20 케이스, 훅 exit 코드로 **결정론** 채점 | P3 |
| G9 | §5.4 모델형 채점기는 사람 라벨 일치율 확인 후 사용 | `llm-rubric` {pass,reason}, 일치율 절차 없음(todo #4) | 절차 문서 + 케이스 `human_label` 선택 필드. 자동화 범위 밖 | P3(문서) |
| G10 | §6.5 관문②③(페어드 비교·카나리) | 없음 | 배포 파이프라인 없는 로컬 하네스 — **범위 밖** 명시 | — |

이미 충족(갭 아님): R1·R3·R4·R6·R7(8바퀴·3회 교착·역할 분리 `carve-verify-loop.js:19-20`)·§5.9 다섯 질문(5축)·§5.10 Stop 게이트(`checklist-gate`, tombstone으로 더 강함)·§6.2 양방향 검증(`--red`)·§6.7 채점기 의심(`carve-validate`)·트레이스 마이닝 절차.

## 2. 설계 결정 (승인 대상)

1. **공통 점수 스키마 = 블루프린트 §5.7 그대로.** `specs/SCORE.json` `{total, pass_line, gates:{G1,G2,G3}, items:{lint,regression,coverage,antislop}, skipped:[], verdict, evidence:{}, stack}`. G1~G3 중 0이면 total 무관 FAIL. 측정 불가 항목은 `skipped`에 명시하고 분모에서 제외(`eval-java.sh` 관례). 스택 미감지 → `verdict: unable`, exit 1(fail-closed).
2. **스택 표는 한 곳.** `.claude/hooks/lib-stacks.sh`(순수 데이터, `lib-protected.sh`와 같은 성격): 스택 id → 감지 마커 · build · test · lint · coverage 리포트 위치. 6스택(java·node·python·go·rust·bash). 새 스택 추가 = 이 파일에 1블록.
   - `stop-verify.sh`로의 이관은 **이번 범위에서 제외**(적대적 감사로 경화된 157줄 — 별도 PR, 테스트 동일 green 조건).
3. **`eval-java.sh`는 유지, Java 어댑터가 호출.** archunit·violations 같은 Java 고유 축은 어댑터가 `evidence`로 붙인다. 새 어휘를 만들지 않는다.
4. **추이 파일은 스크립트만 쓴다.** `eval-trend.sh read|append` — VERSION 직접 읽기, run 서수 = 기존 길이+1, 기존 run 해시 불변 검사(변조 시 exit 1). 워크플로의 `read-baseline`·`persist-trend` 에이전트는 이 스크립트 호출로 대체.
5. **게이트 판정은 여전히 LLM 무관.** `eval-gate.sh` 확장(required·suspicious·stale)도 jq만.
6. 골든셋 `tags` 필드는 **선택**(하위호환). `carve-validate`가 required 0건이면 WARN, `--strict`면 ERROR. assert `metric`·`weight`, 케이스 `threshold`도 같은 방식 — 필드명은 promptfoo와 동일하게 두어 exporter가 1:1 매핑.
7. **응답자(target)는 명령이다.** promptfoo `exec:` 계약(cwd·argv·stdout)을 따르는 어댑터 뒤에 두고, 워크플로 서브에이전트·`claude -p`·임의 명령을 교체 가능하게 한다. CI 실채점은 `claude -p` 어댑터로만 — 게이트 판정은 여전히 jq.
8. promptfoo 엔진 채택은 기각(의존성·과금·결정론 원칙). exporter는 P3 옵트인.

## 3. 개발 단계 (한 단씩 · 각 단계 SC로 완료 증명)

| 단계 | 산출물 | 완료 기준(SC) — 명령으로 증명 |
|---|---|---|
| **P0 추이 무결성** ✅ 2026-09-06 (`docs/md/eval/P0-eval-trend.md`) | `.claude/hooks/eval-trend.sh` · `carve-eval.js` 2개 에이전트 호출 교체 · `tests/eval-trend.test.sh` | ① 기존 run 1바이트 변조 후 `append` → exit 1 ② `append`가 VERSION을 파일에서 읽어 기록(에이전트 입력 무시) ③ run 서수 = length+1 ④ `read`가 `{runs,lastSuiteScore,version,lastCaseVersions}` 그대로 출력 ⑤ 21→22 스위트 green |
| **P1a target 어댑터 + 근거 보존** ✅ 2026-09-06 (`docs/md/eval/P1a-eval-run.md`; SC③은 세션 target 한계로 부분) | `.claude/hooks/eval-run.sh`(setup→target→채점→정리, target = `session`/`claude -p`/`exec:<cmd>`, 계약: cwd=워크디렉토리·argv[1]=prompt·stdout=응답) · `specs/eval-runs/<run>/<case>#<i>.json` · 상태 assert `log_contains` · `carve-eval.js`는 오케스트레이션만 | ① `exec:` 스텁 target으로 케이스 1건 end-to-end 채점, assert별 pass/reason 파일 생성 ② `claude -p` target은 CLI 부재 시 `unable` exit 1 ③ `log_contains`로 `guard-*` 5건의 llm-rubric 신호를 결정론 대체 → `--red` WARN 0건 ④ 워크플로 결과와 스크립트 결과 동일(기존 20건 재채점 비교) |
| **P1 스택 표 + 범용 채점기** | `lib-stacks.sh` · `eval-score.sh` · `tests/eval-score-generic.test.sh`(스택별 픽스처, PATH 스텁으로 툴체인 없이) | ① 6스택 픽스처 각각 `SCORE.json` 생성, `total`·`verdict` 일치 ② 빌드 실패 픽스처 → G1=0·verdict FAIL(나머지 만점이어도) ③ 커버리지 리포트 없음 → `skipped:["coverage"]`·분모 제외 ④ 미감지 디렉토리 → `unable` exit 1 ⑤ Java 픽스처는 `eval-java.sh` 호출 경로 사용(중복 구현 0) |
| **P1 게이트 확장** | `eval-gate.sh`(`--changed <file>`·required·suspicious) · 골든셋 `tags` · `carve-validate.sh`(tags 검증, `--strict`) · `eval-gate.yml` 트리거 경로 | ① required 케이스 caseScore 하락 → 평균 무관 `regressed` ② 전 케이스 0 또는 100 → `suspicious`(block 모드 exit 1) ③ `--changed` 목록에 CLAUDE.md 있고 추이 미갱신 → `stale` ④ 기존 eval-init 스위트 green 유지 |
| **P2 유형별 거부권** | `checklist-gate.sh` `type` 처리 · `checklist-loop` SKILL · `carve-verify-loop.js` 스키마 | ① `type: domain_safety` 항목 score 94 → 총점 무관 exit 2 ② `type` 없는 기존 checklist.json 동작 불변 |
| **P2 감사 + 성숙도** | `harness-audit.sh` AUDIT-09(≥6체크) · Eval LV 출력 | ① 골든셋 없는 픽스처 → LV0 + "다음 한 단" 문구 ② 이 리포 → LV3 판정 ③ 48→54+ PASS ④ `eval-gate` 스텁 판정 4종(missing→unable, 89→regressed, 95→ok, suspicious) 실행 검증 |
| **P2 SUCCESS-CRITERIA** | `specs/SUCCESS-CRITERIA.md` 템플릿 · `eval-init` S2.5 · audit 검사 | ① 템플릿에 기준/지시문/검사문 3줄 형식 ② 이 리포용 실물 5항목(골든셋 4 suite 대응) ③ audit "Q1 성공 기준 문장" PASS |
| **P3 레드팀** | `specs/redteam/*.json`(공격 40·정상 20) · `.claude/hooks/redteam.sh` | ① 탐지율·차단율·과잉차단율 3수치 JSON ② 정상 20건 exit 0(과잉차단 0) ③ LLM 호출 0회 |
| **P3 promptfoo exporter**(옵트인) | `.claude/hooks/eval-export.sh --promptfoo` → `evals/promptfooconfig.yaml` + `eval_state.py` 브리지 | ① 20건 변환 결과가 `npx promptfoo validate config` 통과(node 있을 때만, 없으면 SKIP) ② 상태 assert가 `python:` assert로 eval-state.sh 호출 ③ 정본은 goldenset JSON — 역방향 없음 |
| **P3 문서** | README ko/en · GUIDE · `eval-goldenset` SKILL · `evaluator-feature-todo.md` 상태 동기 · `docs/evaluator/`에 node 예시 1종 | 수치(훅·스위트·체크 수) = 실측. `version-changelog`는 릴리스 시점 |

순서: P0 → P1a(어댑터) → P1(채점기) → P1(게이트) → P2 → P3. 각 단계 PR 1개, 머지 후 다음 단계.

## 4. 범위 밖

- 관문②③(페어드 비교·카나리) — 배포 파이프라인 부재.
- `stop-verify.sh`의 `lib-stacks` 이관 — 별도 PR.
- LLM-judge 사람 일치율 자동화 — 라벨 데이터 필요, 절차 문서만.
- 골든셋 자동 확정 — 기존 결정(2026-08-06) 유지.

## 5. 리스크

| 리스크 | 대응 |
|---|---|
| 스택 어댑터가 각 툴체인 없는 CI에서 테스트 불가 | 픽스처는 PATH 앞에 스텁 실행파일(`gradlew`·`pytest`…)을 두고 exit·리포트만 흉내 — 채점 로직만 검증 |
| 채점기 2개 어휘 공존(eval-java P vs SCORE 100점) 혼란 | SCORE.json이 정본, eval-java는 어댑터 내부 값. GUIDE에 1줄 명시 |
| `tags` 도입으로 기존 케이스 전부 수정 유혹 | 선택 필드. 이 리포는 `harness-guard` 5건만 `required`로 시작 |
| 추이 파일 해시 검사가 사람의 정당한 수정(오늘의 version 정정)을 막음 | `append --allow-rewrite` 없음. 사람 수정은 스크립트 밖(직접 편집)이 정상 경로, DECISIONS에 기록 |

## 6. 선행 정리(이번 패치에서 발견, 이 계획과 별개)

- `specs/eval-score.json` run1 복원 + run2~4 `version` 0.6.0→0.8.0 정정(2026-09-05, 미커밋). DECISIONS 기록 권장.
- 문서 수치 불일치: README ko/en 317행(14+20), 테스트 326→325, `evaluator-feature-todo.md` §3 상태.
- 골든셋 5건의 `CARVE_SRC` 폴백 절대경로(`/Users/mini/...`) — 타 머신 `--red` 실패 지점.
