# HTML 프리젠테이션 (HTML Presentation / 16:9 슬라이드)

> 전역 규칙(SKILL.md §2~§4) 위에 더해지는 추가 제약. 영상 강의용 16:9 슬라이드 전용.

## 산출물 사양 (MUST)
- **캔버스**: `1280×720` 또는 `1920×1080`(16:9 고정). `overflow:hidden`으로 슬라이드 셸 고정.
- **밀도**: 슬라이드당 **아이디어 1개**. 불릿 최대 5개, 각 불릿 1줄(약 6~10어절). 문단 통째 붙여넣기 금지.
- **타이포**: 타이틀 `36~52px`, 본문 `17~24px`, 캡션 `13~15px`. 멀리서도 읽히게.
- **마스터 일관성**: 모든 슬라이드가 동일한 로고 위치·여백(예: `56px 72px`)·챕터 라벨·타이포 스케일을 공유.

## 추가 금지 (MUST NOT)
- **슬라이드 진입/전환 애니메이션 금지**(fade-in, slide-up, stagger build, 타이핑 효과). 정적으로 완성된 화면을 렌더한다.
- **그라데이션 배경·그라데이션 타이틀 금지.** 타이틀 강조는 액센트 1색 `em` 처리로만.
- **슬라이드마다 색 테마 바꾸기 금지.** 챕터 구분은 라벨·번호로, 색은 고정.
- **배경 아트가 내용을 압도하기 금지.** 배경 이미지를 쓸 거면 `opacity` 0.04 이하 + 내용 가독성 우선.
- **상단 그라데이션 액센트 바 금지.** (브루넷 템플릿이 현재 `linear-gradient` topbar를 쓰는데, 이 스킬 기준으로는 **단색 `background:#F59E0B` 4px**로 교체해야 함 — 아래 정렬 노트 참고.)

## 추가 강제 (MUST)
- **위계**: `챕터 라벨(작은 monospace) → 타이틀(큰 굵게) → 본문/리스트` 순으로 크기·여백 위계.
- **불릿**: 이모지 대신 단색 사각/막대 마커(`::before { content:''; width:6px; height:6px; background:#F59E0B; }`).
- **코드 블록**: monospace + 연회색 배경(`#F3F4F6`) + 1px 보더. 구문 강조는 의미 단위 최소 색상만.
- **다이어그램**: 슬라이드 내 도식은 `svg-image.md`의 색 의미 체계와 평면 스타일을 따른다.

## 브루넷 템플릿 정렬 노트 (사실 기반 점검)
현재 `brewnet-slides-template.html`은 본 스킬과 **2곳 충돌**한다 — 적용 시 교체 권장:
1. `.slide-topbar` 가 `linear-gradient(90deg, amber → amber-d → transparent)` → **단색 amber 4px**로 교체.
2. `.slide-bg img { opacity:0.04 }` 배경 워터마크 → 전역 "배경 장식 금지" 위반. 강의 브랜드 요소로 유지하려면 **예외 1건으로 명시**하고 그 외 규칙은 그대로 적용. (나머지: Noto Sans KR+JetBrains Mono, 무채색+amber 단일 액센트, 좌측 4px h2 마커는 본 표준과 정합)

## 슬라이드 카피 (MUST)
- 한 줄 메시지는 **주장 + 근거 수치**. 느낌표·물음표 남발 금지(슬라이드덱 전체에서 0~1회).
  - BAD: "토큰 비용이 엄청나게 줄어듭니다!"
  - GOOD: "토큰 비용 47% 절감 — 동일 태스크 5건 실측 (v1.1.0)"
- 타이틀은 "당연한 사실"이 아니라 판단이 담긴 한 문장으로. 최상급 형용사 대신 비교 대상과 수치.

## 자가 점검 (출력 전 추가 통과 필수)
- [ ] 진입/전환/빌드 애니메이션이 있는가?
- [ ] 슬라이드당 아이디어가 2개 이상인가? 불릿이 6개를 넘거나 한 줄이 2줄로 넘치는가?
- [ ] 슬라이드마다 배경색/테마/액센트 색이 바뀌는가?
- [ ] 타이틀에 그라데이션 텍스트/글로우가 있는가?
- [ ] 16:9 셸 밖으로 콘텐츠가 넘치거나 안전 여백을 침범하는가?

## Good / Bad 예시

**BAD** — 슬라이드마다 그라데이션, 진입 애니메이션, 그라데이션 타이틀
```css
.slide { background: linear-gradient(135deg,#1e3a8a,#0e7490); }
.slide.s2 { background: linear-gradient(135deg,#7c3aed,#db2777); }  /* 슬라이드별 색 변경 금지 */
.title { background: linear-gradient(90deg,#f59e0b,#ef4444);
         -webkit-background-clip:text; color:transparent; }          /* 그라데이션 텍스트 금지 */
@keyframes in { from{opacity:0; transform:translateY(20px);} }
.slide{ animation: in .6s ease; }                                    /* 진입 애니 금지 */
```

**GOOD** — 정적·무채색+단일 액센트·크기 위계
```css
/* 폰트: 강의 슬라이드 가독성+코드 병기 위해 Noto Sans KR / JetBrains Mono */
.slide { width:1280px; height:720px; background:#FFF; overflow:hidden; position:relative;
         box-shadow: 0 1px 2px rgba(0,0,0,.06); }
.slide-topbar { position:absolute; top:0; left:0; right:0; height:4px; background:#F59E0B; } /* 단색 */
.inner   { padding:56px 72px; height:100%; }
.chapter { font:700 11px 'JetBrains Mono'; letter-spacing:.18em; text-transform:uppercase; color:#F59E0B; }
.title   { font:700 40px 'Noto Sans KR'; color:#111; letter-spacing:-.02em; margin:8px 0 24px; }
.title em{ font-style:normal; color:#F59E0B; }                       /* 강조는 액센트 1색 */
.bullet  { font:400 20px 'Noto Sans KR'; color:#111; line-height:1.6; }
.bullet::before { content:''; display:inline-block; width:6px; height:6px;
                  background:#F59E0B; margin-right:12px; vertical-align:middle; }
```

> 활용: 챕터 디바이더는 `.chapter` + 큰 `.title` 한 줄 + 캡션, 본문 슬라이드는 `.title` +
> `.bullet` 3~5개. 한 슬라이드의 메시지는 "당연한 사실 나열"이 아니라 시스템 설계 사고를
> 자극하는 한 문장으로 압축한다.
