---
description: 하네스 구성(제약·피드백·상태)이 실제로 작동하는지 기계적으로 PASS/FAIL 검증한다
---
하네스 게이트를 기계적으로 점검한다. 아래를 실행하고 결과를 그대로 보고하라:

`bash ${CLAUDE_PROJECT_DIR}/.claude/hooks/harness-audit.sh`

- exit 0 → 하네스 정상(모든 게이트 존재).
- non-zero → 게이트 누수. 출력의 `FAIL:` 항목을 수정한 뒤 재실행하라.
