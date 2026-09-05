# LP5 — 감사(AUDIT-09) · 스킬 연동 · 문서 동기화

> 브랜치 `feat/lp5-audit-docs`(LP4 위) · 계획 `specs/language-pack-plan.md` §3 LP5
> 결과: `harness-audit` AUDIT-09(언어팩 무결성 + Eval 성숙도 안내, 이 리포 67 PASS), `/carve-harness-create`·`/eval-init` 팩 연동, README ko/en·GUIDE·HARNESS_GUIDE 수치 실측 동기. 전체 26 스위트 419건 PASS.

## 1. 구성

| 요소 | 변경 |
|---|---|
| `.claude/hooks/harness-audit.sh` AUDIT-09 | 설치 팩(`.claude/harness-packs`, 소스 리포는 전체)마다 ① 경로 전부 실재(`pack_check`) ② 스택 파일 `bash -n` + `stack_gate` 정의 ③ 골든셋 스타터 `carve-validate` 통과 ④ LSP 토글 = 설치 기록(설치본만). 끝에 `INFO: eval maturity LV0~3 — 다음 한 단` 한 줄(블루프린트 §5.12, FAIL 아님). `packs/` 없는 구설치본은 절 자체 스킵 |
| `tests/harness-audit.test.sh` +4 | 완전한 python 팩 → PASS · 스택 파일 삭제 → FAIL(경로명 표시) · LSP off → FAIL · 성숙도 줄 존재 |
| `/carve-harness-create` SKILL §4·§7 | 스택 게이트 표(경로 하드코딩) 제거 → `install.sh pack list` 대조로 **add/remove 제안**. 팩 경로는 keep-list에서 손대지 않는다(반쪽 팩 = AUDIT-09 FAIL). eval-java↔archunit 간선은 팩 내부라 자동 해결 |
| `/eval-init` SKILL S1·S4 | S1이 `.claude/stacks/<pack>.sh`의 `STACK_TEST_CMD_HINT`·`STACK_COVERAGE_MIN`을 읽고, S4 초안이 `specs/goldenset/starters/<lang>.json`을 시드로 복사(id 접두, 스타터 원본 불변) |
| README ko/en | 특징 표 "언어팩" 행, 구성 요소 수치(훅 17·스택 6·팩 6·규칙 11·상세본 10·스타터 20·26 스위트 419건), 설치 절 언어팩 선택, 사용법 표(`pack`·`eval-score`), 훅 표(`eval-score`·`lib-packs`), 구조 트리 |
| GUIDE | 훅 표 3행(`eval-score.sh`·`lib-packs.sh`·`.claude/stacks/`), 감사 설명, 디렉토리 트리(stacks·packs·starters·rules 3종), §8.2는 LP1에서 갱신 |
| HARNESS_GUIDE | "언어팩 선택 설치 + 맞춤 절단" 문단 |
| specs | `evaluator-feature-todo.md` §3 실측 동기(20+20건, run 4회) · `language-pack-plan.md` 상태 완료 |

## 2. 사용방법

```bash
bash .claude/hooks/harness-audit.sh | grep -E 'AUDIT-09|INFO'   # 팩 무결성 + Eval LV
bash install.sh pack list                                        # 감사가 FAIL 낸 팩의 누락 경로 복구 힌트
# 스킬: /carve-harness-create → 팩 add/remove 제안 · /eval-init → 스타터 시드
```

## 3. 완료 기준(SC) 검증

| SC | 증명 | 결과 |
|---|---|---|
| ① 팩 파일 1개 삭제 → AUDIT-09 FAIL 1건, 복구 → PASS | `harness-audit.test.sh` (15) | PASS |
| ② 스킬 참조 경로 실재 | `eval-init.test.sh` 20 · `carve-harness-create.test.sh` 15 green | PASS |
| ③ 문서 수치 = 실측 | 훅 `ls` 17 · 스위트 26 · `npm test` 419 · 감사 67 · 규칙 11 · 상세본 10 | PASS |
| ④ 릴리스 항목 | 릴리스는 사용자 결정 — `version-changelog`는 머지 후 릴리스 시점에 (VERSION 변경 없음) | 보류 |
| 전체 | `npm test` ALL SUITES PASSED · 감사 67/67 | PASS |

## 4. 남은 것 (이번 범위 밖 — 후속 계획 `eval-generalization-plan.md`)

- P0 `eval-trend.sh`(추이 파일 결정론 append), P1a target 어댑터(`eval-run.sh`), P1 게이트 확장(required·suspicious·stale), P3 레드팀·promptfoo exporter.
- antislop 결정론 검사기(eval-score 10점 항목 활성화).
- Java·Go 스타터 정답 증명은 CI(ubuntu-latest, JDK·Go 탑재)에서 첫 확인 — 로컬 런타임 부재로 SKIP.
