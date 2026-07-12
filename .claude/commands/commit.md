---
description: 현재 브랜치에 fetch→pull→commit→push. 인자를 커밋 메시지로 사용
argument-hint: "<commit message>"
disable-model-invocation: true
---

`/commit <메시지>` — 현재 브랜치에서 순수 git만 순서대로 실행한다:

```bash
git fetch
git pull --rebase                 # 원격 먼저 통합(푸시 거부 예방; fetch 포함)
git add -u                        # 스테이징된 게 없으면 tracked 변경만 담는다
git commit -m "$ARGUMENTS"        # 인자를 그대로 커밋 메시지로
git push
```

- 현재 브랜치가 `main`/`master`면 **중단**(기본 브랜치 직접 푸시 금지 → feature/develop).
- `$ARGUMENTS`가 비면 **중단**하고 `/commit <메시지>`로 안내.
- git 에러가 나면 **원문 그대로 + 원인·해결 한 줄**을 보고하고 멈춘다.
- `--no-verify`·`push --force`·히스토리 재작성 금지(pre-commit·commit-msg 게이트는 그대로 통과해야 함).
