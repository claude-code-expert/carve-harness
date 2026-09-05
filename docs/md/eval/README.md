# `docs/md/eval/` — 평가 체계 단계 리포트 (P0~P3)

`specs/eval-generalization-plan.md`의 각 단계 구현 기록. 파일당: 구성 · 구현 메모 · 사용방법 · 완료 기준(SC) 검증 · 한계.

| 리포트 | 단계 |
|---|---|
| `P0-eval-trend.md` | 추이 파일 결정론 읽기·append(prevHash 보호) |
| `P1a-eval-run.md` | target 어댑터 + 근거 파일 + `log_contains` |
| `P1-gates.md` | required 태그·suspicious·stale 게이트 판정 |
| `P2-veto-criteria.md` | `domain_safety` 거부권 + SUCCESS-CRITERIA |
| `P3-redteam.md` | 가드레일 자기평가 |
