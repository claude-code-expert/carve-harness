# Milestone 6 — PoC E2E + README + 벤치마크 점수 (게이트 통과)

## 산출물
- `test/e2e/poc.e2e.test.ts` — PoC 합격 시나리오 통합(5): install→생성물·문서, **rm -rf / exit 2 차단**,
  anti-slop SVG 탐지(vendored 린터), 멱등 재설치+uninstall, 사용자 CLAUDE.md 보존.
- `README.md` — 핵심 README(설치/사용/구성요소/anti-slop/안전/아키텍처). **anti-slop 린터 자기검사 0 ERROR(도그푸딩)**.
- `docs/guide/carve-harness-benchmark-results.md` — 6축 자기평가 점수표.

## 게이트 결과 (2026-05-31)
| 게이트 | 결과 |
|--------|------|
| `tsc --noEmit` | ✅ OK |
| `npm test` | ✅ 94/94 |
| 커버리지 ≥80 | ✅ 94.98% line / 95.4% func |
| PoC 합격 시나리오 | ✅ exit2 차단·anti-slop·멱등·uninstall |
| README 도그푸딩 | ✅ check-slop 0 ERROR |

## 점수 측정 요약
- 자기측정 축 2·5·6: **강함**(결정적 증거). 비교 축 1·3·4: 라이브 벤치 필요(보류).
- **발견 갭(점수 향상 대상)**: ① Squad 라우터/체이닝 훅 vendoring 누락 ② command shim 미작성.

## 다음 루프: 갭 보완 (스코어 향상)
- `squad-router.sh`·`subagent-chain.sh` vendoring + generator 생성 + settings.json 등록(UserPromptSubmit/SubagentStart·Stop).
- 6 핵심 스킬 + squad `/carve-*` command shim.
- 보완 후 벤치마크 점수표 갱신.
