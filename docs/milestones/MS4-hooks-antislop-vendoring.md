# MS4 (part 3) — 7 필수 훅 완성 + anti-slop 팩 vendoring (게이트 통과)

## 산출물
- `assets/hooks/{pre-commit-lint,pre-push-test,auto-format,slack-notify,precompact-handoff}.sh` — 나머지 5 필수 훅.
  - pre-commit-lint·pre-push-test: 실패 시 **exit 2 차단** (lint/test 명령 템플릿, `CARVE_*_CMD` env override).
  - auto-format·slack-notify·precompact-handoff: **비차단(exit 0)**.
- `assets/antislop/**` — anti-slop 스킬 패밀리 vendoring 원본(마스터 SKILL.md + 4 포맷 + clean-html + check-slop.mjs).
- `src/generator.ts` — 훅 자산 **render(변수 치환)** + 5 훅 등록(HOOK_ASSETS/MATCHER) + **anti-slop 팩 파일 emit**(대상 .claude/skills 레이아웃 그대로).
- 테스트: hooks.test(8 훅 문법 + exit code) + generator(anti-slop 팩·7 훅·Squad emit).

## 게이트 결과 (2026-05-31)
| 게이트 | 결과 |
|--------|------|
| `tsc --noEmit` | ✅ OK |
| `npm test` | ✅ 78/78 |
| 커버리지 ≥80 | ✅ 97.3% line / 100% func |
| anti-slop E2E | ✅ install→설치된 훅이 vendored 린터로 SVG 슬롭 탐지 |

이제 `carve install`이 완전한 하네스 생성: harness-architect + 6 핵심 스킬 + Squad 8 + 7 필수 훅 + anti-slop 팩(린터 포함) + flight-rules + evaluation-criteria + settings.json 등록 + manifest.

## 남은 것
- ⏳ MS5: auditor(생성물 secret·권한·injection 스캔) + 대상 CLAUDE.md/HARNESS-GUIDE 생성.
- ⏳ wizard(@clack 대화형 선택) — 현재 비대화형 추천 설치.
- ⏳ MS6: PoC E2E 합격 + 벤치마크 점수 + README.

## 다음: MS5 — Auditor + 문서 생성
