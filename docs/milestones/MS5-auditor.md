# Milestone 5 — Auditor + 문서 생성 (게이트 통과)

## 산출물
- `src/auditor.ts` — 산출물 보안 스캔. secret(AWS·private key·GitHub·OpenAI·Slack)·remote-exec(curl|bash)·
  chmod 777·sudo·하드코딩 비밀번호·훅 주입(settings/훅 기록). `audit`/`errorsOf`.
- `commands.ts` — `cmdInstall`이 설치 **전 자기검증**: ERROR 있으면 중단(exit 1). (PoC #4)
- `assets/templates/target-CLAUDE.md` · `HARNESS-GUIDE.md` — 대상 프로젝트 가이드(COMPONENT_LIST 치환).
- `generator.ts` — CLAUDE.md·HARNESS-GUIDE.md emit.
- 테스트: `auditor.test.ts`(7) — 실제 생성물 0 ERROR + 각 룰 탐지.

## 게이트 결과 (2026-05-31)
| 게이트 | 결과 |
|--------|------|
| `tsc --noEmit` | ✅ OK |
| `npm test` | ✅ 86/86 |
| 커버리지 ≥80 | ✅ auditor 100% · 전체 97.2% line / 100% func |
| PoC #4 | ✅ carve 생성물 auditor ERROR 0건 |

## 남은 것 (완료까지)
- ⏳ wizard(@clack 대화형 선택) — 사용자 필수 요구(현재 비대화형 추천 설치).
- ⏳ `install.sh` bash 래퍼(배포 npx+bash 둘 다).
- ⏳ MS6: PoC E2E 합격 시나리오 + **README.md** + 벤치마크 점수 측정.

## 다음: Wizard + install.sh → MS6(PoC E2E + README + 벤치마크)
