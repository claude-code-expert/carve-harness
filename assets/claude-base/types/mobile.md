# Project Type — Mobile (app)

> Architectural concerns for a mobile app. Layered on top of the stack rules.

## Lifecycle & state
- **Respect the platform lifecycle.** The OS pauses, backgrounds, and kills the app at will — persist and restore UI/navigation state so a kill mid-flow doesn't lose user work.
- **Guard async against teardown.** Never apply results from an in-flight request to a screen that's been disposed; check the view is still mounted/attached first.
- **Keep the main/UI thread free.** Move I/O, parsing, and heavy work off the UI thread to avoid jank and ANRs.

## Network & data
- **Assume the network is flaky or absent.** Handle offline explicitly: cache, queue writes, and reconcile on reconnect; show real state, not an infinite spinner.
- **Store secrets in the platform keystore/keychain**, never in plaintext prefs or bundled in the binary.
- **Budget battery and data.** Batch network calls; back off and respect OS background-execution limits.

## UX & permissions
- **Request permissions in context, just before use**, and degrade gracefully when denied.
- **Design for variable screens** (size, density, safe areas, orientation) and platform back/gesture conventions.

## Accessibility & release
- **Touch targets ≥ 44pt** and support OS font scaling — layouts must not break at larger text sizes.
- **Roll out risky changes gradually** (feature flag / staged rollout) — a bad mobile release can't be hotfixed like a server.
- **Crash reporting without PII**: capture stack traces and device context, never user content or identifiers.
