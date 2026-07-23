# Python 개발 스택 가이드

> **용도**: Claude Code 프로젝트의 `CLAUDE.md` · `.claude/rules/` · `.claude/skills/` 참조용 코딩 표준
> **대상**: 개발을 시작하는 비전공·직장인 → 실무 진입 단계
> **최종 검증일**: 2026-07-06 (KST)

---

## 0. 결론 먼저 — 핵심 규칙 Top 10

| # | 규칙 | 수준 |
|---|------|------|
| 1 | PEP 8 준수, 포매팅은 도구 위임(Ruff/Black) | MUST |
| 2 | 타입 힌트 필수(공개 함수 시그니처) + mypy/pyright 검사 | MUST |
| 3 | 가상환경(venv/uv) 격리, 의존성은 `pyproject.toml`로 관리 | MUST |
| 4 | 예외는 구체 타입으로, bare `except:` 금지 | MUST |
| 5 | 가변 기본 인자 금지(`def f(x=[])` → `None` 패턴) | MUST |
| 6 | f-string 사용, `%`·`.format` 지양 | SHOULD |
| 7 | 컨텍스트 매니저(`with`)로 리소스 관리 | MUST |
| 8 | 리스트/딕셔너리 컴프리헨션 적절히, 과도한 중첩 금지 | SHOULD |
| 9 | 데이터 구조는 `dataclass`/`pydantic`, 원시 dict 남용 지양 | SHOULD |
| 10 | 전역 상태 지양, 순수 함수·명시적 의존성 주입 | SHOULD |

---

## 1. 스택 & 버전 (2026 기준)

| 항목 | 권장 | 비고 |
|------|------|------|
| Python | 3.12 / 3.13 | match문·타입 개선 |
| 패키지·가상환경 | uv (또는 pip+venv) | 빠른 해석 |
| 린트+포맷 | **Ruff** (Flake8/isort/Black 통합) | 단일 도구 |
| 타입체크 | mypy 또는 pyright | strict 권장 |
| 테스트 | pytest | fixture 기반 |
| 검증 모델 | pydantic v2 | 데이터 경계 |

---

## 2. 프로젝트 구조 (src 레이아웃)

```
myapp/
├── pyproject.toml       # 의존성·도구 설정(ruff/mypy/pytest)
├── src/
│   └── myapp/
│       ├── __init__.py
│       ├── config.py    # 설정(pydantic-settings)
│       ├── <domain>/    # 도메인 모듈
│       │   ├── models.py
│       │   ├── service.py
│       │   └── schemas.py
│       └── main.py
└── tests/
    └── test_<domain>.py
```

**src 레이아웃**: 설치된 패키지로 테스트 → import 경로 사고 방지.

---

## 3. 네이밍 & 컨벤션 (PEP 8 / Google)

| 대상 | 규칙 | 예 |
|------|------|-----|
| 함수·변수 | snake_case | `get_user_by_id` |
| 클래스 | PascalCase | `UserRepository` |
| 상수 | SCREAMING_SNAKE | `MAX_RETRY` |
| 모듈·패키지 | 짧은 소문자 | `user_service` |
| 비공개 | `_` 접두 | `_internal` |
| 라인 길이 | 88(Ruff/Black 기본) | |

---

## 4. 베스트 프랙티스 (검증된 코드 샘플)

### 4.1 타입 힌트 + docstring

```python
def divide(a: float, b: float) -> float:
    """a를 b로 나눈다. b가 0이면 ValueError."""
    if b == 0:
        raise ValueError("0으로 나눌 수 없습니다")
    return a / b
```

### 4.2 가변 기본 인자 안전 패턴

```python
def append_item(item: int, bucket: list[int] | None = None) -> list[int]:
    if bucket is None:      # 가변 기본값 함정 회피
        bucket = []
    bucket.append(item)
    return bucket
```

### 4.3 컨텍스트 매니저로 리소스 관리

```python
from pathlib import Path

def read_config(path: Path) -> str:
    with path.open(encoding="utf-8") as f:  # 자동 close 보장
        return f.read()
```

### 4.4 dataclass로 구조화

```python
from dataclasses import dataclass

@dataclass(frozen=True, slots=True)
class User:
    id: str
    email: str
    is_active: bool = True
```

### 4.5 예외 — 구체 타입 + 원인 보존

```python
class UserNotFoundError(Exception):
    pass

def find_user(user_id: str) -> User:
    try:
        return repository.get(user_id)
    except KeyError as exc:
        raise UserNotFoundError(user_id) from exc  # 원인 체이닝
```

### 4.6 컴프리헨션(적정 수준)

```python
active_emails = [u.email for u in users if u.is_active]
```

---

## 5. 안티패턴 (금지)

| 안티패턴 | 문제 | 대안 |
|---------|------|------|
| `except:` bare | 모든 예외(시스템 종료 포함) 삼킴 | 구체 예외 |
| 가변 기본 인자 | 호출 간 상태 공유 버그 | `None` 패턴 |
| `from module import *` | 네임스페이스 오염 | 명시 import |
| 전역 가변 상태 | 예측 불가 | 인자/DI |
| 문자열 경로 조작 | OS 이식성·버그 | `pathlib.Path` |
| 딕셔너리로 도메인 표현 | 오타·타입 부재 | dataclass/pydantic |
| 과도한 컴프리헨션 중첩 | 가독성 붕괴 | 명시적 루프 |

---

## 6. 엄격한 규칙 (강제 설정)

### 6.1 pyproject.toml (Ruff + mypy)

```toml
[tool.ruff]
line-length = 88
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "UP", "B", "SIM"]  # pycodestyle,pyflakes,isort,pyupgrade,bugbear,simplify

[tool.mypy]
strict = true
warn_unused_ignores = true
```

### 6.2 MUST NOT

- `eval`/`exec`에 외부 입력 전달 **금지**
- `pickle`로 신뢰 불가 데이터 역직렬화 **금지**
- 비밀정보 하드코딩 **금지**(환경변수/시크릿)
- 검증 없이 subprocess에 사용자 문자열 결합 **금지**(쉘 인젝션)

---
