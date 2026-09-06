# html-report — HTML 리포트 (장문 문서 · 분석 · 데이터)

> 전역 게이트(`SKILL.md` §1) + `visual-craft.md` 위에 더해지는 추가 제약.
> 임베드(iframe) 배포가 전제인 하네스 산출물은 `carve-guide` §3(폭·앵커)을 함께 따른다.
>
> 기계 검증: `node .claude/hooks/check-slop.mjs <파일.html>`

---

## 산출물 사양 (MUST)

- **레이아웃**: 단일 본문 컬럼. 읽기 폭 `680~820px`(장문 산문) 또는 컨테이너 전폭(데이터 중심).
  풀블리드 히어로 헤더 금지.
- **타이포 스케일**: 본문 `16~18px / line-height 1.7`. 제목 위계는 크기 차이로만
  (`h1 32 → h2 25 → h3 20`, `visual-craft.md` §2 스케일 준수).
- **인쇄 대응**: `@media print`로 배경 제거, 링크 URL 노출, 표·그림 페이지 분리.
- **출처**: 모든 수치·인용에 각주 또는 인라인 출처. 문서 끝에 참고문헌. **1차 출처 우선**
  (공식 문서·CHANGELOG > 커뮤니티 블로그).

## 추가 금지 (MUST NOT)

- **그라데이션 히어로 헤더 금지.** 제목 영역은 흰 배경 + 1px 하단 보더 + 여백으로 구분. (`gradient`)
- **KPI·stat 카드 글로우 금지.** 큰 숫자는 평면, 라벨은 회색 캡션. (`colored-shadow`·`big-shadow`)
- **섹션을 컬러 액센트 바로 꾸미기 금지.** 좌측 4px 바는 `blockquote`에 무채색·단일 액센트로만 허용. (`accent-bar`)
- **섹션 제목에 이모지 아이콘 금지.** 번호 체계(1. / 1.1 / 1.1.1)나 텍스트로만 구분.
- **거대 컬러 콜아웃 박스 금지.** 콜아웃은 연회색 배경 + 1px 보더까지.

## 추가 강제 (MUST)

- **표**: 헤더는 굵기 + 하단 보더로 구분. 본문 행은 보더 또는 아주 옅은 zebra(`#FAFAFA`)까지.
  **숫자 열은 우측 정렬**, 단위 통일, 소수 자릿수 통일, 등폭 폰트.
- **차트**: 데이터 색은 무채색 + 액센트 1색, 또는 `svg-image.md`의 의미 팔레트 재사용.
  강조 계열 하나만 채도를 올리고 나머지는 회색. 3D·그림자·그라데이션 막대 금지.
- **데이터 잉크 비율**: 격자선은 옅게(`#E5E7EB`), 축 장식·범례 박스 테두리 제거.
  라벨은 범례보다 **데이터 옆에 직접** 붙이는 편을 우선한다.
- **링크 검증**: 출력 전 외부 링크가 실제로 연결되는지 확인한다.

## 자가 점검 (출력 전 추가 통과 필수)

- [ ] 헤더·섹션을 색·그라데이션·액센트 바로 구분했는가? (보더·여백으로 바꿀 것)
- [ ] KPI·숫자에 글로우·컬러 그림자가 있는가?
- [ ] 차트에 의미 없는 색이 3종 이상인가? 막대에 3D·그림자·그라데이션이 있는가?
- [ ] 표의 숫자 열이 좌측 정렬이거나 자릿수가 들쭉날쭉한가?
- [ ] 출처 없는 수치·인용이 있는가? 깨진 링크가 있는가?
- [ ] `@media print`에서 배경이 남거나 링크 URL이 사라지는가?

## Good / Bad

**BAD** — 그라데이션 헤더 + 글로우 KPI + 컬러 액센트 바

```css
.report-hero { background: linear-gradient(90deg,#2563eb,#06b6d4); color:#fff; }
.kpi         { box-shadow: 0 0 30px rgba(37,99,235,.5); }
.section     { border-top: 4px solid #2563eb; }
```

**GOOD** — 보더·여백·타이포로만 위계

```css
/* 폰트: 장문 가독성 위해 본문 Noto Sans KR, 수치·코드는 JetBrains Mono */
.report   { max-width: 760px; margin: 0 auto; padding: 48px 24px;
            font: 400 17px/1.7 'Noto Sans KR'; color: #111; }
.report h1{ font-size: 32px; font-weight: 700; letter-spacing: -.02em;
            padding-bottom: 16px; border-bottom: 1px solid #E5E7EB; margin-bottom: 32px; }
.report h2{ font-size: 25px; font-weight: 700; margin: 40px 0 12px; }
.kpi      { border: 1px solid #E5E7EB; border-radius: 8px; padding: 20px; }
.kpi .v   { font: 700 32px 'JetBrains Mono'; color: #111; }
.kpi .l   { font-size: 13px; color: #6B7280; margin-top: 4px; }
table     { width: 100%; border-collapse: collapse; font-size: 15px; }
th        { text-align: left; font-weight: 700; border-bottom: 2px solid #111; padding: 8px 12px; }
td        { border-bottom: 1px solid #E5E7EB; padding: 8px 12px; }
td.num    { text-align: right; font-family: 'JetBrains Mono'; }
@media print {
  .report { max-width: none; }
  a::after { content: " (" attr(href) ")"; font-size: 12px; color: #6B7280; }
  table, figure { break-inside: avoid; }
}
```

비교 분석 리포트라면 핵심 결론을 문서 최상단 요약 블록(연회색 배경 + 1px 보더)에 3~5줄로 먼저
제시하고, KPI는 `.kpi` 그리드로, 근거 표는 `td.num` 우측 정렬로 맞춘다.
