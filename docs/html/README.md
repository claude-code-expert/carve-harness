# `docs/html/` — HTML 산출물 (GitHub Pages 공개)

`carve-guide` 스킬이 만든 정적 페이지(디자인 시스템·anti-slop 게이트 준수). `main` 브랜치의 이 파일들이 GitHub Pages로 공개돼 아래 링크를 클릭하면 바로 열린다.

> 공개 주소 = `https://claude-code-expert.github.io/carve-harness/docs/html/…`. `main`에 머지된 뒤 반영된다(브랜치·PR에서는 로컬 파일로 연다).

## 페이지

| 페이지 | 내용 | 링크 |
|---|---|---|
| 하네스 데모 (오펜 랜딩) | 같은 근거 문서로 오펜(macOS 화면 주석 앱) 랜딩을 하네스 없이(slop) / 하네스로(클린) 만든 결과 비교 — 시각 린터 76→0 error + 사실 경계(§14) 위반 8건 대조 | [열기](https://claude-code-expert.github.io/carve-harness/docs/html/ohpen-demo/index.html) |
| ├ 미적용(slop) | 하네스 없이 만든 결과 (check-slop 76 error) | [열기](https://claude-code-expert.github.io/carve-harness/docs/html/ohpen-demo/without-harness.html) |
| └ 적용(클린) | carve 적용 결과 (check-slop 0 error) | [열기](https://claude-code-expert.github.io/carve-harness/docs/html/ohpen-demo/with-harness.html) |
| carve 워크플로 가이드 | 설치→맞춤→게이트→검증 루프→골든셋 전체 흐름 | [열기](https://claude-code-expert.github.io/carve-harness/docs/html/carve-workflow-guide.html) |
| EDD 완전 가이드 | 평가 주도 개발(Evaluator-Driven) — 골든셋·게이트·성숙도 | [열기](https://claude-code-expert.github.io/carve-harness/docs/html/edd-complete-guide.html) |
| 평가 하네스 가이드 | 채점기·게이트·회귀 판정 구조 | [열기](https://claude-code-expert.github.io/carve-harness/docs/html/evaluation-harness-guide.html) |

## 로컬에서 보기

```bash
open docs/html/ohpen-demo/index.html          # macOS
xdg-open docs/html/carve-workflow-guide.html    # Linux
```

## 갱신

- 편집·신규 페이지는 `carve-guide` 스킬로 만든다(1000px 임베드 안전 폭·SPA 목차 안정화·anti-slop 게이트).
- 새 페이지를 추가하면 이 표에 `github.io/carve-harness/docs/html/<경로>` 링크를 함께 넣는다.
- 공개 반영은 `main` 머지 후(GitHub Pages가 `main`에서 서빙).
