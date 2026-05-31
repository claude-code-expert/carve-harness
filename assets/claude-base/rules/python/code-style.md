# Code Style — Python

> Match existing code first; these are defaults, not overrides.

## Types
- Type hints on all public functions and attributes. **Never use bare `Any`** — use a precise type or a `Protocol`.
- Prefer `@dataclass` or Pydantic models over loose dicts for structured data.
- Never use a mutable default argument (`def f(x=[])`) — use `None` and assign inside.
- Validate all external input (HTTP body, env, third-party responses) with Pydantic at the boundary.

## Errors & Logging
- Never silently swallow exceptions — `except: pass` and bare `except:` are banned. Log with context.
- Raise specific exception types; never raise or catch bare `Exception` as a catch-all.
- Never use `print` in app code — use the `logging` module.

## Naming & Structure
- Functions/variables: `snake_case`; classes: `PascalCase`; constants: `UPPER_SNAKE`.
- Names express intent (`should_retry`, not `flag2`). Keep functions single-purpose.
- Eliminate duplication; make dependencies explicit; minimize shared mutable state.

## Async
- Use `asyncio` with `async`/`await`; never block the event loop with sync I/O or `time.sleep`.
- Offload CPU-bound or blocking calls to a thread/process pool (`run_in_executor`).
- Never leave a coroutine unawaited — `await` it or schedule it with a tracked task.

## Secrets
- Never hardcode secrets, API keys, or tokens. Read from validated settings only.
- Never commit `.env*` or files containing real credentials.
