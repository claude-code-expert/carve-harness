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
- 사용자 응답은 **한국어**로만 쓴다. 영어 요약을 앞에 두지 않는다.
- 코드·명령·파일명·에러 원문·기술 용어는 원문(English) 그대로 둔다.
- 에러 출력이나 영어 인용문이 있으면 그 부분에만 한 줄 한국어 설명을 붙인다.
- 응답은 **핵심 요약**으로 시작한다: 결과·판정을 첫 줄에, 근거는 그 아래에. 과정 서술 금지.
- 작업 완료 시 마지막 블록에 한 번만, 아래 3항목을 요약한다:
  - 변경: 무엇을 변경했는지
  - 이유: 왜 그렇게 했는지
  - 주의: 주의할 점

## 스택 감지 (설치된 언어팩만 존재)
- `**/*.java` → `.claude/rules/java-spring/`
- `**/*.ts`, `**/*.tsx` → `.claude/rules/react-next/`
- `**/*.py` → `.claude/rules/python/` · `**/*.go` → `.claude/rules/go/` · `**/*.rs` → `.claude/rules/rust/`
- 검증 게이트·포맷·채점은 `.claude/stacks/<pack>.sh`가 정의 — 팩 추가/제거는 `bash install.sh pack add|remove`

## 참고
- @AGENTS.md · @.claude/rules/common/


# AI Context

Bash-hook + markdown harness repo — no application code.
See .codesight/skills.md for the project slash-command list.
