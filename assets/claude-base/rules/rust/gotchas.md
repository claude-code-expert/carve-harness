# Gotchas — Rust

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

## Examples (Rust)

### MutexGuard held across an `.await` deadlocks
- Symptom: task hangs intermittently under load; no panic, no log.
- Root cause: a `std::sync::MutexGuard` was held across an `.await` point, blocking the executor thread.
- Fix: drop the guard before awaiting (scope it), or use `tokio::sync::Mutex` for async-held locks.

### Integer overflow: panics in debug, wraps in release
- Symptom: arithmetic correct in `cargo test` but silently wrong in `--release`.
- Root cause: overflow panics in debug builds but wraps in release builds.
- Fix: use `checked_add`/`saturating_add`/`wrapping_add` to make the intended behavior explicit.

---

## Entries
<!-- add new entries below -->
