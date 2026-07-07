---
phase: 05-additive-hardening-drop-in-packaging
plan: 03
status: complete
requirements: [HYG-01, HYG-02, HYG-03]
---

# Plan 05-03 Summary — Drop-in Packaging Hygiene

## What was built
- **HYG-02:** added a root `.env*` block to `.gitignore` (kept `logs/`).
- **HYG-03:** confirmed the shipped surface already uses `code.claude.com` (assertion, no edit).
- **HYG-01:** removed the install docs (user-approved) — root `install.md` + `HARNESS-TEMPLATE-MANUAL.md` deletions committed, the manual + `harness-install-list.md` tracked in `docs/md/`, and `docs/md/install.md` (plugin snippet) deleted. No `install.md` ships.

## Self-Check: PASSED
- HYG-02: `git check-ignore .env` and `.env.production` both succeed; `logs/` still ignored.
- HYG-03: `grep -rn 'docs.claude.com'` over `.claude/`, `docs/`, `specs/`, root `*.md` → nothing.
- HYG-01: no `install.md` tracked anywhere; root manual untracked; `docs/md/HARNESS-TEMPLATE-MANUAL.md` + `docs/md/harness-install-list.md` tracked.
- `/harness-audit` → exit 0; full hook suite → 0 failed.

## Requirements
- **HYG-02 (SC4 partial):** `.gitignore` blocks root `.env*`.
- **HYG-03 (SC4):** shipped docs use `code.claude.com` (already true).
- **HYG-01 (SC4):** no dedicated install.md — deleted after explicit approval; the manual is the single reference.

## Key correctness proofs
- **D-11 (approval gate):** the deletions were a `type=manual` task; nothing was `git rm`'d before the user approved (AskUserQuestion).
- **Move preserved history:** git detected the manual as a rename (`R HARNESS-TEMPLATE-MANUAL.md -> docs/md/…`).
- **D-12:** `.gitignore` edit is additive; no `.env` file was created.

## key-files
### modified
- `.gitignore` — root `.env*` block added.
### deleted (approved)
- `install.md` (root), `HARNESS-TEMPLATE-MANUAL.md` (root — moved to docs/md/), `docs/md/install.md` (plugin snippet).
### added (tracked)
- `docs/md/HARNESS-TEMPLATE-MANUAL.md`, `docs/md/harness-install-list.md`.

## Deviations
- **LICENSE deferred (user):** SC4's LICENSE clause is NOT met — a documented follow-up (unlicensed = all-rights-reserved until added). All other SC4 clauses satisfied.
- Executed inline; the deletion task paused for explicit approval per safety.md.

## Commits
- (this plan) chore(05-03): gitignore .env* + remove install docs (HYG-01/02/03)
