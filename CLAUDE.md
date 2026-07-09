# CLAUDE.md — 프로젝트 가드레일 (하네스 전역 규칙)

> 하네스의 "제약" 기둥. 언어 무관 항상 적용. 스택별 규칙은 `.claude/rules/`에서 glob 자동 로드.

## 하네스 3기둥
- 제약: 이 파일 + `.claude/rules/*` + PreToolUse 차단 훅
- 피드백: PostToolUse(포맷·린트) + Stop(빌드·타입·테스트) + Evaluator 에이전트
- 상태: SessionStart/PreCompact 핸드오프 + `specs/`(SDD 산출물)

## 절대 금지 (언어 무관)
- 자동 커밋 금지, 테스트 없는 개발 금지, 
- 시크릿 하드코딩 금지 → 환경변수/시크릿 매니저
- 위험 git 금지: force push, 히스토리 재작성
- 기존 마이그레이션 수정 금지 → 새 버전만
- 미검증 완료 선언 금지 → 완료는 `specs/`의 완료 기준(SC)으로만

## 작업 원칙
- 한 번에 하나. 분해 후 진행. 모든 완료엔 검증 가능한 SC.
- 프로젝트 도메인 규칙: 이 자리에 프로젝트별 불변식·금지사항을 추가한다.
  (예: "주문 금액 음수 불가", "결제 승인 없이 배송상태 변경 금지")

## 응답 언어 프로토콜 (필수)
- Write the working summary / explanation in English first.
- Then state the final conclusion in Korean (한글로 최종 결론).
- Order is fixed: English summary → Korean conclusion, each exactly once.
- When error output or quoted English text appears, add a brief Korean note for that part only.
- On task completion, the Korean conclusion covers, in one block, once:
  - What changed (무엇을 변경했는지)
  - Why (왜 그렇게 했는지)
  - Caveats (주의할 점)

## 스택 감지
- `**/*.java` → `.claude/rules/java-spring/`
- `**/*.ts`, `**/*.tsx` → `.claude/rules/react-next/`

## 참고
- @AGENTS.md · @.claude/rules/common/


# AI Context

Bash-hook + markdown harness repo — no application code.
See .codesight/skills.md for the project slash-command list.
