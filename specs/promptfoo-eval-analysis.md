# promptfoo 대조 분석 — carve-harness 평가 체계의 범용화 방향

> 작성 2026-09-05 · 대상 https://github.com/promptfoo/promptfoo (문서 promptfoo.dev, Claude Code 플러그인 `promptfoo-evals` 스킬 포함)
> 목적: Evaluator-Driven Development(EDD) 워크플로를 언어·도구에 덜 묶인 형태로 carve-harness에 얹기 위해, 업계 표준 도구의 설계를 우리 구현과 항목별로 대조하고 패치 방향을 정한다.
> 선행 문서: `specs/eval-generalization-plan.md`(블루프린트 대조 갭·단계) — 이 리포트는 그 계획의 P1을 수정한다(§5).

## 1. 한 줄 결론

가장 큰 범용성 병목은 **assert 어휘가 아니라 응답자(target) 결합**이다. promptfoo는 target·cases·grader를 세 역할로 분리해 어떤 명령(`exec:`)·에이전트(`anthropic:claude-agent-sdk`)든 같은 케이스로 채점한다. carve-eval은 응답자가 "대화형 Claude Code 워크플로 안의 서브에이전트"로 고정돼 있어 CI에서 실제 채점을 못 하고 추이 파일만 읽는다. **promptfoo를 엔진으로 들이지 않고**(의존성·과금·결정론 원칙 충돌) 그 역할 분리와 스키마를 bash/jq 엔진에 이식한다. 옵트인 exporter로 promptfoo 뷰어·CI 액션과 연결한다.

## 2. promptfoo 구조 요약 (우리 개념으로 번역)

| promptfoo | 뜻 | carve-harness 대응 |
|---|---|---|
| `providers` (target) | 평가 대상. LLM·`exec: cmd`·`file://x.py`·`http`·**`anthropic:claude-agent-sdk`**(= Claude Code, `working_dir`·`permission_mode`·`append_allowed_tools`·`setting_sources:['project']`로 훅 로드) | `carve-eval.js`의 `agent(prompt,{agentType:'general-purpose'})` 고정. **추상화 없음** |
| `tests[]` (`vars`·`assert`·`metadata`·`threshold`·`options.transform`) | 케이스 | `specs/goldenset/*.json` `cases[]`(`prompt`·`setup`·`k`·`version`·`assert`) |
| 결정론 assert 30여 종 + `javascript/python` 커스텀 + `not-` 접두 | 코드형 채점 | `contains/not_contains/regex/not_regex` + 상태 4종(`file_exists`·`file_contains`·`cmd_exit0`·`git_diff_contains`) |
| `trajectory:tool-used / tool-sequence / tool-args-match` | 에이전트 **경로** 채점(`metadata.toolCalls`) | 없음. 우회 여부는 `llm-rubric`에 의존(`--red` WARN 3건이 정확히 이 지점) |
| `llm-rubric`(`provider` 오버라이드·`rubricPrompt`·score 0~1·`threshold`: pass **AND** score≥th) | 모델형 채점 | `evaluator` 에이전트 `{pass,reason}`. 점수·임계·채점자 지정 없음 |
| `weight`·`metric`·`assert-set(threshold)`·`namedScores`·`derivedMetrics` | 가중·항목명·집계 | 없음. green = 전부 통과. 유형별 정책(convention/correctness/domain_safety) 표현 불가 |
| `evaluateOptions.repeat`·`--no-cache` | 반복(k) / 캐시 무효 | `k`(상한 10) — 캐시 없음이라 문제 없음 |
| `extensions: beforeAll/beforeEach/afterEach` | 픽스처 | `setup` + 워크플로의 `rm -rf` 정리 |
| 출력 JSON `results[].componentResults[]`(assert별 pass/score/reason)·`stats`·JUnit XML | 근거 보존 | `eval-score.json`에 caseScore + 실패 샘플 2건뿐. **assert별 결과·응답 원문 미보존**(블루프린트 R10 "트랜스크립트 읽기 전 점수 불신" 불가) |
| `--filter-metadata k=v`·`--filter-failing`·`--filter-pattern` | 부분 실행 | goldenset glob만 |
| exit 100(실패 케이스 존재/합격률 미달)·GitHub Action(`prompts/**` 변경 PR마다 실행·`fail-on-threshold`) | CI 게이트 | `eval-gate.yml`이 추이 파일만 판정. **CI에서 채점 자체가 안 돎** |
| `redteam`: plugins(공격 생성) × strategies(포장) · 별도 공격 provider · 카테고리·심각도 리포트 | 가드레일 시험 | 없음(수동 적대 감사 34건, `pretool-guard.test.sh` 회귀 테스트) |
| `promptfoo validate config`·`generate assertions/dataset` | 프리플라이트·초안 | `carve-validate.sh`(+`--red`) · `/eval-init` S4 |
| 플러그인 스킬 `promptfoo-evals` 규칙: "Prefer deterministic assertions first", rubric은 "sparingly", 근거 자료를 `{{var}}`로 rubric에 인라인, 실패 사례에서 케이스 추가 | 작성 SOP | `eval-goldenset` 스킬과 동일 원칙 — **방향 확인됨** |

