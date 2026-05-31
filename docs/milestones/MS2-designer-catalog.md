# Milestone 2 — Designer + Catalog (M2, 게이트 통과)

## 산출물
- `src/catalog.ts` — 설치 가능 구성요소 레지스트리(점수 ≥75): 6 핵심 스킬 · 7 필수 훅 + 1 선택 훅 ·
  Squad 8종 · anti-ai-slop 팩 · 추가 스킬(verify·security-scan·test-gen). `applicableTo`/`forType`/`byId`.
- `src/designer.ts` — ProjectProfile → 추천 슬롯 설계. `harnessLevel`(minimal/standard/full) + `design`.
  추천만 한다(일괄 설치 없음). 선택 컴포넌트(auto-commit)는 자동 추천 안 함.
- `test/unit/designer.test.ts` — 12 테스트(카탈로그 무결성·applicableTo 분기·레벨·design).

## 하네스 레벨 휴리스틱
- `full`: CI 있고 언어 ≥2
- `minimal`: cli/library/batch/unknown
- `standard`: 그 외(web/mobile/desktop)
- 추천: minimal=코어 스킬+필수 훅(차단·보호·핸드오프)+anti-slop / standard=+7 훅+Squad / full=+추가 스킬

## anti-slop 통합 (플랜 B)
anti-ai-slop 팩을 카탈로그에 등재(점수 85, 타입 무관 기본 추천) — 모든 프로젝트가 문서·다이어그램을 만들기 때문.

## 게이트 결과 (2026-05-31)
| 게이트 | 결과 |
|--------|------|
| `tsc --noEmit` | ✅ exit 0 |
| `npm test` | ✅ 45/45 |
| 커버리지 ≥80 | ✅ catalog 100% · designer 100% · 전체 96.1% line / 100% func |

## 다음: Milestone 3 — Generator (M3·M4·M5)
generator + 베이스 템플릿: 6 핵심 스킬·harness-architect 트리거 스킬·evaluation-criteria.md·flight-rules.md·
검증 훅(exit 2) + anti-slop 경고훅(C). 게이트: 문법검증·생성물 스냅샷·exit-2 차단 단위테스트.
