# flight-rules — {{PROJECT_TYPE}} 프로젝트 제약

> carve가 생성. 금지/필수 규칙. 검증 훅이 결정적으로 강제한다(PreToolUse exit code 2).
> 행동 원칙(단순함·외과적 변경·TDD·응답 제어 등)과 스택별 규칙은 `carve init-claude`가 만든
> `.claude/CLAUDE.md` 베이스라인 + `.claude/rules/*`가 표준이다. 여기서는 중복하지 않고 하네스 강제만 둔다.

## 금지 (MUST NOT)
- 파괴적 명령(`rm -rf /`·포크밤·디스크 파괴 등) — `carve-block-destructive` 훅이 exit 2로 차단.
- 비밀 파일(`.env`·키·credentials) 접근 — `carve-protect-secrets` 훅이 차단.
{{LANG_RULES}}

## 필수 (MUST)
- 커밋 전 린트 통과: `{{LINT_CMD}}`
- 푸시 전 테스트 통과: `{{TEST_CMD}}`
- 비자명 변경은 계획 우선 — 구현 전 계획 제시·승인, 단계별 확인(루트 `CLAUDE.md`의 "계획 우선" 참조).

## 토큰 효율 (MUST)
{{TOKEN_EFFICIENCY}}
{{ANTI_SLOP_SECTION}}
