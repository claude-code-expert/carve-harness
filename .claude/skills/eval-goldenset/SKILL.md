---
name: eval-goldenset
description: 골든셋(고정 입력→루브릭 케이스)으로 산출물 품질을 정량 채점하고 점수 추이를 추적해 회귀를 잡는다. 프롬프트·에이전트·스킬·규칙을 바꾼 뒤 "더 나빠지지 않았는지"를 숫자로 확인할 때, 또는 반복 신뢰도(pass@k/pass^k)를 재고 싶을 때 발동.
---

# eval-goldenset — 골든셋 정량평가 (모델 무관 SOP)

> 권위는 도구가 아니라 이 절차에 있다. `carve-eval` 워크플로는 이 절차를 코드로 자동 실행할 뿐이다.
> 태스크당 완성도는 `checklist-loop`(항목 5축 채점)이 담당하고, 이 스킬은 **고정 케이스 집합의 품질을 시간축으로** 관리한다.
>
> **첫 골든셋을 만드는 중이면 `/eval-init`을 써라** — 이 문서의 절차를 프로젝트 분석 + 대화형 인터뷰로
> 태우는 실행기다(SOP ⟷ 실행기 관계는 `checklist-loop` ⟷ `carve-verify-loop`와 같다).
> 이 문서는 형식·판정 기준의 **정본**이고, 셋업 이후의 증설(트레이스 마이닝)도 여기 절차를 따른다.

## 언제 쓰나

- 프롬프트·`CLAUDE.md`·에이전트·스킬·규칙을 바꾼 뒤 **회귀 확인** — "이 변경이 출력을 나쁘게 만들지 않았나"를 숫자로.
- 데모는 되는데 프로덕션은 무너지는지 — **pass@k(능력)** vs **pass^k(일관성)** 분리 측정.
- 안 쓰는 경우: 정답 없는 탐색·리서치, 골든셋을 유지할 사람이 없을 때(유지 안 하면 추이가 무의미).

## 골든셋 형식 (`specs/goldenset/*.json`)

```json
{
  "suite": "cs-agent",
  "cases": [
    {
      "id": "refund-policy",
      "version": "1.0",
      "prompt": "고객: 어제 산 제품 환불돼요? 규정대로만 답하라.",
      "k": 3,
      "assert": [
        { "type": "contains",    "value": "14일" },
        { "type": "regex",       "value": "환불|반품" },
        { "type": "not_contains","value": "무조건" },
        { "type": "llm-rubric",  "value": "규정 수치를 정확히 인용하고 규정 외 약속을 하지 않는다" }
      ]
    }
  ]
}
```

- `assert.type` 3계층:
  - **텍스트**(순수 채점): `contains` · `not_contains` · `regex` · `not_regex`
  - **상태**(`.claude/hooks/eval-state.sh`가 결정론 채점 — 워크디렉토리의 실제 상태):
    `file_exists`(경로) · `file_contains`(`경로::리터럴`) · `cmd_exit0`(명령 exit 0) · `git_diff_contains`(diff 내 리터럴) ·
    `log_contains`(`logs/*.jsonl::<jq 불리언 필터>` — 워크디렉토리의 하네스 훅 로그로 **경로(trajectory)를 결정론 채점**. 예:
    `.decision=="block" and .tool=="Write"`. 외부 target(`claude`·`exec:`)에서만 유효 — 세션 응답자는 로그가 리포 `logs/`로 간다)
  - **정성**: `llm-rubric`(evaluator 위임 — "평가의 평가" 문제가 있으니 상태 assert로 대체 가능하면 대체)
- `setup`(선택): 케이스 실행 전 격리 워크디렉토리에서 실행할 bash 스크립트(환경 구성 — 파일·git 초기화 등).
  상태 assert 또는 `setup`이 있으면 respondent는 **리포 밖 임시 디렉토리**에서 실행된다(골든셋 정답 비노출).
- `k`: 반복 실행 횟수(기본 1, 상한 10). k>1이면 pass@k·pass^k가 의미를 가진다.
- `tags`(선택): `["required", "category:domain_safety"]`. **`required`** 케이스는 하나라도 완전 green(100)이 아니면 `eval-gate`가
  평균과 무관하게 `regressed`로 막는다(블루프린트 §6.5 관문 ①). `category:*`는 리포트 분류용. 골든셋에 required가 0건이면
  `carve-validate`가 NOTE(`--strict`면 ERROR) — 안전·결제·인증 케이스에 붙여라. 이 리포는 `harness-guard` 5건이 required.
