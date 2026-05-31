# Project Structure

> Reference map so paths are never guessed (see CLAUDE.md "Source first").

## Layout (adjust per project)
```
.
├── <source dir>/        # application source        <!-- adjust -->
│   ├── domain/          # entities, business rules (framework- & I/O-free)  <!-- adjust -->
│   ├── services/        # use cases / application logic  <!-- adjust -->
│   ├── lib/             # shared utilities           <!-- adjust -->
│   └── <entry point>    # entry point                <!-- adjust -->
├── tests/               # mirrors the source structure
├── .claude/rules/       # project guidelines (this folder)
├── <build manifest>     # dependency/build manifest  <!-- adjust -->
└── CHANGELOG.md
```

## Conventions
- One module = one responsibility. Keep files focused and small.
- Domain/business logic has **no** framework or I/O imports — pure types and logic only.
- Test files mirror the source path one-to-one.

## Where things live
- Config/secret access: a single centralized module, validated at startup.
- Never scatter environment-variable reads across the codebase.
