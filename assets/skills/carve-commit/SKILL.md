---
name: commit
description: >
  Conventional Commit 메시지 생성(빠른 인라인). 스테이지된 변경을 분석해 type(scope): subject 형식의
  커밋 메시지를 만든다. "커밋", "커밋 메시지", "commit" 요청에 사용.
  브랜치·PR·체인지로그 등 깊은 git 워크플로는 squad-gitops 에이전트가 담당한다.
---
# commit — Conventional Commit

1. `git diff --staged`로 변경을 파악한다(스테이지 없으면 무엇을 스테이지할지 먼저 확인).
2. `type(scope): subject` 형식. type ∈ feat/fix/docs/refactor/test/chore/perf.
3. subject는 명령형·72자 이내. 본문은 "왜"를 설명.
4. 커밋은 사용자가 요청할 때만. 기본 브랜치면 먼저 브랜치를 만든다.
