<!--
  Document : Safety Rules
  Purpose  : Project-specific safety rules extending the CLAUDE.md guardrails — absolute prohibitions (data destruction / git / secrets / production), actions requiring explicit approval, and best practices.
  Stack    : TypeScript
  Version  : 1.0.0 (2026-06-01)
-->
# Safety Rules

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
- Never enable destructive ORM auto-migration (drop/recreate) against production.
- Never change production Docker/Compose configs without approval.
- Never expose internal ports (e.g. `5432`, `6379`) to a public network.

---

## Require Explicit User Approval
- DB schema / entity changes; new migration file creation.
- Dependency additions or version changes (`package.json`).
- Build/config changes (`tsconfig.json`, `next.config.*`, bundler config).
- Any Docker config change; documentation file deletions.

---

## Best Practices
- Confirm a backup exists before any destructive DB operation; prefer an SQL fix over a reset.
- Never run `pnpm audit fix --force` / `npm audit fix --force`.
- No new library outside the core stack without rationale + approval.
- For external AI/3rd-party APIs: call asynchronously (never block the request path),
  cache results before persisting, and log every call for audit/debugging.
