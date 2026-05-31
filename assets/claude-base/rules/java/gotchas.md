# Gotchas — Java

> Living log of project-specific bug patterns. When a non-obvious bug recurs,
> record it here immediately (see CLAUDE.md MANDATORY #4). Do not rely on memory.

## Format
Each entry: symptom → root cause → fix → date.

```
### <short title>
- Symptom: what was observed
- Root cause: the actual source-level reason
- Fix: the complete patch (not a workaround)
- Date: YYYY-MM-DD
```

---

## Examples (Java)

### Mutable static field leaked state across requests
- Symptom: one user occasionally saw another user's data under load.
- Root cause: a `static` mutable field on a service held per-request state.
- Fix: make the field non-static / request-scoped (or pass it as a parameter); keep shared state immutable.

### `equals`/`hashCode` not overridden broke a HashMap lookup
- Symptom: a value object stored in a `HashSet`/`HashMap` was never found again.
- Root cause: the type relied on identity equality; `equals`/`hashCode` were not overridden.
- Fix: override both consistently (or use a record); add a test that round-trips through the collection.

---

## Entries
<!-- add new entries below -->
