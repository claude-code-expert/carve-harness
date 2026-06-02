<!--
  Document : Project Structure
  Purpose  : Reference map of the directory layout (src/domain, services, api, lib, tests, .claude/rules) and conventions (path alias, where types/config live) so paths are never guessed.
  Stack    : TypeScript
  Version  : 1.0.0 (2026-06-01)
-->
# Project Structure

> Reference map so paths are never guessed (see CLAUDE.md "Source first").

## Layout (adjust per project) - directory guide

| 경로 | 역할 | 규칙 |
|------|------|------|
| `bin/carve.ts` | CLI 엔트리포인트 | `src/cli.ts`의 얇은 진입점. shebang에서 `--disable-warning` |
| `src/cli.ts` | CLI 코어 | 인자 해석·명령 디스패치. 로직은 여기서 테스트 |
| `src/analyzer.ts` | 프로젝트 스캔 | 읽기 전용. 파일 수정 금지 |
| `src/designer.ts` | 하네스 슬롯 설계 | `vendor/openharness` 분류 체계 참조 |
| `src/generator.ts` | 자산 깎기·생성 | `vendor/subagents`·`assets`에서 소스 로드 |
| `src/auditor.ts` | 생성물 자기 검증 | 보안·권한·훅 주입 스캔 |
| `src/installer.ts` | 대상 프로젝트 설치 | 멱등성 필수 |
| `src/claudebase.ts` | CLAUDE.md 베이스라인 + 스택별 rules 생성 | `assets/claude-base`에서 스택 선택·렌더 (`carve init-claude`) |
| `assets/claude-base/` | CLAUDE.md 베이스라인 + 언어별 rules 템플릿 | 스택 무관 `CLAUDE.md` + `rules/<lang>/*` (ts·py·go·rust·java·dart·_default) |
| `assets/squad/` | Squad 자산(녹여넣음) | vendor/subagents에서 melt-in. carve는 vendor 비의존 |
| `assets/antislop/` | anti-slop 패밀리(녹여넣음) | vendor/.claude에서 melt-in |
| `assets/` | 베이스 템플릿 | 깎기 전 원목 |

## Conventions
- One module = one responsibility. Keep files focused and small.
- Path alias `@/*` → `src/*` (configured in `tsconfig.json`).

