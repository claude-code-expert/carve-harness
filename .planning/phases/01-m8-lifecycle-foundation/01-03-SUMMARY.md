---
phase: 01-m8-lifecycle-foundation
plan: 03
subsystem: cli-commands
tags: [lifecycle, diff, doctor, classify]
requires: ["01-01", "01-02"]
provides: ["classify", "DiffEntry", "cmdDiff", "v2-doctor"]
affects: ["src/commands.ts"]
tech-stack:
  added: []
  patterns: ["pure 3-way hash classification (orig/cur/next)", "info command always exits 0"]
key-files:
  created: ["test/unit/commands.test.ts"]
  modified: ["src/commands.ts", "test/e2e/installer.e2e.test.ts"]
decisions:
  - "orig==='' (un-migrated v1) treated conservatively as user-modified — never auto-overwrite an un-hashed file"
  - "file deleted on disk (cur===null) classified as carve-updated so update restores it"
  - "cmdDiff exits 0 even when differences exist (read-only info command)"
metrics:
  duration: ~15m
  completed: 2026-06-05
requirements: [LIFE-02]
---

# Phase 1 Plan 3: classify() 3-way + carve diff + v2-aware doctor Summary

Pure 3-way diff engine (`classify`) comparing orig/cur/next hashes per asset, the read-only `carve diff` info command, and a v2-manifest-aware `cmdDoctor` — the correct, side-effect-free signal that `carve update` (01-04) will act on.

## What Was Built

- `DiffEntry` type + `export function classify(root, m, artifacts)`: pure function, no writes. Reads on-disk content defensively (existsSync guard before readFileSync). Implements the exact rule order: no manifest entry → new-recommended; orig==='' → user-modified+unmigrated; cur===null (deleted) → carve-updated (restore); cur===next → unchanged; cur===orig && next!==orig → carve-updated; else user-modified.
- `export function cmdDiff(root, io)`: reuses analyze→design→generate, classifies, prints grouped Korean output (변경 없음 / carve 갱신 가능 / 사용자 수정 — 보존됨 / 신규 추천) with counts, migrate hint when unmigrated, always returns 0.
- `cmdDoctor` adapted to v2: iterates `m.files` as `{ path }` objects, `.sh` filter uses `f.path`, prints `스키마 v${m.schemaVersion}`, and emits a `carve migrate 권장` hint when schemaVersion < 2 or any file hash is ''.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Guarded `m.files[0]` index access in installer.e2e.test.ts**
- **Found during:** Verification gate (tsc must be fully clean).
- **Issue:** Pre-existing tsc error `TS2532: Object is possibly 'undefined'` at installer.e2e.test.ts:43, introduced by 01-02 under `noUncheckedIndexedAccess`. Blocked the plan's "tsc FULLY clean" gate.
- **Fix:** `m!.files[0].hash` → `m && m.files[0] && m.files[0].hash` (also drops a non-null `!` per code-style).
- **Files modified:** test/e2e/installer.e2e.test.ts
- **Commit:** 6f2f73d

## Verification

- `npm run check` (tsc --noEmit): exits 0, fully clean (manifest + installer + commands + tests all v2).
- `npm test`: 136 tests pass, 0 fail. Includes 7 new classify unit tests and the previously-failing `install→doctor→uninstall 라운드트립` (cli.test.ts) now passing.

## Self-Check: PASSED

- FOUND: src/commands.ts (classify, cmdDiff, DiffEntry, v2 doctor)
- FOUND: test/unit/commands.test.ts
- FOUND: commit 6f2f73d
