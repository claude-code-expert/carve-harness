---
paths: ["**/*.py"]
---
# Python 규칙 (자동 로드)

> 자동 로드되는 **규칙 목록**. 근거·샘플·프로젝트 구조는 상세본 참조:
> `docs/rules/code-convention/dev-stack-{python,fastapi}.md`
> 게이트: `.claude/stacks/python.sh` — `ruff check` · `pytest`(Stop) · `ruff format`(PostToolUse)

## 코드
- [MUST] PEP 8. 포맷은 도구에 위임(`ruff format`) — 손으로 정렬하지 않는다.
- [MUST] 공개 함수 시그니처에 타입 힌트. `Any` 남발 금지, mypy/pyright 통과.
- [MUST] 예외는 구체 타입으로 잡는다. bare `except:`·`except Exception: pass` 금지.
- [MUST] 가변 기본 인자 금지(`def f(x=[])` → `None` 패턴).
- [MUST] 리소스는 `with`(컨텍스트 매니저)로. 파일·커넥션·락을 열어 두고 반환하지 않는다.
- [SHOULD] f-string. 데이터 구조는 `dataclass`/`pydantic` — 원시 dict 남용 지양.
- [SHOULD] 전역 상태 지양. 의존성은 인자로 주입.

## 프로젝트
- [MUST] 의존성은 `pyproject.toml`(또는 `requirements.txt`)로 관리, 가상환경 격리. 시스템 파이썬에 `pip install` 금지.
- [MUST] 시크릿은 환경변수(`os.environ`)에서만. 코드·설정 파일에 키 리터럴 금지 — 없으면 명확한 오류로 실패.
- [MUST] 테스트는 `pytest`. 새 코드에는 테스트가 있고 `pytest -q`가 녹색이어야 완료.
- [SHOULD] 입력 검증은 경계에서(pydantic·명시적 검사). 내부 함수는 검증된 타입만 받는다.
