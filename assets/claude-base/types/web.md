# Project Type — Web (service / API / app)

> Architectural concerns for a web service. Layered on top of the stack rules — these are about request boundaries and operations, not language idioms.

## Request boundary
- **Validate every request at the edge.** Body, query, headers, path params are untrusted — validate and normalize before they reach business logic. Reject with a 4xx, don't coerce silently.
- **AuthN vs AuthZ are separate.** Authenticate (who) then authorize (may they) on every protected route. Never trust a client-supplied identity/role field.
- **Map errors to status codes deliberately.** User error → 4xx, server fault → 5xx. Never leak stack traces, SQL, or internal paths in responses; log details server-side, return a stable error shape to the client.

## State & correctness
- **Prefer stateless handlers.** Keep session/derived state in a store, not in process memory — so any instance can serve any request.
- **Make mutating endpoints idempotent** where clients may retry (idempotency key or natural upsert) to survive network retries and at-least-once delivery.
- **Set timeouts and limits.** Every outbound call (DB, cache, upstream API) needs a timeout; cap request body size and apply rate limiting on public endpoints.

## Operations
- **Config & secrets from validated env**, never hardcoded; fail fast at startup if a required value is missing.
- **Structured logs with a request/correlation id**; emit health and readiness endpoints.
- **CORS is an allowlist**, not `*`, for credentialed/cross-origin APIs.

## Frontend (if this service ships UI)
- **Semantic HTML + visible focus.** Use real `<button>`/`<label>`/heading hierarchy; never remove `:focus-visible` outlines.
- **Text contrast ≥ 4.5:1** for body text (3:1 for large text) — the anti-ai-slop linter's `contrast-aa` rule enforces this statically.
- **Client-side validation is UX only.** Always re-validate on the server; the browser is an untrusted client.
