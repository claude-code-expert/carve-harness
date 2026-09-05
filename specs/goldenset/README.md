# `specs/goldenset/` — 골든셋 (고정 케이스 은행)

`/eval`이 재채점하는 고정 입력→기대 케이스. 프롬프트·규칙·모델을 바꾼 뒤 "더 나빠지지 않았는지"를 숫자로 본다. 형식·판정 기준 정본은 `eval-goldenset` 스킬.

- 케이스: `{id, version, prompt, setup, k, tags, assert:[{type,value}]}`. assert 3계층 — 텍스트(contains/regex)·상태(file_exists·cmd_exit0·log_contains…)·정성(llm-rubric).
- `tags:["required"]` 케이스는 100점 아니면 게이트가 평균 무관 차단. `version`은 케이스를 고칠 때 올린다.
- 이 리포 실물 20건: `carve-harness`·`harness-guard`(required)·`harness-craft`·`harness-hard` 각 5.
- `starters/`는 언어팩 스타터(하네스 자산) — `/eval` 글롭 밖. 아래 README 참고.

> 작성·검수: `carve-validate.sh --red`(구조+신호), 정답 상태 green 양방향 확인. 자동 확정 금지(사람 검수).
