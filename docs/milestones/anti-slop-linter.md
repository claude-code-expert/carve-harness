# Anti-AI-Slop 린터 게이트 확장 (플랜 항목 A + F1)

> 출처: 승인된 플랜 `~/.claude/plans/html-mossy-clock.md`. 이 작업은 "최우선(갭1)" 항목.
> 나머지 항목(B 카탈로그·C 생성훅·D 설치·E 벤치·F2 포지셔닝)은 MS2~MS6에서 진행.

## 무엇을 했나

생성-전 규칙(스킬)은 이미 완성돼 있으나, 결정론적 게이트(`check-slop`)가 HTML/CSS만 덮어
SVG·Markdown은 산문 자가점검에만 의존했다. 그 갭을 메웠다.

- **A1 SVG 모드**: `<linearGradient>`/`<radialGradient>`/`<meshgradient>`·CSS gradient(ERROR),
  `feGaussianBlur`/`feDropShadow`/`filter blur`(ERROR), 팔레트 밖 chromatic 색(WARN), `viewBox` 누락(WARN)
- **A2 Markdown 모드**: 마케팅 버즈워드·이모지 검사
- **A3 한국어 마케팅어**: "차원이 다른"·"혁신적인" 등 substring 매칭 추가(영어는 word-boundary 유지)
- **A4 확장자 디스패치**: `.html/.css`→HTML/CSS, `.svg`→SVG, `.md/.markdown`→문서. 의존성 0 유지
- **포팅 수정**: `check-slop.js` → **`check-slop.mjs`**. `.claude/package.json`이 `commonjs`라 `.js`는
  CJS로 해석돼 `import`가 깨졌다(잠복 버그). `.mjs`는 어느 프로젝트 package.json type에도 항상 ESM →
  임의 프로젝트로 복사돼도 동작.
- **F1**: `clean-html/SKILL.md`의 stale 참조(미존재 `docs/guide/FRONTEND-GENERATE-HTML-SKILL.md`)를
  실제 단일출처(마스터 `.claude/skills/SKILL.md` = anti-ai-slop)로 교체.

## 게이트 결과 (2026-05-31)

| 게이트 | 결과 |
|--------|------|
| `node --check check-slop.mjs` | ✅ OK (ESM) |
| `tsc --noEmit` | ✅ exit 0 |
| `npm test` | ✅ 34/34 |
| 커버리지 ≥80 | ✅ check-slop.mjs 94.6% line/100% func, 전체 95.1% line/100% func |

fixtures: `test/fixtures/slop/{clean,slop}.{svg,md,html}` + `slop.css`. 모든 핵심 MUST-NOT 룰 발화 검증.
clean 산출물 exit 0, slop 산출물 exit 1, 잘못된 호출 exit 2.

## 남은 anti-slop 작업 (플랜)
- B(MS2): 카탈로그에 anti-ai-slop 팩 등록(점수85, 타입무관 기본추천)
- C(MS3): PostToolUse 경고훅(예외경로) + flight-rules/eval 섹션
- D(MS4): 스킬패밀리 vendoring·멱등설치·uninstall
- E(MS6): PoC anti-slop 합격 + 벤치 seeds
- F2: README/HARNESS-GUIDE 부각
