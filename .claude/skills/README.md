# `.claude/skills/` — 스킬 (절차 지식)

발화가 `description`과 맞으면 모델이 스스로 로드하거나 `/<이름>`으로 부르는 절차서. **각 스킬 = 하위 폴더 + `SKILL.md`**(프런트매터 필수 — 감사 AUDIT-06). 평소 컨텍스트 비용 0(필요할 때만 로드).

## 목록
| 스킬 | 발동 | 용도 |
|---|---|---|
| `anti-ai-slop` · `carve-guide` | 시각·HTML 산출물 직전 | 슬롭 차단 게이트 |
| `handoff` · `changelog` · `version-changelog` | 세션 종료·결정·릴리스 | 상태·결정·버전 기록 |
| `carve-harness-create` | 설치 후 맞춤 | 스택 감지 → 팩 add/remove·prune 제안 |
| `checklist-loop` · `eval-goldenset` · `eval-init` | 검증·평가 | 검증 루프 SOP · 골든셋 SOP · 골든셋 셋업 실행기 |
| `theme-factory` | 테마 적용 | 외부 벤더링(SKILL.md만) |

## 사용방법
- 자동: 작업 신호가 description과 맞으면 로드. 수동: `/eval-init`, `/carve-harness-create` 등.
- 새 스킬 = `<이름>/SKILL.md`. `--- name: ... description: <언제 발동> ---` + 절차. 실패 이력(Gotchas)이 최고의 내용.
- 이 폴더 루트의 `README.md`는 하위 폴더가 아니므로 스킬로 로드되지 않는다(각 스킬 폴더의 `README.md`도 마찬가지 — 로더는 `SKILL.md`만 읽는다).

> `frontend-design`·`ponytail`은 스킬이 아니라 `settings.json` 플러그인 선언으로 배포.
