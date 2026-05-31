# Milestone 1 — Analyzer (게이트 통과 기록)

## 산출물

- `src/types.ts` — `ProjectType`(cli/web/mobile/desktop/batch/library/unknown), `ProjectProfile`
- `src/analyzer.ts` — 결정적 휴리스틱 탐지. 읽기 전용(파일 수정 없음)
- `test/fixtures/{cli,web,mobile,desktop,batch}/` — 타입별 마커 fixture
- `test/unit/analyzer.test.ts` — 18개 테스트

## 탐지 휴리스틱 (우선순위)

1. mobile — pubspec.yaml(flutter) / react-native·expo·capacitor / android+ios
2. desktop — electron / tauri / src-tauri
3. web — react·vue·svelte·angular·next·vite 등 (반응형 web 흡수)
4. cli — package.json `bin` / commander·yargs·oclif / python click·typer
5. batch — node-cron·bull·agenda / python apscheduler·celery
6. library — exports/main 있고 앱·cli 시그널 없음
7. unknown — 폴백

부가: 언어, 패키지매니저(lockfile), test/lint/format 명령(scripts), CI(.github/.gitlab), git.

## 게이트 결과 (2026-05-31)

| 게이트 | 결과 |
|--------|------|
| `tsc --noEmit` | ✅ exit 0 |
| 테스트 | ✅ 25/25 (누적) |
| 5 fixtures type·language | ✅ 전부 정확 |
| 커버리지 ≥80 | ✅ analyzer 94.4% line / 100% func, 전체 95.6% |

## 알려진 한계

- 미커버 분기: java(pom/gradle)·poetry·cargo·tauri·android+ios 등 fixture 없는 대체 시그널.
  80 기준 여유 통과라 추가 fixture는 후속 필요 시 보강.
- analyzer는 모듈로만 완성. CLI 명령 연결은 MS3(wizard)/MS4(installer).

## 다음: Milestone 2 — Designer + Catalog (M2)
OpenHarness 10서브시스템 슬롯 매핑 + catalog(점수표) + 하네스 레벨 자동 제안.
게이트: profile→슬롯추천 스냅샷, 커버 ≥80.
(플랜 재조정: `docs/guide/carve-harness-features-priority.md` 반영 — ARCHITECTURE.md "마일스톤" 참조)
