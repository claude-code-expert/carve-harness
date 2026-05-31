# MS4 (part 4) — Wizard 대화형 선택 + bash 배포 (게이트 통과)

## 산출물
- `src/wizard.ts` — `buildChoices`(순수, 추천=기본체크) + `selectInteractive`(@clack 멀티셀렉트, TTY).
- `src/commands.ts` — `interactiveInstall`(TTY 선택→설치), `cmdInstall(root, io, selected?)` 부분집합 설치.
- `src/cli.ts` — `parseOnly`(--only a,b) + 플래그 제외 위치인자로 dir 선택.
- `bin/carve.ts` — install + TTY + --only/--yes 없음 → 대화형 wizard, 아니면 비대화형.
- `install.sh` — npx/node 양쪽 배포 래퍼(+ --uninstall).
- 테스트: `wizard.test.ts`(buildChoices·parseOnly·--only 부분집합 설치).

## 게이트 결과 (2026-05-31)
| 게이트 | 결과 |
|--------|------|
| `bash -n install.sh` | ✅ OK |
| `tsc --noEmit` | ✅ OK |
| `npm test` | ✅ 89/89 |
| 커버리지 ≥80 | ✅ 94.98% line / 95.4% func |
| 레포 오염 | ✅ 없음 |

**대화형 선택 설치(일괄 없음)** 요구 충족: `--only`로 고른 스킬만 설치되고 나머지(훅·에이전트)는 미설치 확인.

## 남은 것 (완료까지)
- ⏳ MS6 = **완료 틱**: PoC E2E 합격 시나리오 통합 테스트 + **README.md** + 벤치마크 점수 측정(`carve-harness-benchmark-criteria.md`).

## 다음: MS6 — PoC E2E + README + 벤치마크 점수 (완료)
