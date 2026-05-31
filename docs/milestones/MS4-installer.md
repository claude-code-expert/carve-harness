# Milestone 4 (part 1) — Installer + Manifest (M6, 게이트 통과)

## 산출물
- `src/manifest.ts` — `carve-manifest.json` 읽기/쓰기/삭제. 설치 파일·백업·훅 추적.
- `src/installer.ts` — 멱등 `install`/`uninstall`.
  - 사용자 파일은 `.bak`로 1회 보존 후 carve 콘텐츠 작성.
  - settings.json 훅 **idempotent 병합**(carve 마커 `_carve`). 재설치 시 중복 없음.
  - uninstall: manifest 기준 carve 파일 제거 + `.bak` 복원 + carve 훅만 제거(사용자 훅 보존) + manifest 삭제.
- 테스트: `test/e2e/installer.e2e.test.ts`(5) — 임시 디렉토리 왕복.

## 게이트 결과 (2026-05-31)
| 게이트 | 결과 |
|--------|------|
| `tsc --noEmit` | ✅ OK |
| `npm test` | ✅ 64/64 |
| 커버리지 ≥80 | ✅ installer 98.6% · manifest 95.2% · 전체 96.8% line / 100% func |

검증: fresh install·재설치 멱등·사용자 파일 .bak 보존·uninstall 복원·사용자 훅 보존·manifest 없을 때 무해.

## 이 틱 범위 / 남은 것
- ✅ M6 멱등 설치 엔진 + manifest + uninstall
- ⏳ MS4 part 2: CLI 와이어링(`carve install`=analyze→design→generate→install, `list`/`doctor`/`uninstall`) +
  wizard(@clack 선택) + 6 핵심 스킬·harness-architect 자산 작성 + Squad 8 vendoring(asset copy)

## 다음: MS4 part 2 — CLI 와이어링 + Wizard + 자산
게이트: `carve` 명령 E2E(분석→생성→설치→doctor→uninstall) + 자산 문법검증.
