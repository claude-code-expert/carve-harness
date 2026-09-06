# svg-image — SVG 다이어그램 · 일러스트

> 전역 게이트(`SKILL.md` §1) + `visual-craft.md` 위에 더해지는 추가 제약.
> 시퀀스·플로우·아키텍처 다이어그램, 라인 일러스트 전용.
> 복잡한 시퀀스·상태 다이어그램은 SVG 대신 PlantUML로 제공하고 색 의미만 아래와 맞춘다.
>
> 기계 검증: `node .claude/hooks/check-slop.mjs <파일.svg>`

---

## 산출물 사양 (MUST)

- **이식성**: 색은 CSS 변수 없이 **inline hex**로 직접 박는다. `<defs>` 변수·외부 스타일 의존 금지 —
  브라우저·PPT·PNG 변환 어디서나 동일하게 보여야 한다.
- **스케일**: 반드시 `viewBox` 지정. 고정 `width/height` px 의존 금지. `preserveAspectRatio` 기본 유지. (`svg-viewbox`)
- **폰트**: 라벨은 `font-family="'Noto Sans KR', sans-serif"`. PNG 내보내기(rsvg-convert·헤드리스 크롬)는
  `Noto Sans CJK KR`로 렌더한다. 라벨이 도형 밖으로 잘리지 않게.
- **선·모서리**: stroke `1~2px`, 모서리 `rx ≤ 8`. 화살촉(marker)은 한 종류로 통일.

## 색 의미 체계 (MUST 재사용)

다이어그램의 색은 장식이 아니라 **역할·상태 의미**다. 아래 매핑을 고정한다.
린터 `svg-offpalette` 룰이 이 5색 밖의 유채색을 WARN으로 잡는다.

| 색 | hex | 의미 |
|---|---|---|
| gray | `#6B7280` / 면 `#F3F4F6` | 중립 · 사용자(User) |
| purple | `#7C3AED` | LLM · Lead · 상위 모델 |
| teal | `#0D9488` | 도구(Tools) · Teammate · 승인(approved) |
| amber | `#F59E0B` | 상태 관리 · 큐(queue) |
| coral | `#EF4444` | 종료(shutdown) · 거부(rejection) |

면은 옅게(흰색·연회색), 테두리와 라벨은 진한 hex로. **같은 의미는 다이어그램 전체에서 같은 색.**

## 추가 금지 (MUST NOT)

- **그라데이션 채움 금지** — `<linearGradient>` · `<radialGradient>` · `<meshGradient>`. 모든 채움은 단색 `fill`. (`gradient`)
- **glow·blur 필터 금지** — `feGaussianBlur` · `feDropShadow` · `filter: blur()`. 그림자가 꼭 필요하면 회색 1px 오프셋 사각만. (`svg-filter`)
- **3D·베벨·광택 금지** — 가짜 입체, 글로시 하이라이트, 다중 그림자.
- **무지개·다색 팔레트 금지.** 의미 없는 색은 회색. 위 5색 밖 임의 색 추가 금지.
- **장식 배경 금지** — 닷 그리드, 광선, 큰 반투명 아이콘.

## 추가 강제 (MUST)

- **평면(flat)**: 단색 면 + 단색 테두리. 노드는 `rect rx=8` 또는 `circle`, 흐름은 직선·직각 경로 + 통일된 화살촉.
- **위계**: 굵기·크기·여백·정렬로. 중요한 노드는 크게·굵게, 보조는 작게·회색.
- **라벨 가독성**: 도형 안 텍스트는 중앙 정렬, 긴 라벨은 `<tspan>`으로 줄바꿈. 대비는 본문 기준을 따른다.
- **범례**: 색을 의미로 썼으면 색-의미 매핑 범례를 같이 둔다.

## 자가 점검 (출력 전 추가 통과 필수)

- [ ] `<linearGradient>`·`<radialGradient>` 또는 그라데이션 `fill`이 있는가?
- [ ] `filter`·`feGaussianBlur`·drop-shadow·glow가 있는가?
- [ ] 5색 체계를 벗어난 임의 색이 있는가? 같은 의미에 다른 색을 썼는가?
- [ ] CSS 변수·외부 스타일에 색을 의존하는가? (inline hex로 바꿀 것)
- [ ] `viewBox`가 없거나 라벨이 도형 밖으로 잘리는가?
- [ ] 3D·베벨·광택·장식 배경이 있는가?

## Good / Bad

**BAD** — 그라데이션 채움 + glow 필터 + 무지개색

```xml
<defs>
  <linearGradient id="g"><stop offset="0" stop-color="#a855f7"/><stop offset="1" stop-color="#ec4899"/></linearGradient>
  <filter id="glow"><feGaussianBlur stdDeviation="6"/></filter>
</defs>
<rect fill="url(#g)" filter="url(#glow)" .../>
```

**GOOD** — 평면 단색 + inline hex + 색 의미 체계

```xml
<svg viewBox="0 0 520 200" xmlns="http://www.w3.org/2000/svg"
     font-family="'Noto Sans KR', sans-serif">
  <!-- User (gray) -->
  <rect x="20" y="70" width="120" height="56" rx="8" fill="#F3F4F6" stroke="#6B7280" stroke-width="1.5"/>
  <text x="80" y="104" text-anchor="middle" font-size="15" fill="#111">사용자</text>
  <line x1="140" y1="98" x2="200" y2="98" stroke="#6B7280" stroke-width="1.5" marker-end="url(#arrow)"/>
  <!-- LLM (purple) -->
  <rect x="200" y="70" width="140" height="56" rx="8" fill="#FFFFFF" stroke="#7C3AED" stroke-width="1.5"/>
  <text x="270" y="104" text-anchor="middle" font-size="15" fill="#7C3AED">LLM</text>
  <line x1="340" y1="98" x2="400" y2="98" stroke="#6B7280" stroke-width="1.5" marker-end="url(#arrow)"/>
  <!-- Tools (teal) -->
  <rect x="400" y="70" width="100" height="56" rx="8" fill="#FFFFFF" stroke="#0D9488" stroke-width="1.5"/>
  <text x="450" y="104" text-anchor="middle" font-size="15" fill="#0D9488">도구</text>
  <defs>
    <marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
      <path d="M0,0 L8,4 L0,8 Z" fill="#6B7280"/>
    </marker>
  </defs>
</svg>
```

노드는 역할색 테두리 + 흰·연회 면, 흐름은 회색 직선 + 통일 화살촉. 승인=teal, 거부=coral처럼
상태도 같은 색 규칙을 따른다.
