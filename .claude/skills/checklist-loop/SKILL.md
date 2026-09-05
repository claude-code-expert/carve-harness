---
name: checklist-loop
description: 개발이 스펙대로 됐는지 구현 주장 항목을 코드 대조로 0~100 채점하고, 95점 미만은 되먹여 재작업하는 검증 루프를 돈다. carve-verify-loop 워크플로가 없거나(타 에이전트·일반 세션) 손으로 돌릴 때 사용.
---

# checklist-loop — 스펙→개발→체크리스트→채점→재작업 루프 (모델 무관 SOP)

> 권위는 도구가 아니라 이 절차에 있다(fable-team-guide 4절).
> `carve-verify-loop` 워크플로는 이 절차를 코드로 자동 실행할 뿐이다.
> Fable/Opus/Sonnet 어떤 세션이든, 훅 없는 다른 에이전트든 아래를 그대로 수동 실행하면 동일하게 동작한다.

## 핵심 불변식

- **생성자(builder)와 채점자(evaluator)는 절대 같은 에이전트가 아니다** (Self-Eval Blindspot 방지, AGENTS.md 6절).
- **주장을 믿지 않는다.** "구현했다"는 claim은 실제 코드 대조 + 테스트 실행으로만 인정한다.
- **완료 = 모든 항목 score ≥ 임계(기본 95).** 하나라도 미달이면 루프는 끝나지 않는다.
- 에이전트 간 통신은 파일 기반 — `specs/checklist.json`이 단일 진실원.

## specs/checklist.json 스키마 (정본)

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
      "axes": { "exists": 25, "match": 25, "test": 13, "contract": 15, "no_regress": 10 },
      "pass": false,
      "gaps": ["멱등성 미검증", "이미 취소된 주문 409 테스트 없음"],
      "evidence": "src/api/cancel/route.ts:12; test 3/4 pass"
    }
  ]
}
```

- `claim`/`acceptance`/`owns`: 분해 단계에서 채운다. `owns` glob은 **항목끼리 겹치면 안 된다**(파일 오너 1개).
- `type`(선택): `convention` | `correctness` | `domain_safety`. **`domain_safety` 항목은 100점이 아니면 총점·임계와 무관하게 Stop 게이트가 차단한다**(GATE-C7, 블루프린트 §5.5 허용 실패율 0%). 도메인 불변식(`CLAUDE.md` 도메인 규칙)을 구현하는 항목에 붙여라. type 없는 항목은 임계(95) 규칙만.
- `axes`/`score`/`pass`/`gaps`/`evidence`/`attempts`: 채점 단계에서 채운다. `score = 5축 합`, `pass = score >= threshold`.
- **5축 루브릭(합 100)**: `exists`25·`match`25·`test`25·`contract`15·`no_regress`10. `test`는 실행 출력으로만 채운다 → verify 미실행이면 test=0 → 합 ≤75 < 95(거짓 완료 차단). 게이트는 `score`만 보므로 하위호환.

## 루프 SOP (순서 고정)

```
S1. Spec/분해   목표를 리서치 → 3~7개 항목으로 분해(claim·acceptance·owns 비중복).
                상호의존 파일(구현 + 그 테스트, 모듈 + 그 마이그레이션)은 반드시 같은 항목 owns에 함께 둔다 —
                항목은 격리 worktree에서 채점돼 다른 항목 파일을 못 보므로, 구현·테스트를 쪼개면 테스트 항목이 영구 미달.
                specs/checklist.json 작성(전 항목 score:null). → Stop 게이트가 이때부터 완료를 막는다.
S2. Build       미해결 항목(pass=false)마다 builder 1개. worktree 격리, 동시 3~5개 상한.
                owns 밖 쓰기 금지. 재작업이면 아래 S4의 반성 프롬프트 + gaps를 입력으로 준다.
S3. Score       항목마다 evaluator(read-only)에 채점 위임 → 코드 대조 + 테스트 실행으로 5축(exists·match·test·contract·no_regress) 채점, score=합.
                결과를 checklist.json에 반영(axes·score·pass·gaps·evidence·attempts++).
S4. Loop        score<임계 항목만 골라 gap을 builder에 되먹여 S2로. 미달 항목만 재작업(전수 아님).
                반성 프롬프트 강제: "무엇이 실패했나? 어떤 구체적 변경이 임계를 넘기나? 같은 접근 반복 중인가?"
S5. 종료        전 항목 pass=true → S6. / 특정 항목 3회(MAX_ATTEMPTS) 재작업에도 미달 → [ESCALATION] 후
                그 항목 failed 기록하고 루프 탈출(무한 재시도 금지, orchestration.md 5절).
S6. 최종        evaluator 통합 최종 판정(항목 간 계약 위반·회귀 점검). 통과분만 완료로 선언.
```

가드레일: 항목당 재작업 3회, 외곽 루프 8회(MAX_ITERATIONS)를 상한으로 둔다. 예산 85% 도달 시 일시정지 보고.

## 완료 게이트 연동 (checklist-gate 훅)

`specs/checklist.json`이 존재하고 `score<threshold`거나 미채점(`score:null`) 항목이 남으면
Stop 훅 `checklist-gate.sh`가 완료를 **차단(exit 2)**한다("미완 N개 — 루프 계속"). 워크플로 없이 손으로 돌려도 강제력이 걸린다.
루프를 연 적 없으면 무동작 — 루프를 쓰지 않는 작업은 방해받지 않는다.

- 루프 시작: checklist.json 작성(전 항목 미채점) → 게이트 활성.
- 루프 종료: 전 항목 pass=true → 게이트 통과. 또는 escalated 항목을 사람이 승인 후 checklist.json에서 제거/조정.

**자가 우회는 막혀 있다** (채점당하는 쪽이 채점을 끝낼 수 없다):

- **채점 파일 삭제 → 계속 차단.** 첫 차단 때 tombstone `specs/.checklist-active`가 생기고, 정상 완료(전 항목 통과)만이 그것을 지운다. checklist.json이 사라지면 게이트는 "복원해서 채점을 마쳐라"로 차단한다.
- **threshold 하향 → 무효.** 파일의 `threshold`가 하한(기본 95)보다 낮으면 하한으로 클램프된다. 진짜 다른 기준이 필요하면 파일이 아니라 환경변수 `CARVE_CHECKLIST_FLOOR`로 바꾼다(에이전트가 못 건드리는 축).
- tombstone·checklist 경로는 `PROTECTED_RE`에 있어 에이전트의 Write·`rm` 둘 다 차단된다. **루프를 중단하려면 사람이** 자기 셸에서 `rm specs/.checklist-active`를 실행한다 — 중단은 사람의 결정이다.

## 워크플로로 자동 실행

```
/verify-loop 주문 취소 API 구현
```

또는 발화에 `carve-verify-loop 실행` / `ultracode`. 인자로 항목을 직접 줄 수도 있다:

```json
{ "goal": "주문 취소 API",
  "threshold": 95,
  "tasks": [
    { "id": "api",  "claim": "취소 엔드포인트", "acceptance": "204+CANCELLED 전이 테스트 통과", "owns": ["src/api/cancel/**"] }
  ] }
```

## 참고
- 루프 코드: `.claude/workflows/carve-verify-loop.js`
- 게이트 훅: `.claude/hooks/checklist-gate.sh`
- 채점자: `.claude/agents/evaluator.md`(채점 모드 절)
- 오케스트레이션 규칙: `docs/md/orchestration.md`, `docs/md/fable-team-guide.md`
