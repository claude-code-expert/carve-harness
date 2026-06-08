# 이미지·HTML 생성 규칙 — Anti-AI-Slop

> 모든 이미지·HTML·SVG·슬라이드 생성에 적용. 장식이 아니라 정보 위계·여백·정렬·타이포로 품질을 만든다.

## MUST NOT (금지)

- **그라데이션 일체 금지** — `linear-gradient` · `radial-gradient` · `conic-gradient`, 배경·채움·텍스트(`background-clip:text`) 전부. 특히 보라/핑크 계열.
- **글로우·컬러 그림자 금지** — 색 들어간 `box-shadow`, 광택 inset 링, `blur ≥ 20px` 그림자, `backdrop-filter: blur`(글래스모피즘).
- **장식 모션 금지** — hover 시 `transform: translate/scale`, 로드 시 fade/stagger, `pulse·shimmer·float·glow` 키프레임. `transition`은 색·투명도 등 기능적 상태에만 150ms 이하.
- **배경 장식 금지** — 거대 반투명 워터마크, 닷·그리드 배경, 페이드 마스크, 광선.
- **카드 상단 컬러 액센트 바 금지** (`border-top: Npx solid color`).
- **이모지 불릿·장식 금지**, 뱃지/pill 남발 금지.
- **마케팅 상투어 금지** — Seamlessly, Elevate, Unlock, Empower, Supercharge, ✨ 등.

## MUST (강제)

- **색**: 무채색(흰/회/검) 베이스 + 액센트 1색. 색은 의미(상태·위계)에만 쓴다.
- **그림자**: 쓰더라도 중성 회색 1단계만 (`0 1px 2px rgba(0,0,0,.06)`). 없어도 좋다.
- **구획**: 효과 대신 `1px solid border` + 여백으로 나눈다.
- **모서리**: `border-radius`는 0~8px. 한쪽 테두리(`border-left` 등)엔 radius 0.
- **위계**: 크기·굵기·여백·정렬로 만든다. 색·효과로 만들지 않는다.
- **폰트**: Inter/Roboto/Arial/system-ui로 기본 수렴 금지. 목적에 맞는 폰트를 의도적으로 고르고 이유를 한 줄 밝힌다.
- **정당성**: 모든 시각 요소는 "이게 어떤 정보를 전달하는가"에 답할 수 있어야 한다. 답 못 하면 삭제한다.

## 출력 전 자가 점검 — 하나라도 YES면 제거 후 재작성

- [ ] gradient(any)가 있는가?
- [ ] 색 들어간 그림자 또는 `blur ≥ 20px`가 있는가?
- [ ] hover/load에 transform·fade·키프레임이 있는가?
- [ ] 콘텐츠와 무관한 배경 장식(워터마크/그리드/광선)이 있는가?
- [ ] 정보를 전달하지 않는 순수 장식 요소가 있는가?
- [ ] 폰트가 기본값(Inter/Roboto/Arial/system)으로 수렴했는가?
