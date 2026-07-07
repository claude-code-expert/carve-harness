# Phase 5: Additive Hardening + Drop-in Packaging - Context

**Gathered:** 2026-07-07
**Status:** Ready for planning
**Source:** Default-proposal review (discuss Q&A skipped per user preference; HYG-01 + LICENSE forks confirmed via approval questions)

<domain>
## Phase Boundary

The core is trustworthy (Phases 1–4). This final phase adds the two remaining additive enforcement capabilities and finishes the template as a clean drop-in.

- **GUARD-04:** content secret scan — a write whose *content* carries a hardcoded secret (AKIA / `sk-` / `ghp_` / PEM / JWT) is blocked exit 2, complementing the path guard.
- **GATE-03:** incremental Stop verify — only changed stacks are built/tested, not the full suite every Stop.
- **CFG-05:** fill remaining `[…내용없음]` stubs with usable generic defaults.
- **HYG-01/02/03:** delete the install docs (rely on the manual), add the root `.env*` gitignore block, and confirm shipped docs already use `code.claude.com`.

**In scope:** editing `pretool-guard.sh` + `lib-protected.sh` (GUARD-04), `stop-verify.sh` (GATE-03), 5 stub files (CFG-05), `.gitignore` + install-doc deletions (HYG), and tests. **Out of scope:** a LICENSE file (deferred by user), rewriting the manual, CI integration, new stacks.

</domain>

<decisions>
## Implementation Decisions

### GUARD-04 — content secret scan
- **D-01:** Add a single-source `SECRETS_RE` to `lib-protected.sh` (mirrors the existing `PROTECTED_RE` single-source pattern). Patterns: `AKIA[0-9A-Z]{16}` (AWS), `sk-[A-Za-z0-9]{20,}` (OpenAI, incl. `sk-proj-`), `ghp_[A-Za-z0-9]{36,}` (GitHub PAT), `-----BEGIN [A-Z ]*PRIVATE KEY-----` (PEM), `eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.` (JWT header.payload).
- **D-02:** In `pretool-guard.sh`, after the existing path check, extract the write CONTENT and grep it against `SECRETS_RE`; on match → stderr `[guard] 시크릿 내용 차단` + `log-event.sh PreToolUse <tool> block` + exit 2. Content fields by tool: Write=`.tool_input.content`, Edit=`.tool_input.new_string`, MultiEdit=`.tool_input.edits[].new_string`, NotebookEdit=`.tool_input.new_source`.
- **D-03:** Content scan runs under the same fail-closed posture already in place (jq-absent/malformed already exit 2 in the preamble). Benign content (no pattern) → allow (existing exit 0 path). Patterns require a minimum length so ordinary prose / `sk-`-prefixed words don't false-positive (SC1: benign allowed).
- **D-04:** Scan is best-effort on field absence — a write with no content field (pure path Edit) just falls through to the existing allow. Never crash the guard.

### GATE-03 — incremental Stop verify
- **D-05:** Before each stack verify, compute changed files via `git status --porcelain` (staged + unstaged + untracked, working-tree scope) → `changed()` helper. Run the gradle verify only if a changed path matches `\.java$|\.kt$|\.gradle` (under the relevant dir); run the node verify only if a changed path matches `\.ts$|\.tsx$|package\.json`. No matching change → skip that stack (SC2).
- **D-06:** Fallbacks — not a git repo (`git` absent or `git status` fails) → best-effort run the current full detection (do not skip, avoids missing a verify when change-detection is impossible). Preserve `set -o pipefail`, the GATE-01 `stop_hook_active` loop-guard, the jq-absent best-effort skip, the `exit 2` on failure, and the pass/fail/loop-yield log calls — all byte-for-byte (Phase 1/2 regression).
- **D-07:** The existing `ponytail:` comment at `stop-verify.sh` (full-suite cost) is the exact ceiling this closes — replace it with the change-scoped guard.

### CFG-05 — fill stubs
- **D-08:** Replace `[…내용없음]` placeholders with generic, immediately-usable defaults in: `specs/README.md` (`[초기 스펙 — 내용없음]`), `.claude/rules/java-spring/patterns.md` (`[추가 규칙 — 내용없음]`), `.claude/rules/react-next/patterns.md` (`[추가 규칙 — 내용없음]`), `.claude/skills/handoff/SKILL.md` (`[프로젝트별 인계 항목 추가 — 내용없음]`), `.claude/skills/changelog/SKILL.md` (`[프로젝트별 기록 규칙 — 내용없음]`).
- **D-09:** Defaults are generic template guidance (no project-specific domain rules) — a line or two of real, sensible content each, matching the file's existing tone. The audit's sentinel check (Phase 4, HANDOFF-scoped) is unaffected; these are different files.

### HYG-01 — delete install docs (user-confirmed: "delete entirely, rely on manual")
- **D-10:** No dedicated `install.md`. Commit the already-made root deletions of `install.md` and `HARNESS-TEMPLATE-MANUAL.md`; formalize the move by adding `docs/md/` (untracked) to the repo; remove `docs/md/install.md` (a 9-line plugin snippet, not real install steps). Keep `docs/md/HARNESS-TEMPLATE-MANUAL.md` (the manual, relied upon) and `docs/md/harness-install-list.md`.
- **D-11:** ⚠️ **SAFETY GATE:** these are doc deletions (`.claude/rules/safety.md` → docs deletions require approval). The HYG plan is `autonomous: false`; the deletion/commit task is `type=manual` — execution pauses for approval before any `git rm`/deletion is staged.

