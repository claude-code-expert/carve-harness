# Safety Rules

## Absolute Prohibitions

### Data Destruction
- Never run `DROP TABLE`, `DROP DATABASE`, `TRUNCATE`, or `DELETE FROM` without a `WHERE` clause
- Never run `ALTER TABLE DROP` without explicit user approval
- Never run `docker compose down -v` (destroys volumes)
- Never run `rm -rf` on the project root or critical directories
- Never edit or delete existing Flyway migration files

### Git
- Never run `git push --force`, `git reset --hard`, or `git commit --no-verify`
- Never commit or push without an explicit user request

### Environment & Secrets
- Never create or edit `.env*` or `application-dev.yml` files directly
- Never expose API keys, secrets, or tokens in code or logs

### Production
- Never auto-modify a production database under any circumstance
- Never set `spring.jpa.hibernate.ddl-auto` to `update`, `create`, or `create-drop` in production
- Never modify production Docker or Compose configurations without approval
- Never expose internal ports (`5432`, `6379`) to a public network

---

## Require Explicit User Approval

### Backend
- JPA Entity changes (`domain/` package)
- New Flyway migration file creation
- `build.gradle` dependency additions or version changes
- Any `application*.yml` configuration changes
- Spring Security configuration changes

### Frontend
- `package.json` dependency additions or changes
- `next.config.ts`, `postcss.config.mjs`, `tsconfig.json` changes

### Shared
- Any Docker configuration changes (`docker/`)
- Documentation file deletions (`docs/`)

---

## Best Practices

### Database
- Confirm a backup exists before any destructive operation
- Prefer SQL fixes over a database reset

### Dependencies
- Never run `npm audit fix --force`
- Do not introduce libraries outside the core stack without presenting a rationale and receiving approval

### AI API Calls
- Never call Claude/Gemini API synchronously — use `@Async` with a thread pool
- Cache AI results in Redis before writing to DB
- Log all AI API calls to the `ai_analysis_logs` table