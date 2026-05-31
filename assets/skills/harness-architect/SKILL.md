---
name: harness-architect
description: >
  이 프로젝트에 맞는 하네스를 구성한다. "이 프로젝트에 맞는 하네스 구성해줘",
  "하네스 세팅", "carve 구성" 같은 요청에 사용. 프로젝트를 분석해 추천 구성요소를
  제시하고, 사용자가 선택한 것만 설치하도록 안내한다(일괄 설치 안 함).
---
# harness-architect — 프로젝트 맞춤 하네스 구성

자연어 트리거 진입점. 다음 순서로 안내한다.

1. **분석**: `npx carve-harness list`로 탐지된 프로젝트 타입과 추천 구성요소를 보여준다.
2. **선택 제시**: 추천 슬롯(코어 스킬·필수 훅·Squad·anti-slop)을 펼쳐 보이고, 무엇이 왜 추천되는지 설명한다.
3. **선택 설치**: 사용자가 고른 것만 `carve install`로 설치한다. **일괄 자동 설치는 하지 않는다.**
4. **CLAUDE.md 셋업**: 설치 후 `carve init-claude`로 작업 지침 베이스라인(`.claude/CLAUDE.md`)과
   탐지 언어 스택의 규칙 묶음(`.claude/rules/techstack·project-structure·commands·code-style·safety·gotchas.md`)을
   생성한다. 루트 `CLAUDE.md`가 이들을 `@import`하도록 자동 연결된다(멱등). 생성 후 프로젝트 실정에 맞게 다듬도록 안내한다.
5. **검증**: `carve doctor`로 구성을 확인하고, 생성된 `flight-rules.md`·`evaluation-criteria.md`를 함께 본다.

> 제약은 권고가 아니라 결정적 훅(exit code 2)으로 강제된다. 위험 명령·비밀 파일은 차단되고,
> 시각·문서 산출물은 anti-ai-slop 게이트로 경고된다.
