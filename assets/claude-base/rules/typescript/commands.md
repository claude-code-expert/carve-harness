# Commands — TypeScript

> Canonical commands. Use these names; don't invent ad-hoc variants. Keep in sync with `package.json`.

## Daily
| Task | Command |
|------|---------|
| Install deps | `{{PKG_MANAGER}} install` |
| Dev server | `{{PKG_MANAGER}} run dev` |
| Build | `{{PKG_MANAGER}} run build` |
| Start (prod build) | `{{PKG_MANAGER}} run start` |

## Quality (run before commit)
| Task | Command |
|------|---------|
| Type check | `{{PKG_MANAGER}} run typecheck`  (`tsc --noEmit`) |
| Lint | `{{LINT_CMD}}` |
| Format | `{{FORMAT_CMD}}` |
| Unit tests | `{{TEST_CMD}}` |
| All checks | `{{PKG_MANAGER}} run check`  (typecheck + lint + test) |

## Notes
- "Always run tests before committing" → run the full check.
- Long-running tests may be skipped locally but must pass in CI.
- Define each script in `package.json`; keep this table in sync.
