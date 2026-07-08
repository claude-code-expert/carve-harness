# Claude Skills

Project-local slash commands available to Claude Code agents:

- `/commit` — 커밋 룰(commitlint) 준수 메시지로 커밋을 준비한다
- `/harness-audit` — 하네스 구성(제약·피드백·상태)이 실제로 작동하는지 기계적으로 PASS/FAIL 검증한다
- `/plan` — 작업을 완료 기준(SC)이 있는 단위로 분해하고 specs/에 계획을 남긴다
- `/review` — 변경분을 타입·보안·예외·상태관리 관점에서 검토한다
- `/verify` — 현재 변경을 완료 기준(SC)·빌드·타입·테스트로 검증한다
- `/squad <member>` — Squad 에이전트 디스패처
- `/squad-plan` — 기능 기획·유저스토리·와이어프레임
- `/squad-review` — 코드 리뷰 (보안·성능·유지보수)
- `/squad-qa` — 테스트 실행·기능 검증
- `/squad-refactor` — 중복·긴 함수·네이밍 리팩토링
- `/squad-debug` — 근본 원인 분석 (수정 제안만)
- `/squad-audit` — 보안 감사 (OWASP·시크릿)
- `/squad-docs` — 문서 생성 (README·API·주석)
- `/squad-gitops` — 커밋 메시지·PR·체인지로그

_Source: .claude/commands_
