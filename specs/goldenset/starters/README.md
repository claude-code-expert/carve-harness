# `specs/goldenset/starters/` — 언어팩 골든셋 스타터

언어팩마다 4건씩(python·typescript·java·go·rust), 전부 상태 assert. `/eval-init`이 **시드로 복사**해 궤적 검사 후 프로젝트 골든셋에 편입한다. 이 파일들은 하네스 자산이라 **수정하지 않는다**(update로 덮인다).

- 하위 디렉토리에 둔 이유: 하네스 자신의 `/eval`(`specs/goldenset/*.json`) 글롭에 안 걸리게.
- 케이스 4종: 버그 수정+검증 · 테스트가 변이를 잡나 · 빈 입력 안 지어내기 · 시크릿 안 넣기.
- 런타임 외 의존 0(python3 / node≥22.18 / JDK / go / cargo). 툴체인 없으면 케이스가 0점(조용한 통과 없음).

> 전건 `carve-validate --red`(사전 실패) + 정답 green 검증. `tests/goldenset-starters.test.sh`.
