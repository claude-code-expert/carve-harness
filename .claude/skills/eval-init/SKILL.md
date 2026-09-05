---
name: eval-init
description: 프로젝트를 분석한 뒤 대화형 인터뷰로 평가 게이트(골든셋·k·회귀 허용폭)와 품질 게이트(커버리지·검증루프 임계·CI 강도)를 확정하고, 골든셋 초안 생성 → 궤적 검사 → 승인분만 편입 → CI 배선 → baseline 기록까지 수행한다. 설치 후 `/eval`을 실제로 쓸 수 있게 만드는 1회성 셋업.
disable-model-invocation: true
argument-hint: "[--dry-run]"
---

# eval-init — 평가·품질 게이트 확정 인터뷰

`/eval`은 골든셋(`specs/goldenset/*.json`)이 있어야 의미가 있는데, 설치 직후엔 비어 있다.
이 스킬이 그 빈칸을 **분석 + 대화형 확정 + 궤적 검사**로 채운다. 채점 절차의 정본은
`eval-goldenset` 스킬이고, 이 스킬은 그 절차를 **실행**하는 쪽이다
(`checklist-loop`(SOP) ⟷ `carve-verify-loop`(실행)와 같은 구조).

> `--dry-run`이면 **S4 초안 제시까지만** 하고 파일을 쓰지 않는다.

## 절대 규칙 (어기면 골든셋이 죽는다)

1. **자동 확정 금지.** 에이전트가 혼자 만든 케이스는 자기가 이미 통과하는 것만 담는다(자기강화).
   크리티컬 경로·실패 소재·엄격도는 **반드시 사람이 정한다.**
2. **궤적 검사를 통과한 케이스만 편입한다.** 미승인 케이스는 파일에 쓰지 않는다.
3. **상태 assert 우선.** "했다"는 텍스트가 아니라 파일·명령 exit로 채점한다.
4. **기존 자산 불가침.** 골든셋이 이미 있으면 덮어쓰지 않고 **증설**만 한다.
5. 질문은 한 번에 하나씩, 근거(분석 결과)를 함께 제시한다. 추측으로 답을 대신 채우지 마라.

---

## S0. 사전 점검 (질문 없음)

1. 하네스가 갖춰졌는지 확인. 둘 중 **하나라도** 만족하면 진행한다:
   - 설치본: `.claude/harness-manifest.txt` 존재
   - 하네스 소스 레포: `install.sh` + `.claude/hooks/` + `VERSION` 존재(manifest는 설치본에만 생긴다)
   둘 다 아니면 **중단** — "설치된 하네스가 아닙니다. 먼저 `bash install.sh`".
2. `git status --porcelain` — dirty면 경고만("결과를 git diff로 검토·롤백하려면 clean 권장").
3. `specs/goldenset/*.json` 존재 → **증설 모드**로 전환하고 그렇게 고지한다(기존 케이스·suite 이름 보존).
4. `specs/eval-score.json` 존재 → 기존 baseline 점수를 보여준다(S3 Q6의 근거).

## S1. 프로젝트 분석 (질문 없음 — 근거와 함께 1문단 요약)

읽기 전용으로만 수집한다. **쓰지 마라.**

| 축 | 방법 | 쓰임 |
|---|---|---|
| 스택·테스트 러너·커버리지 도구 | 설치 팩(`.claude/harness-packs`)의 `.claude/stacks/<pack>.sh`에서 `STACK_TEST_CMD_HINT`·`STACK_COVERAGE_MIN`을 읽는다. 팩 없으면 `package.json`·`pyproject.toml`·`go.mod`·`build.gradle` 직접 감지 | 케이스의 `cmd_exit0` 형태 · Q4 기본값 |
| 진입점 목록 | 라우트·핸들러·CLI 서브커맨드·public API 스캔 | 크리티컬 경로 **후보** |
| 수정 빈도 상위 | `git log --since=3.months --name-only --pretty=format: \| sort \| uniq -c \| sort -rn \| head -15` | 자주 깨지는 곳 = 1순위 후보 |
| 하네스 차단 이력 | `cat logs/*.jsonl \| jq -r 'select(.decision=="block") \| [.tool,.reason//"-"] \| @tsv' \| sort \| uniq -c \| sort -rn` | 실제 막아낸 실수 패턴 |
| 기존 테스트·커버리지 | 테스트 파일 수, 가능하면 커버리지 실측 1회 | Q4 제안의 근거 |
| CI | `.github/workflows/` | Q7 선택지 |

요약은 **숫자와 파일 경로를 포함**해 한 문단으로 보여준다. 근거 없는 단정 금지.
분석 결과가 비면(진입점 0·git 이력 없음) 그 사실을 말하고, 합성 케이스로 갈지 물어라.

