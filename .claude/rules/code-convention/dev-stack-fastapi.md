# FastAPI 개발 스택 가이드

> **용도**: Claude Code 프로젝트의 `CLAUDE.md` · `.claude/rules/` · `.claude/skills/` 참조용 코딩 표준
> **대상**: 개발을 시작하는 비전공·직장인 → 실무 진입 단계
> **최종 검증일**: 2026-07-06 (KST)
> **주 출처**: zhanymkanov/fastapi-best-practices (실무 스타트업 규약)

---

## 0. 결론 먼저 — 핵심 규칙 Top 10

| # | 규칙 | 수준 |
|---|------|------|
| 1 | 도메인 단위 패키지 구조(`src/<domain>/router,service,schemas...`) | SHOULD |
| 2 | I/O는 `async def`, 블로킹 작업은 async 라우트에 넣지 말 것 | MUST |
| 3 | 블로킹/CPU 작업은 스레드풀·워커(Celery 등)로 분리 | MUST |
| 4 | 요청/응답은 Pydantic 모델로 검증·직렬화 | MUST |
| 5 | 공통 로직은 Dependency Injection(`Depends`)로 재사용 | SHOULD |
| 6 | `response_model` 명시(과다 노출·직렬화 오류 방지) | SHOULD |
| 7 | DB 마이그레이션은 Alembic, 네이밍 컨벤션 고정 | MUST |
| 8 | REST 규약 준수(리소스 명사·적절한 상태코드) | SHOULD |
| 9 | 설정은 pydantic-settings로 환경변수 파싱·검증 | MUST |
| 10 | 린트/포맷은 Ruff, 테스트 클라이언트는 async로 초기부터 | SHOULD |

---

## 1. 스택 & 버전 (2026 기준)

| 항목 | 권장 | 비고 |
|------|------|------|
| Python | 3.12 / 3.13 | |
| FastAPI | 0.11x+ | |
| 검증 | Pydantic v2 | `BaseModel`·`BaseSettings` |
| ORM | SQLAlchemy 2.0(async) 또는 SQLModel | |
| 마이그레이션 | Alembic | |
| 서버 | Uvicorn (+Gunicorn 워커) | |
| 린트/포맷 | Ruff | |

---

## 2. 프로젝트 구조 (도메인 기반 — 출처 규약)

```
src/
├── main.py              # FastAPI 앱 초기화
├── config.py            # 전역 설정(pydantic-settings)
├── database.py          # DB 연결/세션
├── constants.py         # 공통 상수·에러코드
├── exceptions.py        # 전역 예외
├── auth/
│   ├── router.py        # 엔드포인트
│   ├── schemas.py       # Pydantic 모델
│   ├── service.py       # 비즈니스 로직
│   ├── dependencies.py  # Depends 함수
│   ├── models.py        # DB 모델
│   └── constants.py
└── posts/
    └── (동일 구조)
```

- 모든 도메인 디렉터리는 `src/` 하위(출처: "Store all domain directories inside src folder")
- 도메인 간 참조는 명시적 절대 임포트(`from src.auth import service`)

---

## 3. 라우팅 규칙 (동기 vs 비동기)

| 작업 성격 | 처리 |
|-----------|------|
| async 라이브러리로 I/O(DB/HTTP) | `async def` |
| 동기 SDK로 I/O | `def`(FastAPI가 스레드풀 처리) 또는 명시적 threadpool |
| CPU 집약 | 별도 워커/프로세스(Celery, RQ 등) |

> `async def` 라우트 안에서 **블로킹 호출 금지** — 이벤트 루프 정지 유발.

---

## 4. 베스트 프랙티스 (검증된 코드 샘플)

### 4.1 Pydantic 스키마 (요청/응답 분리)

```python
from pydantic import BaseModel, EmailStr

class UserCreate(BaseModel):
    email: EmailStr
    password: str

class UserRead(BaseModel):
    id: str
    email: EmailStr
    # password 등 민감필드는 응답 모델에서 제외
```

### 4.2 라우터 + response_model + 의존성

```python
from fastapi import APIRouter, Depends, status

router = APIRouter(prefix="/users", tags=["users"])

@router.post("", response_model=UserRead, status_code=status.HTTP_201_CREATED)
async def create_user(
    payload: UserCreate,
    service: "UserService" = Depends(get_user_service),
) -> UserRead:
    return await service.create(payload)
```

### 4.3 설정 — pydantic-settings

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str
    jwt_secret: str

    class Config:
        env_file = ".env"

settings = Settings()  # 시작 시 환경변수 검증
```

### 4.4 의존성 재사용(체이닝)

```python
async def get_current_user(
    token: str = Depends(oauth2_scheme),
) -> User:
    return await decode_token(token)

async def require_admin(
    user: User = Depends(get_current_user),
) -> User:
    if not user.is_admin:
        raise ForbiddenError()
    return user
```

### 4.5 전역 예외 처리

```python
from fastapi import Request
from fastapi.responses import JSONResponse

@app.exception_handler(UserNotFoundError)
async def not_found_handler(request: Request, exc: UserNotFoundError):
    return JSONResponse(status_code=404, content={"error": "사용자를 찾을 수 없습니다"})
```

---

## 5. 안티패턴 (금지)

| 안티패턴 | 문제 | 대안 |
|---------|------|------|
| async 라우트에서 블로킹 호출 | 이벤트 루프 정지 | async 라이브러리/threadpool |
| `response_model` 생략 | 민감필드 과노출 | 응답 모델 명시 |
| 라우터에 비즈니스 로직 | 재사용·테스트 곤란 | service 계층 |
| DB 모델을 그대로 응답 | 순환·과노출 | Pydantic 응답 모델 |
| 전역 세션 공유 | 동시성 버그 | 요청 스코프 세션(Depends) |
| 마이그레이션 없이 스키마 변경 | 환경 불일치 | Alembic |
| 예외를 라우트마다 try/except | 중복 | 전역 핸들러 |

---

## 6. 엄격한 규칙 (강제 설정)

- **MUST**: 모든 외부 입력은 Pydantic 모델 통과 후 사용
- **MUST**: DB 접근은 요청 스코프 세션(`Depends`)으로만
- **MUST NOT**: 비밀키/DB URL 하드코딩(설정 클래스+env)
- **SHOULD**: DB 제약·인덱스 네이밍 컨벤션 고정(Alembic naming_convention)
- **SHOULD**: 테스트 클라이언트는 async(httpx AsyncClient)로 day 0부터

---
