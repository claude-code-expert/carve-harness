# CLAUDE.md — {{PROJECT_TYPE}} 프로젝트 하네스

> carve가 설치한 하네스 가이드. 사용법은 `HARNESS-GUIDE.md` 참고.

## 설치된 구성요소
{{COMPONENT_LIST}}

## 제약 (결정적 강제 — 권고가 아님)
- 위험 명령(`rm -rf /`·포크밤 등)·비밀 파일(`.env`·키)은 PreToolUse 훅이 **exit 2로 차단**한다.
{{ANTI_SLOP_CLAUDE}}
- 커밋 전 린트·푸시 전 테스트가 강제된다(해당 훅 설치 시).

## 토큰 효율 (기본 탑재)
{{TOKEN_EFFICIENCY}}
codesight·LSP MCP가 `.claude/settings.json`에 등록돼 있다. 모든 스킬·서브에이전트는 이를 우선 사용한다.

## 계획 우선 (Plan-before-code)
- 새 기능·비자명 변경은 (1) 계획(Spec/파일구조)을 먼저 제시하고 **사용자 승인**을 받은 뒤 (2) 구현한다.
- 각 구현 단계 종료 시 상태를 보고하고 확인을 받는다(단계별 컨펌).
- 추론(왜)과 실행(무엇을)을 분리해 기술한다. 계획은 `squad-plan`, 계약은 `sprint-contract.md` 참조.

## 워크플로
- 스킬: 핸드오프·메모리·커밋·체인지로그·리뷰·PR (자연어로 트리거).
- 깊은 작업은 Squad 서브에이전트(`/squad <member>`)에 위임.

자세한 규칙: `flight-rules.md` · 품질 기준: `evaluation-criteria.md`
