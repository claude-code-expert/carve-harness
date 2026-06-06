# Sprint Contract — {{PROJECT_TYPE}}

> 코딩 *전* "완료"를 합의하는 계약. squad-evaluator가 이 문서를 기준으로 판정한다.

## 목표
- (이번 작업이 무엇을 "완료"로 보는가 — 한두 문장)

## 계획 승인 (Plan Gate)
> 코드 작성 *전* 계획을 분리·검증한다. 추론(왜)과 실행(무엇)을 나눠 먼저 합의한다.
- [ ] 구현 전 계획(Spec/플랜)을 사용자가 명시적으로 승인
- [ ] Plan Quality Score 기록 — MUST 3/3 (미달 시 계획 보완 후 재승인)

## 완료 조건 (Definition of Done)
- [ ] `{{TEST_CMD}}` 통과
- [ ] `evaluation-criteria.md`의 MUST PASS 전부 충족
- [ ] 위험 명령·비밀 노출 0 (검증 훅 통과)
- [ ] 회귀 없음(기존 테스트 유지)

## 범위 밖 (Out of scope)
- (이번 작업에서 다루지 않는 것 — 범위 크리프 방지)
