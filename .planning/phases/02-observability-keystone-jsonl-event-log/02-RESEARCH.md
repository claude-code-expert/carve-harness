# Phase 2: Observability Keystone (JSONL Event Log) - Research

**Researched:** 2026-07-07
**Domain:** Bash + jq structured logging in Claude Code hooks (zero runtime dependency)
**Confidence:** HIGH (all load-bearing patterns verified empirically against local jq 1.8.1 / bash 5.3.9 and cross-checked with official Claude Code hook docs)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Log file layout (OBS-01)**
- **D-01:** Daily file `logs/YYYY-MM-DD.jsonl`. Matches the SC `logs/*.jsonl` glob, avoids single-file unbounded growth, and the date *is* the rotation — no separate rotation logic.
- **D-02:** Add `logs/` to `.gitignore` — **the repo currently has no `.gitignore`, so create one**. Logs are not committed (PII/noise). Size/day retention caps and cleanup are deferred to **Phase 5 hardening** (outside this phase's boundary).

**Hook coverage & shared helper (OBS-01)**
- **D-03:** **All 5** hook entry points log an event — `pretool-guard` (allow/block), `posttool-format` (ok/fail), `stop-verify` (pass/fail), `session-handoff` (start/save). Matches SC1 "every hook fire".
- **D-04:** A shared `.claude/hooks/log-event.sh` helper is the **single source**. Each hook calls `log_event <event> <tool> <decision> [target]`. Schema, timestamp, and path masking are defined in one place to prevent drift (same single-source philosophy as Phase 1's `PROTECTED_RE`). The helper **takes values as arguments — it does NOT re-consume stdin** (the calling hook already consumed the stdin JSON).
- **D-05:** **best-effort / fail-safe append (invariant).** A log failure (jq absent, `logs/` creation failure, write failure) **NEVER changes the hook's exit code.** Preserves Phase 1's fail-closed invariant — logging must not make the guard fail-open or defeat the Stop gate. The helper swallows its own errors (best-effort) and does not affect the caller's flow or exit code.

### Claude's Discretion (documented defaults — planner re-confirms)
- **Event schema:** `{ts, event, tool, decision, target}` one JSON line. `ts` = ISO8601 UTC (`date -u +%Y-%m-%dT%H:%M:%SZ`). `event` = hook name (PreToolUse/PostToolUse/Stop/SessionStart/PreCompact). `tool` = tool name (when present). `decision` = `allow|block|format-ok|format-fail|pass|fail|start|save` etc. `target` = file path / command (when present).
- **PII/secret masking:** `target` has any substring matching `pretool-guard`'s **PROTECTED_RE** replaced with `<masked>` — honors `security.md` "no PII/secrets in logs" and reuses the single-source pattern.
- **OBS-02 failure record:** `posttool-format` detects formatter **missing** (`command -v` fails) or **non-zero exit** and logs `{event:PostToolUse, tool:<formatter>, decision:format-fail, target:<file>, reason:missing|error}`. The formatter's **normal stdout stays silenced** (`2>/dev/null` retained) — only the failure **fact** is surfaced (C8 resolved, minimal noise).
- **Concurrency:** A single short JSON line `>>` append is atomic under POSIX PIPE_BUF (4096B) → no lock (documented ceiling). Event lines are far shorter in practice. Interleaving of >4096B lines is assumed non-occurring — `flock` if ever needed is Phase 5.

### Deferred Ideas (OUT OF SCOPE)
- **Log rotation / retention caps / cleanup** — size/day based. Deferred to **Phase 5 hardening**.
- **Adding `.env*` to `.gitignore`** — Phase 1's security ceiling ("`.gitignore .env*` + security.md") root defense, but no `.gitignore` currently exists. Whether Phase 2 (creating a `logs/` `.gitignore`) also adds `.env*` is planner/user judgment — default is **outside Phase 2 scope** (observability); add `logs/` only. (Recorded as an observed security gap; this is HYG-02, mapped to Phase 5.)
- **Large (>4096B) event line atomicity** — realistically non-occurring. `flock` if needed, Phase 5.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OBS-01 | Append hook events as structured JSONL to `logs/` (Bash+jq, no runtime dep) | Standard Stack (jq -cn construction), Pattern 1 (helper), Pattern 3 (atomic append), Pattern 4 (daily file + dir resolution). Verified: `jq -cn --arg` produces one compact valid line per fire; `>>` on a local file is atomic for single-write() short lines. |
| OBS-02 | Format-hook failure (formatter missing/error) recorded in JSONL, made visible (C8) | Pattern 5 (missing-vs-error detection in `posttool-format` case block), Pitfall 5 (PostToolUse exit 2 is non-blocking — must stay exit 0 + log). Confirmed the formatter's own stdout stays silenced while the failure fact is logged. |
</phase_requirements>

## Summary

This phase adds one new file (`.claude/hooks/log-event.sh`), edits four existing hooks to call it, and creates a `.gitignore`. There is **no new runtime dependency** — it uses `jq` and `date` (coreutils), both already required by Phase 1 (SC3 is satisfied by construction). The entire technical risk concentrates in three failure modes the naive implementation gets wrong: (a) **breaking the JSON** by string-concatenating attacker-controlled paths/commands, (b) **changing a hook's exit code** when logging fails (violating Phase 1's fail-closed invariant, D-05), and (c) **leaking secrets/PII** into a log that path-masking doesn't catch.

All three are solved by verified patterns. (a) is solved by **`jq -cn --arg`/`--argjson`** — never string interpolation; empirically confirmed that a malicious `target` containing quotes, newlines, and `{"fake":"line"}` is escaped into a single valid line. (b) is solved by **process isolation**: the helper runs as a **subprocess** (`bash log-event.sh …`), whose exit code, `set -e`, and internal `exit` cannot touch the parent (the hooks have no `set -e`; a bare command's exit code is discarded). I empirically proved the counter-case: a *sourced* function that calls `exit 2` **kills its caller** — so if the team prefers the sourced-function shape of D-04, the function must use only `return`, never `exit`/`set -e`. (c) is a genuine ceiling: PROTECTED_RE masks protected *paths* but not secret *values* embedded in a Bash command string — surfaced below as a security finding with a recommended mitigation.

**Primary recommendation:** Build `log-event.sh` as a **standalone subprocess script** (safest D-05 guarantee), single-sourcing `PROTECTED_RE` via a tiny shared snippet that both `pretool-guard.sh` and `log-event.sh` source. Construct every line with `jq -cn --arg`. Use `date -u +%Y-%m-%dT%H:%M:%SZ` (portable; not bash `printf %()T`, which macOS bash 3.2 lacks). Guard every operation and end the helper on a no-op `exit 0` so any failure is silently swallowed.

## Architectural Responsibility Map

> Tiers here are shell-tooling roles, not web tiers.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Deciding *what* to log (event/tool/decision/target) | Hook caller | — | Only the caller knows its own decision, tool name, and target; it passes them as args (D-04). |
| JSON line construction + schema | `log-event.sh` helper | — | Single source (D-04) — schema drift is prevented by one definition. |
| ISO8601 UTC timestamp | `log-event.sh` helper | — | Defined once so all events share one clock format. |
| PII / protected-path masking | `log-event.sh` helper | `pretool-guard` (owns PROTECTED_RE) | Masking applied uniformly to *every* target regardless of caller; reuses the single-source pattern. |
| Atomic append | Filesystem (O_APPEND via `>>`) | helper | Kernel-level guarantee; helper just opens with `>>` and emits one write(). |
| **Exit-code preservation (D-05)** | Hook caller (literal `exit N`) | helper isolation (subprocess) | Caller exits with a literal code *after* the log call; subprocess isolation means the helper cannot leak a code. |
| Format-failure detection (OBS-02) | `posttool-format` caller | helper | Only the caller can distinguish `command -v` failure vs non-zero formatter exit. |
| Log directory creation (`logs/`) | helper (`mkdir -p`, best-effort) | — | Created lazily on first write, failure is swallowed. |
| `logs/` gitignore | `.gitignore` (config) | — | Keeps logs out of git (D-02). |
| Rotation / retention / cleanup | — (OUT — Phase 5) | — | Daily file *is* the rotation for now (D-01). |

## Standard Stack

### Core
| Tool | Version (verified) | Purpose | Why Standard |
|------|-------------------|---------|--------------|
| `jq` | 1.8.1 (local; any 1.5+ has `-n`/`--arg`/`--argjson`/`-c`) | Safe JSON construction *and* append target | Already the harness's JSON parser (Phase 1). `--arg` guarantees escaping — the only correct way to build JSON from untrusted strings. |
| `date` (coreutils/BSD) | GNU coreutils present; BSD `date` compatible | ISO8601 UTC timestamp | `date -u +%Y-%m-%dT%H:%M:%SZ` is portable across GNU and BSD. Already used in `session-handoff.sh`. |
| `bash` | 5.3.9 local (target ≥3.2 for macOS drop-in) | Hook runtime | Existing `#!/usr/bin/env bash` shebang. No new features required. |

**No packages are installed. No `npm`/`pip`/`cargo` involved. SC3 (zero new runtime dependency) is satisfied by construction.**

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `date -u +…` (fork per event) | bash `printf '%(%Y-%m-%dT%H:%M:%SZ)T' -1` (zero fork) | **Rejected for the template.** Verified it works in bash 4.2+ but **fails in zsh** and in **macOS default bash 3.2**. `date -u` is already a dependency and is portable. The fork cost (~1ms) is irrelevant for a hook. |
| `jq -cn` for the append line | `printf '{...}' >> file` with manual escaping | **Rejected — this is the core anti-pattern.** Any unescaped `"`/`\`/newline in a path or command breaks the JSON or forges a second line. See Pitfall 1. |

**Installation:** none. Verify presence only:
```bash
command -v jq && jq --version      # -> jq-1.8.1
date -u +%Y-%m-%dT%H:%M:%SZ         # -> 2026-07-07T02:50:00Z
```

## Package Legitimacy Audit

**N/A — this phase installs no external packages.** It uses only pre-existing, OS-provided tools (`jq`, `date`/coreutils, `bash`), all already relied on by Phase 1. No registry, no slopcheck target, no supply-chain surface. SC3 forbids introducing any new tooling.

## Architecture Patterns

### System Architecture Diagram

```
Claude Code event (PreToolUse/PostToolUse/Stop/SessionStart/PreCompact)
        │  stdin: JSON payload
        ▼
┌─────────────────────────────────────────────┐
│ HOOK CALLER  (pretool-guard / posttool-format │
│              / stop-verify / session-handoff) │
│                                               │
│  input=$(cat)          ← consumes stdin ONCE  │
│  parse fields with jq                         │
│  compute decision (allow|block|ok|fail|…)     │
│                                               │
│  bash log-event.sh <event> <tool> <decision>  │  ← ARGS, not stdin
│                    [target] [reason]          │
│        │ (bare command — exit code discarded) │
│        ▼                                       │
│  exit <LITERAL 0 or 2>  ← unchanged by log    │
└─────────────────────────────────────────────┘
        │  subprocess (isolated: its exit/set -e/failure cannot reach caller)
        ▼
┌─────────────────────────────────────────────┐
│ log-event.sh  (single source)                 │
│                                               │
│  command -v jq  || exit 0   ┐                 │
│  mkdir -p logs/ || exit 0    │ every op        │
│  mask target via PROTECTED_RE│ guarded →       │
│  line=$(jq -cn --arg …)      │ return/exit 0   │
│  printf/jq >> logs/DATE.jsonl│ on ANY failure  │
│  ... 2>/dev/null || exit 0  ┘                 │
└─────────────────────────────────────────────┘
        │  O_APPEND, single write() of one short line
        ▼
   logs/YYYY-MM-DD.jsonl   (one valid JSON object per line)
```

Trace of the primary use case (guard blocks a `.env` write): PreToolUse JSON → `pretool-guard` parses `tool_name=Write`, `file_path=.env.production` → matches PROTECTED_RE → calls `log-event.sh PreToolUse Write block .env.production` (subprocess masks target → `<masked>`, appends one line) → `exit 2`. The append cannot change the `exit 2`.

### Recommended file layout
```
.claude/hooks/
├── log-event.sh        # NEW — single-source: schema + ts + masking + append
├── lib-protected.sh    # NEW (recommended) — one line: PROTECTED_RE, sourced by both
├── pretool-guard.sh    # EDIT — source lib-protected.sh; log_event at allow/block
├── posttool-format.sh  # EDIT — detect missing/error; log format-ok/fail/skip
├── stop-verify.sh      # EDIT — log pass/fail (and loop-yield)
└── session-handoff.sh  # EDIT — log start/save
logs/                   # NEW dir (created lazily by helper) — gitignored
.gitignore              # NEW — contains `logs/`
```

### Pattern 1: Safe JSON construction with `jq -cn --arg` (the load-bearing pattern)
**What:** Build the line with jq's argument binding, never string interpolation. `-n` = null input (don't read stdin), `-c` = compact single line (+ one trailing `\n`), `--arg name val` = bind as a *string* (auto-escaped), `--argjson` = bind as raw JSON (only for values you control).
**When to use:** Every event line.
**Verified** (local jq 1.8.1):
```bash
# Source: jq manual (--arg/--argjson/-c/-n) + local verification 2026-07-07
jq -cn \
  --arg ts       "$ts" \
  --arg event    "$event" \
  --arg tool     "$tool" \
  --arg decision "$decision" \
  --arg target   "$target" \
  '{ts:$ts, event:$event, tool:$tool, decision:$decision, target:$target}'
# -> {"ts":"2026-07-07T02:15:03Z","event":"PreToolUse","tool":"Write","decision":"block","target":"<masked>"}
```
Injection proof (verified): with `target='x"; DROP TABLE; {"fake":"line"}<newline>\ end'` the output is a **single** line where every metacharacter is escaped (`\"`, `\n`, `\\`); piping it back through `jq .` parses as one object. Empty/omitted optional fields: use `// empty` at the caller or bind `--arg tool ""` (empty string) — decide one convention.

### Pattern 2: Exit-code-safe helper (process isolation — the D-05 guarantee)
**What:** The helper is a **subprocess**, so nothing it does can change the caller's exit code.
**Why this is safest (verified):** A *sourced* function that calls `exit 2` was shown to **terminate its caller with exit 2**. A subprocess cannot — the parent has no `set -e`, and a bare `bash log-event.sh …` statement's `$?` is discarded before the caller's literal `exit`.
```bash
# In each hook, at every decision point, BEFORE the literal exit:
bash "${LOG_EVENT}" PreToolUse "$tool" block "$p"   # subprocess, isolated
exit 2                                               # literal — never $?
```
Helper skeleton (guard every op, no `set -e`, end on a swallow):
```bash
#!/usr/bin/env bash
# log-event.sh — best-effort JSONL append. NEVER changes any caller's exit code (D-05).
command -v jq >/dev/null 2>&1 || exit 0
DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$(dirname "${BASH_SOURCE[0]}")/lib-protected.sh" 2>/dev/null || PROTECTED_RE='(\.env($|[./])|application-prod|secret|db/migration/)'
LOG="$DIR/logs/$(date -u +%F).jsonl"
mkdir -p "$DIR/logs" 2>/dev/null || exit 0
event="${1:-}"; tool="${2:-}"; decision="${3:-}"; target="${4:-}"; reason="${5:-}"
# mask protected substrings in target
[ -n "$target" ] && printf '%s' "$target" | grep -Eq "$PROTECTED_RE" && target='<masked>'
{ jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg event "$event" --arg tool "$tool" --arg decision "$decision" \
      --arg target "$target" --arg reason "$reason" \
      '{ts:$ts,event:$event,tool:$tool,decision:$decision}
        + (if $target!="" then {target:$target} else {} end)
        + (if $reason!="" then {reason:$reason} else {} end)' \
    >> "$LOG"; } 2>/dev/null || exit 0
exit 0
```
> `ponytail:` masking is a full-substring `grep -Eq` → replaces the whole `target` with `<masked>` when any protected token appears (coarse but safe). Fine-grained partial redaction is not worth it — a matched path shouldn't be logged at all.

### Pattern 3: Atomic append (validate the "no lock" ceiling — with a corrected rationale)
**What:** `… >> "$LOG"` opens the file with `O_APPEND`. Each hook is a *separate process* opening its own fd.
**The accurate guarantee (corrected from CONTEXT):** On Linux, O_APPEND writes to a **regular file** are serialized by the inode lock (`i_rwsem`) and the offset-seek+write is atomic — so concurrent single `write()` calls each append whole, one blocking until the other finishes. This is **stronger** than, and independent of, the PIPE_BUF number. The CONTEXT cites PIPE_BUF (4096B), which technically governs **pipes/FIFOs**, not O_APPEND regular files — but the **conclusion (no lock needed) is correct** for this use case.
**When the ceiling holds:** (1) `logs/` is on a **local** filesystem, and (2) each line is emitted in **one `write()`** — true for a short line via `jq -cn >>` or `printf '%s\n' >>`. **When it breaks:** NFS (no inode locking → not atomic), or a line large enough to be split across multiple `write()` syscalls (another writer can interleave between them). Event lines are ~100 bytes → one write(). `flock` is the Phase 5 upgrade only if logs ever move to NFS or lines grow huge.
**Verified:** two `jq -cn >>` calls produced exactly 2 lines; `tail -1 | jq .` parsed clean.

### Pattern 4: Robust project-root + daily-file resolution
```bash
DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LOG="$DIR/logs/$(date -u +%F).jsonl"     # date -u +%F -> 2026-07-07
```
`settings.json` invokes hooks with `${CLAUDE_PROJECT_DIR}` set (Phase 1), so the primary path is used in production; the `../..`-from-`.claude/hooks/` fallback makes tests and subdirectory invocations work. Daily filename via `date -u +%F` matches the `logs/*.jsonl` glob (D-01) and needs no rotation logic.

### Pattern 5: OBS-02 missing-vs-error detection in `posttool-format`
**What:** Restructure each `case` arm to distinguish (a) formatter **missing** from (b) formatter **non-zero exit**, log exactly one record per fire, and **keep the formatter's own stdout silenced**.
```bash
# Source: verified against posttool-format.sh current structure + Claude Code exit-code docs
input=$(cat)                                    # consume stdin once (jq can then use it via <<<)
f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
case "$f" in
  *.ts|*.tsx|*.js|*.jsx)
    if ! command -v pnpm >/dev/null 2>&1; then
      bash "$LOG_EVENT" PostToolUse prettier format-fail "$f" missing
    elif ! pnpm exec prettier --write "$f" >/dev/null 2>&1; then
      bash "$LOG_EVENT" PostToolUse prettier format-fail "$f" error
    else
      bash "$LOG_EVENT" PostToolUse prettier format-ok "$f"
    fi ;;
  *.java)
    if [ ! -x ./gradlew ]; then
      bash "$LOG_EVENT" PostToolUse spotless format-fail "$f" missing
    elif ! ./gradlew spotlessApply -PspotlessFiles="$f" -q >/dev/null 2>&1; then
      bash "$LOG_EVENT" PostToolUse spotless format-fail "$f" error
    else
      bash "$LOG_EVENT" PostToolUse spotless format-ok "$f"
    fi ;;
  *) bash "$LOG_EVENT" PostToolUse none format-skip "$f" ;;   # SC1: still one line per fire
esac
exit 0                                          # MUST stay 0 — see Pitfall 5
```
**`2>/dev/null` on the formatter is retained** (silences the formatter's noisy stdout/stderr per the OBS-02 note); the failure **fact** is surfaced only in the JSONL. See Pitfall 6 for the gradlew-absent noise tradeoff — a real judgment call for the planner.

### Anti-Patterns to Avoid
- **String-concatenated JSON** (`echo "{\"target\":\"$p\"}"`) — breaks on any `"`/`\`/newline; enables log forging. Always `jq -cn --arg`.
- **Sourcing the helper as a function that can `exit`** — a sourced `exit` kills the caller (verified). If a function shape is required, it must use `return` only and never `set -e`.
- **`echo` for the append** — `echo` mangles backslashes and leading `-n`/`-e`. Use `jq -cn >>` (emits its own `\n`) or `printf '%s\n'`.
- **Logging only failures in `posttool-format`** — violates SC1 "every hook fire appends exactly one line". Log ok/fail/skip. (The OBS-02 "only surface failure" note refers to the *formatter's stdout*, not the JSONL line — see Pitfall 7.)
- **Making the append the last command whose `$?` becomes the hook's exit** — always follow with a literal `exit`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON escaping (quotes, newlines, unicode, backslash) | A `sed`/`printf` escaper | `jq -cn --arg` | Escaping JSON by hand is the classic injection bug; jq does it correctly and is already present. |
| Timestamp formatting | A `printf`-assembled date string | `date -u +%Y-%m-%dT%H:%M:%SZ` | Correct ISO8601 UTC, portable GNU/BSD, already used in the repo. |
| Atomic concurrent append | A `flock`/lockfile scheme | plain `>>` (O_APPEND) | Kernel already serializes single-write() appends to a local file. `flock` is Phase-5-only, and only for NFS/huge lines. |
| Daily rotation | A size/mtime rotation loop | `logs/$(date -u +%F).jsonl` | The date in the filename *is* the rotation (D-01). Rotation/retention is Phase 5. |

**Key insight:** every "hard" part of this phase is already solved by a tool the harness depends on. The only code to write is the ~15-line glue that wires them together without breaking the exit-code invariant.

## Common Pitfalls

### Pitfall 1: Broken/forged JSON from untrusted target
**What goes wrong:** A file path like `a"b` or a Bash command containing a newline concatenated into a JSON string breaks parsing or injects a second fake line.
**Why it happens:** String interpolation instead of `jq --arg`.
**How to avoid:** `jq -cn --arg target "$target" '{…}'` — verified to escape `"`, `\`, and newline into one valid line.
**Warning signs:** any `"{...$var...}"` in the diff; `jq .` failing on a log line during tests.

### Pitfall 2: Logging changes the hook's exit code (breaks Phase 1 fail-closed, D-05)
**What goes wrong:** The guard is supposed to `exit 2` (block) but the log call, or a `set -e`, or a sourced `exit`, makes it exit 0 → the protected write goes through (fail-open regression).
**Why it happens:** Sourced helper leaking `exit`/`set -e`; or the append being the final command whose non-zero `$?` becomes the hook's exit.
**How to avoid:** Subprocess helper (isolated); helper guards every op and ends on `exit 0`; caller always follows the log call with a **literal** `exit 2`/`exit 0`. Verified: a failed append under `{ …; } 2>/dev/null || exit 0` with no `set -e` does not abort.
**Warning signs:** a test where jq is stripped or `logs/` is unwritable shows the guard's exit code flip from 2 to something else.

### Pitfall 3: jq-absent path can't (and shouldn't) log — but must still block
**What goes wrong:** `pretool-guard`'s fail-closed preamble does `command -v jq || exit 2` *before* stdin is even read. Trying to log there fails (no jq).
**Why it happens:** The log helper itself needs jq.
**How to avoid:** Accept that the two fail-closed preamble exits (jq-missing, malformed-JSON) produce **no** log line — the block still happens (exit 2 preserved), which is the security-critical behavior. Document this gap. (Optional enhancement: a *static* `printf` line — no attacker data, injection-safe — could record the jq-missing block; flag as discretion, not required.)
**Warning signs:** expecting a log entry for a jq-less block; there won't be one.

### Pitfall 4: Helper re-reading stdin (double-consume)
**What goes wrong:** If the helper did `input=$(cat)` it would hang or steal stdin the caller already consumed.
**Why it happens:** Copy-pasting the stdin pattern from other hooks.
**How to avoid:** The helper takes **arguments only** (D-04). Callers pass already-parsed values.

### Pitfall 5: `posttool-format` must NOT try to block on a format failure
**What goes wrong:** Emitting `exit 2` (or any non-zero) from `posttool-format` on a formatter error.
**Why it happens:** Assuming exit 2 = "report failure" as in the guard.
**How to avoid:** Per Claude Code docs, **PostToolUse exit 2 is non-blocking** (the tool already ran) and any non-zero exit surfaces a "hook error" notice to Claude (noise). The formatter failure is recorded **in the JSONL** and `posttool-format` stays `exit 0`. `[CITED: code.claude.com/docs/en/hooks]`
**Warning signs:** "posttool-format hook error" appearing in the transcript on every format miss.

### Pitfall 6: gradlew-absent noise (OBS-02 judgment call)
**What goes wrong:** Logging `format-fail:missing` for every `.java` edit in a repo that simply isn't Gradle-based floods the log.
**Why it happens:** `[ ! -x ./gradlew ]` treats "no build tool" identically to "formatter broken".
**How to avoid — planner decision:** Either (a) log `missing` literally per OBS-02 (formatter expected for `.java`, absent), or (b) treat gradlew-absent / pnpm-absent as "no formatter applies" → `format-skip` (no failure), reserving `format-fail` for a formatter that ran and **errored**. Recommendation: (b) reduces noise and still satisfies OBS-02's core intent (a formatter that *runs and fails* stops vanishing). Surface for re-confirmation.
**Warning signs:** logs dominated by `format-fail:missing` in a non-Java/non-Node repo.

### Pitfall 7: SC1 vs "surface only failures" contradiction
**What goes wrong:** Reading the OBS-02 note ("only surface the failure fact") as "log nothing on success" → `posttool-format` writes zero lines on a clean format → violates SC1 "every hook fire appends exactly one line".
**Why it happens:** Conflating the *formatter's stdout silencing* with the *JSONL record*.
**How to avoid:** Silence the formatter's stdout (`2>/dev/null`), but **always write one JSONL line** (`format-ok`/`format-fail`/`format-skip`). These are different channels.

### Pitfall 8: `date -u` fork alternative that isn't portable
**What goes wrong:** Swapping in `printf '%(…)T'` to avoid the fork breaks under zsh and macOS bash 3.2.
**How to avoid:** Use `date -u`. Verified `printf %()T` fails under zsh and needs bash 4.2+.

## Code Examples

### Wiring `pretool-guard.sh` (add log calls at existing exit points, single-source PROTECTED_RE)
```bash
# Source: pretool-guard.sh current structure (verified) + Pattern 2
# Near top, after the fail-closed preamble, replace the inline PROTECTED_RE definition with:
source "$(dirname "${BASH_SOURCE[0]}")/lib-protected.sh"   # single source for guard + log mask
LOG_EVENT="$(dirname "${BASH_SOURCE[0]}")/log-event.sh"
# ... Bash-write block branch:
    bash "$LOG_EVENT" PreToolUse Bash block "$cmd"; echo "[guard] ..." >&2; exit 2
# ... Bash allow:
    bash "$LOG_EVENT" PreToolUse Bash allow ""; exit 0     # target omitted: see Security finding
# ... write-tool block:
    bash "$LOG_EVENT" PreToolUse "$tool" block "$p"; echo "[guard] ..." >&2; exit 2
# ... final allow:
bash "$LOG_EVENT" PreToolUse "$tool" allow "$p"; exit 0
```

### Wiring `stop-verify.sh` (log pass/fail at existing exits; note `set -o pipefail` is safe)
```bash
# stop_hook_active loop-yield path (already exit 0): optionally log a loop-yield
bash "$LOG_EVENT" Stop verify loop-yield ""; exit 0
# fail path:
{ echo "[verify] 검증 실패 ..." >&2; bash "$LOG_EVENT" Stop verify fail ""; exit 2; }
# pass path:
bash "$LOG_EVENT" Stop verify pass ""; exit 0
```
`set -o pipefail` in stop-verify only affects pipeline exit status, not standalone commands, and never terminates — the subprocess log call is safe. The jq-absent early-exit (`exit 0`) can't log (no jq); acceptable.

### Wiring `session-handoff.sh` (log start/save; stays arg-driven, no stdin read)
```bash
case "${1:-}" in
  start) [ -f "$H" ] && { echo "..."; cat "$H"; }; bash "$LOG_EVENT" SessionStart handoff start "" ;;
  save)  { ...; } > "$H"; bash "$LOG_EVENT" PreCompact handoff save "" ;;
esac
exit 0
```
> The SessionStart `source` (startup/resume/clear/compact) and PreCompact `trigger` (manual/auto) fields are available on stdin `[CITED: code.claude.com/docs]`, but `session-handoff.sh` uses the positional arg and ignores stdin. Adding those fields is YAGNI for this phase — flag only if the planner wants richer session events.

### `.gitignore` (D-02)
```gitignore
logs/
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Format-hook errors → `2>/dev/null` (silent, C8) | Failure recorded as a JSONL `format-fail` record; formatter stdout still silenced | This phase (OBS-02) | Failures become observable without adding noise. |
| No structured event trail | One JSON line per hook fire in `logs/*.jsonl` | This phase (OBS-01) | Foundation for `/harness-audit` (Phase 4). |

**Deprecated/outdated:**
- Hand-built JSON via `echo`/`printf` string interpolation — never acceptable for untrusted input; `jq -cn --arg` supersedes it.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | BSD/macOS `date -u +%Y-%m-%dT%H:%M:%SZ` produces identical output to GNU (verified GNU locally, BSD from training) | Standard Stack | Low — format specifiers are standard strftime; worst case a differing offset representation, still valid ISO8601. |
| A2 | The harness template may run on macOS default bash 3.2, so avoid bash-4.2 `printf %()T` | Standard Stack, Pitfall 8 | Low — `date -u` is the safe default regardless; this only rules out an optimization. |
| A3 | `stop_hook_active` remains a real Stop-hook stdin field (one docs summary omitted it; Phase 1 relies on and validated it) | Code Examples (stop-verify) | Low for Phase 2 — the pass/fail log does not depend on it; only Phase 1's loop-guard does, and that already shipped. |
| A4 | Introducing `lib-protected.sh` (shared PROTECTED_RE snippet) is the preferred single-source mechanism vs. duplicating the regex | Recommended file layout, Open Q1 | Low — either choice works; affects file count, not behavior. |

## Open Questions (RESOLVED)

1. **Helper shape: subprocess script vs. sourced function.**
   - What we know: D-04 shows a `log_event <event> …` *function* call. A subprocess (`bash log-event.sh …`) gives the strongest D-05 isolation (verified a sourced `exit` kills the caller). A sourced function matches D-04's call shape and needs no `lib-protected.sh` (log-event.sh can *be* the single source of PROTECTED_RE that `pretool-guard` sources).
   - What's unclear: which the team prefers.
   - Recommendation: **subprocess script** for maximum exit-code safety (the load-bearing invariant), with `PROTECTED_RE` extracted to a one-line `lib-protected.sh` sourced by both. If the function shape is preferred, enforce: `return` only, never `exit`, never `set -e`, and call it as `log_event … || :`.
   - **RESOLVED:** Plan 02-01 chose the subprocess script + `lib-protected.sh` single-source PROTECTED_RE (sourced by both `pretool-guard.sh` and `log-event.sh`) for maximum D-05 exit-code safety.

2. **Bash command as `target` can leak inline secret *values*.** (See Security Domain.)
   - What we know: PROTECTED_RE masks protected *paths*, not tokens like `sk-…`/`ghp_…` inside a `Bash` command string. Secret-value scanning is GUARD-04 (Phase 5).
   - Recommendation: for `Bash` decisions, **do not log the raw command as `target`** (pass `""` or the first word only). This avoids logging inline secrets to even a local gitignored file, and keeps Phase 2 from hand-rolling a secret scanner. Re-confirm with planner.
   - **RESOLVED:** Plan 02-01 logs `""` as the target for Bash decisions — the raw command is never written to the JSONL (no inline-secret leak). Secret-value scanning stays GUARD-04/Phase 5.

3. **gradlew/pnpm-absent → `format-fail:missing` vs `format-skip`.** (See Pitfall 6.) Recommendation: `format-skip` for "no build tool present", reserve `format-fail` for a formatter that ran and errored.
   - **RESOLVED:** CONTEXT §OBS-02 (locked decision) overrides this recommendation — a recognized extension (`.java`/`.ts…`) whose formatter tool is absent is `format-fail` with `reason:missing`; a formatter that ran non-zero is `format-fail` with `reason:error`; only UNrecognized extensions get `format-skip`. Plan 02-02 implements this three-way split.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `jq` | JSON construction + append | ✓ | 1.8.1 | none — if absent, helper no-ops (best-effort); guard still fail-closes |
| `date` (coreutils/BSD) | ISO8601 UTC timestamp | ✓ | GNU coreutils | none needed; portable |
| `bash` | hook runtime | ✓ | 5.3.9 (target ≥3.2) | none |
| `mkdir`, `printf`, `grep`, `dirname` | dir creation, append, masking | ✓ | coreutils | none |

**Missing dependencies with no fallback:** none — everything required is present.
**Note:** the template ships to *other* machines. On a box without `jq`, the helper silently no-ops (no log) and the guard still fail-closes — the observability layer degrades gracefully, the security layer does not weaken.

## Security Domain

> `security_enforcement` not disabled in config → included. Scoped to the real threats of a logging feature.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation / Output Encoding | **yes** | `jq -cn --arg` for all JSON encoding — untrusted paths/commands are escaped, never concatenated. This is the primary control. |
| V7 Error Handling & Logging | **yes** | Best-effort logging that never alters control flow (D-05); no secrets/PII in log content (masking + not logging Bash command values). |
| V6 Cryptography | no | No crypto in scope. |
| V2/V3/V4 Auth/Session/Access | no | Local hook tooling, no auth surface. |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Log injection / forged line via crafted file path or command (newline/quote) | Tampering / Repudiation | `jq -cn --arg` — verified to neutralize `"`, `\`, newline into one line. |
| **Secret value leakage** — `sk-…`/`ghp_…`/password inside a `Bash` command logged as `target` (PROTECTED_RE path-masking does NOT catch it) | Information Disclosure | **Do not log the raw Bash command as `target`** (Open Q2). Full secret-value scanning is GUARD-04 / Phase 5. This is the one real security gap of the naive design. |
| PII/secret path in `target` (`.env`, `secret`, prod config) | Information Disclosure | Mask via single-source PROTECTED_RE → `<masked>`. |
| Log write fails silently and masks a real block | Repudiation | Best-effort logging by design; the *security decision* (exit 2) is independent of and unaffected by logging (D-05). |

## Project Constraints (from CLAUDE.md / AGENTS.md)

- **Exit-code invariant:** block = `exit 2`, allow = `exit 0`; `exit 1` is treated as non-blocking. Logging must never change these (D-05). `[CITED: HARNESS-TEMPLATE-MANUAL.md §2.2]`
- **Zero new runtime deps:** Bash + jq + coreutils only (SC3). No new tools.
- **No secrets/PII in logs:** `security.md` §PII — mask; do not over-log.
- **Single-source patterns:** reuse PROTECTED_RE (Phase 1), do not redefine (D-04).
- **Surgical changes:** touch only the 4 hooks + new helper + `.gitignore`; do not refactor unrelated code.
- **Git:** no direct push to `main`; commit/PR only when explicitly asked; Conventional Commits in English.
- **Language:** code/comments/logs in English; user-facing replies in Korean.

## Sources

### Primary (HIGH confidence)
- Local empirical verification (jq 1.8.1, bash 5.3.9, 2026-07-07): `jq -cn --arg` compact single-line output + injection escaping; `>>` append line-count & `jq .` parse; sourced-`exit`-kills-caller proof; fail-safe append under no-`set -e`; `printf %()T` bash-only/zsh-fails; `date -u` output.
- [code.claude.com/docs/en/hooks] — hook stdin JSON fields per event (PreToolUse/PostToolUse/Stop/SessionStart/PreCompact) and exit-code semantics (exit 2 blocks PreToolUse but is non-blocking for PostToolUse).
- Existing code (verified by reading): `pretool-guard.sh` (PROTECTED_RE, exit points), `posttool-format.sh` (case block, `2>/dev/null`), `stop-verify.sh` (`set -o pipefail`, exits), `session-handoff.sh` (arg-driven), `settings.json` (hook registration, `${CLAUDE_PROJECT_DIR}`).

### Secondary (MEDIUM confidence)
- O_APPEND regular-file atomicity on Linux (inode-serialized, stronger than PIPE_BUF; NFS excluded): linux-fsdevel discussion, notthewizard.com "Are File Appends Really Atomic?", nullprogram.com "Appending to a File from Multiple Processes". Corrects the CONTEXT's PIPE_BUF framing while confirming the "no lock" conclusion.
- jq manual — `--arg`/`--argjson`/`-c`/`-n` semantics (corroborated by local test).

### Tertiary (LOW confidence)
- BSD/macOS `date -u` output identical to GNU (A1) — training knowledge, not re-verified on BSD this session.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools present and version-verified; no packages to install.
- Architecture (jq construction, subprocess isolation, atomic append): HIGH — each pattern empirically reproduced locally.
- Pitfalls: HIGH — the exit-code and injection pitfalls were demonstrated, not asserted; OBS-02 exit-code behavior cited from official docs.
- Security (secret-value leakage gap): MEDIUM — real gap identified with a concrete mitigation; final policy is a planner decision (Open Q2).

**Research date:** 2026-07-07
**Valid until:** ~2026-08-07 (stable domain — Bash/jq/POSIX; the only volatile input is Claude Code's hook stdin schema, re-check if Claude Code is upgraded).