우리에게만 있는 것(유지·강화): 상태 assert가 1급 시민(promptfoo는 커스텀 스크립트로 우회), 리포 밖 격리 워크디렉토리, `--red` NO-SIGNAL 탐지, `version`/`caseVersion` 비교 가능성, 채점(LLM)과 강제(jq) 분리, Stop 게이트 tombstone. 그리고 **빌드 건강도 채점(SCORE.json, 계획 P1)** — promptfoo는 LLM 출력을 채점하지 코드베이스 상태를 채점하지 않는다. 이게 코딩 하네스의 차별점이다.

## 3. 엔진 선택 — 세 안

| 안 | 내용 | 판정 |
|---|---|---|
| A. promptfoo 채택 | `anthropic:claude-agent-sdk` provider + 상태 assert를 `python:`/`exec:`로 래핑 | **기각.** Node 22+·npm 의존(하네스는 bash/jq 무의존), SDK provider는 API 키 과금(Claude Code 구독과 별도), 기본 채점자가 외부 모델 자격증명에 좌우, 캐시가 파일 해시+프롬프트 기준이라 k회 반복 시 `--no-cache` 필수. 결정론 게이트 원칙과 어긋남 |
| B. 설계 이식 | 역할 분리(target 어댑터)·스키마(`tags`/`metric`/`weight`/`threshold`)·assert별 결과 보존·trajectory assert·레드팀 구조를 bash/jq로 | **채택.** `specs/eval-generalization-plan.md` 단계에 삽입 |
| C. 브리지 | goldenset → `promptfooconfig.yaml` exporter(jq 100줄 내외). 뷰어·GitHub Action·redteam을 원하는 팀만 옵트인 | **P3 옵트인.** 정본은 계속 goldenset JSON. 매핑: `prompt`→`vars`, 텍스트 assert→네이티브, 상태 assert→`python: file://eval_state.py`(eval-state.sh 호출), `setup`→`beforeEach`, `k`→`repeat`, provider→`anthropic:claude-agent-sdk`(`working_dir`=임시, `setting_sources:['project']`) |

## 4. 패치 방향 (promptfoo에서 가져올 것 / 안 가져올 것)

### 4.1 가져온다

1. **target 어댑터** — `eval-run.sh <goldenset> <case-id> [--target <spec>] [--k N]`. 케이스 1건의 setup → target → 채점 → 정리를 한 스크립트가 맡는다. target 계약은 promptfoo `exec:`와 같게: **cwd=워크디렉토리, argv[1]=prompt, stdout=응답 텍스트**.
   - `session`(기본): 현재처럼 워크플로 서브에이전트가 응답(워크플로가 이 스크립트를 setup/grade 단계로 호출).
   - `claude -p` 헤드리스: `claude -p "$prompt" --cwd "$W" --allowedTools ...` — **CI에서 실채점 가능**해지는 지점.
   - `exec:<cmd>`: 임의 명령(다른 에이전트·스텁·회귀 픽스처).
   → `carve-eval.js`는 오케스트레이션(k 병렬·집계)만 남는다. 언어는 target·setup·`cmd_exit0` 안에서만 나타나므로 러너는 언어 무관.
