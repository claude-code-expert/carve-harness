# `specs/` — 상태·평가 산출물 루트 (하네스 3기둥의 '상태')

세션을 넘어 지속되는 파일이 여기 쌓인다. 일부는 훅·스킬이 자동 생성한다.

| 경로 | 무엇 | 생성 |
|---|---|---|
| `HANDOFF.md` | 세션 인계(진행·미완료·결정) | `session-handoff.sh` 자동(gitignore) |
| `DECISIONS.md` | 비가역 결정 로그(append-only) | `changelog` 스킬 |
| `SUCCESS-CRITERIA.md` | 성공 기준 = 지시문 = 채점 기준(블루프린트 §6.1) | `eval-init` / 수동 |
| `checklist.json` · `.checklist-active` | 검증 루프 상태·tombstone | `carve-verify-loop` |
| `eval-score.json` | 골든셋 점수 추이(append-only, prevHash 보호) | `eval-trend.sh` |
| `SCORE.json` | 빌드 건강도 채점표 | `eval-score.sh` |
| `goldenset/` `redteam/` `eval-runs/` | 골든셋 케이스 · 레드팀 셋 · 실행 근거 | 사람 + `/eval` |
| `<기능>/` | SDD 산출물(SPEC→PLAN→SC) | GSD/spec-kit |

> `HANDOFF.md`·`eval-runs/`는 gitignore. 새 기능 계획은 `specs/<기능>/`에 SPEC→PLAN→SC 순으로.
