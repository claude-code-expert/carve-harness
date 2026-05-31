# Safety Rules

> Project-specific safety. Extends the Safety Guardrails in CLAUDE.md.

## Absolute Prohibitions

### Data Destruction
- Never run `DELETE`/`TRUNCATE` without a `WHERE` clause, or `DROP TABLE`/`DROP DATABASE`.
- Never destroy data stores or volumes (e.g. `docker compose down -v`).
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
- Never enable destructive auto-migration (drop/recreate) against production.
- Never change production infra/config without approval.
- Never expose internal ports (e.g. database/cache ports) to a public network.

## Require Explicit User Approval
- DB schema / entity changes; new migration files.
- Dependency additions or version changes ({{PKG_MANAGER}} manifest). <!-- fill in if blank -->
- Build/config changes (build manifest, tooling, framework config).
- Any infra/Docker config change; documentation file deletions.

## Best Practices
- Confirm a backup exists before any destructive DB operation; prefer a targeted fix over a reset.
- Never apply a `--force` fix to silence an error; address the cause.
- No new library outside the core stack without rationale + approval.
- Fix the structural root cause, not a workaround, so the issue never recurs.
