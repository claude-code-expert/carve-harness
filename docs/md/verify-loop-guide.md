# 검증 루프 가이드 — carve-verify-loop (스펙→개발→체크리스트→채점→재작업)

> 개발이 스펙대로 됐는지 **구현 주장 항목을 하나씩 실제 코드와 대조해 0~100점 채점**하고,
> 95점 미만 항목만 골라 gap을 되먹여 다시 고치는 루프를 **전 항목 95점 이상**이 될 때까지 돌린다.
> 하네스 3기둥(제약·피드백·상태)의 "피드백"을 개발 사이클 전체로 확장한 검증 스테이션.
>
> 규칙 원본: [orchestration.md](orchestration.md) · [fable-team-guide.md](fable-team-guide.md)

---

## 1. 왜 필요한가

기존 하네스의 `stop-verify` 훅은 빌드/타입/테스트 **통과 여부**만 본다. "스펙의 각 요구가 실제로
구현됐는지"는 검증하지 않는다. `fable-team-pipeline`은 build→verify를 **1회**만 돌 뿐, 미달분을
되먹여 고치는 루프도, 항목별 점수도 없었다.

이 시스템이 채우는 빈틈:

- **전수 채점**: "구현했다"는 주장(claim)을 모두 리스트업하고, evaluator가 각 항목을 코드 대조 + 테스트 실행으로 0~100 채점한다. 주장만 믿지 않는다.
- **미달 재작업 루프**: 95점 미만 항목만 외과적으로 골라, "무엇을 어떻게 고쳐야 넘는지"(gap)를 빌더에 되먹여 다시 고치고 재채점한다.
- **완료 게이트**: 미달 항목이 남으면 Stop 훅이 완료 선언을 차단한다(exit 2). 워크플로 없이 손으로 돌려도 강제력이 걸린다.

핵심 원칙: **생성자(builder)와 채점자(evaluator)는 절대 같은 에이전트가 아니다**(Self-Eval Blindspot 방지).

---

## 2. 언제 쓰나

| 상황 | 이 루프 | 대안 |
|------|--------|------|
| 스펙에 요구가 여러 개, 전부 됐는지 확인 필요 | ✅ carve-verify-loop | — |
| 단일 변경 통과 여부만 | — | `/verify` (stop-verify) |
| 리서치→구현→문서→그림까지 한 번에 | — | `fable-team-pipeline` |
| 완료 기준(SC) 분해만 | 선행 | `/plan` |

---

## 3. 빠른 시작

### 3.1 커맨드로

```
/verify-loop 주문 취소 API 구현
```

`$ARGUMENTS`가 목표(goal)가 된다. 항목을 직접 안 주면 리서치 기반으로 3~7개 체크리스트 항목을
자동 분해한다(claim·acceptance·owns 비중복).

### 3.2 워크플로로 (항목 직접 지정)

발화에 `carve-verify-loop 실행` 또는 `ultracode` 포함. 인자:

```json
{
  "goal": "주문 취소 API",
  "threshold": 95,
  "tasks": [
    { "id": "api",  "claim": "POST /orders/{id}/cancel 엔드포인트",
      "acceptance": "204 반환 + CANCELLED 전이 테스트 통과", "owns": ["src/api/cancel/**"] },
    { "id": "rule", "claim": "이미 취소된 주문 재취소 차단",
      "acceptance": "409 반환 테스트 통과", "owns": ["src/domain/order/**"] }
  ]
}
```

`threshold` 생략 시 95. `tasks` 생략 시 P1에서 자동 분해.

---

## 4. 4단계 흐름

```
P1 Spec/Checklist   fable-researcher 리서치 → 목표를 체크리스트 항목으로 분해
                    (claim + acceptance + owns 비중복) → specs/checklist.json 기록
P2 Build            항목별 fable-builder(worktree 격리) → claim 구현 + 테스트
P3 Score            항목별 evaluator → 실제 코드 열고 테스트 실행 → 0~100 채점
                    → checklist.json 갱신(score·pass·gaps·evidence)
P4 Loop             score<95 항목만 gap을 빌더에 되먹여 P2로 (미달분만 재작업, 전수 아님)
                    항목당 최대 3회(교착 시 에스컬레이션) · 외곽 루프 최대 8회
P5 Verify           전 항목 95점 이상 → evaluator 통합 최종 판정(계약 위반·회귀 점검)
```

반환값:

```json
{ "goal": "...", "threshold": 95, "iterations": 2, "total": 3,
  "passed": [{"id":"api","score":100}], "failed": [], "allPassed": true,
  "finalVerdict": { "pass": true, "reasons": [...] } }
```

---

## 5. specs/checklist.json 스키마 (단일 진실원)

빌더·채점자·게이트 훅이 모두 이 파일을 읽는다(파일 기반 통신).

