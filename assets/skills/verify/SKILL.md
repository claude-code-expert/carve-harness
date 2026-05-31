---
name: verify
description: >
  검증 루프 — build → lint → test → typecheck를 순서대로 돌려 통과시킨다.
  "검증해", "verify", "빌드·테스트 확인", 변경 후 품질 게이트 요청에 사용.
---
# verify — 검증 루프

1. build(있으면) → 2. lint → 3. test → 4. typecheck. 순서대로 실행하고, 실패하면 멈춰 고친 뒤 재실행한다.
- 명령은 프로젝트에서 탐지한다(package.json scripts / flight-rules). 해당 단계가 없으면 건너뛴다.
- 통과 기준: 4단계 모두 green. pass@k가 아니라 pass^k(반복해도 일관 통과)를 목표로 한다.
- 게이트를 통과한 뒤에만 커밋·PR로 진행한다.
