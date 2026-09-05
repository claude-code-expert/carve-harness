# `.claude/` — Claude Code 하네스 설정 루트

Claude Code가 세션마다 읽는 설정·게이트·확장이 모두 여기 있다. `install.sh`가 대상 프로젝트로 복사하고, `settings.json`이 훅을 이벤트에 배선한다.

| 경로 | 역할 |
|---|---|
| `settings.json` | 훅 6이벤트 등록 + 권한 deny + LSP/플러그인 선언. 하네스의 배선 정본 |
| `CLAUDE.md` | Claude Code 고유 행동 지침(정본은 루트 `AGENTS.md`) |
| `hooks/` | 게이트·가드·헬퍼 스크립트 + 스택 정의를 source (`stacks/`) |
| `stacks/` | 언어별 검증 게이트·포맷·채점 어댑터 1파일씩 (언어팩 단위 설치) |
| `rules/` | glob 자동 로드 규칙(스택별·공통) |
| `workflows/` | 오케스트레이션 워크플로 (자체 `README.md` 참조) |
| `bin/` | install.sh가 vendor에서 배치한 jq·shellcheck (gitignore) |
| `harness-manifest.txt` · `harness-version` · `harness-components` · `harness-packs` | 설치 상태 기록(gitignore). update·uninstall·pack이 읽는다 |

> 설치본에서는 `hooks/`·`stacks/`·`settings.json`·manifest가 자기보호(GUARD-07) 대상 — 에이전트가 게이트를 끄지 못한다.

## 로더가 스캔하는 폴더 (개별 README 없음)

`commands/` · `agents/` · `skills/` 는 Claude Code가 폴더 안 파일을 **컴포넌트로 읽는다** — loose `README.md`를 두면 `/README` 커맨드나 이름 없는 에이전트/스킬로 등록되므로 여기서는 이 표로 역할을 남긴다.

| 폴더 | 무엇 | 파일 단위 |
|---|---|---|
| `commands/` | 사람이 `/<이름>`으로 부르는 저장된 프롬프트 | `<이름>.md` (`/plan`·`/verify`·`/eval`·`/harness-audit` …) |
| `agents/` | 별도 컨텍스트 서브에이전트(생성/검증 분리). 채점자는 코드를 안 고친다 | `<이름>.md` + 프런트매터(도구·모델). evaluator·security-reviewer·pr-test-analyzer·fable-* |
| `skills/` | 발화가 description과 맞으면 로드되는 절차서 | `<이름>/SKILL.md` (프런트매터 필수 — AUDIT-06). anti-ai-slop·carve-*·eval-* … |

> 전체 목록·발동 시점은 루트 `README.md`의 "전체 구성" 표와 `GUIDE.md` §5.
