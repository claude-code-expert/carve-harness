<!--
  Document : Project Structure
  Purpose  : carve-harness 디렉토리 맵 — bin/src 모듈 역할, 2레이어(리포 A vs 산출물 B), assets 원목, 빌드 산출물 규칙. 경로를 추측하지 않기 위함.
  Stack    : TypeScript (ESM, Node >=22.18)
  Version  : 1.1.0 (2026-06-02)
-->
# Project Structure

> 경로를 추측하지 말고 이 맵을 본다. 두 레이어(A=리포 자체, B=carve가 까는 산출물)를 항상 구분한다.

## 모듈 맵 (레이어 A — 이 리포)

| 경로 | 역할 | 규칙 |
|------|------|------|
| `bin/carve.ts` | CLI 엔트리포인트 | `src/cli.ts`의 얇은 진입점. `console`을 `IO`로 주입. shebang `--disable-warning` |
| `src/cli.ts` | CLI 코어 | 인자 해석·명령 디스패치. `IO` 인터페이스 정의. 로직은 여기서 테스트 |
| `src/commands.ts` | 명령 구현 | install/list/doctor/uninstall/init-claude. analyzer→designer→generator→auditor→installer 오케스트레이션 |
| `src/analyzer.ts` | 프로젝트 스캔 | 읽기 전용. 대상 파일 수정 금지 |
| `src/catalog.ts` | 구성요소 카탈로그 | id·kind·점수·core/optional·applicable의 단일 출처 |
| `src/designer.ts` | 하네스 슬롯 설계 | `catalog` 기준 레벨·추천 산출. 추천만(설치 안 함) |
| `src/generator.ts` | 자산 깎기·생성 | `assets/`에서 소스 로드해 변수 치환. 파일은 쓰지 않음(installer가 씀) |
| `src/auditor.ts` | 생성물 자기 검증 | secret 노출·과도 권한·훅 주입·셸 문법 스캔 |
| `src/installer.ts` | 대상 프로젝트 설치 | **멱등 필수**. manifest 기록·.bak 보존·settings.json 병합 |
| `src/claudebase.ts` | CLAUDE.md 베이스라인 + 스택 rules 생성 | `assets/claude-base`에서 스택 선택·렌더 (`carve init-claude`) |
| `src/manifest.ts` | 설치 매니페스트 | 멱등·uninstall 기준(files·hooks·mcps) |
| `src/wizard.ts` | 대화형 선택 | `@clack/prompts` 체크박스. TTY에서만 |
| `src/types.ts` | 공용 타입 | ProjectProfile·ProjectType 등 |

## 자산 (레이어 A — 깎기 전 원목)

| 경로 | 내용 |
|------|------|
| `assets/skills/<id>/SKILL.md` | 스킬 본문 + 커맨드 shim은 `assets/commands/carve-<id>.md` |
| `assets/hooks/*.sh` | 훅 스크립트(결정적 차단·포맷 등) |
| `assets/squad/` | Squad 8 에이전트·커맨드·라우터/체이닝 훅 (melt-in, vendor 비의존) |
| `assets/antislop/` | anti-slop 패밀리 + `check-slop.mjs` 린터 (melt-in) |
| `assets/claude-base/` | 스택무관 `CLAUDE.md` + `rules/<lang>/*` (ts·py·go·rust·java·dart·_default) |
| `assets/templates/` | flight-rules·evaluation-criteria·HARNESS-GUIDE 등 |

## 레이어 B (carve가 *대상 프로젝트*에 까는 산출물)

`<user-project>/.claude/` (skills·hooks·agents·commands·rules·settings.json) + 루트 가이드(CLAUDE.md·flight-rules.md 등) + `carve-manifest.json`. **코드에서 "지금 만지는 게 A인가 B의 템플릿인가"를 항상 분명히 한다.**

## 관례 (carve 한정)

- **ESM·빌드리스 개발**: Node >=22.18 타입 스트리핑으로 `.ts` 직접 실행. **경로 alias 없음**(`@/*` 미사용) — 상대경로만.
- 상대 import는 **확장자 명시**(`'./designer.ts'`). 배포 빌드가 `.ts`→`.js`로 재작성한다.
- `bin/*.js`·`src/*.js`는 **배포 빌드 산출물**(gitignore). 소스는 `.ts`뿐. 직접 편집 금지.
- 자산 경로는 `new URL('../assets/', import.meta.url)` 기준 — 파일을 다른 깊이로 옮기면 깨진다.
- `vendor/`는 삭제됨(런타임 비의존). 필요한 건 전부 `assets/`로 melt-in 완료.
- 테스트: `test/{unit,e2e,fixtures}`, `node --test`로 `.ts` 직접 실행.
