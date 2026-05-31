# Tech Stack — Python

> Detected stack. Trim/extend to match reality.

## Core
- **Language**: Python 3.11+ (type hints everywhere)
- **Package manager**: {{PKG_MANAGER}} (lockfile committed)
- **Project metadata**: `pyproject.toml` (PEP 621)
- **Isolation**: virtualenv (`.venv/`, never install into system Python)

## Quality Tooling
- **Lint/format**: Ruff (`ruff check`) + `ruff format` (or Black)
- **Type check**: mypy or pyright in CI (strict mode)
- **Test**: pytest (unit) + pytest-cov (coverage)
- **Validation**: Pydantic v2 for runtime schema validation at boundaries

## Frontend / API (if applicable)
- Framework: FastAPI / Django / Flask — pick one, keep it consistent
- Async: FastAPI + `asyncio` for I/O-bound services
- Serialization: Pydantic v2 models for request/response shapes

## Backend (if applicable)
- DB access: SQLAlchemy / SQLModel — no raw string SQL in app code
- Migrations: Alembic (Django: built-in migrations) — never edit applied migrations
- Auth: JWT (stateless) or session — document the choice

## Rules
- No library outside this stack without a stated rationale and user approval.
- Pin major versions in `pyproject.toml`; document any upgrade in the changelog.
