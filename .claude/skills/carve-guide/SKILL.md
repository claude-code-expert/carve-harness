---
name: carve-guide
description: docs/html/carve-workflow-guide.html(run-ai.kr 게시용 개요)을 현재 코드베이스 실측으로 다시 생성한다. 기능 출시마다 실행 — 구성 인벤토리·CHANGELOG 업데이트 로그·소스 리포 링크·전체 스킬/커맨드/훅 목록·상세 사용 예시를 갱신. 이 repo 유지보수 전용(하네스 배포 제외).
disable-model-invocation: true
---

# carve-guide — 출시 가이드 HTML 갱신

`docs/html/carve-workflow-guide.html`을 **현재 코드베이스 실측**으로 다시 채운다. run-ai.kr/learn/carve-harness에 게시되는 개요 문서다. **이 repo 유지보수 전용** — `install.sh`의 `DEV_SKILLS`에 등록돼 소비자 설치에는 포함되지 않는다.

## 언제 쓰나
- 새 훅·스킬·커맨드·에이전트·워크플로 추가 후
- 릴리스(VERSION·CHANGELOG 갱신) 직후 — 인벤토리·업데이트 로그가 바뀔 때마다

## 절차 (순서 고정)

### 1. 인벤토리 실측 (프로즈·README 신뢰 금지 — 파일시스템에서 직접 카운트)
```bash
ls .claude/hooks/*.sh | wc -l                # 훅
ls .claude/commands/*.md | wc -l             # 커맨드
ls .claude/agents/*.md | wc -l               # 에이전트
ls .claude/skills | grep -vx carve-guide | wc -l   # 스킬 (DEV_SKILLS 제외 = 배포 수)
find .claude/rules -name '*.md' | wc -l      # 규칙
ls .claude/workflows | wc -l                 # 워크플로
bash .claude/hooks/tests/run-all.sh 2>&1 | grep -oE '[0-9]+ passed' | awk '{s+=$1}END{print s}'  # 테스트 케이스
```
각 카테고리의 **이름 목록**도 수집한다(전체 리스트 표용). 배포 제외 스킬(`carve-guide`)은 인벤토리·목록에서 뺀다.

### 2. 업데이트 로그
`CHANGELOG.md` 최신 버전 항목들을 읽어 버전 이력 표로 정리(최근 5~8개). `VERSION` 파일 값과 헤더 버전을 일치시킨다.

### 3. 소스 리포 표기
헤더 메타에 소스 리포를 고정: `https://github.com/claude-code-expert/carve-harness`.

### 4. 전체 목록 + 상세 사용 예시
- 스킬·커맨드·훅 **전체 표**(이름 + 한 줄 용도). 각 카테고리 카운트는 1번 실측치와 일치.
- 대표 **사용 예시**: 슬래시 명령·자연어 발화, 오케스트레이션(`fable-team-pipeline`) 호출, 훅 게이트 동작.

### 5. 시각 게이트 (필수)
시각 산출물이므로 **먼저 `anti-ai-slop` 스킬을 발동**한다. 기존 `carve-workflow-guide.html` 디자인 시스템 유지: Pretendard + JetBrains Mono, teal 액센트 1색, 무채색 베이스, 1px border. 그라데이션·글로우·이모지·장식 모션 0.

**레이아웃 폭(기본)**: 콘텐츠 컨테이너는 **기본 1000px 고정폭**으로 설계한다 — `.wrap { max-width: 1000px; margin:0 auto; }`. 뷰포트가 그보다 좁으면 패딩으로 자연 축소(반응형), `@media (max-width: 640px)`에서 모바일 여백 조정. 이 폭 기준은 carve-guide로 생성하는 모든 HTML 산출물의 기본값이다.

**SPA 임베드 안전 (필수)**: 이 가이드는 run-ai.kr/learn에 임베드된다. TOC·본문 내부 앵커(`href="#..."`)가 URL 해시를 바꾸면 호스트 SPA(React) 라우터가 route 변경으로 오인해 API fetch(CORS 차단)·크래시를 유발한다. `<body>` 끝에 내부 앵커 클릭을 가로채 `e.preventDefault()` + `scrollIntoView`만 하는 스크립트를 **반드시 포함**한다(해시 미변경):
```html
<script>
  document.querySelectorAll('a[href^="#"]').forEach(function (a) {   // 내부 앵커: 해시 미변경 스크롤
    a.addEventListener('click', function (e) {
      var id = this.getAttribute('href').slice(1);
      var el = id && document.getElementById(id);
      if (el) { e.preventDefault(); el.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
    });
  });
  document.querySelectorAll('a.ext').forEach(function (a) {          // 외부 링크: 새 탭 강제(target strip·SPA 우회)
    a.addEventListener('click', function (e) { e.preventDefault(); window.open(a.href, '_blank', 'noopener'); });
  });
</script>
```

**라이브 데모 링크(필수)**: 데모(<code>docs/html/harness-demo/</code>)는 GitHub Pages 절대 URL로 링크하고 `class="ext"`를 붙인다 — 마크다운은 `target="_blank"`를 sanitize로 제거하므로 위 `window.open` 스크립트로만 새 창이 보장된다. 예: `<a class="ext" href="https://claude-code-expert.github.io/carve-harness/docs/html/harness-demo/index.html">…</a>`.

### 6. 검증 (완료 선언 전 필수)
- 헤드리스 크롬으로 렌더 → PNG를 **열어 육안 확인**.
- slop 스캔 0 (gradient·blur·keyframes·colored-shadow·emoji).
- 표의 카운트가 `README`(한/영)·`CHANGELOG`·`VERSION`과 일치하는지 대조.

### 7. 출력
`docs/html/carve-workflow-guide.html` 덮어쓰기. 커밋·푸시는 **명시 요청 시에만**.

## 정합 축 (한 곳 고치면 전부)
인벤토리 수치는 이 HTML · `README.md` · `README.en.md` · `GUIDE.md` · `CHANGELOG.md`가 공유한다 — 하나 고치면 전부 맞춘다. 버전은 `VERSION` 파일과 일치.

## 불변 규칙
- 수치는 **실측**(파일시스템·`npm test`). 프로즈 복붙 금지.
- 배포 제외 스킬(`carve-guide` 자신)은 배포 스킬 카운트·목록에서 뺀다.
- 내부 앵커는 `preventDefault`+`scrollIntoView` 스크립트로 처리(URL 해시 변경 금지) — run-ai.kr SPA 임베드 호환.
- anti-slop 통과 + PNG 육안 확인이 완료 기준. 확인 전 완료 선언 금지.
