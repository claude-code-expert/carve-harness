# Safety Rules — Go

> Project-specific safety. Extends the Safety Guardrails in CLAUDE.md.

## Absolute Prohibitions

### Data Destruction
- Never run `DELETE`/`TRUNCATE` without a `WHERE` clause, or `DROP TABLE`/`DROP DATABASE`.
- Never run `docker compose down -v` (destroys volumes).
- Never run `rm -rf` on the project root or critical directories.
- Never edit or delete existing migration files.

### Git
- Never run `git push --force`, `git reset --hard`, or `git commit --no-verify`.
- Never commit or push without an explicit user request.

### Environment & Secrets
- Never create or edit `.env*` files directly.
- Never expose API keys, secrets, or tokens in code or logs.

### Production
- Never auto-modify a production database.
- Never run destructive auto-migrations (drop/recreate) against production.
- Never change production Docker/Compose configs without approval.
- Never expose internal ports (e.g. `5432`, `6379`) to a public network.

## Require Explicit User Approval
- DB schema changes; new migration files.
- Dependency additions or version changes (`go.mod` / `go.sum`).
- Build/config changes (build tags, CI config, framework config).
- Any Docker config change; documentation file deletions.

## Best Practices
- Confirm a backup exists before any destructive DB operation; prefer an SQL fix over a reset.
- No `--force` style destructive operations.
- No new library outside the core stack without rationale + approval.
- For external AI/3rd-party APIs: call with a `context.Context` (timeout/cancel),
  cache results before persisting, and log every call for audit/debugging.
