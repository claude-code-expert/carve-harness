# `.claude/rules/python/` — Python 규칙 (python 팩)

`**/*.py`를 열면 자동 로드. `python` 언어팩과 함께 설치.

| 파일 | glob | 내용 |
|---|---|---|
| `patterns.md` | `**/*.py` | PEP 8·타입 힌트 · bare except 금지 · 가변 기본 인자 금지 · 컨텍스트 매니저 · 시크릿은 env |

## 사용방법
- 자동 로드. 게이트: `.claude/stacks/python.sh`(ruff check·pytest·ruff format). 상세본: `docs/rules/code-convention/dev-stack-{python,fastapi}.md`.
