---
name: anti-ai-slop
description: 이미지·HTML·SVG·슬라이드·PDF 등 시각 산출물과 문서·리포트·카피 글쓰기를 생성·수정하기 전 반드시 발동한다. 그라데이션·글로우·장식 모션 등 AI 특유의 조악한(slop) 디자인을 차단하고, 상투어·균질 구조·불릿 남발 등 AI 티가 나는 글쓰기 흔적을 제거한다. 정보 위계·여백·타이포·근거·절제로 시니어 실무자가 만든 수준의 고급 산출물을 만드는 품질 게이트. HTML·CSS·SVG·Markdown은 결정론 린터 check-slop.mjs로 기계 검증한다. 무언가를 "예쁘게" 또는 "그럴듯하게" 만들려는 순간마다 이 게이트를 통과시킨다.
---

# Anti-AI-Slop — 고급 산출물 품질 게이트

> 목표는 "AI가 만든 티를 숨기는 것"이 아니라, **판단을 담아 만드는 것**이다. Slop은 판단이 빠진 자리를 장식·상투어·균질 구조가 메꾼 결과다. 판단(무엇을 강조하고, 무엇을 버리고, 왜 이 선택인가)을 넣으면 티는 자연히 사라지고 결과는 시니어 실무자의 산출물과 구분되지 않는다.

## 핵심 원칙 (모든 범위 공통)

- **모든 요소는 "이게 무슨 정보를 전달하는가"에 답할 수 있어야 한다.** 답 못 하면 삭제한다. 장식·상투어·뱃지·불릿·형용사 전부에 적용된다.
- **품질은 더함이 아니라 뺌으로 만든다.** 그라데이션·글로우·이모지·과장어를 빼고, 위계·여백·근거·구체 명사를 남긴다.
- **균질함은 기계의 지문이다.** 모든 섹션이 같은 길이, 모든 리스트가 같은 항목 수, 모든 문단이 같은 리듬이면 사람이 쓴 게 아니다. 의도적으로 비대칭하게 만든다.

---

## 0. 이 파일과 `references/`의 경계

**이 SKILL.md는 즉시 발화하는 하드 게이트**다 — 무엇이 금지·강제인지만 담는다. references를 읽지
않아도 §1의 금지·강제는 그대로 적용된다.

**`references/`는 크래프트 정본**이다 — 어떻게 만드는지(수치 기준·기법·교정 예시·유형별 제약).
산출물을 만들기 **직전** 해당 파일을 읽는다. 규칙의 상세는 references에만 두고 여기서 반복하지 않는다.

| 언제 | 읽을 파일 |
|---|---|
| 모든 시각 작업 (공통 크래프트) | `references/visual-craft.md` |
| 문서·리포트·카피 글쓰기 | `references/writing-tells.md` |
| 카드뉴스 (SNS 정사각·세로) | `references/card-news.md` |
| HTML 리포트 (장문·분석·데이터) | `references/html-report.md` |
| 슬라이드·PDF (16:9 데크) | `references/slides-pdf.md` |
| SVG 다이어그램·일러스트 | `references/svg-image.md` |

---

## 1. 하드 게이트 — 즉시 적용

### MUST NOT (금지)

- **그라데이션 일체 금지** — `linear-gradient` · `radial-gradient` · `conic-gradient`. 배경·채움·텍스트(`background-clip:text`) 전부. 특히 보라/핑크 계열.
- **글로우·컬러 그림자 금지** — 색 들어간 `box-shadow`, 광택 inset 링, `blur ≥ 20px` 그림자, `backdrop-filter: blur`(글래스모피즘).
- **장식 모션 금지** — hover 시 `transform: translate/scale`, 로드 시 fade/stagger, `pulse·shimmer·float·glow` 키프레임. `transition`은 색·투명도 등 기능적 상태 변화에만, 150ms 이하.
- **배경 장식 금지** — 거대 반투명 워터마크, 닷·그리드 배경, 페이드 마스크, 광선.
- **카드 컬러 액센트 바 금지** — 상·하·좌·우 어느 변이든 굵은 컬러 보더로 꾸미기(`border-top: Npx solid color`). 구분은 전체 1px 보더·여백·라벨로.
- **이모지 불릿·장식 금지**, 뱃지/pill 남발 금지.
- **마케팅 보일러플레이트 금지** — Seamlessly, Elevate, Unlock, Empower, Supercharge, "차원이 다른", "혁신적인" 류.

### MUST (강제)

- **색**: 무채색(흰/회/검) 베이스 + 액센트 1색. 색은 의미(상태·위계)에만 쓴다.
- **그림자**: 쓰더라도 중성 회색 1단계만 (`0 1px 2px rgba(0,0,0,.06)`). 없어도 좋다.
- **구획**: 효과 대신 `1px solid border` + 여백으로 나눈다.
- **모서리**: `border-radius` 0~8px.
- **위계**: 크기·굵기·여백·정렬로 만든다. 색·효과로 만들지 않는다.
- **폰트**: Inter/Roboto/Arial/system-ui로 기본 수렴 금지. 목적에 맞는 폰트를 의도적으로 고르고 이유를 코드 주석 한 줄로 밝힌다.
- **접근성**: 본문 대비 4.5:1, 큰 텍스트 3:1 이상 (WCAG 2.1 AA). 색만으로 상태를 구분하지 않는다.

