# Tech Stack

> Language could not be auto-detected. Fill the blanks to match your stack.
> The principles below apply regardless of language — keep them even after filling in.

## Core
- **Language & version**: <!-- fill in: e.g. the language and its version -->
- **Runtime**: <!-- fill in: runtime/platform the project targets -->
- **Package manager**: {{PKG_MANAGER}} <!-- fill in if blank --> (lockfile committed)
- **Build system**: <!-- fill in: build tool / manifest -->
- **Project type**: {{PROJECT_TYPE}} <!-- fill in if blank -->

## Quality Tooling
- **Lint/format**: {{LINT_CMD}} / {{FORMAT_CMD}} <!-- fill in the tools if blank -->
- **Type / static analysis**: <!-- fill in: type checker or static analyzer run in CI -->
- **Test framework**: <!-- fill in: the unit/e2e test framework -->
- **Validation**: <!-- fill in: how external input is validated at boundaries -->

## Rules (stack-agnostic)
- **One stack, stated rationale.** No library outside this stack without a clear reason and user approval — every dependency is attack surface and maintenance cost.
- **Pin versions; commit the lockfile.** Reproducible installs across machines and CI. Document any upgrade in the changelog.
- **Prefer the standard library.** Reach for a dependency only when the stdlib genuinely can't solve it.
- **Validate at the boundary.** Treat all external input (HTTP, env, files, third-party responses) as untrusted; validate and normalize where it enters, not deep inside.
- **One toolchain, run everywhere.** Lint/format/type/test commands must be identical locally and in CI — see `commands.md`. CI is the source of truth; a green local run that fails CI means the local setup drifted.
