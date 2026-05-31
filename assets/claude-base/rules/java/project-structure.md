# Project Structure — Java

> Reference map so paths are never guessed (see CLAUDE.md "Source first").

## Layout (adjust per project)
```
.
├── src/
│   ├── main/
│   │   ├── java/<package>/   # application source
│   │   │   ├── domain/       # entities, value objects, business rules
│   │   │   ├── service/      # use cases / application logic
│   │   │   ├── web/ (api/)   # controllers, request/response DTOs
│   │   │   └── config/       # typed configuration
│   │   └── resources/        # application.yml, migrations, static assets
│   └── test/
│       └── java/<package>/   # mirrors main/ structure
├── .claude/rules/            # project guidelines (this folder)
├── build.gradle(.kts)        # or pom.xml
└── CHANGELOG.md
```

## Conventions
- Package by feature/domain, not by layer only. One class = one responsibility.
- `domain/` stays free of framework annotations where practical — pure types and logic.
- Test files mirror the source path (`service/XService.java` → `service/XServiceTest.java`).
- DTOs live next to their controller; never leak entities across the web boundary.

## Where things live
- Types/value objects: `domain/` (prefer records for immutable data).
- Config/env access: a single typed `@ConfigurationProperties` class per concern.
- Never scatter raw `System.getenv` / `@Value` reads across the codebase.
