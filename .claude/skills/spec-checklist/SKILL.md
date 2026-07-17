---
name: spec-checklist
description: 스펙(완료기준 SC)과 실제 git diff를 교차해 "구현했다"고 주장하는 요소를 하나도 빠짐없이 전수 열거하고 specs/<slug>/CHECKLIST.json으로 남긴다. 정합성 채점(conformance-scorer)의 입력. "체크리스트 열거", "구현 주장 전수", "스펙 정합성 준비" 신호일 때.
---

스펙과 실제 변경을 교차해 **검증 단위(claim) 전수 목록**을 만든다. 계약 정본은 `.claude/rules/conformance.md` §2다. 채점은 하지 않는다 — 열거만 한다.

## 전수(exhaustive) 원칙
누락과 허위를 **동시에** 잡는다.
- 스펙의 완료기준(SC) → 각 SC를 항목화(구현 주장이 없어도 항목으로 남겨 "누락"을 드러낸다).
- 실제 `git diff` → 코드에 실재하는 변경을 항목화(스펙에 없던 것도 "허위/스코프 이탈"로 드러낸다).
- 둘을 교차: SC엔 있는데 코드 없음(누락), 코드엔 있는데 SC 없음(스코프 이탈) 둘 다 항목이 된다.

## 절차
1. slug 확정 → `specs/<slug>/` 준비(있으면 이어서). 대상 스펙 소스(`specs/` 계획·PRD·이슈)와 `git diff`(또는 변경 파일)를 읽는다.
2. 입력이 비면 멈추고 보고(빈 diff·스펙 없음). 열거한 척 금지.
3. 각 검증 단위를 아래 스키마 한 항목으로 만든다. **한 항목 = 한 검증 단위.**
4. `CHECKLIST.json`을 `specs/<slug>/`에 쓴다.

## 항목 스키마 (conformance.md §2)
```json
{
  "slug": "order-cancel",
  "goal": "주문 취소 API 구현",
  "source": "spec+diff",
  "items": [
    {
      "id": "C1",
      "claim": "POST /orders/{id}/cancel — 취소 엔드포인트 구현",
      "targets": ["src/api/cancel.ts"],
      "acceptance": "유효 주문 → 200 + status=CANCELLED, 이미 취소 → 409 (테스트 어서션)",
      "verify": "vitest run cancel.test.ts"
    }
  ]
}
```

각 필드의 뜻:
- `claim`: "구현했다"고 주장하는 단일 요소.
- `targets`: 주장을 실증할 실제 파일/심볼. **비면 채점 시 0점 후보**(코드가 없다는 신호). diff에서 실제 경로를 채운다.
- `acceptance`: 검증 가능한 완료 기준(SC). 검증 방법이 안 떠오르면 SC가 아니다 — 더 구체화한다.
- `verify`: 재현 가능한 명령(테스트·grep). 스코어러가 **실제 실행**하므로 실행 가능한 형태로 쓴다. 테스트가 없으면 "테스트 없음"을 명시(채점에서 test축 0으로 드러난다 — 허위로 채우지 마라).

## 금지
- 코드에 근거 없는 주장을 넣거나, 검증 불가한 `acceptance`를 통과 가능처럼 적는 것.
- SC 또는 diff의 일부만 열거하고 전수인 척하는 것.
