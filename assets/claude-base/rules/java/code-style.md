# Code Style — Java

> Match existing code first; these are defaults, not overrides.

## Types & Immutability
- Prefer immutability: `final` fields, records for data carriers, unmodifiable collections.
- **No raw types** (`List` over `List<T>`). Never use `@SuppressWarnings` to hide a real problem.
- Use `Optional<T>` for absence in new APIs — don't return `null`.
- Validate all external input (HTTP body, config, third-party responses) with Bean Validation at the boundary.

## Errors & Logging
- Never swallow exceptions — empty `catch` is banned. Log with context or rethrow wrapped.
- Throw specific exceptions, not bare `Exception` / `RuntimeException`.
- Use the SLF4J logging facade — never `System.out.println` / `printStackTrace` in app code.

## Naming & Structure
- Methods/fields: `camelCase`; classes: `PascalCase`; constants: `UPPER_SNAKE`.
- Names express intent (`shouldRetry`, not `flag2`). Keep methods single-purpose.
- Eliminate duplication; make dependencies explicit; minimize shared mutable state.

## Dependencies & State
- Prefer constructor injection — no field injection, no service locators.
- Avoid premature `static` / singletons; mutable static state is a cross-request leak waiting to happen.
- Override `equals`/`hashCode` together when a type is used as a map/set key.

## Secrets
- Never hardcode secrets, API keys, or tokens. Read from validated config only.
- Never commit `application-*.properties`/`.env*` files containing real credentials.
