# Project Type — Batch (job / pipeline / worker)

> Architectural concerns for a batch job or data pipeline. Layered on top of the stack rules.

## Re-run safety
- **Idempotent by design.** A re-run after a partial or failed run must converge to the same result, not double-apply. Use upserts, dedupe keys, or "mark processed" so retries are safe.
- **Checkpoint and resume.** For long jobs, record progress so a restart continues from the last good point instead of from zero.
- **Atomic outputs.** Write to a staging location and promote on success — never leave consumers reading a half-written result.

## Failure handling
- **Fail loud, with a non-zero exit.** Distinguish transient (retry with backoff) from permanent (stop, alert) failures. Don't swallow per-item errors silently — collect and report them.
- **Bound the blast radius.** Process in batches with limits on memory, rows, and concurrency; cap retries to avoid infinite loops.

## Observability
- **Log start/end, counts, and durations** with a run id; emit metrics (processed / failed / skipped) so a run's outcome is auditable.
- **Make runs reproducible**: pin inputs (date window, source snapshot) explicitly rather than "now".

## Concurrency & windows
- **Lock against overlapping runs** (advisory lock / lease) — a slow run and the next schedule firing together must not double-process.
- **Date windows carry an explicit timezone**; "yesterday" in UTC vs local is a classic silent off-by-one.
- **Define a retention policy** for outputs and logs (how long, who deletes) so storage doesn't grow unbounded.
