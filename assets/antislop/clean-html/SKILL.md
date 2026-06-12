---
name: clean-html
description: >
  AI 슬롭(gradient, 글로우 그림자, 글래스모피즘, 모션 장식, 워터마크, 마케팅 문구 등)을
  제거한 절제된 프로덕션 HTML을 생성하거나, 기존 HTML에서 그 요소들을 걷어낸다.
  규칙은 상위 anti-ai-slop 마스터 스킬(.claude/skills/SKILL.md)이 단일 출처.
  Use when the user says "AI 요소 제거한 html 만들어", "anti-ai-slop", "슬롭 없는 UI/HTML",
  "이 html 정리/디슬롭 해줘", "clean HTML 생성", or asks to generate/clean frontend HTML
  that must avoid the generic "AI-generated" look. 생성·수정 후 반드시 check-slop.mjs로 게이트한다.
  규칙의 단일 출처는 상위 anti-ai-slop 마스터 스킬(.claude/skills/SKILL.md).
allowed-tools: Read, Write, Edit, Bash(node:*), Bash(ls:*), Bash(mkdir:*), Bash(open:*), Bash(grep:*)
---

# clean-html — Anti-AI-Slop HTML 생성 / 정리

## 이 스킬이 존재하는 이유

"HTML 만들어줘"라고 하면 LLM은 매번 같은 방향으로 흐른다 — 보라/핑크 그라데이션, 컬러 글로우 그림자, 글래스모피즘, hover 시 떠오르는 카드, ✨ 이모지, "Seamlessly Elevate" 류 마케팅 문구. 이게 **AI 슬롭(slop)** 이다. 예뻐 보이려는 장식일 뿐, 정보를 전달하지 않는다.

이 스킬은 두 가지를 보장한다.
1. **생성** 시 절제된 프로덕션 UI 규칙(아래)을 강제한다.
2. 출력 전 **결정론적 린터**(`scripts/check-slop.mjs`)로 자가 점검을 통과시킨다. 모델의 눈대중이 아니라 스크립트가 게이트한다.

> 규칙의 단일 출처는 상위 anti-ai-slop 마스터 스킬 `.claude/skills/SKILL.md`(전역 규칙 §2~§4). 큰 변경 전 반드시 그 파일을 먼저 읽는다. 이 SKILL.md는 운영 체크리스트다. 린터는 HTML/CSS·SVG·Markdown을 확장자로 디스패치한다.

## 핵심 원칙

> 위계는 **크기·굵기·여백·정렬·타이포**로 만든다. 색·효과로 만들지 않는다.
> 모든 시각 요소는 "이게 어떤 정보를 전달하는가"에 답할 수 있어야 한다. 답할 수 없으면 삭제한다.

## 금지 (MUST NOT)

| 분류 | 금지 대상 | linter rule |
|---|---|---|
| 그라데이션 | `linear/radial/conic-gradient`, 그라데이션 텍스트(`background-clip:text`) | `gradient`, `gradient-text` |
| 그림자/광택 | 색이 들어간 `box-shadow`, blur/offset ≥ 20px, inset 광택 링, `backdrop-filter:blur` | `colored-shadow`, `big-shadow`, `gloss-ring`, `glassmorphism` |
| 모션 장식 | `@keyframes`(pulse/shimmer/float/glow/fade…), hover 시 `transform: translate/scale`, 150ms 초과 transition | `keyframes`, `hover-transform`, `motion-decor`, `slow-transition` |
| 배경 장식 | 거대 반투명 워터마크, 닷·그리드 배경, 페이드 마스크 | `watermark`, `fade-mask` |
| 타이포 | font-size < 10px, 본문 행간 < 1.4, 헤딩 레벨 건너뛰기·h1 다중 | `tiny-font`, `line-height-body`, `heading-skip`, `multi-h1` |
| 대비 | 본문 텍스트/배경 대비 < 4.5:1 (3.0 미만은 ERROR, 대형 텍스트는 3:1) | `contrast-aa` |
| 레이아웃 | `border-radius` > 8px, 동일 radius 남발, 만능 중앙정렬, 유채색 3종+ | `radius-cap`, `pill`, `uniform-radius`, `centered-everything`, `multi-accent` |
| 카피 톤 | 느낌표 남발, 최상급/주관 수식어, "단순한 X가 아니라 Y" 문형, AI 상투어구, 무공백 em-dash | `exclamation`, `superlative`, `ai-contrast`, `ai-stock-phrase`, `em-dash` |
| 기타 | 카드 상단 컬러 액센트 바, 이모지 불릿/장식, 마케팅 보일러플레이트 | `accent-bar`, `emoji`, `marketing` |

transition은 색·투명도 등 **기능적 상태 변화**에만, **150ms 이하**로 한정.

## 강제 (MUST)

