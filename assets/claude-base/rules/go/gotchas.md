# Gotchas — Go

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

## Examples (Go)

### Loop variable captured by goroutine closure (pre-1.22)
- Symptom: goroutines all observed the same final loop value.
- Root cause: pre-Go-1.22 loop variables were shared across iterations; the closure captured the variable, not its value.
- Fix: rebind inside the loop (`v := v`) or upgrade to Go 1.22+ where each iteration has its own variable.

### nil error interface holding a typed nil
- Symptom: `if err != nil` was true even though the underlying pointer was nil.
- Root cause: a non-nil interface wrapping a typed-nil concrete value — the interface itself is not nil.
- Fix: return a literal `nil` on the success path; don't return a typed `*MyErr` variable that is nil.

---

## Entries
<!-- add new entries below -->
