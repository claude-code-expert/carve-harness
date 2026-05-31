# Tech Stack — Java

> Detected stack. Trim/extend to match reality.

## Core
- **Language**: Java 21 LTS (records, sealed types, pattern matching for `switch`)
- **Runtime**: JVM 21+ (Temurin/OpenJDK)
- **Build tool**: {{PKG_MANAGER}} (lockfile/wrapper committed)
- **Module style**: package-by-feature; Kotlin/JVM interop where present

## Quality Tooling
- **Lint/format**: Spotless + Checkstyle (or google-java-format)
- **Static analysis**: Error Prone / SpotBugs in CI
- **Test**: JUnit 5 + AssertJ + Mockito (unit) + Testcontainers (integration, if DB)
- **Coverage**: JaCoCo with a gate in CI
- **Validation**: Bean Validation (Jakarta) at boundaries

## Backend (if applicable)
- Framework: Spring Boot — keep it consistent across modules
- DB access: JPA/Hibernate or jOOQ — no string-concatenated SQL in app code
- Migrations: Flyway or Liquibase — schema is versioned, never hand-edited live
- Auth: JWT (stateless) or session — document the choice

## Frontend (if applicable)
- Served separately or via a templating layer (Thymeleaf) — keep view logic thin
- Treat the API as the contract; validate all inbound payloads

## Rules
- No library outside this stack without a stated rationale and user approval.
- Pin major versions; document any upgrade in the changelog.