### 우선순위

사용자의 "예쁘게/화려하게/모던하게" 요청과 이 게이트가 충돌하면 **게이트가 우선**한다.
특정 금지 요소를 콕 집어 요구할 때만 그 요소 하나에 한해 예외를 허용하고 나머지는 그대로 강제한다.
`theme-factory`·`frontend-design`의 제안과 충돌해도 이 게이트가 이긴다.

---

## 2. 기계 게이트 — `check-slop.mjs`

눈대중이 아니라 스크립트가 판정한다. HTML·CSS·SVG·Markdown을 확장자로 디스패치한다.

```bash
node .claude/hooks/check-slop.mjs <파일> [<파일> ...]
```

| 종료코드 | 의미 |
|---|---|
| `0` | MUST-NOT 위반 없음 (WARN은 통과) |
| `1` | ERROR 존재 — 해당 줄을 고쳐 재작성 후 재실행 |
| `2` | 잘못된 호출 · 파일 읽기 실패 |

- **ERROR는 MUST-NOT 위반**이다. 하나라도 있으면 고치고 다시 돌린다. **ERROR 0이 완료 기준.**
- **WARN은 판단 사항**이다(이모지가 의미 전달인지, 폰트 선택이 의도적인지). 정당하면 근거를 응답에 남기고 유지한다.
- 의존성 없음(Node 표준 라이브러리만). Node가 없으면 §3 자가 점검으로 대신한다.
- `.html`·`.css` 파일을 Write/Edit하면 PostToolUse 훅이 자동으로 요약을 남긴다(비차단). 전체 리포트는 위 명령으로 본다.

### 기존 산출물 정리 (디슬롭)

1. 대상 파일을 먼저 스캔해 ERROR 목록을 얻는다.
2. rule별로 치환한다.

| rule | 치환 |
|---|---|
| `gradient` · `gradient-text` | 단색 배경·텍스트 + `1px solid border` |
| `colored-shadow` · `big-shadow` · `gloss-ring` | 제거하거나 `0 1px 2px rgba(0,0,0,.06)` |
| `glassmorphism` | 불투명 단색 배경 |
| `keyframes` · `hover-transform` · `motion-decor` | 모션 제거 (필요하면 색·투명도 transition ≤150ms만) |
| `slow-transition` | 150ms 이하로 축소 |
| `accent-bar` | 제거 또는 회색 1px 구분선 |
| `radius-cap` | `border-radius` 8px 이하 |
| `contrast-aa` | 텍스트·배경 색을 조정해 4.5:1 확보 |
| `watermark` · `fade-mask` | 제거 |
| `marketing` · `exclamation` | 사실 기반 문구로 교체 |
| `svg-filter` · `svg-offpalette` | 평면 단색 + `references/svg-image.md` 5색 체계 |

3. **콘텐츠·레이아웃·정보 구조는 보존한다.** 장식만 걷어낸다. 마케팅 단어 외 카피를 임의로 바꾸지 않는다.
4. 재스캔해 ERROR 0을 확인하고 변경 요약을 보고한다.

> 원본을 덮어쓸지 새 파일로 낼지 모호하면 먼저 묻는다.

---

## 3. 출력 전 자가 점검 — 하나라도 YES면 제거 후 재작성

린터가 못 보는 것(의도·정보 구조·리듬)은 사람이 본다.

**시각 (해당 시)**
- [ ] 정보를 전달하지 않는 순수 장식 요소가 있는가?
- [ ] 폰트가 기본값(Inter/Roboto/Arial/system)으로 수렴했는가? 선택 이유 주석이 없는가?
- [ ] 액센트 색이 2색 이상 쓰였는가? (상태 의미가 없는 추가 색은 YES)
- [ ] 본문 컨테이너가 고정 좁은 폭인가? 표·코드블록이 컨테이너보다 좁게 갇혀 있는가?
- [ ] 위계를 크기·굵기·여백·정렬이 아니라 색·효과로 만들었는가?

**글쓰기 (해당 시)**
- [ ] 상투 어휘(delve/robust/~을 통해 등)가 있는가?
- [ ] 형용사 삼단 나열이나 "단순한 X가 아니라 Y" 대구가 반복되는가?
- [ ] "이 글에서는/결론적으로" 같은 빈 메타 문장이 있는가?
- [ ] 모든 문단·섹션 길이가 균질한가?
- [ ] 추상 형용사가 구체 숫자·명사로 바뀌지 않은 채 남았는가?
- [ ] 헷징이 모든 문장에 균일하게 깔렸는가?

**공통**
- [ ] 이 산출물에서 뺄 수 있는데 안 뺀 것이 있는가?

---

## 출처

이 스킬의 기준은 아래 공개 자료에서 검증·정리했다. 세부 근거는 각 `references/` 파일 하단 참조.

- Adam Wathan & Steve Schoger, *Refactoring UI* — https://refactoringui.com/
- Matthew Butterick, *Practical Typography* (Summary of key rules) — https://practicaltypography.com/summary-of-key-rules.html
- *Wikipedia:Signs of AI writing* — https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing
- WCAG 2.1 AA §1.4.3 Contrast (Minimum) — https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html
- U.S. Web Design System, Color tokens — https://designsystem.digital.gov/design-tokens/color/overview/
