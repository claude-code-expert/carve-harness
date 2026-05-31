# Commands — Python

> Canonical commands. Use these names; don't invent ad-hoc variants. Keep in sync with `pyproject.toml`.

## Daily
| Task | Command |
|------|---------|
| Install deps | `{{PKG_MANAGER}} install` |
| Dev server | `{{PKG_MANAGER}} run dev` |
| Run app | `{{PKG_MANAGER}} run start` |
| Build (wheel/sdist) | `{{PKG_MANAGER}} build` |

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