```json
{
  "goal": "주문 취소 API",
  "iteration": 2,
  "threshold": 95,
  "items": [
    {
      "id": "c1",
      "claim": "POST /orders/{id}/cancel 구현",
      "acceptance": "204 반환 + 상태 CANCELLED 전이 테스트 통과",
      "owns": ["src/api/cancel/**"],
      "attempts": 2,
      "score": 88,
      "pass": false,
      "gaps": ["멱등성 미검증", "이미 취소된 주문 409 테스트 없음"],
      "evidence": "src/api/cancel/route.ts:12; test 3/4 pass"
    }
  ]
}
```

- `claim`/`acceptance`/`owns`: 분해 단계에서 채운다. `owns` glob은 항목끼리 겹치면 안 된다(파일 오너 1개).
- `score`/`pass`/`gaps`/`evidence`/`attempts`: 채점 단계에서 채운다. `pass = score >= threshold`.

---

## 6. 채점 기준 (evaluator 채점 모드)

evaluator가 항목마다 수행:

1. **코드 대조** — claim이 acceptance를 문자 그대로 충족하는지 실제 파일을 Read/Grep으로 확인. 주장을 믿지 않는다.
2. **테스트 실행** — Bash로 직접 돌려 통과/실패/스킵/미수집을 구분. 명령 성공 ≠ 결과 정확.
3. **감점** — 미구현·부분구현·미테스트·계약(스키마/시그니처) 위반·엣지케이스 누락마다 감점.
4. **evidence** — 파일:라인과 테스트 결과 원문 인용.
5. **gaps** — 95 미만이면 빌더가 바로 실행 가능하도록 "무엇을 어떻게 고칠지" 구체적으로 명시.

정의: `.claude/agents/evaluator.md`(채점 모드 절).

---

## 7. 완료 게이트 훅 (checklist-gate)

`specs/checklist.json`이 존재하고 `score<threshold`거나 미채점(`score:null`) 항목이 남으면
Stop 훅이 완료를 **차단(exit 2)**한다:

```
[carve-harness:checklist] 미완 2개 (임계 95): c1(88), c3(미채점) — 루프 계속(gap 수정 후 재채점)
```

- 파일 없음 → 무동작(exit 0). 루프를 안 쓰는 작업은 방해받지 않는다.
- `jq` 없음/JSON 파손 → best-effort 스킵(교착 방지, `stop-verify`와 동일).
- 전 항목 `pass=true` → 통과(exit 0).

정의: `.claude/hooks/checklist-gate.sh` · `settings.json`의 Stop 배열에 `stop-verify` 뒤 등록.

---

## 8. 모델 무관 수동 실행 (워크플로 없이)

Fable/Opus/Sonnet 어떤 세션이든, 훅 없는 다른 에이전트(Cursor·Codex)든 아래를 손으로 실행하면 동일하다.
권위는 도구가 아니라 절차에 있다. 상세 SOP는 `checklist-loop` 스킬:

```
S1 분해   목표 → 항목(claim·acceptance·owns 비중복) → checklist.json(전 항목 score:null)
S2 Build  미해결 항목마다 builder 1개, worktree, owns 밖 쓰기 금지
S3 Score  항목마다 evaluator(read-only) 채점 → checklist.json 반영
S4 Loop   score<임계 항목만 gap 되먹여 S2로 (반성 프롬프트 강제)
S5 종료   전 항목 pass=true → S6 / 3회 교착 → [ESCALATION] 후 failed 기록·탈출
S6 최종   evaluator 통합 판정. 통과분만 완료 선언
```

---

## 9. 트러블슈팅

| 증상 | 원인 | 조치 |
|------|------|------|
| Stop이 계속 막힘 | checklist.json에 미달/미채점 항목 잔존 | 게이트 메시지의 항목 id 확인 → gap 수정 → 재채점, 또는 escalated 항목을 사람이 조정 후 파일에서 제거 |
| 게이트가 안 막음 | `jq` 미설치(best-effort 스킵) 또는 checklist.json 없음 | `jq` 설치. 워크플로 루프 자체는 jq 없이도 동작 |
| 특정 항목 3회 계속 미달 | 스펙 모호·아키텍처 변경 필요 | 루프가 자동 에스컬레이션 → 사람 판단. `acceptance` 재정의 검토 |
| 항목이 서로 파일 충돌 | `owns` glob 중복 | 분해를 다시 — 파일 오너 1개 원칙 |
| 테스트 항목이 계속 0점/미달 | 구현과 테스트를 별개 항목으로 쪼갬 → 격리 worktree에서 테스트가 구현 파일을 못 봄 | 상호의존 파일(구현 + 그 테스트)을 **한 항목 owns**에 함께 묶어 재분해 |

---

## 10. 참고

- 루프 코드: `.claude/workflows/carve-verify-loop.js`
- 게이트 훅: `.claude/hooks/checklist-gate.sh` (+ 자가 테스트 `tests/checklist-gate.test.sh`)
- 채점자: `.claude/agents/evaluator.md`
- 진입 커맨드: `.claude/commands/verify-loop.md`
- 모델 무관 SOP: `.claude/skills/checklist-loop/SKILL.md`
- 오케스트레이션 규칙: [orchestration.md](orchestration.md) · [fable-team-guide.md](fable-team-guide.md)
