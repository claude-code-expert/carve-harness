# carve-harness 아키텍처

> 요구사항은 [requirement.md](./requirement.md), 개발 지침은 [CLAUDE.md](./CLAUDE.md) 참고.

## 두 레이어 (절대 혼동 금지)

- **레이어 A** = carve-harness CLI 자체 (`bin/`, `src/`, `vendor/`, `assets/`)
- **레이어 B** = carve가 대상 프로젝트에 까는 산출물 (`<user-project>/.claude/`)

## 파이프라인

```
carve install
  └─ analyzer   읽기 전용 스캔 → ProjectProfile (타입·언어·도구)
  └─ catalog    설치 가능한 구성요소 레지스트리 (적합성·의존성·점수)
  └─ wizard     대화형 선택 (@clack/prompts). 추천은 하되 선택은 사용자가. 일괄 없음
  └─ designer   선택 + 프로필 → 슬롯 설계 (템플릿 변수 결정)
  └─ generator  assets/ 원목을 깎아 자산 생성 + 변수 치환
  └─ auditor    자기검증 (secret·권한·injection·문법)
  └─ installer  멱등 설치 + manifest 기록 (클린 언인스톨용)
```

## 디렉토리

| 경로 | 역할 | 규칙 |
|------|------|------|
| `bin/carve.ts` | 엔트리포인트 | `src/cli.ts`의 얇은 진입점 |
| `src/cli.ts` | CLI 코어 | 인자 해석·명령 디스패치. 로직은 여기서 테스트 |
| `src/analyzer.ts` | 프로젝트 스캔 | 읽기 전용. 파일 수정 금지 |
| `src/catalog.ts` | 구성요소 레지스트리 | 타입 적합성·점수 정의 |
| `src/wizard.ts` | 대화형 선택 | @clack/prompts |
| `src/designer.ts` | 슬롯 설계 | vendor/openharness 분류 참조 |
| `src/generator.ts` | 자산 생성 | assets·vendor에서 소스 로드 |
| `src/auditor.ts` | 자기 검증 | 보안·권한·훅 주입 스캔 |
| `src/installer.ts` | 대상 설치 | 멱등성 필수 |
| `src/manifest.ts` | 설치 내역 추적 | 클린 언인스톨 |
| `assets/` | 베이스 템플릿 | 깎기 전 원목 |
| `assets/squad/` | Squad 자산(melt-in) | 8 에이전트·9 커맨드·라우터/체이닝 훅. vendor 비의존 |
| `assets/antislop/` | anti-slop 패밀리(melt-in) | 마스터 스킬·포맷·clean-html·check-slop.mjs |
| `test/{unit,e2e,fixtures}/` | 테스트 | 커버리지·E2E ≥80 |

## 설치 산출물 (레이어 B)

```
<user-project>/.claude/
  skills/carve-*/SKILL.md      # 6 핵심 + 추가
  commands/carve-*.md          # 얇은 shim
  agents/squad-*.md            # Squad 8종 (보존)
  hooks/*.sh                   # 7 필수 + 1 선택
  settings.json                # 훅 등록 (멱등 머지)
carve-manifest.json            # 설치 내역 (언인스톨용)
CLAUDE.md                      # 생성된 하네스 가이드
HARNESS-GUIDE.md               # 사용법
```

## 기술 스택

- **TypeScript (ESM), 빌드 0** — Node ≥22.18 타입 스트리핑으로 `.ts` 직접 실행. `.ts` import는 확장자 명시
- 런타임 의존성: `@clack/prompts` (대화형 선택)
- 개발 의존성: `typescript`(`tsc --noEmit` 타입체크), `@types/node`
- 테스트: `node --test` 내장 러너 + 내장 커버리지(`--experimental-test-coverage`)
- 배포: npm/npx + `install.sh` 래퍼. bin shebang은 `env -S node --disable-warning=ExperimentalWarning`

## PoC 성공 기준 (단일 기준)

> 출처: `docs/guide/carve-harness-features-priority.md`

```
임의 프로젝트에서 "프로젝트에 맞는 하네스 구성해줘"
  → analyzer가 스택을 맞게 감지하고
  → (설계된 슬롯을 선택) → generator가 .claude/에 깎인 자산을 생성하며
  → 생성된 검증 훅이 실제로 위반을 차단한다 (PreToolUse exit code 2)
```

PoC 합격 시나리오(=최종 E2E 게이트): ① TS 프로젝트 → `any` 금지 flight-rule + PostToolUse 린트 훅 생성
② 생성된 PreToolUse 훅이 `rm -rf`를 exit code 2로 차단 ③ 재실행 멱등(사용자 수정 비파괴) ④ auditor secret·과도권한 0건.

