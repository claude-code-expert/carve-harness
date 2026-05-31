# Milestone 3 — Generator (M3·M4·M5, 게이트 통과)

## 산출물
- `src/generator.ts` — 설계+프로필 → 깎인 자산 생성. `render`({{KEY}} 치환) + `generate`. 파일은 안 씀(installer 담당).
- `assets/hooks/block-destructive.sh` — PreToolUse, `rm -rf /`·포크밤·디스크파괴·`git push --force main` **exit 2 차단**.
- `assets/hooks/protect-secrets.sh` — PreToolUse, `.env`·키·credentials 접근 **exit 2 차단** (`.env.example`는 허용).
- `assets/hooks/anti-slop.sh` — PostToolUse, `check-slop.mjs` 호출 **경고만(exit 0)** + 예외경로(presentation/slides).
- `assets/templates/flight-rules.md` · `_flight-rules-antislop.md` · `evaluation-criteria.md` — 변수 치환 템플릿.
- 테스트: `generator.test.ts`(6) + `hooks.test.ts`(11, exit code 단언).

JSON 파싱은 jq 대신 **node**(대상 프로젝트에 항상 존재). 훅은 결정적·테스트 가능.

## 게이트 결과 (2026-05-31)
| 게이트 | 결과 |
|--------|------|
| `bash -n` 훅 3종 | ✅ OK |
| `tsc --noEmit` | ✅ OK |
| `npm test` | ✅ 59/59 |
| 커버리지 ≥80 | ✅ generator 100% line · 전체 96.5% line / 100% func |

**PoC 핵심 검증**: 위험 명령 exit 2 차단·비밀파일 exit 2 차단·anti-slop 경고(비차단) 전부 단위테스트 통과.

## 이 틱에서 다룬 범위 / 남은 것 (정직)
- ✅ M3 generator 코어, M4 evaluation-criteria, M5 flight-rules + exit-2 검증훅, anti-slop 경고훅(C1)
- ⏳ 다음 틱: M7 `harness-architect` 트리거 스킬 + 6 핵심 스킬 SKILL.md 본문(generator 자산), 그 후 MS4 installer

## 다음: Milestone 4 — Installer + Wizard (M6·M7)
6 핵심 스킬·harness-architect 자산 작성 → wizard(@clack 선택) + installer 멱등(.bak·settings.json 병합) +
Squad 8 vendoring + uninstall. 게이트: E2E install→doctor→uninstall, 멱등, 자산 보존.
