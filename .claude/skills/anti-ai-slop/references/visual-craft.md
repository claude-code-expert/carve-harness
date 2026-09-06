# visual-craft — 시각 크래프트 상세 기준

> `SKILL.md` §1이 **하드 게이트**(무엇을 금지·강제하는가)라면, 이 파일은 **크래프트**(그래서 어떻게
> 만드는가)다. 게이트를 통과한 다음 품질을 만드는 단계에서 읽는다. 규칙 문장은 SKILL.md에 두고,
> 여기서는 반복하지 않는다.
>
> 기계 검증: `node .claude/hooks/check-slop.mjs <파일>` — 이 문서의 수치 기준 중 자동 판정
> 가능한 것은 린터 룰로 구현돼 있다. 룰 id를 각 절에 병기했다.

---

## 1. 위계는 네 가지로만 만든다

색·효과가 아니라 **크기 · 굵기 · 여백 · 정렬**. 이 넷으로 안 되면 정보 구조가 잘못된 것이지
장식이 부족한 게 아니다.

| 도구 | 쓰는 법 | 흔한 실패 |
|---|---|---|
| 크기 | 단계를 크게 벌린다(1.25배 미만은 차이로 안 읽힘) | 16→17px 같은 무의미한 차이 |
| 굵기 | 400 본문 / 700 강조. 500·600을 섞어 4단계 만들지 않는다 | 굵기 5종 남발 |
| 여백 | 관련된 것은 붙이고 무관한 것은 띄운다(근접성) | 상하 여백을 균등하게 줘서 그룹이 안 보임 |
| 정렬 | 축을 하나로 유지. 본문은 좌측 정렬 | 만능 중앙정렬 (`centered-everything`) |

**근접성 원칙**: 요소 사이 여백은 "위 요소와의 거리 < 아래 요소와의 거리"가 되도록 준다.
제목의 `margin-top`은 `margin-bottom`보다 항상 크다.

```css
h2 { margin: 40px 0 12px; }   /* 위 40 / 아래 12 — 제목이 아래 본문에 붙는다 */
```

## 2. 타입 스케일

한 문서에 크기 단계를 **5~6개**로 제한한다. 비율은 1.25(Major Third) 또는 1.333(Perfect Fourth)
중 하나를 골라 끝까지 유지한다. 임의 픽셀값을 그때그때 만들지 않는다.

**1.25 스케일 (기본 권장 — 조밀한 UI·리포트)**

| 역할 | px | line-height |
|---|---|---|
| 캡션·라벨 | 13 | 1.4 |
| 본문 | 16 | 1.6~1.7 |
| 소제목 (h3) | 20 | 1.4 |
| 제목 (h2) | 25 | 1.3 |
| 대제목 (h1) | 32 | 1.2 |
| 디스플레이 | 40 | 1.1 |

규칙:
- **본문은 16px 이상.** 14px 본문은 데스크톱에서도 피로하다. (`tiny-font`: 10px 미만 ERROR, 12px 미만 WARN)
- **행간은 크기에 반비례.** 본문 1.6~1.7, 제목 1.1~1.3. 본문 1.4 미만은 가독성 경고. (`line-height-body`)
- **자간은 큰 글자에서만 음수.** 32px 이상에 `letter-spacing: -.02em`. 본문 자간은 건드리지 않는다.
- 대문자·`letter-spacing: .08~.18em` 조합은 **작은 라벨(11~13px)에만**. 문장에 쓰지 않는다.

## 3. 8pt 그리드

여백·크기를 **8의 배수**로 통일한다(미세 조정이 필요한 곳만 4). 값이 `13px`·`22px`·`37px`처럼
흩어지면 그것 자체가 기계의 지문이다.

```
허용:  4 · 8 · 12 · 16 · 24 · 32 · 40 · 48 · 64 · 96
```

- 컴포넌트 내부 패딩: 12~24
- 컴포넌트 사이 간격: 24~40
- 섹션 사이 간격: 64~96
- 본문 좌우 패딩: 20(모바일) / 32~40(데스크톱)

토큰으로 고정하고 리터럴을 흩뿌리지 않는다.

```css
:root { --s1:4px; --s2:8px; --s3:16px; --s4:24px; --s5:40px; --s6:64px; }
```

## 4. 색

무채색 베이스 + **액센트 1색**. 액센트는 "여기를 봐라"가 아니라 **의미**(상태·판정·분류)에만 쓴다.
유채색이 3종 넘게 등장하면 의미 체계가 없다는 뜻이다. (`multi-accent`)

**중립 램프 (예시 — 프로젝트 토큰으로 교체 가능)**

| 역할 | hex | 용도 |
|---|---|---|
| ink | `#111111` | 본문 텍스트 |
| ink-muted | `#6B7280` | 캡션·보조 |
| border | `#E5E7EB` | 구분선·테두리 |
| surface | `#F8F7F4` | 콜아웃·코드 배경 |
| base | `#FFFFFF` | 페이지 배경 |

