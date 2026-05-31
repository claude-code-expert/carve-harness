# Project Structure — Python

> Reference map so paths are never guessed (see CLAUDE.md "Source first").

## Layout (adjust per project)
```
.
├── src/<package>/       # application source (src layout)
│   ├── domain/          # entities, dataclasses, business rules (framework-free)
│   ├── services/        # use cases / application logic
│   ├── api/ (or routes/)# HTTP handlers, controllers
│   ├── lib/             # shared utilities
│   └── __main__.py      # entry point
├── tests/               # mirrors src/<package>/ structure
├── .claude/rules/       # project guidelines (this folder)
├── pyproject.toml
└── CHANGELOG.md
```

## Conventions
- One module = one responsibility. Keep files focused and small.
- `domain/` has **no** framework or I/O imports — pure types and logic only.
- Test files mirror the source path (`src/pkg/services/x.py` → `tests/services/test_x.py`).
- Use the `src/` layout so tests run against the installed package, not the working tree.

## Where things live
- Types/models: `src/<package>/domain/`.
- Config/env access: a single typed settings module (Pydantic `BaseSettings`).
- Never scatter `os.environ` reads across the codebase.