- `version`(필수): 케이스 정의의 버전. **케이스를 고치면 반드시 올린다.** 버전 없이 점수만 쌓으면
  run #3과 run #7이 서로 다른 문제를 푼 점수인데도 같은 축에 그려져 추이가 조용히 무의미해진다.
  추이 엔트리에 `caseVersion`으로 함께 기록되고, 직전 run과 다르면 `[VERSION CHANGED]`로 경고한다.
- 알 수 없는 assert 타입·잘못된 정규식·상태 채점 불능은 전부 **fail-closed**(통과로 새지 않음).

**원칙: verifier는 에이전트의 말이 아니라 환경의 상태를 채점한다.** "파일을 만들었다"는 응답 텍스트가
아니라 `file_exists`로, "테스트가 통과한다"는 주장이 아니라 `cmd_exit0`로 확인하라.

**assert 값은 원본 파일에서만 읽는다.** 상태 채점기는 `eval-state.sh <workdir> <골든셋파일> --case <id>`
형태로 호출되어 jq로 직접 값을 뽑는다. assert를 프롬프트에 실어 에이전트에게 옮기게 하거나 `@tsv`로
꺼내면 백슬래시가 두 배가 되어(`\+` → `\\+`) 정규식이 영구 미매칭된다 — 실제로 이 결함으로 골든셋
3건이 0점으로 오채점됐다. **setup을 보호 경로(`db/migration/`·`.env` 등)에 두지 마라** — 하네스가
픽스처 생성 자체를 차단해 케이스가 자기 전제를 세울 수 없다(`--red`가 잡아준다).

## 채점 규칙

- 한 실행이 green = **모든 결정론 assert 통과 AND 모든 llm-rubric 통과**.
- `caseScore = green/k × 100`(일관성률). `pass_at_k = green≥1`, `pass_pow_k = green==k`.
- `suiteScore = 케이스 caseScore 평균`. 임계(기본 70) 미만 케이스는 리포트에 나열.

## 회귀 게이트

- `eval-gate.sh` 판정 순서: `unable`(추이 없음·손상) → `stale`(`--changed`에 CLAUDE.md·AGENTS.md·`.claude/**`·`specs/goldenset/**`가 있는데 추이 미갱신 — 프롬프트 변경도 게이트를 지난다, R8) → `suspicious`(최근 run 케이스 ≥3건 전부 0 또는 전부 100 — 채점기·문항부터 의심, §6.7) → `regressed`(required 케이스 미green **또는** 직전 baseline 대비 `suiteScore` DELTA(기본 3pt) 초과 하락) → `ok`. block 모드는 ok 외 전부 exit 1.
- `specs/eval-score.json`은 append-only 추이(`{"runs":[{run, version, suiteScore, cases[], prevHash}]}`) — 기존 원소 수정 금지.
  **읽기·append는 `eval-trend.sh`만 한다**(`read` / `append <entry.json>`): run 서수와 `version`은 스크립트가 VERSION 파일에서
  채우고, 각 run의 `prevHash`가 이전 run들의 해시를 담아 **변조된 추이엔 append를 거부**한다(exit 1). 에이전트에게 JSON을
  열어 고치게 하지 마라 — 실제로 run 하나가 유실되고 version이 오기록된 적이 있다. 사람이 정정해야 하면 손으로 고치고
  `DECISIONS.md`에 남긴다.
- 강제(CI/pre-push 차단)는 옵트인 — 팀이 골든셋을 유지할 때만 배선한다(과잉 차단 방지).

## 프리플라이트 — 돌리기 전에 검증한다 (`carve-validate`)

채점기는 전부 fail-closed다. assert 타입 오타 하나, 컴파일 안 되는 정규식 하나가 **조용히 0점**이 되고,
그건 "에이전트가 못했다"와 구별되지 않는다. 그래서 비싼 런 전에 설정 오류를 먼저 분리한다 — 에이전트 0회.

```bash
bash .claude/hooks/carve-validate.sh              # specs/goldenset/*.json 구조 검증
bash .claude/hooks/carve-validate.sh --red        # + 케이스가 실제로 무언가를 재는지 확인
```

- 기본 검증: 필수 필드(`id`·`prompt`·`version`·`assert`) · id 중복 · 미지 assert 타입 ·
  정규식 컴파일(JS 의미론, node 있을 때만 — 없으면 `SKIP`으로 명시 보고) · `file_contains`의 `::` ·
  `k` 범위 · 부정형 전용 케이스 · llm-rubric 전용 경고.
