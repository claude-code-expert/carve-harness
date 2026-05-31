# Gotchas

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

## Examples (TypeScript)

### `any` leaking through JSON.parse
- Symptom: runtime shape mismatch not caught by `tsc`.
- Root cause: `JSON.parse` returns `any`; downstream code trusted it.
- Fix: parse then validate with a Zod schema at the boundary.
- Date: ____

### Floating promise swallowed an error
- Symptom: failure happened but nothing was logged.
- Root cause: an `async` call was not awaited and had no `.catch`.
- Fix: `await` it (or attach a logging `.catch`); enable `no-floating-promises` lint.
- Date: ____

---

## Entries
<!-- add new entries below -->