### HYG-02 — gitignore only (LICENSE deferred by user)
- **D-12:** Add a root `.env*` block to `.gitignore` (currently only `logs/`). Patterns: `.env`, `.env.*` at repo root (and a general `*.env` guard). Do NOT create a `LICENSE` file (user deferred — note "unlicensed = all-rights-reserved" in the summary, not a blocker).

### HYG-03 — link check (already satisfied)
- **D-13:** Shipped docs already use `code.claude.com` (`docs/md/*`); zero `docs.claude.com` in the shipped surface. HYG-03 is a **verification assertion**, not an edit: assert `grep -r docs.claude.com` finds nothing under the shipped template (`.claude/`, `docs/`, `specs/`, repo-root `*.md`). Remaining `docs.claude.com` hits live only in `.planning/` internal artifacts (not shipped) — out of scope.

### Cross-cutting
- **D-14:** TDD (RED→GREEN) in the Phase 1/2 harness style for GUARD-04 + GATE-03; Bash + jq + coreutils + git only; no new runtime dependency; `bash -n` clean; guards stay exit-2-on-block / exit-0-on-allow, verify stays best-effort. CFG-05 + HYG are doc/config edits (no test harness beyond a stub-absence grep + the `/harness-audit` self-check staying green).

### Claude's Discretion
- Exact secret regexes' min-lengths (must avoid false positives — SC1) and the `SECRETS_RE` composition.
- The `changed()` helper's exact git plumbing (porcelain parse) and per-stack match regex.
- Generic stub wording (must be real, usable, non-placeholder).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` §"Phase 5" — goal, 4 success criteria, `Mode: mvp`.
- `.planning/REQUIREMENTS.md` — GUARD-04, GATE-03, CFG-05, HYG-01, HYG-02, HYG-03.

### Files edited
- `.claude/hooks/lib-protected.sh` — add `SECRETS_RE` (single-source, alongside `PROTECTED_RE`).
- `.claude/hooks/pretool-guard.sh` — content extraction + `SECRETS_RE` scan after the path check (GUARD-04).
- `.claude/hooks/stop-verify.sh` — `changed()` guard on each stack verify (GATE-03); preserve pipefail/loop-guard/jq-absent/exit-2/logs.
- `.gitignore` — add root `.env*` block (currently only `logs/`).
- Stubs: `specs/README.md`, `.claude/rules/java-spring/patterns.md`, `.claude/rules/react-next/patterns.md`, `.claude/skills/handoff/SKILL.md`, `.claude/skills/changelog/SKILL.md`.

### Deletions (SAFETY-gated, D-11)
- root `install.md`, root `HARNESS-TEMPLATE-MANUAL.md` (already deleted in working tree — commit), `docs/md/install.md`.

### Safety / test style
- `.claude/rules/safety.md` §"Require Explicit User Approval" — docs deletions + (creating `.env`/config) need approval; `.gitignore` edit is additive (not a `.env*` file itself).
- `.claude/rules/common/security.md` §PII/secrets — GUARD-04 aligns with "secrets not in code".
- `.claude/hooks/tests/pretool-guard.test.sh`, `stop-verify.test.sh` — harness style for GUARD-04 / GATE-03 tests.
- `.claude/hooks/harness-audit.sh` — the Phase 4 self-audit must still exit 0 after Phase 5 edits.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib-protected.sh` single-source `PROTECTED_RE` — `SECRETS_RE` follows the same shape (one definition, sourced by the guard).
- `pretool-guard.sh` already extracts `.tool_input.*` via jq and logs block/allow via `log-event.sh` — GUARD-04 extends the existing branch, no new structure.
- `stop-verify.sh` already detects gradle/node stacks — GATE-03 wraps each in a `changed()` check; the `ponytail:` comment already names this exact upgrade path.

### Established Patterns
- Guards fail-closed (exit 2) on jq-absent/malformed; verify is best-effort (exit 0 on jq-absent). GATE-03/GUARD-04 preserve their respective postures.
- Single-source patterns in `lib-protected.sh`; surgical edits; `${CLAUDE_PROJECT_DIR}` roots.

### Integration Points
- GUARD-04 adds a second block reason to `pretool-guard.sh` (content vs path).
- GATE-03 changes *when* stack verifies run, not their pass/fail semantics.
- HYG changes the repo's shipped file set (deletions + `.gitignore`) — the only phase that mutates tracked non-`.claude` files.

</code_context>

<specifics>
## Specific Ideas

- A Write with `content` containing `AKIA...`/`sk-...`/`ghp_...`/PEM/JWT → blocked exit 2 (SC1); benign content → allowed exit 0.
- Staging only a `.md` change then firing Stop → the gradle/node verify is skipped (SC2); a `.java` change → gradle verify runs.
- No `[내용없음]` sentinel remains in `specs/README`, the two `patterns.md`, or the two skill bodies (SC3).
- `.gitignore` blocks root `.env*`; `grep -r docs.claude.com` finds nothing in the shipped surface (SC4). (LICENSE deferred — SC4's LICENSE clause noted as a known follow-up.)

</specifics>

<deferred>
## Deferred Ideas

- `LICENSE` file — deferred by user (add later; unlicensed = all-rights-reserved until then).
- Rewriting/expanding the manual or `harness-install-list.md` — kept as-is.
- Pipe/heredoc-indirection secret scanning, and scanning Bash-command content for secrets — GUARD-04 targets write-tool content; Bash-write secret content is a documented ceiling.

*None block Phase 5.*

</deferred>

---

*Phase: 05-additive-hardening-drop-in-packaging*
*Context gathered: 2026-07-07 via default-proposal review*
</content>