- `--red`: 각 케이스의 `setup`을 임시 디렉토리에서 돌린 뒤 **에이전트 작업 없이** 결정론 assert를 채점한다.
  전부 통과하면 `NO-SIGNAL` — 아무것도 안 한 응답자가 green을 받는 케이스이므로 그 케이스는 아무것도 재지 않는다.
  setup 스크립트 자체가 실패해도 여기서 잡힌다. (setup·`cmd_exit0`을 로컬에서 실행하므로 옵트인)
- `/eval`은 이 검증을 Phase 0으로 자동 실행하고, 실패하면 **런을 시작하지 않는다**(비용 보호).

## verifier 반복 절차 (첫 verifier는 거의 항상 틀린다)

새 케이스를 추가하면 **채점 결과만 보지 말고 반드시 1회는 양쪽 궤적을 검사**한다:

0. **양방향으로 확인한다** — 한쪽만 보면 절반은 틀린다.
   - *red*: `carve-validate.sh --red` — 에이전트가 아무것도 안 했을 때 assert가 **실패**하는가(안 그러면 아무것도 재지 않는다).
   - *green*: 케이스를 손으로 푼 정답 상태에서 assert가 **통과**하는가(안 그러면 영원히 0점인 케이스다).
   green 확인 없이 넣은 케이스가 실제로 run#1에서 false-zero 3건을 만들었다.
1. 케이스를 1회 실행한다(`/eval` 또는 단건).
2. **에이전트 궤적** 검사: respondent가 실제로 무엇을 했나(툴콜·산출물) — 태스크를 우회했는가.
3. **verifier 궤적** 검사: assert가 잰 것이 의도한 능력인가 — 프록시만 잰 것 아닌가.
4. 아래 리워드 해킹 카탈로그로 점검 → 해당되면 케이스/setup/assert 수정 후 재실행.
5. 두 궤적이 의도와 일치할 때만 골든셋에 확정 편입.

**리워드 해킹 점검 카탈로그** (케이스 작성·리뷰 시 필수 통과):

| 해킹 | 징후 | 대응 |
|---|---|---|
| 허위 주장 | "했다"는 텍스트만 있고 상태 변화 없음 | 텍스트 assert → 상태 assert(`file_exists`·`cmd_exit0`)로 교체 |
| 프록시 충족 | 지표는 green인데 태스크 미완 | 최종 결과물 기준 상태 assert 추가 — `--red`가 자동 탐지(NO-SIGNAL) |
| 정답 노출 | respondent가 골든셋/assert를 읽고 역산 | 상태 assert·setup 케이스는 자동으로 리포 밖 격리 — 텍스트 전용 케이스는 assert에 답 자체를 넣지 않기 |
| 과잉 충족 | 금지어 회피를 위해 무의미한 출력 | `not_*` 만 있는 케이스에 positive assert 병행 |

## 트레이스 마이닝 — 실패를 케이스로 (지속 개선 루프)

프로덕션(실사용 세션)의 실패가 최고의 골든셋 소재다. 주기적으로:

```bash
# 가드 차단·검증 실패 이벤트 추출 → 케이스 후보
cat logs/*.jsonl | jq -r 'select(.decision=="block") | [.ts,.tool,.reason//"-",.target//"-"] | @tsv'
bash .claude/hooks/logs-report.sh 7        # 차단 상세 요약
```

- 반복되는 block(같은 tool/reason) = 하네스가 막아낸 실수 패턴 → 그 상황을 재현하는 케이스로.
- `stop-verify` 실패·재작업 이력 = 출력 품질 실패 → 해당 태스크를 프롬프트+상태 assert로 고정.
- **편향 주의**: 트레이스 기반 케이스는 "이미 아는 문제"로 치우친다 — 합성 시나리오(경계값·미발생 위험)를 별도 보충.

## 시작 로드맵 (덱 §5)

1. **일찍, 작게** — 실제 실패 20~50건으로 골든셋 v1. 수백 개 불필요.
2. **이미 하는 것에서** — 릴리스 전 수동 체크·버그 트래커·CS 큐가 최고 소재.
3. **모호하지 않게** — 품질 기준 = 전문가 2명이 독립적으로 같은 합/불 판정.
4. **생성 케이스는 인간 검수 필수** — Claude로 케이스를 늘리되 자기강화 방지.

### day-0 부트스트랩 (설치 직후 — 실패 트레이스가 아직 없을 때)

실사용 실패가 쌓이기 전엔 소재가 없다. **`/eval-init`이 이 절차를 대화형으로 수행한다** —
아래는 그 스킬이 따르는 규약이자, 손으로 돌릴 때의 순서다:

