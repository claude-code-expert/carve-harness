# Project Type — General

> Project type could not be classified. These are stack- and type-agnostic architectural concerns. Replace with type-specific guidance (web / cli / mobile / desktop / batch / library) once the type is clear.

## Boundaries
- **Define clear boundaries** between layers (entry point, business logic, I/O). Keep business logic free of framework and I/O concerns so it stays testable.
- **Validate untrusted input where it enters** — don't push raw external data deep into the system.

## Failure & state
- **Fail loud, not silent.** Surface errors with context; never swallow them. Make failure states explicit in the return/throw contract.
- **Minimize shared mutable state.** Prefer explicit inputs/outputs over hidden globals so behavior is predictable and testable.

## Operations
- **Config and secrets from validated sources** (env/config), never hardcoded; fail fast on missing required values.
- **Make repeated runs/calls predictable** — same inputs, same result; guard destructive actions.
- **Observability**: log meaningful events with enough context to diagnose a failure after the fact.
