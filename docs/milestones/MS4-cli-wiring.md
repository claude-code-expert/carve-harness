# Milestone 4 (part 2) — CLI 와이어링 + 자산 (M7, 게이트 통과)

## 산출물
- `assets/skills/{harness-architect,handoff,memory,commit,changelog,review,pr}/SKILL.md` — 진입 스킬(M7) + 6 핵심.
- `src/commands.ts` — `cmdList`/`cmdInstall`/`cmdDoctor`/`cmdUninstall`. install = analyze→design→generate→install.
- `src/cli.ts` — list/install/doctor/uninstall 디스패치(두 번째 인자=대상 디렉토리, 기본 cwd).
- `src/generator.ts` 확장 — 추천 스킬(assets/skills) + Squad 에이전트(vendor/subagents) 자산 emit, `hookRegsFor`.
- `src/catalog.ts` — `harness-architect` 코어 스킬 추가.
- 테스트: `cli.test.ts` install→doctor→uninstall 라운드트립(임시 디렉토리), `cli.e2e.test.ts` `carve list` 스모크.

## 게이트 결과 (2026-05-31)
| 게이트 | 결과 |
|--------|------|
| `tsc --noEmit` | ✅ OK |
| `npm test` | ✅ 65/65 |
| 커버리지 ≥80 | ✅ commands·cli 100% · 전체 97.3% line / 100% func |
| 레포 오염 | ✅ 없음(임시 디렉토리 사용) |

`carve install <dir>`가 실제 파이프라인을 수행함을 라운드트립으로 검증.

## 남은 것 (정직)
- ⏳ 5개 미작성 훅 스크립트(pre-commit-lint·pre-push-test·auto-format·slack-notify·precompact-handoff) — 현재 추천되나 미생성.
- ⏳ **anti-slop 팩 vendoring**: 훅은 생성되나 `check-slop.mjs`/스킬 패밀리가 대상에 복사되지 않아 훅이 린터를 못 찾음 → 다음 틱 최우선.
- ⏳ wizard(@clack 대화형 선택) — 현재 비대화형(추천 설치). 
- ⏳ MS5 auditor + CLAUDE.md/HARNESS-GUIDE 생성, MS6 PoC E2E + 벤치마크 + README.

## 다음: 5 훅 + anti-slop 팩 vendoring → MS5 auditor