1. 스택·핵심 경로 감지(인증·결제·PII·핵심 API — 수정 빈도 상위·차단 이력이 1순위 후보).
2. 경로당 1케이스, 총 3~5개 — **상태 assert 우선**(`cmd_exit0`으로 테스트 실행, `file_exists`로 산출물).
3. `example-goldenset.json`(텍스트)·`example-harness-e2e.json`(상태)을 복사해 개조 — 형식 재발명 금지.
4. **반드시 인간 검수 후 편입**(위 verifier 반복 절차 그대로) — 자동 생성분을 무검수 확정하지 않는다.
5. 며칠 운용 후 트레이스 마이닝으로 교체·증설 — 부트스트랩 케이스는 임시 골격이지 정본이 아니다.

### 회귀 강제 (CI)

채점(`carve-eval`)과 강제(`eval-gate.sh`)는 분리돼 있다 — CI가 모델 판단에 의존하지 않게 하려는 것이다.

```bash
bash .claude/hooks/eval-gate.sh --mode report          # 판정만 출력(항상 exit 0)
bash .claude/hooks/eval-gate.sh --mode block --delta 3 # 회귀 시 exit 1 (CI 차단)
```

추이 파일이 없거나 손상됐거나 채점된 run이 없으면 `unable` — block 모드에서 **실패로 처리**한다
(점수가 없다는 건 품질의 증거가 아니다). CI 배선은 `/eval-init`이 선택에 따라 깔아준다.

## 워크플로로 자동 실행

```
/eval                       # specs/goldenset/*.json 전체 재채점 → 추이 append → 회귀 판정
```

또는 발화에 `carve-eval 실행`. 인자: `{ goldenset?: glob, threshold?: 70, delta?: 3, config?: "라벨", target?: "session" | "claude" | "exec:<cmd>" }`.

**응답자(target)는 명령이다** — `eval-run.sh`가 setup→응답→채점→근거 파일을 한 번에 처리한다(promptfoo `exec:` 계약: cwd=워크디렉토리, argv[1]=prompt, stdout=응답).
- `session`(기본): 워크플로 서브에이전트가 응답, setup·채점은 스크립트.
- `claude`: 헤드리스 `claude -p` — CI에서 **실채점**이 가능해지는 경로(CLI+인증 필요, 없으면 `target-unavailable`).
- `exec:<cmd>`: 임의 명령(다른 에이전트·스텁·회귀 픽스처).
실행 근거는 `specs/eval-runs/run-<N>/<id>#<i>.json`(응답 원문 + assert별 pass/reason)에 남는다 — 점수가 이상하면 여기부터 읽는다(블루프린트 R10). gitignore 대상.

> **`carve-eval.js`를 고친 직후에는 이름(`carve-eval`)으로 실행하지 마라.** 이름 해석은 세션 초반에 잡힌
> 레지스트리 스냅샷을 쓸 수 있어 **수정 전 코드가 그대로 돌아간다**(실측 확인됨 — run#3이 구버전 회귀
> 판정 로직으로 실행됐다). 수정 후 첫 실행은 `Workflow({scriptPath: ".claude/workflows/carve-eval.js"})`로
> 파일을 직접 지정하고, 결과에 새 필드가 실제로 들어왔는지 확인하라.

- 추이 엔트리에 하네스 `VERSION`과 `config` 라벨이 함께 기록된다 — **환경·태스크 고정, 구성만 교체**
  방식으로 버전 간(v0.5.1 vs 다음)·구성 간(모델 A vs B) 비교가 가능.

## 참고
- 루프 코드: `.claude/workflows/carve-eval.js` · 상태 채점기: `.claude/hooks/eval-state.sh`
  · 프리플라이트: `.claude/hooks/carve-validate.sh`
- 예시 골든셋: `example-goldenset.json`(텍스트) · `example-harness-e2e.json`(상태 기반 — 하네스 능력 e2e)
- 이 리포의 실제 골든셋: `specs/goldenset/harness-guard.json`(가드 준수 5) ·
  `harness-craft.json`(작업 품질 5) · `harness-hard.json`(고난도 5) — 케이스 작성 참고용
- **난이도 관리**: 전 케이스가 통과하는 골든셋은 회귀 탐지 여지가 없다. 개선을 못 재고, 작은 퇴행도
  절벽처럼만 보여 원인 해상도가 낮다. 일부가 실패하는 상태를 유지하라 — `harness-hard.json`은
  실제로 관측된 실패(이스케이프 파손·소스 grep 위장 테스트·`mv`로 실행권한 소실·비멱등 스크립트·
  빈 입력 처리)를 케이스로 고정한 것이다.
- 태스크당 5축 채점: `.claude/skills/checklist-loop/SKILL.md`
