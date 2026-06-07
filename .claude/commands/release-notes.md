---
name: release-notes
description: carve-harness 리포의 변경 이력을 갱신한다 — CHANGELOG 작성 → README Update 영역 한 줄 추가(한/영). What's New는 폐지.
argument-hint: "<version> [요약할 변경 맥락/마일스톤]"
allowed-tools:
  - Read
  - Edit
  - Bash
  - Glob
  - Grep
---

`release-notes` 스킬을 적용해 변경 이력을 갱신한다. 고정 순서(① CHANGELOG.md → ② README.md Update 한 줄 → ③ README.en.md Update 한 줄, 한/영 락스텝)와 가드레일(추측 금지·커밋/푸시 금지)을 스킬 그대로 따른다.

`$ARGUMENTS`의 첫 토큰을 버전(예: `1.2.2`), 나머지를 요약 맥락으로 해석한다.

$ARGUMENTS
