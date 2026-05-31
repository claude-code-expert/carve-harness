---
name: harness-audit
description: >
  설치된 하네스 자체를 점검한다. "하네스 점검", "harness audit", "설치 상태 확인" 요청에 사용.
  carve doctor + settings 훅 등록·자산 정합·셸 문법을 확인한다.
---
# harness-audit — 하네스 자기 점검

1. `carve doctor`로 설치 자산·훅·백업 수를 확인한다.
2. `.claude/settings.json`에 carve 훅이 이벤트별로 등록됐는지 확인한다.
3. 설치된 훅의 셸 문법(`bash -n`)과 실행 권한을 점검한다.
4. `flight-rules.md`·`evaluation-criteria.md`·`sprint-contract.md` 존재를 확인한다.

발견한 이슈는 우선순위로 보고하고, 재설치(`carve install`)나 수정으로 교정한다.
