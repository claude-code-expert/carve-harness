# Commands

> Canonical commands. Use these names; don't invent ad-hoc variants. Keep in sync with the build manifest.

## Daily
| Task | Command |
|------|---------|
| Install deps | `{{PKG_MANAGER}} install` <!-- fill in if blank --> |
| Run (dev) | {{PKG_MANAGER}} run dev <!-- fill in the real command --> |
| Build | {{PKG_MANAGER}} run build <!-- fill in the real command --> |
| Start (prod) | {{PKG_MANAGER}} run start <!-- fill in the real command --> |

## Quality (run before commit)
| Task | Command |
|------|---------|
| Type / static check | <!-- fill in: type checker or static analyzer --> |
| Lint | `{{LINT_CMD}}` <!-- fill in if blank --> |
| Format | `{{FORMAT_CMD}}` <!-- fill in if blank --> |
| Tests | `{{TEST_CMD}}` <!-- fill in if blank --> |
| All checks | <!-- fill in: the combined check (type + lint + test) --> |

## Notes
- "Always run tests before committing" → run the full check (type + lint + test) as one command.
- Use the exact commands above — don't invent ad-hoc variants. CI runs these same commands; keep local and CI identical.
- Long-running tests may be skipped locally but must pass in CI.
- Define each command in the build manifest; keep this table in sync.