2. **케이스 필드**: `tags:[]`(`required`·`category:convention|correctness|domain_safety`), assert `metric`·`weight`, 케이스 `threshold`. 게이트 정책(유형별 허용 실패율·required 즉시 실패)은 이 필드로만 판정.
3. **assert별 결과 + 응답 원문 보존**: `specs/eval-runs/<run>/<case>#<i>.json` `{output, asserts:[{type,value,pass,reason}], target, durationMs}`. `eval-score.json`은 집계만. 블루프린트 §6.7 "채점기→문항→에이전트" 순 의심이 파일로 가능해진다.
4. **trajectory 채점의 결정론 대체**: 우리 훅이 이미 JSONL 판정을 남기므로 상태 assert `log_contains`(`<jsonl 경로>::<jq 필터>`)를 추가하고 target 실행 시 `CLAUDE_PROJECT_DIR=$W`로 로그를 워크디렉토리에 떨군다. `guard-*` 케이스의 "우회하지 않았다"를 `llm-rubric`이 아니라 `decision=="block"` 기록 존재로 채점. `--red` WARN 3건 해소.
5. **llm-rubric 구조화**: `{pass, score(0~1), reason}` + 케이스 `threshold`(pass AND score≥th) + `grader` 지정(에이전트/모델). rubric 값에 setup 산출물이나 기대치를 인라인(할루시네이션 탐지).
6. **부분 실행**: `/eval {filter:"tag=required"}`·`{failing:true}`(직전 run 실패만).
7. **레드팀 구조**: 공격 케이스(plugins) × 포장 전략(strategies: `env VAR=`·`sudo`·`base64`·변수 간접) 매트릭스를 `specs/redteam/*.json`으로, 채점은 `pretool-guard.sh` exit 코드(0/2)로 결정론. 탐지율·차단율·과잉차단율 3수치.
8. **exporter**(옵트인, §3 C).

### 4.2 가져오지 않는다

웹 뷰어·클라우드 공유, 유사도 메트릭(bleu/rouge/levenshtein), RAG assert(context-*), 합성 케이스 자동 확정(`generate dataset` — 2026-08-06 결정 유지), 외부 모델 기본 채점자.

## 5. `eval-generalization-plan.md` 반영 (수정 사항)

- **P1 앞에 P1a 삽입**: `eval-run.sh` target 어댑터 + `specs/eval-runs/` 보존 + `log_contains` assert. 이게 없으면 P1 게이트 확장(required·stale)이 CI에서 실채점 없이 반쪽이다.
- P1 게이트 확장의 `tags`에 `metric`·`weight`·`threshold` 추가(promptfoo 호환 필드명 채택 — exporter가 1:1 매핑).
- P3에 exporter 추가.
- 스택 표(`lib-stacks.sh`)·SCORE.json은 그대로. promptfoo에 없는 우리 몫.

## 6. 근거 링크

- 리포: https://github.com/promptfoo/promptfoo · provider 목록 /docs/providers/ · `anthropic:claude-agent-sdk` /docs/providers/claude-agent-sdk/
- assert 레퍼런스 /docs/configuration/expected-outputs/ · 모델 채점 /docs/configuration/expected-outputs/model-graded/
- CLI(`--repeat`·`--filter-*`·exit 100) /docs/usage/command-line/ · 출력 JSON /docs/configuration/outputs/
- CI 액션 https://github.com/promptfoo/promptfoo-action · 레드팀 /docs/red-team/quickstart/
- 작성 SOP: `plugins/promptfoo/skills/promptfoo-evals/SKILL.md`