## MUST 구성요소 (M1–M7)

| M | 무엇 | 매핑 |
|---|------|------|
| M1 | Analyzer — 읽기전용 스택 감지 → ProjectProfile | MS1 ✅ |
| M2 | Designer — OpenHarness 10서브시스템 슬롯 매핑 + 하네스 레벨 제안(`--level`로 강제 가능) | MS2 |
| M3 | Generator — vendor/subagents·assets에서 깎아 4종 자산 생성 | MS3 |
| M4 | `evaluation-criteria.md` 생성 — 측정 가능 품질 기준(가중치, MUST/SHOULD PASS) | MS3 |
| M5 | `flight-rules.md` + 검증 훅 — 금지/필수 규칙 + **exit code 2 결정적 차단** | MS3 |
| M6 | 멱등 설치 — .bak 보존, jq 기반 settings.json 안전 갱신, 충돌 diff | MS4 |
| M7 | CLI 엔트리 + `harness-architect` 스킬 — 자연어 트리거(설계 슬롯을 선택지로 제시) | MS4 |

> 자연어 트리거는 자동 일괄이 아니다. analyze→design 후 **선택 게이트**를 거쳐 generate한다(사용자 결정: 일괄 설치 없음).

## 마일스톤

| MS | M-매핑 | 산출물 | 게이트 |
|----|--------|--------|--------|
| 0 ✅ | — | 구조·CLI 스켈레톤(TS) | check/test/--version |
| 1 ✅ | M1 | analyzer + ProjectProfile | fixtures 5종, 커버 ≥80 |
| 2 | M2 | designer(10슬롯 매핑) + catalog(점수표) + 하네스 레벨 제안 | profile→슬롯추천 스냅샷, 커버 ≥80 |
| 3 | M3·M4·M5 | generator + 템플릿: 6 핵심 스킬·harness-architect·evaluation-criteria.md·flight-rules.md·검증훅(exit 2) | 문법검증, 생성물 스냅샷, exit-2 차단 테스트 |
| 4 | M6·M7 | wizard(선택) + harness-architect 스킬 + installer 멱등 + uninstall + Squad 8 보존 | E2E install→doctor→uninstall, 멱등, 자산 보존 |
| 5 | PoC#4 | auditor(secret·권한·injection) + CLAUDE.md·HARNESS-GUIDE 생성 | 위반 fixture 차단, 0 findings |
| 6 | PoC accept | PoC 합격 E2E(예: Next.js+TS) + 커버리지 게이트 | exit-2 차단·멱등·auditor 0·커버 ≥80 |

## post-PoC 로드맵 (실제 릴리스 상태)

- **v1.0–v1.2.1** ✅: MVP(M1–M7) + 카탈로그-자산 정합.
- **v1.3** ✅ (SHOULD #1–4): Evaluator 서브에이전트 · Sprint Contract 생성 · auditor 강화(shellcheck/bash -n).
- **v1.4** ✅ (COULD #5–7): 멀티에이전트 병렬 · Evaluator 튜닝 루프 · 모델 3-Tier 라우팅.
- **v2.0** ✅ (COULD #8·#10): harness-audit · coordinator. (#11 provider · #12 TUI = carve 모델 밖, out-of-fit/보류)
- **v2.1** ✅: 토큰 효율 기본 탑재 — codesight(MCP+refresh) + LSP(cclsp MCP + 언어서버 자동설치). 모든 구성요소가 grep 대신 우선 사용.
- **v2.2** ✅: 설치 레벨 강제 플래그 `--level <minimal|standard|full>` — 프로필 자동 판정을 사용자가 수동 override(`full`은 단일언어에도 병렬·조율 스킬 설치).
- **v2.3** ✅: `carve init-claude` — CLAUDE.md 베이스라인(`.claude/CLAUDE.md`) + 언어 스택별 `.claude/rules/*`(ts/py/go/rust/java/dart/_default × 6) 생성, 루트 `CLAUDE.md` `@import` 멱등 연결. 내부 템플릿 `assets/claude-base/`.
- **v2.4** ✅ (문서): 전체 설치 매뉴얼 `INSTALL.md`(한)·`INSTALL.en.md`(영) + README 재정비(풀 설치·라이브 벤치 점수·제거). 코드 변경 없음.
- **잔여**: 벤치 cross-harness 축 3(트리거)·4(컨텍스트) 라이브 측정, v2.1 절약 수치 검증(대형 fixture).
