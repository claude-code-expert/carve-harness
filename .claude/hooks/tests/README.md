# `.claude/hooks/tests/` — 훅 어서션 스위트

훅·스크립트·설치기의 동작을 `bash`만으로 검증한다. `npm test`(= `run-all.sh`)가 전량 실행하고, `stop-verify.sh` Bash 게이트가 훅 변경 시 자동으로 돌린다. CI(`.github/workflows/ci.yml`)도 같은 러너를 쓴다.

- 파일당 한 스위트: `<대상>.test.sh`. 차단은 exit 2, 통과는 exit 0을 어서션.
- 툴체인이 없어도 돌도록 **PATH 스텁**으로 `gradlew`·`go`·`pytest` 등을 흉내 낸다(게이트 로직만 검증).
- `run-all.sh`가 `CLAUDE_PROJECT_DIR`를 임시 로그 디렉토리로 격리 — 테스트 판정이 실관측 로그를 오염시키지 않는다.

> 규칙: 로직을 재구현하지 말고 **실제 코드를 추출·실행**한다(드리프트 가드). 예: `carve-eval.test.sh`가 워크플로의 배선을, `eval-score.test.sh`가 실제 상수를 검사.