## S2. 인터뷰 A — 무엇이 중요한가 (사람만 아는 것)

**Q1. 크리티컬 경로** (복수 선택 — 분석 후보를 수정 빈도와 함께 제시, "기타" 허용)
> 여기 깨지면 사고인 경로를 고르세요(3~5개 권장).

**Q2. 최근 실제 실패** (자유 입력, skip 허용)
> 최근 실제로 터진 버그·재발 이슈가 있나요? **있다면 그 재현이 최고의 첫 케이스입니다.**
> 없으면: 합성 케이스로 시작하되 "2주 뒤 트레이스 마이닝으로 교체" 액션을 S5 요약에 고정한다.

**Q3. 도메인 불변식** (3개까지, skip 허용)
> "이건 절대 안 된다" 3개. 예: "주문 금액 음수 불가", "결제 승인 없이 배송상태 변경 금지".
> 승인 시 `CLAUDE.md`의 도메인 규칙 자리에 **append**한다(기존 내용 보존, 덮어쓰기 금지).

**Q3-b. 성공 기준 문장화** (Q1·Q3 답에서 자동 초안, 사용자 확인 1회)
> 크리티컬 경로·불변식마다 **기준 / 지시문 / 검사문** 세 줄을 `specs/SUCCESS-CRITERIA.md`에 쓴다(블루프린트 §6.1 "프롬프트와 Eval은 앞뒷면").
> 검사문은 그대로 골든셋 `llm-rubric` 값 또는 상태 assert의 근거가 되고, 지시문은 `CLAUDE.md` 도메인 규칙과 같은 문장이어야 한다.
> 템플릿: `specs/SUCCESS-CRITERIA.md`가 없으면 `.claude/skills/eval-init/SUCCESS-CRITERIA.template.md`를 복사해 채운다. 있으면 **append만**.

## S3. 인터뷰 B — 얼마나 엄격한가 (품질 게이트)

**Q4. 커버리지 임계** — S1 실측치를 보여주고: 현행 유지 / **80(권장, `common/testing.md` 기준)** / 미설정
> S1에서 **커버리지 도구가 없으면 이 질문을 건너뛴다**(bash·shell 중심 프로젝트 등). 물어봐야 적용할 자리가
> 없으므로 질문 피로만 늘린다. 건너뛴 사실은 S5 요약에 한 줄로 남긴다.
> 선택값은 프로젝트 설정(`vitest.config`·`jacoco`·`pytest --cov-fail-under` 등)에 반영할 위치만
> **안내**한다. 빌드 설정 자동 수정 금지(`safety.md` — 설정 변경은 승인 사항).

**Q5. 검증 루프 임계** — **95(기본·권장)** / 90(완화) / 100(엄격)
> 95 외 값은 `CARVE_CHECKLIST_FLOOR` 환경변수로만 적용된다(파일의 threshold는 하한으로 클램프됨).
> 어디에 export할지(셸 프로파일·CI env) 안내한다.

**Q6. 반복 신뢰도와 회귀 허용폭** — k=1(빠름) / **k=3(권장)** / k=5(엄격), 허용 하락폭 기본 3pt
> k>1이라야 pass@k(능력)와 pass^k(일관성)가 갈린다고 1줄로 설명한다.

**Q7. 게이트 강도** — 로컬 리포트만 / PR 코멘트(report) / CI 차단(block)
> **차단 모드는 골든셋을 유지할 사람이 있을 때만 권한다**고 반드시 고지한다.
> 유지 안 하는 팀에 차단을 걸면 품질이 아니라 우회 압력이 생긴다.

## S4. 초안 생성 + 궤적 검사 (두 번째 인터랙션 지점)

### 4-1. 초안

선택된 경로마다 케이스 1개, 총 3~5개. **상태 assert가 전체의 절반 이상**이어야 한다.

```json
{
  "suite": "<프로젝트명>",
  "cases": [{
    "id": "checkout-idempotent",
    "prompt": "결제 확정 API에 멱등키 처리를 추가하고 테스트를 통과시켜라.",
    "setup": "git init -q . && <픽스처 구성> ",
    "k": 3,
    "assert": [
      { "type": "cmd_exit0",     "value": "<프로젝트 테스트 명령>" },
      { "type": "file_contains", "value": "src/api/checkout/route.ts::idempotencyKey" },
      { "type": "git_diff_contains", "value": "idempotency" }
    ]
  }]
}
```

