# Code Style — Dart / Flutter

> Match existing code first; these are defaults, not overrides.

## Types & Null Safety
- Sound null safety always on. **Never use `!`** (bang) to silence a null — handle the null case.
- **Avoid `dynamic`** — use a precise type or generics.
- Prefer `final`/`const` over `var`; mark widgets and models immutable.
- Validate all external input (JSON, args, platform channels) at the boundary.

## Errors & Logging
- Never silently swallow errors (empty `catch {}` is banned) — log with context.
- Never use `print` in app code — use a logger (e.g. `logging`/`logger`).
- Throw typed exceptions; don't throw raw strings.

## Naming & Structure
- Variables/functions: `lowerCamelCase`; types/widgets/classes: `UpperCamelCase`; files: `lowercase_with_underscores`.
- Names express intent (`shouldRetry`, not `flag2`). Keep functions single-purpose.
- Eliminate duplication; make dependencies explicit; minimize shared mutable state.

## Flutter
- Use `const` constructors wherever possible — avoids needless rebuilds.
- Keep widgets small and composable; extract subtrees over deep nesting.
- Dispose controllers, streams, and listeners in `dispose()`; cancel subscriptions.
- Never call `setState` after `dispose` — guard with `mounted`.

## Secrets
- Never hardcode secrets, API keys, or tokens. Read from env / secure storage.
- Never commit `.env*`, signing keys, or credential files.
