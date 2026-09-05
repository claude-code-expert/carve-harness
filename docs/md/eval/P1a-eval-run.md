# P1a — target 어댑터 `eval-run.sh` + 실행 근거 보존 + `log_contains`

> 브랜치 `feat/eval-p1a-run`(P0 위) · 계획 `specs/eval-generalization-plan.md` §3 P1a · 설계 근거 `specs/promptfoo-eval-analysis.md` §4.1
> 결과: 케이스 실행(setup→응답→채점→근거)이 스크립트 한 개로 모였고 응답자가 명령으로 교체된다. 워크플로에서 채점 코드가 사라졌다. 테스트 21+9건, 전체 28 스위트 461건·감사 69 PASS.

## 1. 구성

```
.claude/hooks/eval-run.sh              setup | grade | run  (--target exec:<cmd> | claude)
.claude/hooks/eval-state.sh            + log_contains 상태 assert
.claude/hooks/carve-validate.sh        + log_contains 타입·형식 검증·--red 사전통과
.claude/workflows/carve-eval.js        Run 단계 = 스크립트 릴레이. 내장 gradeAssertions 삭제. ARGS.target. 근거 디렉토리 봉인
specs/eval-runs/run-<N>/<id>#<i>.json  응답 원문 + assert별 {type,value,pass,reason} (gitignore)
tests/eval-run.test.sh (21) · carve-eval.test.sh (9, 배선 검사로 재작성)
```

| 서브커맨드 | 계약 |
|---|---|
| `setup <gs> <id>` | mktemp 워크디렉토리에서 `setup` 실행(`CARVE_SRC` 기본 = 리포 루트). `{dir, setupExit}`. 실패해도 디렉토리는 남긴다(원인 검사) |
| `grade <gs> <id> <dir> [--output F] [--out DIR] [--label L] [--keep]` | 텍스트 assert(`contains/regex`, node JS 정규식 — node 없으면 regex는 **fail-closed**) + 상태 assert(`eval-state.sh --case`, 원본 파일에서 직접). `llm-rubric`은 `pendingRubric`으로 반환 → `green: null`. 근거 파일 기록. 기본은 워크디렉토리 삭제 |
| `run <gs> <id> --target T [--k N] [--out DIR] [--timeout S]` | k회: setup → target → grade. 집계 `{greens, pending, pass_at_k, pass_pow_k, caseScore, runs[]}` |

**target 계약**(promptfoo `exec:`와 동일): cwd = 워크디렉토리 · argv[1] = prompt · stdout = 응답 · `CLAUDE_PROJECT_DIR` = 워크디렉토리(setup이 복사한 훅이 있으면 그 로그가 워크디렉토리 `logs/`에 쌓인다).
- `exec:<cmd>` — 임의 명령. 테스트는 이 형태의 스텁으로 러너를 검증한다.
- `claude` — `claude -p "$prompt" --output-format text --permission-mode acceptEdits --allowedTools "Bash Read Write Edit MultiEdit Glob Grep"`. CLI 부재 → `{"error":"target-unavailable"}` exit 1.
- `session` — 스크립트가 아니라 워크플로가 응답(서브에이전트). setup·채점은 여전히 스크립트.

**`log_contains`** — `"<jsonl glob>::<jq 불리언 필터>"`. 워크디렉토리의 훅 로그 어느 한 줄이 필터를 만족하면 통과. 예: `logs/*.jsonl::.decision=="block" and .tool=="Write"`. promptfoo `trajectory:*` assert의 결정론 대체. 파싱 불가·빈 로그·`::` 없음은 전부 실패.

## 2. 워크플로 변화

| 전 | 후 |
|---|---|
| 에이전트가 `mktemp` + setup 실행 | `eval-run.sh setup` 릴레이(effort low) |
| 응답 텍스트를 JS `gradeAssertions`로 채점, 상태 assert는 별도 에이전트가 `eval-state.sh` 호출 + `rm -rf` | 응답 텍스트를 임시 파일에 옮기고 `eval-run.sh grade` 한 번(텍스트+상태+근거 파일+정리) |
| llm-rubric 전건을 evaluator에 | 결정론이 전부 통과한 실행의 pending rubric만 evaluator에 |
| 응답 원문 미보존 | `specs/eval-runs/current/` → 추이 append 후 `run-<N>`으로 봉인 |
| 응답자 고정(서브에이전트) | `ARGS.target`: `claude`·`exec:`면 `eval-run.sh run`이 k회 전부 처리 |

## 3. 사용방법

```bash
bash .claude/hooks/eval-run.sh setup specs/goldenset/starters/python.json python-bugfix-state-verified
bash .claude/hooks/eval-run.sh grade specs/goldenset/starters/python.json python-bugfix-state-verified /tmp/tmp.X --output out.txt --out specs/eval-runs/manual
bash .claude/hooks/eval-run.sh run specs/goldenset/starters/python.json python-bugfix-state-verified --target claude --k 3 --out specs/eval-runs/manual
bash .claude/hooks/eval-run.sh run specs/goldenset/harness-hard.json hard-empty-input-not-faked --target "exec:python3 my_agent.py"
jq '.asserts[] | select(.pass|not)' specs/eval-runs/run-5/python-bugfix-state-verified#1.json   # 왜 떨어졌나
```
워크플로: `/eval {target: "claude"}` — CI에서 `claude` CLI가 인증돼 있으면 추이 파일 읽기가 아니라 실채점이 돈다.

## 4. 완료 기준(SC) 검증

| SC | 증명 | 결과 |
|---|---|---|
| ① `exec:` 스텁 target으로 케이스 1건 end-to-end, assert별 pass/reason 파일 | `eval-run.test.sh` (5)(6): k=2 greens 2, 근거 2파일 | PASS |
| ② `claude` target은 CLI 부재 시 `unable` exit 1 | (10) — 이 머신엔 CLI가 있어 SKIP, 분기 코드는 `command -v` 게이트 | 부분(코드 경로 검토) |
| ③ `log_contains`로 `guard-*` 5건의 llm-rubric 신호를 결정론 대체 → `--red` WARN 0 | **미적용.** 세션 target에서는 훅 로그가 리포 `logs/`로 가서 워크디렉토리 `log_contains`가 못 본다. 타입·채점기·검증기는 완성(테스트 (8)(9)); `guard-*` 케이스 전환은 `claude` target으로 골든셋을 돌리는 시점(P1 게이트 확장)에 | 부분 |
| ④ 워크플로 결과 = 스크립트 결과 | 워크플로에서 채점 코드 삭제 — 같은 스크립트를 쓰므로 정의상 동일. `carve-eval.test.sh`가 배선 9건 고정 | PASS |
| 전체 | `npm test` 28 스위트 461건 · 감사 69 | PASS |

## 5. 한계

- 세션 target은 응답 텍스트가 에이전트 → 임시 파일 경유(재직렬화 1회). 점수·assert 값은 거치지 않는다.
- `claude` target의 권한 플래그(`--permission-mode acceptEdits`, `--allowedTools`)는 CLI 2.1.x 기준. CI 실측 전.
- 근거 디렉토리는 gitignore — 회귀 사후 분석은 로컬/CI 아티팩트로.
