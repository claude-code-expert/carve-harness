# 앱 UI 컴포넌트 (UI Component)

> 전역 규칙(SKILL.md §2~§4·§6) 위에 더해지는 추가 제약. 폼·버튼·내비게이션·상태 화면 등 앱 UI 크롬 전용.

## 산출물 사양 (MUST)
- **인터랙티브 상태 5종 명시**: default / hover / focus-visible / disabled / error 를 모두 정의한다.
  hover는 색·보더 변화만(150ms 이하, transform 금지). `:focus-visible` outline은 **필수이며 제거 금지**
  (`outline: 2px solid #111; outline-offset: 2px` 기본).
- **터치 타깃**: 클릭/탭 가능한 요소는 최소 `44×44px` 히트 영역(시각 크기가 작아도 padding으로 확보).
- **폼 라벨**: `<label>`은 placeholder로 대체 금지. placeholder는 예시 값만, 라벨은 항상 보이게.
- **상태 콘텐츠 정의**: empty(비어 있을 때 무엇을 안내하는가) / error(무엇이 실패했고 다음 행동은) /
  loading(어떤 작업이 진행 중인가, 텍스트 동반) 3가지를 콘텐츠로 정의한다.

## 추가 금지 (MUST NOT)
- **skeleton shimmer 금지** — 로딩은 정적 placeholder + 상태 텍스트("불러오는 중")로.
- **상태 텍스트 없는 무한 스피너 금지.**
- **라벨/`aria-label` 없는 아이콘 단독 버튼 금지.**
- **toast 남발 금지** — 폼 오류는 필드 인라인 메시지로, toast는 비동기 완료 통지에만.
- **disabled를 안내 수단으로 남용 금지** — 왜 비활성인지 인접 텍스트로 설명한다.

## 추가 강제 (MUST)
- **대비**: 본문·라벨 텍스트 4.5:1 이상. disabled 텍스트만 완화 허용(명시적 의도).
- **에러 표현**: 색(`#EF4444`)만으로 전달 금지 — 아이콘/텍스트 동반(색각 이상 대응).
- **버튼 위계**: primary 1개(채움) + secondary(보더)·tertiary(텍스트)로 구분. 같은 화면에 primary 2개 금지.
- **간격**: SKILL.md §6의 4/8px 그리드 — 필드 간 16px, 라벨–입력 4~8px, 섹션 간 32~48px.

## 자가 점검 (출력 전 추가 통과 필수)
- [ ] focus-visible outline이 제거되거나 정의되지 않았는가?
- [ ] hover에 transform/그림자 확대가 있는가?
- [ ] 라벨 없는 입력·아이콘 단독 버튼이 있는가?
- [ ] empty/error/loading 상태가 정의되지 않은 목록·폼이 있는가?
- [ ] 한 화면에 primary 버튼이 2개 이상인가?

## Good / Bad 예시

**BAD** — shimmer 로딩 + 라벨 없는 입력 + focus 제거
```css
.skeleton { animation: shimmer 1.5s infinite; }          /* 모션 장식 금지 */
input:focus { outline: none; }                           /* 접근성 파괴 금지 */
.btn-icon { width: 24px; height: 24px; }                 /* 라벨 없음 + 44px 미달 */
```

**GOOD** — 상태 5종 + 라벨 + 히트 영역
```css
/* 폰트: UI 라벨 가독성 위해 Noto Sans KR, 수치 입력은 JetBrains Mono */
.field label { display:block; font-size:14px; font-weight:700; margin-bottom:4px; color:#111; }
.field input { font-size:16px; padding:10px 12px; border:1px solid #E5E7EB; border-radius:6px; }
.field input:hover { border-color:#9CA3AF; transition: border-color 120ms; }
.field input:focus-visible { outline:2px solid #111; outline-offset:2px; }
.field input:disabled { color:#9CA3AF; background:#F8F7F4; }
.field.error input { border-color:#EF4444; }
.field.error .msg { font-size:13px; color:#B91C1C; margin-top:4px; }  /* 색+텍스트 동반 */
.btn { min-height:44px; padding:0 16px; font-size:15px; border-radius:6px; }
.btn-primary { background:#111; color:#fff; }
.btn-secondary { background:#fff; color:#111; border:1px solid #E5E7EB; }
.loading { color:#6B7280; font-size:14px; }              /* "불러오는 중" 텍스트 동반 */
```

> 활용: 목록 화면이라면 empty 상태에 "아직 항목이 없습니다 — [추가하기]"처럼 다음 행동을,
> error 상태에 실패 원인 + 재시도 버튼을 콘텐츠로 먼저 설계한 뒤 스타일을 입힌다.
