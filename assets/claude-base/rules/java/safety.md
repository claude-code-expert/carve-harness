# Safety Rules — Java

> Project-specific safety. Extends the Safety Guardrails in CLAUDE.md.

## Absolute Prohibitions

### Data Destruction
- Never run `DELETE`/`TRUNCATE` without a `WHERE` clause, or `DROP TABLE`/`DROP DATABASE`.
- Never construct SQL by string concatenation — use parameterized queries / the query builder.
- Never run `rm -rf` on the project root or critical directories.
- Never edit or delete existing Flyway/Liquibase migration files — add a new versioned one.

### Git
- Never run `git push --force`, `git reset --hard`, or `git commit --no-verify`.
- Never commit or push without an explicit user request.

### Environment & Secrets
- Never create or edit `.env*` / `application-*.properties` secrets directly.
- Never expose API keys, secrets, or tokens in code or logs.

### Production
- Never auto-modify a production database.
- Never set `spring.jpa.hibernate.ddl-auto=create`/`create-drop`/`update` against production.
- Never change production Docker/Compose configs without approval.
- Never expose internal ports (e.g. `5432`, `6379`) to a public network.

## Require Explicit User Approval
- DB schema / entity changes; new migration files.
- Dependency additions or version changes (`build.gradle` / `pom.xml`).
- Build/config changes (Gradle/Maven config, framework config).
- Any Docker config change; documentation file deletions.

## Best Practices
- Confirm a backup exists before any destructive DB operation; prefer an SQL fix over a reset.
- Never run a dependency auto-upgrade that rewrites the lock without review.
- No new library outside the core stack without rationale + approval.
- For external AI/3rd-party APIs: call asynchronously (never block the request thread),
  cache results before persisting, and log every call for audit/debugging.
