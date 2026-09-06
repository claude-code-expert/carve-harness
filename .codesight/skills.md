# Claude Skills

Project-local slash commands available to Claude Code agents:

- `/commit` — 현재 브랜치에 commit→pull→push. 인자를 커밋 메시지로 사용
- `/commit-branch` — 현재 브랜치에 Conventional Commits 규칙으로 커밋하고 푸시한다
- `/plan` — 작업을 완료 기준(SC)이 있는 단위로 분해하고 specs/에 계획을 남긴다
- `/verify` — 현재 변경을 완료 기준(SC)·빌드·타입·테스트로 검증한다
- `/verify-loop` — 스펙→개발→체크리스트→채점 루프를 돌려 모든 구현 항목이 95점 이상이 될 때까지 검증한다
- `/review` — 변경분을 타입·보안·예외·상태관리 관점에서 검토한다
- `/eval` — 골든셋(specs/goldenset/*.json)을 재채점해 점수 추이를 남기고 baseline 대비 회귀를 판정한다
- `/harness-audit` — 하네스 구성(제약·피드백·상태)이 실제로 작동하는지 기계적으로 PASS/FAIL 검증한다
- `/ponytail` — ponytail 강도 전환 (lite/full/ultra/off)
- `/ponytail-help` — ponytail 레벨·스킬·커맨드 빠른 참조
- `/ponytail-audit` — 리포 전체에서 오버엔지니어링을 감사, 삭제 가능분 도출
- `/ponytail-review` — 변경분의 오버엔지니어링·삭제 가능분 검토
- `/ponytail-debt` — 코드의 `ponytail:` 주석을 추적 부채 원장으로 수확
- `/ponytail-gain` — ponytail의 측정된 효과(코드·비용·시간 절감) 스코어보드

_Source: .claude/commands_
