# CLAUDE.md — {{PROJECT_TYPE}} 프로젝트 하네스

> carve가 설치한 하네스 가이드. 사용법은 `HARNESS-GUIDE.md` 참고.

## 설치된 구성요소
{{COMPONENT_LIST}}

## 제약 (결정적 강제 — 권고가 아님)
- 위험 명령(`rm -rf /`·포크밤 등)·비밀 파일(`.env`·키)은 PreToolUse 훅이 **exit 2로 차단**한다.
- 시각·문서 산출물(HTML·SVG·문서)은 **anti-ai-slop** 표준 — `check-slop`이 게이트한다.
- 커밋 전 린트·푸시 전 테스트가 강제된다.

## 워크플로
- 스킬: 핸드오프·메모리·커밋·체인지로그·리뷰·PR (자연어로 트리거).
- 깊은 작업은 Squad 서브에이전트(`/squad <member>`)에 위임.

자세한 규칙: `flight-rules.md` · 품질 기준: `evaluation-criteria.md`
