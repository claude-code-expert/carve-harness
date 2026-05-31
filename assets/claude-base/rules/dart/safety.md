# Safety Rules — Dart / Flutter

> Project-specific safety. Extends the Safety Guardrails in CLAUDE.md.

## Absolute Prohibitions

### Data Destruction
- Never run `DELETE`/`TRUNCATE` without a `WHERE` clause, or `DROP TABLE` (sqflite/drift).
- Never drop or recreate a local DB/store without an explicit request.
- Never run `rm -rf` on the project root or critical directories.
- Never edit or delete existing migration files (drift schema versions).

### Git
- Never run `git push --force`, `git reset --hard`, or `git commit --no-verify`.
- Never commit or push without an explicit user request.

### Environment & Secrets
- Never create or edit `.env*` files directly.
- Never commit signing keys, keystores, or a `google-services.json`/`GoogleService-Info.plist` containing real secrets.
- Never expose API keys, secrets, or tokens in code or logs.

### Production
- Never auto-modify a production backend/database.
- Never enable destructive store migration (drop/recreate) against production data.
- Never expose debug endpoints, debug builds, or internal flags to production.

## Require Explicit User Approval
- DB schema / drift migration changes; new migration versions.
- Dependency additions or version changes (`pubspec.yaml`).
- Build/config changes (Gradle, Xcode signing, `Info.plist`, `AndroidManifest.xml`).
- Documentation file deletions.

## Best Practices
- Confirm a backup exists before any destructive DB operation; prefer a targeted fix over a reset.
- No new library outside the core stack without rationale + approval.
- For external/3rd-party APIs: call asynchronously (never block the UI thread),
  handle failures explicitly, and log every call for audit/debugging.
