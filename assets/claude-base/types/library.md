# Project Type — Library (package / SDK)

> Architectural concerns for a reusable library. Layered on top of the stack rules.

## Public API
- **The public surface is a contract.** Keep it small and intentional; everything exported is something you must not break. Mark internal code as non-public so it can change freely.
- **Follow semver strictly.** Breaking change → major. Additive → minor. Fix → patch. Document every change in the changelog; provide a migration note for breaking ones.
- **Deprecate before removing.** Mark, warn, and give consumers a release or two before deleting.

## Behavior
- **No side effects on import.** Importing the library must not perform I/O, mutate global state, or read env — do work only when the consumer calls an API.
- **No hidden global state.** Prefer explicit instances/parameters over singletons so consumers stay in control and can test in isolation.
- **Errors are part of the contract.** Throw/return typed, documented errors; don't leak internal types across the boundary.

## Footprint
- **Minimize dependencies** — each one becomes the consumer's transitive cost and risk. Default to zero runtime deps; justify each addition.
- **Document the surface** (types, parameters, examples); ship type definitions if the ecosystem uses them.

## Docs as contract
- **Every public API has a runnable example** — and the examples are executed in tests so they can't rot.
- **Declare the supported runtime matrix** (language/runtime versions, platforms) explicitly and test against its edges.
