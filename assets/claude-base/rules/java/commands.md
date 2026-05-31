# Commands — Java

> Canonical commands. Use these names; don't invent ad-hoc variants. Keep in sync with the build file.
> Maven equivalent: replace `{{PKG_MANAGER}}` with `./mvnw` and the task names accordingly.

## Daily
| Task | Command |
|------|---------|
| Build | `{{PKG_MANAGER}} build`  (Maven: `./mvnw package`) |
| Run | `{{PKG_MANAGER}} bootRun`  (Maven: `./mvnw spring-boot:run`) |
| Clean | `{{PKG_MANAGER}} clean`  (Maven: `./mvnw clean`) |

## Quality (run before commit)
| Task | Command |
|------|---------|
| Lint / static analysis | `{{LINT_CMD}}`  (`{{PKG_MANAGER}} check`) |
| Format | `{{FORMAT_CMD}}`  (`{{PKG_MANAGER}} spotlessApply`) |
| Unit tests | `{{TEST_CMD}}`  (`{{PKG_MANAGER}} test`) |
| All checks | `{{PKG_MANAGER}} spotlessApply check`  (Maven: `./mvnw verify`) |

## Notes
- "Always run tests before committing" → run the full check.
- Long-running integration tests may be skipped locally but must pass in CI.
- Use the committed wrapper (`./gradlew` / `./mvnw`); keep this table in sync with the build file.
