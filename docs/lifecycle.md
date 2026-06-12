# 컴포넌트 라이프사이클 — 단계적 fade-out / fade-in

> 카탈로그(`src/catalog.ts`)의 `status` 필드가 단일 출처다. 이 문서는 정책과 케이던스를 기록한다.

## 상태 정의

| 상태 | 추천(`recommended`) | 목록(`list`/wizard) | 설치 | update | uninstall |
|---|---|---|---|---|---|
| `active` (생략 기본값) | 레벨 규칙대로 | 표시 | 가능 | 갱신 | 가능 |
| `deprecated` | **제외** | `{비추천→대체id}` 태그 | `--only`/wizard 명시 선택 시 가능 | **동결**(안내 출력) | 가능 |
| `hidden` | 제외 | **미표시** | 불가 | 동결(안내 출력) | **가능** (manifest 기반 — 영구 보장) |

- `replacedBy`: 비추천 안내에 표시할 대체 컴포넌트 id.
- `coordination`: monorepo/CI 시그널 가중 대상(active만 가중).
- `doctor`·`update`는 설치된 deprecated/hidden 컴포넌트를 안내한다(에러 아님 — exit code 무관).
- uninstall은 CATALOG를 참조하지 않고 manifest만 보므로, 카탈로그에서 항목이 사라져도 제거는 항상 동작한다.

## 케이던스 (단계적 fade-out)

```
active → deprecated (≥1 minor 유지) → hidden (≥1 minor 유지) → 카탈로그 항목 + assets/ 자산 삭제
```

- deprecated 동안 자산 파일(`assets/skills/<id>/`, `assets/commands/carve-<id>.md`)은 **유지**한다
  (기존 설치 + 명시 선택 설치가 계속 동작해야 함).
- 삭제 릴리스에서 카탈로그 항목과 자산을 **함께** 지운다(assets.test가 카탈로그 기준으로 자산을 검사하므로 자동 정합).

## fade-in (신규 기능 추가)

- 새 컴포넌트는 **한 번에 하나씩** 추가한다. 추가 시: 카탈로그 등재(점수 ≥75) + 자산 + 회귀 테스트 + `npm run score` 90+ 유지.
- 점수·중복지수는 `npm run score`의 redundancy 축이 감시한다(라인셋 Jaccard ≥ 0.5 = 중복쌍 감점).

## Wave 1 (v1.4.0, 2026-06-12)

| 컴포넌트 | 처리 | 대체 |
|---|---|---|
| `review` | deprecated | `squad-review` (NL 트리거는 squad-router가 이미 담당) |
| `changelog` | deprecated | `squad-gitops` |
| `security-scan` | deprecated | `squad-audit` |
| `coordinator` | deprecated | `parallel-agents` |
| `evaluator-tuning` | `optional: true` 강등 | — (직접 선택 시에만 설치) |
| `commit` | 유지 + 범위 명확화 | 빠른 인라인 메시지 생성 전용 — 깊은 git 작업은 squad-gitops |