**대비 (WCAG 2.1 AA — `contrast-aa`)**
- 본문 텍스트 **4.5:1** 이상, 대형 텍스트(24px 이상 또는 19px+bold) **3:1** 이상
- 3.0 미만은 ERROR — 어떤 근거로도 통과시키지 않는다
- **색만으로 상태를 구분하지 않는다.** 색 + 라벨/아이콘/텍스트를 함께 준다(색각 이상 대응)

흰 배경 위 `#6B7280`은 4.83:1로 본문에 쓸 수 있지만, `#9CA3AF`(2.54:1)는 캡션에도 못 쓴다.

## 5. 구획 — 효과 대신 선과 여백

```css
/* GOOD — 1px 보더 + 여백 */
.card { border: 1px solid var(--border); border-radius: 8px; padding: 20px; }

/* BAD — 그림자로 띄우고 라운드를 키워 "카드처럼" 보이게 */
.card { box-shadow: 0 8px 24px rgba(37,99,235,.25); border-radius: 16px; }
```

- `border-radius`는 **0~8px**. 8 초과는 ERROR(`radius-cap`). pill·원형은 아바타·태그 등 의도가 분명할 때만(`pill`)
- 그림자는 쓰더라도 중성 회색 1단계: `0 1px 2px rgba(0,0,0,.06)`. 색이 들어가면 ERROR(`colored-shadow`), blur/offset 20px 이상이면 ERROR(`big-shadow`)
- 한 문서에서 radius가 5곳 이상 전부 같은 값이면 위계 없이 기본값을 복사한 것이다(`uniform-radius`)

## 6. 폰트 선택

기본 수렴(Inter·Roboto·Arial·system-ui·Space Grotesk·Helvetica Neue)을 피하고 **목적에 맞는 폰트를
의도적으로 고른 뒤 이유를 코드 주석 한 줄로 남긴다**. 주석이 없으면 선택이 아니라 기본값이다.
(`font-default` — WARN, 주석 유무는 사람이 판단)

| 용도 | 권장 | 이유 |
|---|---|---|
| 한글 본문 | `Pretendard` · `Noto Sans KR` | 한/영/숫자 폭 정합, 웹폰트 안정 |
| 코드·수치 | `JetBrains Mono` · `IBM Plex Mono` | 0/O·1/l 구분, 표 숫자 정렬 |
| 장문 산문 | `Source Serif` · `Noto Serif KR` | 긴 호흡 가독성 |
| PNG 내보내기(한글) | `Noto Sans CJK KR` | 헤드리스 렌더에서 한글 누락 방지 |

```css
/* 폰트: 한/영/숫자 폭이 맞아 표 정렬이 어긋나지 않는 Pretendard, 수치는 JetBrains Mono */
body { font-family: 'Pretendard', sans-serif; }
```

## 7. 모션

기능적 상태 변화(색·투명도)에만, **150ms 이하**. 그 외 전부 금지.

```css
/* GOOD */ a { transition: color 120ms ease; }
/* BAD  */ .card { transition: all .3s; }              /* slow-transition + transition-scope */
/* BAD  */ .card:hover { transform: translateY(-4px); } /* hover-transform */
/* BAD  */ @keyframes pulse { … }                       /* keyframes + motion-decor */
```

`prefers-reduced-motion`을 존중한다 — 애초에 장식 모션이 없으면 문제되지 않는다.

## 8. 레이아웃 폭

본문 컨테이너는 뷰포트에 비례해 채운다. 고정 좁은 폭은 데스크톱에서 여백만 남긴다.

```css
.wrap { width: min(96vw, 1680px); margin: 0 auto; padding: 56px 40px 96px; }
@media (max-width: 1120px) { .wrap { width: 100%; padding: 32px 20px 64px; } }
```

- 데스크톱 실효 폭 **1080px 이상**을 보장한다
- 표·`pre`·`img`·`svg`는 컨테이너 전폭을 쓴다. 개별 `max-width`로 다시 가두지 않는다
- 장문 산문 전용 문서에 한해 `p { max-width: 100ch }`까지 허용
- 임베드(iframe `srcdoc`) 대상 HTML은 폭 고정 규칙이 다르다 → `carve-guide` §3

## 9. 산출물 유형별 추가 기준

전역 게이트를 통과한 뒤, 만들려는 유형의 파일을 추가로 읽는다.

| 유형 | 파일 |
|---|---|
| 카드뉴스 (SNS 정사각/세로) | `card-news.md` |
| HTML 리포트 (장문·분석·데이터) | `html-report.md` |
| 슬라이드·PDF (16:9 데크) | `slides-pdf.md` |
| SVG 다이어그램·일러스트 | `svg-image.md` |

---

## 출처

- Adam Wathan & Steve Schoger, *Refactoring UI* — https://refactoringui.com/
- Matthew Butterick, *Practical Typography*, Summary of key rules — https://practicaltypography.com/summary-of-key-rules.html
- WCAG 2.1 AA §1.4.3 Contrast (Minimum) — https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html
- WCAG 2.1 AA §1.4.1 Use of Color — https://www.w3.org/WAI/WCAG21/Understanding/use-of-color.html
- U.S. Web Design System, Design tokens (spacing·color) — https://designsystem.digital.gov/design-tokens/
