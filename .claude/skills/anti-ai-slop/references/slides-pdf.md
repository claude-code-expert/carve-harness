# slides-pdf — 슬라이드 · PDF (16:9 데크 · 보고서)

> 전역 게이트(`SKILL.md` §1) + `visual-craft.md` 위에 더해지는 추가 제약.
> HTML 16:9 데크, pptx/pdf 산출물 공통.
>
> 기계 검증(HTML 데크): `node .claude/hooks/check-slop.mjs <파일.html>`

---

## 데크에서 AI 티를 만드는 두 가지

1. **불릿 벽** — 문단을 통째로 불릿에 넣고 슬라이드마다 5~7개씩 반복
2. **균질한 템플릿 리듬** — 모든 슬라이드가 같은 레이아웃·같은 항목 수

내용의 종류가 다르면 레이아웃도 달라야 한다. 같은 틀에 다른 내용을 붓는 순간 지문이 남는다.

## 산출물 사양 (MUST)

- **캔버스**: `1280×720` 또는 `1920×1080`(16:9 고정). `overflow:hidden`으로 셸 고정.
- **밀도**: 슬라이드당 **주장 하나**. 불릿 최대 5개, 각 1줄(6~10어절). 문단 붙여넣기 금지.
- **타이포**: 타이틀 `36~52px`, 본문 `17~24px`, 캡션 `13~15px`. 멀리서 읽히는 것이 기준.
- **마스터 일관성**: 모든 슬라이드가 동일한 여백(예: `56px 72px`)·챕터 라벨 위치·타이포 스케일을 공유.
- **제목은 주제가 아니라 주장**: "매출 현황"(주제) ✗ → "3분기 매출 12% 감소, 이탈이 원인"(주장) ✓

## 추가 금지 (MUST NOT)

- **진입·전환 애니메이션 금지** — fade-in, slide-up, stagger build, 타이핑 효과.
  정적으로 완성된 화면을 렌더한다. (`keyframes`·`motion-decor`)
- **그라데이션 배경·그라데이션 타이틀 금지.** 타이틀 강조는 액센트 1색 `em` 처리로만. (`gradient`·`gradient-text`)
- **슬라이드마다 색 테마 바꾸기 금지.** 챕터 구분은 라벨·번호로, 색은 고정.
- **배경 아트가 내용을 압도하기 금지.** 배경 이미지를 쓸 거면 `opacity ≤ 0.04` + 가독성 우선. (`watermark`)
- **상단 그라데이션 액센트 바 금지.** 필요하면 단색 4px. (`accent-bar`)

## 추가 강제 (MUST)

- **위계**: `챕터 라벨(작은 monospace) → 타이틀(큰 굵게) → 본문·리스트` 순으로 크기·여백 위계.
- **불릿 마커**: 이모지 대신 단색 사각·막대 마커.
- **불릿보다 나은 것을 먼저 고려**: 도식·비교표·단일 숫자로 대체할 수 있으면 대체한다.
  불릿을 쓰면 항목 수와 길이를 일부러 다르게 한다.
- **코드 블록**: monospace + 연회색 배경(`#F3F4F6`) + 1px 보더. 구문 강조는 의미 단위 최소 색상만.
- **다이어그램**: 슬라이드 내 도식은 `svg-image.md`의 색 의미 체계와 평면 스타일을 따른다.

## 자가 점검 (출력 전 추가 통과 필수)

- [ ] 진입·전환·빌드 애니메이션이 있는가?
- [ ] 슬라이드당 주장이 2개 이상인가? 불릿이 6개를 넘거나 한 줄이 2줄로 넘치는가?
- [ ] 슬라이드마다 배경색·테마·액센트 색이 바뀌는가?
- [ ] 타이틀에 그라데이션 텍스트·글로우가 있는가?
- [ ] 16:9 셸 밖으로 콘텐츠가 넘치거나 안전 여백을 침범하는가?
- [ ] 모든 슬라이드가 같은 레이아웃·같은 항목 수인가?
- [ ] 제목이 주제 나열인가, 주장인가?

## Good / Bad

**BAD** — 슬라이드별 그라데이션, 진입 애니메이션, 그라데이션 타이틀

```css
.slide     { background: linear-gradient(135deg,#1e3a8a,#0e7490); }
.slide.s2  { background: linear-gradient(135deg,#7c3aed,#db2777); }
.title     { background: linear-gradient(90deg,#f59e0b,#ef4444);
             -webkit-background-clip: text; color: transparent; }
@keyframes in { from { opacity:0; transform: translateY(20px); } }
.slide     { animation: in .6s ease; }
```

**GOOD** — 정적 · 무채색 + 액센트 1색 · 크기 위계

```css
/* 폰트: 강의 슬라이드 가독성 + 코드 병기 위해 Noto Sans KR / JetBrains Mono */
.slide        { width:1280px; height:720px; background:#FFF; overflow:hidden; position:relative;
                box-shadow: 0 1px 2px rgba(0,0,0,.06); }
.slide-topbar { position:absolute; top:0; left:0; right:0; height:4px; background:#F59E0B; }
.inner        { padding:56px 72px; height:100%; }
.chapter      { font:700 11px 'JetBrains Mono'; letter-spacing:.18em;
                text-transform:uppercase; color:#F59E0B; }
.title        { font:700 40px 'Noto Sans KR'; color:#111; letter-spacing:-.02em; margin:8px 0 24px; }
.title em     { font-style:normal; color:#F59E0B; }
.bullet       { font:400 20px 'Noto Sans KR'; color:#111; line-height:1.6; }
.bullet::before { content:''; display:inline-block; width:6px; height:6px;
                  background:#F59E0B; margin-right:12px; vertical-align:middle; }
```

챕터 디바이더는 `.chapter` + 큰 `.title` 한 줄 + 캡션. 본문 슬라이드는 `.title` + `.bullet` 3~5개.
한 슬라이드의 메시지는 사실 나열이 아니라 판단 한 문장으로 압축한다.

## PDF 보고서 추가 노트

- 본문 레이아웃·표·차트 기준은 `html-report.md`를 따른다
- 페이지 분리: 표·그림에 `break-inside: avoid`
- 머리말·꼬리말은 텍스트만. 로고 워터마크·페이지 장식 금지
- 인쇄 시 배경색 제거, 링크는 URL을 본문에 노출
