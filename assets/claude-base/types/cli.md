# Project Type — CLI (command-line tool)

> Architectural concerns for a command-line tool. Layered on top of the stack rules.

## Contract with the shell
- **Exit codes are the API.** `0` = success, non-zero = failure (distinct codes for distinct failure classes). Scripts and CI branch on these — never exit 0 on error.
- **stdout is data, stderr is diagnostics.** Machine-readable output (the result) goes to stdout; logs, progress, and errors go to stderr. This keeps `tool | next` pipelines clean.
- **Provide `--help` and `--version`.** Document every flag; fail with a clear message and non-zero on unknown flags.

## Behavior
- **Parse args explicitly** with a real parser; validate inputs before doing work. Define precedence: flags > env > config file > defaults.
- **Don't prompt in a non-TTY.** Detect non-interactive use (pipe/CI) and require flags instead of blocking on input; offer `--yes`/`--no-input` for automation.
- **Be idempotent and predictable.** Re-running with the same inputs gives the same result; make destructive actions require confirmation or an explicit flag.

## Output
- **Quiet by default, `--verbose` to expand**; consider a `--json` mode for scripting.
- **No color/spinners when output isn't a TTY** (or honor `NO_COLOR`).

## Failure UX & signals
- **Error messages are actionable**: state what failed *and* how to fix it ("config not found — run `tool init` first"), not just the symptom.
- **Clean up on SIGINT/SIGTERM**: remove temp files and partial output before exiting; never leave half-written state behind.
- **Document exit codes in `--help`** so scripts can branch on them without reading source.
