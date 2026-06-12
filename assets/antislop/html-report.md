# HTML 리포트 (HTML Report)

> 전역 규칙(SKILL.md §2~§4) 위에 더해지는 추가 제약. 장문 문서·분석·데이터 리포트 전용.

## 산출물 사양 (MUST)
- **레이아웃**: 단일 본문 컬럼. 읽기 폭 `680~820px`(`max-width`), 좌우 자동 여백. 풀블리드 헤더 금지.
- **타이포 스케일**: 본문 `16~18px / line-height 1.7`. 제목 위계는 `H1 32 → H2 24 → H3 18`처럼 **크기 차이로만** 만든다.
- **인쇄 대응**: `@media print`로 배경 제거, 링크 URL 노출(`a::after{content:" ("attr(href)")"}`), 페이지 분리(`break-inside: avoid` for 표/그림).
- **출처**: 모든 수치·인용에 각주 또는 인라인 출처. 문서 끝에 참고문헌 목록. (프로젝트 규칙: 1차 출처 우선)

## 추가 금지 (MUST NOT)
- **그라데이션 히어로 헤더 금지.** 제목 영역은 흰 배경 + 1px 하단 보더 + 여백으로 구분.
- **stat 카드 글로우 금지.** 큰 숫자(KPI)는 외곽선 없는 평면, 라벨은 회색 캡션.
- **카드 상단/좌측 컬러 액센트 바로 섹션 꾸미기 금지.** (좌측 4px 바는 인용구 `blockquote`에만 무채색/단일 액센트로 허용)
- **섹션 제목에 이모지 아이콘 금지.** 번호 체계(1. / 1.1 / 1.1.1)나 텍스트로만 구분.
- **거대 컬러 콜아웃 박스 금지.** 콜아웃은 연회색 배경(`#F8F7F4`) + 1px 보더까지만.

## 추가 강제 (MUST)
- **표**: 헤더는 굵기·하단 보더로 구분, 본문 행은 보더 또는 아주 옅은 zebra(`#FAFAFA`)까지. **숫자 열은 우측 정렬**, 단위 통일, 소수 자릿수 통일.
- **차트**: 데이터 색은 **무채색 + 액센트 1색** 또는 의미 기반 팔레트(`svg-image.md`의 색 의미 체계 재사용). 강조 계열 1개만 채도 높이고 나머지는 회색. 3D·그림자·그라데이션 막대 금지.
- **데이터 잉크 비율**: 격자선은 옅게(`#E5E7EB`), 불필요한 축 장식·범례 박스 테두리 제거. 라벨을 직접 데이터 옆에 붙이는 편을 우선.
- **링크 검증**: 출력 전 모든 외부 링크가 실제 연결되는지 확인하고, 1차 출처(공식 문서·CHANGELOG)를 community 블로그보다 우선 표기한다.

## 카피라이팅 (MUST)
- 결론·요약은 **수치 + 단위 + 출처**로 쓴다. 부사("크게"·"매우")와 느낌표를 걷어낸다.
  - BAD: "혁신적인 성능 개선을 달성했습니다!"
  - GOOD: "p95 응답 시간 420ms → 180ms (57% 감소, 측정: k6 n=1000)"
- "단순한 X가 아니라 Y" 류 대비 문형 대신 Y를 직접 서술한다.
- 간격은 SKILL.md §6의 4/8px 그리드 — 섹션 간 40~48px, 문단 간 16px로 고정.

## 자가 점검 (출력 전 추가 통과 필수)
- [ ] 헤더/섹션을 색·그라데이션·액센트 바로 구분했는가? (보더·여백으로 바꿀 것)
- [ ] KPI/숫자에 글로우·컬러 그림자가 있는가?
- [ ] 차트에 의미 없는 색이 3색 이상 쓰였는가? 막대에 3D/그림자/그라데이션이 있는가?
- [ ] 표의 숫자 열이 좌측 정렬이거나 자릿수가 들쭉날쭉한가?
- [ ] 출처 없는 수치·인용이 있는가? 깨진 링크가 있는가?

## Good / Bad 예시

**BAD** — 그라데이션 헤더 + 글로우 KPI + 컬러 액센트 바
```css
.report-hero { background: linear-gradient(90deg,#2563eb,#06b6d4); color:#fff; }
.kpi { box-shadow: 0 0 30px rgba(37,99,235,.5); }      /* 글로우 금지 */
.section { border-top: 4px solid #2563eb; }            /* 액센트 바 금지 */
```

**GOOD** — 보더·여백·타이포로만 위계
```css
/* 폰트: 장문 가독성 위해 본문 Noto Sans KR, 수치/코드 JetBrains Mono */
.report  { max-width: 760px; margin: 0 auto; padding: 48px 24px;
           font: 400 17px/1.7 'Noto Sans KR'; color:#111; }
.report h1 { font-size:32px; font-weight:700; letter-spacing:-.02em;
             padding-bottom:16px; border-bottom:1px solid #E5E7EB; margin-bottom:32px; }
.report h2 { font-size:24px; font-weight:700; margin:40px 0 12px; }
.kpi   { border:1px solid #E5E7EB; border-radius:8px; padding:20px; }
.kpi .v{ font:700 32px 'JetBrains Mono'; color:#111; }
.kpi .l{ font-size:13px; color:#6B7280; margin-top:4px; }
table  { width:100%; border-collapse:collapse; font-size:15px; }
th     { text-align:left; font-weight:700; border-bottom:2px solid #111; padding:8px 12px; }
td     { border-bottom:1px solid #E5E7EB; padding:8px 12px; }
td.num { text-align:right; font-family:'JetBrains Mono'; }
@media print { .report{max-width:none;} a::after{content:" ("attr(href)")"; font-size:12px; color:#6B7280;} }
```

> 활용: 비교 분석 리포트라면 핵심 결론을 문서 최상단 `요약` 블록(연회색 배경+1px 보더)에 3~5줄로
> 먼저 제시하고, KPI는 `.kpi` 카드 그리드로, 근거 표는 `td.num` 우측 정렬로 정렬한다.
