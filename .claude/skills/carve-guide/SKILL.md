---
name: carve-guide
description: 하네스의 모든 HTML 산출물(문서·가이드·랜딩·리포트·데모 등)을 일관된 디자인 시스템으로 작성·갱신하는 범용 스킬. anti-ai-slop 하드 게이트 + theme-factory(색·폰트)·frontend-design(레이아웃 방향) 디자인 검토 + 1000px 반응형 + 임베드(SPA) 안전 + 실측 검증을 기본 탑재. HTML을 "예쁘게/그럴듯하게" 만들 때 발동. 릴리스 시 carve-workflow-guide.html 갱신은 §7 특수 모드(이 리포 전용).
disable-model-invocation: true
---

# carve-guide — 하네스 HTML 산출물 작성 스킬

harness의 **모든 HTML 산출물**을 검증된 디자인 시스템 + 제약으로 만든다. run-ai.kr 게시(임베드)·GitHub Pages 호스팅을 전제로 한다. **v0.0.13부터 하네스 번들에 포함** — 소비자도 §0~6(범용 HTML 작성)을 쓴다. §7(릴리스 인벤토리 갱신)만 이 리포 전용이다.

## 0. 언제 쓰나
- 새 HTML 문서/페이지/리포트/랜딩/데모 작성
- 기존 HTML 디자인·내용 갱신
- 릴리스 시 `carve-workflow-guide.html` 실측 갱신 (§6 특수 모드)

---

## 1. 디자인 도구 오케스트레이션 (스킬·플러그인 적극 활용)

HTML 착수 전 아래를 **순서대로 검토·발동**한다. 방향은 풍부하게 뽑되, 실행은 anti-slop 안에서.

1. **`anti-ai-slop` (하드 게이트 · 항상 · 필수)** — 시각 작업 전 **먼저 발동**. 금지 목록(그라데이션·글로우·색그림자·`blur≥20`·장식 모션·이모지 불릿·카드 상단 컬러바·마케팅 상투어)은 **예외 없음**. 최종 산출물은 이 게이트를 통과해야 한다.
2. **`theme-factory` (색·폰트 방향)** — 10개 프리셋(또는 즉석 생성)에서 문서 성격에 맞는 팔레트·폰트 페어링을 **능동 선택**(기술문서=차분/무채색+청록, 랜딩=대비 강한 단색, 교육=따뜻한 중립 등). **단 anti-slop이 이긴다**: 테마의 다색·그라데이션은 버리고 **무채색 베이스 + 액센트 1색 + 폰트 페어링**만 취한다.
3. **`frontend-design` 플러그인 (레이아웃·타이포 방향)** — 템플릿 기본값(Inter/system-ui 수렴, 밋밋한 카드 나열)을 피할 **의도적 레이아웃·위계·타이포 방향** 탐색에 쓴다. anti-slop 금지 목록과 충돌하면 **금지 목록이 이긴다**.

> **규칙 순위**: `anti-ai-slop`(하드) > `theme-factory`·`frontend-design`(방향 제안). 디자인 요소는 이 셋을 적극 조합해 풍부하게, 그러나 게이트 위반은 0.

---

## 2. 기본 디자인 시스템 (재사용 베이스)

**정본 CSS 시작점**: `docs/html/carve-workflow-guide.html`의 `<style>` 블록을 복사 기반으로 쓴다(검증된 anti-slop 통과본). 핵심 토큰·컴포넌트:

- **폰트**: 본문 `Pretendard`(한/영/숫자 정합), 코드·수치 `JetBrains Mono`. theme-factory가 다른 페어링을 제안하면 그 이유를 CSS 주석 한 줄로 남기고 교체 가능(단 system-ui 기본 수렴 금지).
- **색**: 무채색 베이스(`--ink`/`--surface`/`--border`) + **액센트 1색**(기본 teal `#0F766E`, theme-factory 선택색으로 교체 가능). 색은 의미(위계·상태·판정)에만.
- **구획**: `1px solid border` + 여백. 그림자는 중성 회색 1단계 또는 없음.
- **컴포넌트**: `.callout`(accent/warn/good), `.mono-panel`(고정폭 요약), `table`(1px border), `.doc-meta`(3열 메타), `nav.toc`(2열 목차). 필요한 것만 가져오고 안 쓰는 규칙은 제거(죽은 CSS 금지).
- **CSS는 인라인**(`<style>`) — 임베드 CSP `style-src 'unsafe-inline'`만 허용, 외부 CSS 링크는 차단될 수 있다.

---

## 3. 레이아웃 폭 + 임베드 안전 (필수 · 검증됨)

### 3.1 폭 — 기본 1000px, `!important` 고정
run-ai.kr는 이 HTML을 `<iframe srcdoc="…">`로 감싸고 `<head>` 최상단에 `.wrap{max-width:80%!important;margin-left:0!important}`를 **주입**한다. 파일 `.wrap`은 소스 순서상 **뒤**라 `!important`로 그 주입을 이긴다(같은 specificity는 뒤 규칙 승 — 실측: computed max-width=1000px). 따라서:
```css
.wrap { max-width: 1000px !important; margin: 0 auto !important; padding: 64px 32px 96px; }
@media print       { .wrap { padding: 0; max-width: none !important; } }
@media (max-width: 640px) { .wrap { padding: 32px 18px 64px; } }   /* 좁으면 자연 축소(반응형) */
```

