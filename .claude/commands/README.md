# `.claude/commands/` — 슬래시 커맨드

사람이 `/<이름>`으로 직접 부르는 저장된 프롬프트. **파일명 = 커맨드명**. Claude Code가 이 폴더의 `*.md`를 각각 커맨드로 로드한다.

## 역할
자주 쓰는 지시를 한 단어로. 커맨드 본문이 그대로 프롬프트가 되고, `$ARGUMENTS`로 뒤 인자를 받는다.

## 목록
| 커맨드 | 용도 |
|---|---|
| `/plan` `/verify` `/review` | SC 분해 · SC 검증 · 다관점 코드 검토 |
| `/commit` `/commit-branch` | 커밋 / 브랜치 커밋+푸시 (자동호출 비활성) |
| `/harness-audit` | 구성 PASS/FAIL (AUDIT-01~09) |
| `/eval` `/verify-loop` | 골든셋 재채점 / 검증 루프 워크플로 |
| `/ponytail*` (6) | ponytail 모드 제어 |

## 사용방법
- 세션에서 `/plan "OAuth 로그인 추가"`. 인자는 커맨드 뒤에.
- 새 커맨드 = `<이름>.md` 1파일. `--- description: ... ---` 프런트매터 + 본문(지시). 파괴적/명시호출 전용이면 `disable-model-invocation: true`.

> 이 폴더는 `*.md`를 커맨드로 읽으므로 이 `README.md`도 `/README`로 노출된다(무해 — 폴더 설명일 뿐). 전체 목록·발동 시점은 루트 `README.md` "전체 구성" 표.
