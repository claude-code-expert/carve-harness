---
name: pr
description: >
  PR 본문 생성·생성. 브랜치 변경을 요약해 PR 설명을 만들고 gh로 PR을 연다.
  "PR 만들어", "PR 본문", "풀리퀘스트" 요청에 사용.
---
# pr — Pull Request

1. base 대비 변경(`git log`, `git diff`)을 요약한다.
2. 본문: 요약 / 변경사항 / 테스트 방법 / 관련 이슈.
3. `gh pr create`로 연다(원격·인증 확인). 푸시·PR 생성은 사용자 요청 시.