- **색**: 무채색(흰/회/검) 베이스 + **액센트 1색**. 색은 의미(상태·위계)에만.
- **그림자**: 쓰더라도 중성 회색 1단계 (`0 1px 2px rgba(0,0,0,.06)`). 없어도 좋다.
- **구분**: 효과 대신 `1px solid border` + 여백으로 구획.
- **border-radius**: 0~8px.
- **폰트**: Inter·Roboto·Arial·system-ui·Space Grotesk로 기본 수렴 금지. 목적에 맞는 폰트를 **의도적으로 선택**하고 그 이유를 한 줄로 밝힌다.

## 워크플로 A — 생성 (clean HTML 만들기)

1. 요구사항을 받는다(콘텐츠·용도). 무엇을 전달하는 화면인지 먼저 정리한다.
2. 위 MUST/MUST NOT를 지키며 HTML/CSS를 작성해 **파일로 저장**한다.
   - 폰트를 고르고 *왜 그 폰트인지* 한 줄 근거를 코드 주석 또는 응답에 남긴다.
   - 색은 무채색 + 액센트 1색으로 토큰화(`--accent: …`)한다.
3. **게이트**: `node .claude/skills/clean-html/scripts/check-slop.mjs <파일>`
4. ERROR가 하나라도 있으면 그 줄을 고쳐 재작성 → 다시 3번. **ERROR 0이 될 때까지 반복.**
5. WARN은 판단 사항(이모지가 의미 전달인지, 폰트 선택이 의도적인지). 정당하면 응답에 근거를 적고 남긴다.
6. 결과 보고: 파일 경로, 고른 폰트와 근거, 최종 linter 결과(`0 error`).

## 워크플로 B — 디슬롭 (기존 HTML 정리)

1. `node .claude/skills/clean-html/scripts/check-slop.mjs <대상.html>` 로 먼저 스캔.
2. 리포트의 ERROR를 rule별로 치환:
   - `gradient` → 단색 배경 + `1px solid border`
   - `colored-shadow`/`big-shadow`/`gloss-ring` → 제거하거나 `0 1px 2px rgba(0,0,0,.06)`
   - `glassmorphism` → 불투명 단색 배경
   - `keyframes`/`hover-transform`/`motion-decor` → 모션 제거(필요하면 색·투명도 transition ≤150ms만)
   - `gradient-text` → 단색 텍스트
   - `accent-bar` → 제거 또는 회색 `1px` 구분선
   - `marketing` → 사실 기반 문구로 교체
   - `watermark`/`fade-mask` → 제거
3. **콘텐츠·레이아웃·정보 구조는 보존**한다. 장식만 걷어낸다. 마음대로 카피를 바꾸지 말 것(마케팅 단어 외).
4. 재스캔 → ERROR 0 확인 → 변경 요약 보고.

> Edit/Write로 대상 파일을 직접 수정하기 전에, 원본을 덮어쓰는 게 맞는지 확인한다. 새 파일로 출력할지 in-place로 고칠지 모호하면 사용자에게 묻는다.

## 린터 사용법

```bash
# 한 파일 또는 여러 파일
node .claude/skills/clean-html/scripts/check-slop.mjs path/to/page.html
node .claude/skills/clean-html/scripts/check-slop.mjs a.html b.html c.css
```

- 종료 코드 **0** = MUST-NOT 위반 없음(WARN은 통과), **1** = ERROR 존재, **2** = 잘못된 호출/읽기 실패.
- 의존성 없음(Node 표준 라이브러리만). HTML·CSS 파일 모두 스캔 가능.
- 휴리스틱이라 일부 WARN(emoji/watermark/font-default)은 오탐일 수 있다 — 판단해서 남기거나 제거.

## 자가 점검 (출력 전 통과 필수)

`check-slop.mjs`가 자동 점검하지만, 출력 직전 사람이 다시 확인한다. 하나라도 YES면 제거 후 재작성.

- [ ] gradient(any)가 있는가?
- [ ] 색이 들어간 그림자 또는 blur ≥ 20px 그림자가 있는가?
- [ ] hover/load에 transform·fade·키프레임 애니메이션이 있는가?
- [ ] 콘텐츠와 무관한 배경 장식(워터마크/그리드/광선)이 있는가?
- [ ] 정보를 전달하지 않는 순수 장식 요소가 있는가?
- [ ] 폰트가 Inter/Roboto/Arial/system 기본값으로 수렴했는가?

## 주의

- 이 스킬은 **범용 프론트엔드 HTML**용이다. 슬라이드 데크(`docs/html/presentation/*`)는 자체 디자인 시스템(다크 테마·앰버 액센트)을 의도적으로 쓰므로 이 린터의 대상이 아니다. 데크 작업은 `md-to-slidedeck` / `export-html-deck`를 사용한다.
