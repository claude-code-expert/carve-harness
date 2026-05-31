# Gotchas — Python

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

## Examples (Python)

### Mutable default argument shared across calls
- Symptom: a list/dict accumulated values from previous calls unexpectedly.
- Root cause: `def f(items=[])` — the default is evaluated once and reused.
- Fix: default to `None`, then `items = items if items is not None else []` inside.

### Broad `except Exception` swallowed a real bug
- Symptom: failure happened but nothing surfaced; behavior silently wrong.
- Root cause: a `try/except Exception` block caught and ignored the real error.
- Fix: catch the specific exception type; log with context; let unexpected errors propagate.

---

## Entries
<!-- add new entries below -->