- **시드는 설치 팩의 스타터에서 복사한다**: `specs/goldenset/starters/<lang>.json`(팩당 4건, 전부 상태 assert,
  `--red`·정답 green 양방향 검증 완료). 케이스 `id`에 프로젝트 접두를 붙이고 `version: "1.0"`으로 편입 후보에
  넣는다. 스타터 파일 자체는 하네스 자산이라 **수정하지 않는다**(update로 덮인다). 프로젝트 고유 케이스(Q1·Q2)는
  스타터 형식을 복제해 만든다.
- assert 타입·`setup` 규약은 `eval-goldenset` 스킬의 "골든셋 형식" 절이 정본이다.
- **respondent 셸에는 세션 환경변수가 전달되지 않는다**(`CLAUDE_PROJECT_DIR`조차 없다). `setup`이 리포
  바깥 파일을 참조해야 하면(하네스 자신을 평가하는 스위트 등) **생성 시점의 절대경로를 박고 env 오버라이드를
  남겨라** — `"${MY_SRC:-/abs/path}"`. 경로가 틀리면 setup이 실패해 케이스가 fail 된다(조용한 통과 없음).
- `setup`이나 상태 assert가 있으면 respondent는 **리포 밖 임시 디렉토리**에서 돌아간다(정답 비노출).
- **assert에 답 자체를 넣지 마라.** 정답 문자열을 그대로 `contains`로 넣으면 역산된다.

### 4-2. 궤적 검사 (건너뛰기 금지)

케이스마다 1회 실행하고 **양쪽 궤적**을 표로 제시한다:

| 케이스 | 에이전트 궤적(무엇을 했나) | verifier 궤적(무엇을 쟀나) | 의심 | 판정 |
|---|---|---|---|---|
| checkout-idempotent | 라우트 수정 + 테스트 추가 | 상태 3축, 우회 없음 | — | 편입? |
| auth-session-expiry | **테스트만 수정**, 구현 미변경 | `cmd_exit0` 통과 | **프록시 충족** | 수정 필요 |

`eval-goldenset`의 리워드 해킹 카탈로그(허위 주장·프록시 충족·정답 노출·과잉 충족)로 자동 점검하고,
의심 항목은 사유를 달아 **사람이 결정**하게 한다. 사용자가 승인한 케이스만 다음 단계로 넘어간다.

## S5. 확정 · 배선 · 요약

승인된 것만, 순서 고정:

1. **골든셋** — `specs/goldenset/<suite>.json` 기록. 증설 모드면 기존 `cases` 배열에 append(기존 원소 변형 금지).
2. **도메인 규칙** — Q3 승인분을 `CLAUDE.md`에 append. Q3-b 승인분을 `specs/SUCCESS-CRITERIA.md`에 append(같은 문장 — 지시문과 검사문이 어긋나면 골든셋이 프롬프트를 잰다).
3. **CI 배선** — Q7이 report/block이면 이 디렉토리의 `eval-workflow.yml.template`을
   `.github/workflows/eval-gate.yml`로 복사하고 `__MODE__`·`__DELTA__`를 치환한다.
   이미 같은 파일이 있으면 **덮어쓰지 말고** diff를 보여주고 물어라.
4. **baseline** — `/eval`을 1회 실행해 `specs/eval-score.json`에 첫 점수를 남긴다.
   그 뒤 `bash .claude/hooks/eval-gate.sh --mode report`로 게이트가 읽히는지 확인한다.
5. **결정 기록** — 임계값 3종(커버리지·검증루프·허용 하락폭)과 **그 근거**를 `specs/DECISIONS.md`에
   기록한다(`changelog` 스킬). 나중에 "왜 80이었나"에 답할 수 있어야 한다.
6. **요약표** — 확정 케이스 수 · 임계값 3종 · 게이트 강도 · baseline 점수 · 다음 액션.
   Q2가 비어 있었다면 **"2주 뒤 트레이스 마이닝으로 합성 케이스 교체"** 를 다음 액션에 반드시 넣는다.

## 주의

- 이 스킬은 **1회성 셋업**이다. 이후 케이스 증설은 `eval-goldenset`의 트레이스 마이닝 절차로 한다.
- 커버리지·빌드 설정 파일은 자동 수정하지 않는다 — 위치와 값만 안내한다(`safety.md`).
- 골든셋을 유지할 사람이 없으면 만들지 마라. 방치된 추이는 숫자만 있고 의미가 없다.

## 참고

- 절차 정본: `.claude/skills/eval-goldenset/SKILL.md` (형식·리워드 해킹 카탈로그·트레이스 마이닝)
- 채점 엔진: `.claude/workflows/carve-eval.js` · 상태 채점기: `.claude/hooks/eval-state.sh`
- 회귀 게이트(결정론): `.claude/hooks/eval-gate.sh`
- 예시 골든셋: `.claude/skills/eval-goldenset/example-harness-e2e.json`
