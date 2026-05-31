# Gotchas — Dart / Flutter

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

## Examples (Dart / Flutter)

### setState called after dispose
- Symptom: "setState() called after dispose()" exception after an async call returns.
- Root cause: a `BuildContext` / `State` was used across an async gap; the widget was already unmounted.
- Fix: guard with `if (!mounted) return;` before `setState`; cancel pending work in `dispose()`.

### Missing `const` causing needless rebuilds
- Symptom: janky frames; widgets rebuild every parent rebuild.
- Root cause: a static subtree was constructed without a `const` constructor.
- Fix: add `const` to the constructor and its call site; enable `prefer_const_constructors` lint.

---

## Entries
<!-- add new entries below -->
