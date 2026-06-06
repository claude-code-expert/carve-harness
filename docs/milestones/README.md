# 마일스톤 기록 (전부 완료 — v1.3.x)

> 이 디렉토리의 `MS*.md`·`anti-slop-linter.md`는 **개발 당시의 틱별 스냅샷**이다.
> 각 문서의 "남은 것"·"다음:" 항목은 *그 시점*의 TODO이며, 이후 틱에서 해소됐다(현재 TODO 아님).
> 현재 진행 상태·남은 작업은 `CHANGELOG.md`와 `docs/guide/carve-harness-benchmark-results.md`를 본다.

| 마일스톤 | 산출물 | 상태 |
|----------|--------|:--:|
| MS0 | 구조·CLI 스켈레톤(TS) | ✅ |
| MS1 | analyzer + ProjectProfile | ✅ |
| MS2 | designer + catalog | ✅ |
| MS3 | generator + flight-rules/eval + exit-2 훅 | ✅ |
| MS4 | installer·CLI·훅·anti-slop vendoring·wizard | ✅ |
| MS5 | auditor + CLAUDE.md/HARNESS-GUIDE 생성 | ✅ |
| MS6 | PoC E2E + README + 벤치마크 점수 | ✅ |
| anti-slop-linter | check-slop SVG/Markdown 확장 | ✅ |

이후: v1.1.0(MVP + post-PoC + mattpocock 스킬 + 카탈로그-자산 정합) → v1.1.1(대화형 진입 수정) → v1.2.0(M8·M9·M10 — 라이프사이클·분석 지능화·텔레메트리) → v1.3.0(운용 3대 조건 보강 + 전수 감사 패치). 로드맵은 CHANGELOG `[Unreleased]`·MS7 참조.

## v2.0 ([MS7 로드맵](MS7-v2-roadmap.md))

| 마일스톤 | 산출물 | 상태 |
|----------|--------|:--:|
| M8 | 라이프사이클 기반: 자산 hash + manifest v2 + `diff`/`update`/`migrate` (사용자 수정 보존) | ✅ |
| M9 | 분석·추천 지능화: 모노레포·컨테이너 시그널 + 가중 스코어링 + 선호 영속화 | ✅ |
| M10 | 로컬 효과 텔레메트리(opt-in): `_metrics.sh` emit + `carve report` 집계 | ✅ |
| M11 | 비교·증명 벤치 완성 | 📋 |
| M12 | 피드백 루프 통합 (closed loop) | 📋 |

> M8·M9·M10은 v1.2.0(2026-06-05)에서 완료. M11·M12는 예정.
