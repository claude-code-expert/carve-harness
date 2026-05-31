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

## Examples

### Unvalidated external input crashed a downstream step
- Symptom: a runtime failure occurred deep in processing, not at the entry point.
- Root cause: external input was trusted without validation at the boundary.
- Fix: validate and normalize the input at the boundary before passing it on.

### An error was caught and silently ignored
- Symptom: a failure happened but nothing was logged.
- Root cause: an error was caught and discarded with no logging or rethrow.
- Fix: log with context (or rethrow); never swallow errors silently.

---

## Entries
<!-- add new entries below -->
