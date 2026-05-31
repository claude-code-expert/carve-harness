---
name: changelog
description: >
  CHANGELOG 생성·갱신. Keep a Changelog 형식으로 미릴리스 변경을 정리한다.
  "체인지로그", "changelog", "릴리스 노트" 요청에 사용.
---
# changelog — CHANGELOG 갱신

- Keep a Changelog 형식: `## [Unreleased]` 아래 Added/Changed/Fixed/Removed.
- 커밋 히스토리(`git log`)에서 사용자 영향이 있는 변경만 추린다(내부 리팩터 제외).
- 릴리스 시 `[Unreleased]`를 버전·날짜로 고정한다.
