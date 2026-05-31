# Commands

> Canonical commands. Use these names; don't invent ad-hoc variants.

## Daily
| Task | Command |
|------|---------|
| Install deps | `pnpm install` |
| Dev server | `pnpm dev` |
| Build | `pnpm build` |
| Start (prod build) | `pnpm start` |

## Quality (run before commit)
| Task | Command |
|------|---------|
| Type check | `pnpm typecheck`  (`tsc --noEmit`) |
| Lint | `pnpm lint` |
| Format | `pnpm format` |
| Unit tests | `pnpm test` |
| E2E tests | `pnpm test:e2e` |
| All checks | `pnpm check`  (typecheck + lint + test) |

## Notes
- "Always run tests before committing" → run `pnpm check`.
- Long-running tests may be skipped locally but must pass in CI.
- Define each script in `package.json`; keep this table in sync.