### 3.2 앵커·외부 링크 스크립트 (`<body>` 끝에 필수)
내부 앵커가 URL 해시를 바꾸면 호스트 SPA(React) 라우터가 오작동(CORS fetch·크래시). 외부 링크는 마크다운/호스트가 `target="_blank"`를 지울 수 있다. 둘 다 JS로 처리:
```html
<script>
  document.querySelectorAll('a[href^="#"]').forEach(function (a) {   // 내부 앵커: 해시 미변경 스크롤
    a.addEventListener('click', function (e) {
      e.preventDefault();   // 항상 — 빈("#")·미존재 ID라도 해시 변경 차단(SPA 크래시 방지)
      var id = this.getAttribute('href').slice(1);
      var el = id && document.getElementById(id);
      if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  });
  document.querySelectorAll('a.ext').forEach(function (a) {          // 외부 링크: 새 탭 강제
    a.addEventListener('click', function (e) { e.preventDefault(); window.open(a.href, '_blank', 'noopener'); });
  });
</script>
```
외부/새 창 링크에는 `class="ext"` + GitHub Pages 절대 URL을 쓴다(상대경로는 소스로 뜨거나 안 열림).

---

## 4. 콘텐츠 원칙
- 위계는 **크기·굵기·여백·정렬**로 만든다(색·효과 아님).
- **정직한 카피** — 마케팅 상투어·과장 금지.
- **수치·사실은 실측**(파일시스템·명령 실행 결과). 프로즈 복붙 금지, 미확인은 불확실 표기.
- 넘버링·목차·참조 축은 한 곳 고치면 연동 전부 수정.

---

## 5. 검증 (완료 선언 전 필수)
- **anti-slop 스캔 0**: `gradient`·`backdrop-filter/blur(`·`@keyframes/animation:`·색 `box-shadow`·이모지 = 모두 0.
- **헤드리스 크롬 렌더 → PNG를 열어 육안 확인**(레이아웃·줄바꿈·표 정렬).
- **임베드 폭 시뮬레이션**(임베드 대상일 때): 호스트 `.wrap{max-width:80%!important}` 주입을 앞에 넣고 렌더 → `getComputedStyle(.wrap).maxWidth === '1000px'` 확인.
- **사실·카운트 정합**: 문서 수치가 정본(코드·README·CHANGELOG·VERSION)과 일치.

## 6. 출력·커밋
대상 HTML 덮어쓰기. 커밋·푸시·PR은 **명시 요청 시에만**.

---

## 7. 특수 모드 — `carve-workflow-guide.html` 릴리스 갱신

기능 출시마다 개요 가이드를 **실측**으로 다시 채운다.

1. **인벤토리 실측**(프로즈·README 신뢰 금지):
   ```bash
   ls .claude/hooks/*.sh | wc -l                      # 훅
   ls .claude/commands/*.md | wc -l                   # 커맨드
   ls .claude/agents/*.md | wc -l                     # 에이전트
   ls .claude/skills | wc -l                          # 스킬 (carve-guide 포함 — v0.0.13부터 배포)
   find .claude/rules -name '*.md' | wc -l            # 규칙
   ls .claude/workflows | wc -l                       # 워크플로
   bash .claude/hooks/tests/run-all.sh 2>&1 | grep -oE '[0-9]+ passed' | awk '{s+=$1}END{print s}'  # 테스트
   ```
   각 카테고리 **이름 목록**도 수집(전체 표용) — `carve-guide` 포함.
2. **업데이트 로그**: `CHANGELOG.md` 최신 5~8 버전을 표로. 헤더 버전 = `VERSION` 값.
3. **소스 리포**: 헤더 메타에 `https://github.com/claude-code-expert/carve-harness` 고정.
4. **전체 목록 + 사용 예시**: 스킬·커맨드·훅 전체 표(카운트는 1번과 일치) + 슬래시·발화·오케스트레이션 예시.
5. **라이브 데모**: `class="ext"` + Pages 절대 URL(`…/docs/html/harness-demo/index.html`).
6. §1~5(디자인 도구·기본 시스템·폭/임베드 안전·검증) 적용 후 `docs/html/carve-workflow-guide.html` 덮어쓰기.

정합 축(한 곳 고치면 전부): 인벤토리 수치는 이 HTML · `README.md` · `README.en.md` · `GUIDE.md` · `CHANGELOG.md` 공유.

---

## 불변 규칙
- 규칙 순위: **`anti-ai-slop`(하드 게이트) > theme-factory·frontend-design(방향)**. 게이트 위반 0이 완료 기준.
- `.wrap` 폭은 `!important`로 고정(임베드 호스트 주입을 이김), `@media print`는 `none !important`.
- 내부 앵커는 `preventDefault`+`scrollIntoView`(해시 미변경), 외부 링크는 `a.ext`+`window.open` — SPA 임베드 호환.
- CSS는 인라인(외부 링크 CSP 차단 대비).
- 수치는 **실측**. 프로즈 복붙 금지.
- **PNG 육안 확인 전 완료 선언 금지.**
