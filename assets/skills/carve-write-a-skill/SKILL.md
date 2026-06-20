---
name: write-a-skill
description: >
  재사용 가능한 에이전트 스킬(SKILL.md)을 만든다. "스킬 만들어", "write a skill",
  하네스 확장 요청에 사용. description에 발화 트리거를 명시하는 것이 핵심.
---
# write-a-skill — 스킬 작성

> mattpocock/skills(MIT)의 write-a-skill 패턴에서 영감.

절차: 요구사항 수집 → 초안 작성 → 사용자 검토.
구조: `SKILL.md`(본문) + 선택 `references/` + 선택 `scripts/`.
원칙:
- **description은 에이전트가 보는 전부** — "Use when [구체 트리거]" 형태로 발화 조건을 명시한다.
- SKILL.md 본문은 100줄 이하. 길면 `references/`로 분리(Progressive Disclosure).
- 반복 작업은 결정적 스크립트로. 추상 설명보다 구체 예시.
검토 체크: 트리거가 description에 있는가? 초점이 한 가지인가? 예시가 구체적인가?
