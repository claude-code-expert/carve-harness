---
phase: 02-m9-analysis-recommendation-intelligence
plan: 03
subsystem: cli
tags: [prefs, wizard, persistence, json, interactive-install]

# Dependency graph
requires:
  - phase: 02-01
    provides: HarnessDesign (recommended/available) consumed by applyPrefs/buildChoices
provides:
  - "src/prefs.ts: CarvePrefs type + pure readPrefs/writePrefs/applyPrefs (.claude/.carve-prefs.json)"
  - "Prefs-aware wizard: buildChoices(design, prefs?) default-check = recommended − deselected + selected"
  - "selectInteractive(design, root) reads prefs on start, writes derived prefs on confirm"
  - "interactiveInstall wires root through so prefs round-trip per project"
affects: [installer, update, lifecycle]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "User-data prefs file confined to .claude/, excluded from install manifest"
    - "Fail-safe JSON read (try/catch + shape narrowing → null, never throw)"

key-files:
  created:
    - src/prefs.ts
    - test/unit/prefs.test.ts
  modified:
    - src/wizard.ts
    - src/commands.ts
    - test/unit/wizard.test.ts

key-decisions:
  - ".carve-prefs.json is user data → NOT added to install manifest (uninstall must not delete it; update must not diff it as an asset)"
  - "Followed PLAN.md contract (applyPrefs returns default-checked id[]; derivation inlined in selectInteractive) — kept module minimal per CLAUDE.md simplicity rule"
  - "selectInteractive root param is required (single caller updated), avoiding an optional that silently skips persistence"

patterns-established:
  - "Pure data module (no console.*); callers own logging and TTY"
  - "applyPrefs intersects with design.available — never default-check an unavailable id"

requirements-completed: [INTEL-04]

# Metrics
duration: 2min
completed: 2026-06-05
---

# Phase 02 Plan 03: prefs persistence + prefs-aware wizard Summary

**User component selections persist to `.claude/.carve-prefs.json` and drive default-checked state on the next interactive run, via a pure prefs module excluded from the install manifest (INTEL-04).**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-06-05T04:43:20Z
- **Completed:** 2026-06-05T04:45:23Z
- **Tasks:** 2 (both TDD)
- **Files modified:** 5 (2 created, 3 modified)

## Accomplishments
- New `src/prefs.ts`: `CarvePrefs` + pure `readPrefs`/`writePrefs`/`applyPrefs` using only `node:fs` + JSON (no new deps).
- Malformed/missing prefs fail-safe to `null` (try/catch + shape narrowing), so corrupt prefs never break install.
- `buildChoices(design, prefs?)` is prefs-aware; no-prefs behavior identical to before (backward compatible).
- `selectInteractive(design, root)` reads prefs at start and writes derived prefs (deselected = recommended not chosen; selected = chosen not in recommended) after confirm; cancel writes nothing.
- `interactiveInstall` passes `root`, so prefs round-trip at `<root>/.claude/.carve-prefs.json`.
- Explicitly documented (code comment + here): `.carve-prefs.json` is excluded from the install manifest.

## Task Commits

1. **Task 1: src/prefs.ts (pure read/write/apply) + round-trip tests** - `4b84776` (feat, TDD test→impl)
2. **Task 2: prefs-aware wizard + interactiveInstall root wiring** - `9b816d8` (feat, TDD test→impl)

_Both tasks were TDD: failing test (RED) verified before implementation (GREEN); code was already minimal so no REFACTOR commit._

## Files Created/Modified
- `src/prefs.ts` - CarvePrefs type, readPrefs/writePrefs/applyPrefs (pure + thin fs), PREFS_REL constant
- `test/unit/prefs.test.ts` - round-trip, missing→null, malformed→null, shape-mismatch→null, applyPrefs deselect/select/available-intersection
- `src/wizard.ts` - buildChoices(design, prefs?) + selectInteractive(design, root) with read/write prefs
- `src/commands.ts` - interactiveInstall passes root to selectInteractive (+ manifest-exclusion comment)
- `test/unit/wizard.test.ts` - deselected→selected=false, added→selected=true; existing no-prefs test unchanged

## Decisions Made
- `.carve-prefs.json` is user data, not a carve-generated asset → MUST NOT be in `manifest.files`. Adding it would make `uninstall` delete user preferences and `update` treat it as an asset to diff. `installer.ts`/`manifest.ts` left untouched (verified by grep: prefs symbols absent there).
- Followed the PLAN.md interface (`applyPrefs` returns the default-checked id array; prefs derivation inlined in `selectInteractive`) rather than adding extra `defaultCheckedIds`/`derivePrefs` helpers mentioned in loose context — keeps the module minimal (CLAUDE.md simplicity rule).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- M9 (analysis + recommendation intelligence) deselection-persistence success criterion is met.
- Future lifecycle work (update/diff) should continue to treat `.carve-prefs.json` as user data (out of manifest).

## Self-Check: PASSED
- FOUND: src/prefs.ts
- FOUND: test/unit/prefs.test.ts
- FOUND: src/wizard.ts (modified), src/commands.ts (modified), test/unit/wizard.test.ts (modified)
- FOUND commit: 4b84776
- FOUND commit: 9b816d8
- Gate: `npm run check` clean; `npm test` 173/173 pass.
- Verified: `.carve-prefs.json` / prefs symbols NOT referenced in installer.ts or manifest.ts.

---
*Phase: 02-m9-analysis-recommendation-intelligence*
*Completed: 2026-06-05*
