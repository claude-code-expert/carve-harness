# Commands — Python

> Canonical commands. Use these names; don't invent ad-hoc variants. Keep in sync with `pyproject.toml`.

## Daily
| Task | Command |
|------|---------|
| Install deps | `{{PKG_MANAGER}} install -r requirements.txt` (poetry/uv: `{{PKG_MANAGER}} install` / `uv sync`) |
| Run app | `python -m <package>` (or `python main.py`) |
| Dev server | framework-specific, e.g. `uvicorn app:app --reload` · `flask run` · `python manage.py runserver` |
| Build (wheel/sdist) | `python -m build` |

## Quality (run before commit)
| Task | Command |
|------|---------|
| Type check | `mypy src` |
| Lint | `ruff check`  (`{{LINT_CMD}}`) |
| Format | `{{FORMAT_CMD}}`  (`ruff format`) |
| Unit tests | `{{TEST_CMD}}`  (`pytest`) |
| Coverage | `pytest --cov` |

## Notes
- "Always run tests before committing" → run lint + type check + tests.
- Long-running tests may be skipped locally but must pass in CI.
- Define scripts/entry points in `pyproject.toml`; keep this table in sync.
