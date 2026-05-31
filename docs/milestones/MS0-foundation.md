# Milestone 0 — Foundation (게이트 통과 기록)

> 다음 마일스톤 진입 전, 이 문서의 게이트가 모두 통과해야 한다.

## 산출물

- 디렉토리 구조: `bin/ src/ assets/{skills,commands,hooks,docs} vendor/ test/{unit,e2e,fixtures}`
- `vendor/openharness`, `vendor/subagents` 이동 (git mv, 히스토리 보존)
- `package.json` (name=carve-harness, ESM, bin=carve, dep=@clack/prompts)
- `bin/carve.js` (얇은 진입점) + `src/cli.js` (CLI 코어)
- 기본 문서: `requirement.md`, `ARCHITECTURE.md`, `README.md`
- 테스트: `test/unit/cli.test.js`

## 게이트 결과 (2026-05-31, 검증 후)

| 게이트 | 명령 | 결과 |
|--------|------|------|
| 문법 | `node --check bin/carve.js` / `src/cli.js` | ✅ OK |
| 테스트 | `npm test` (unit 7 + e2e 4) | ✅ 11/11 pass |
| 커버리지 | `npm run test:cov` (≥80) | ✅ bin 100% + src 100% (게이트 exit 0) |
| CLI 동작 | `carve --version` | ✅ `0.1.0` |
| CLI 동작 | `carve` / `--help` | ✅ 사용법 출력 |
| CLI 동작 | `carve bogus` | ✅ exit 1 |

## 검증에서 발견·수정한 누락

1. **bin/carve.js 커버리지 사각지대**: 단위 테스트가 `src/cli.js`만 import해 엔트리포인트가
   커버리지 리포트에서 빠져 있었다(가짜 100%). → `test/e2e/cli.e2e.test.js`에서 `spawnSync`로
   실제 `node bin/carve.js`를 실행해 bin을 100% 포착.
2. **E2E 0건**: `test/e2e/`가 비어 있었다. → 스모크 4건 추가(--version, no-args, install 스텁, 미지 명령).

## 한계 (정직 표기)

- E2E는 **현재 구현된 범위(엔트리포인트·명령 분기)만** 커버한다.
  `install`/`uninstall`을 fixtures에 적용하는 **풀 시스템 E2E는 MS4/MS6에서 추가**된다.

## 주의

- `node --test`는 트리 전체를 탐색하므로 `vendor/`의 서드파티 테스트를 실행하지 않도록
  `'test/**/*.test.js'`로 한정했다. (vendor는 읽기 전용)

## 언어 전환 (2026-05-31): JS → TypeScript (빌드 0)

- Rust 검토 후 비채택(npx 배포 불가·@clack 불가·I/O 바운드라 성능 이득 없음).
- `.js` → `.ts` 전환. Node ≥22.18 타입 스트리핑으로 빌드 없이 직접 실행. `engines` `>=22.18`.
- `tsconfig.json`(`allowImportingTsExtensions`+`noEmit`+`strict`), `package.json` 갱신, `typescript`·`@types/node` 추가.
- 게이트 재확인: `tsc --noEmit` exit 0, 테스트 11/11, 커버리지 bin+src 100%.
- bin shebang `env -S node --disable-warning=ExperimentalWarning`로 타입 스트리핑 경고 억제(stderr 깨끗).

## 다음: Milestone 1 — Analyzer
프로젝트 타입/언어/도구 탐지 → ProjectProfile. fixtures 5종(cli/web/mobile/desktop/batch).
