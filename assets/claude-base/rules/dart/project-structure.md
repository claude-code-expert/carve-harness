# Project Structure — Dart / Flutter

> Reference map so paths are never guessed (see CLAUDE.md "Source first").

## Layout (adjust per project)
```
.
├── lib/                  # application source (feature-first)
│   ├── features/         # one folder per feature
│   │   └── <feature>/
│   │       ├── presentation/  # widgets, screens (UI only)
│   │       ├── domain/        # entities, business rules (framework-free)
│   │       └── data/          # repositories, data sources
│   ├── core/             # shared utilities, theme, routing
│   └── main.dart         # entry point
├── test/                 # mirrors lib/ structure
├── .claude/rules/        # project guidelines (this folder)
├── pubspec.yaml
├── analysis_options.yaml
└── CHANGELOG.md
```

## Conventions
- One file = one responsibility. Keep widgets small and composable.
- `domain/` has **no** Flutter or I/O imports — pure entities and logic only.
- Separate UI (widgets) from domain (business logic) from data (sources).
- Test files mirror the source path (`lib/features/auth/x.dart` → `test/features/auth/x_test.dart`).

## Where things live
- Models/entities: feature `domain/` (immutable, `freezed`).
- Config/env access: a single typed module; never scatter env reads across the codebase.
- Theme, routes, constants: `lib/core/`.
