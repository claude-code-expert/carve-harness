#!/usr/bin/env bash
# Single-source protected-path pattern (D-04). Sourced by pretool-guard.sh and
# log-event.sh so the regex has exactly ONE definition — do not redefine it
# anywhere else. Pure data: no shebang logic, no side effects.
# Matches `.env` only when followed by end/`.`/`/` so `src/environment.ts` is
# not a false positive.
PROTECTED_RE='(\.env($|[./])|application-prod|secret|db/migration/)'

# GUARD-07 self-protection: the gates themselves. Without it an agent can write
# `exit 0` into a hook or empty settings.json and the whole harness goes inert —
# a gate that cannot protect itself is not a gate.
# Active only in an INSTALLED harness (`.claude/harness-manifest.txt`, written by
# install.sh). The source repo has no manifest, so harness development can still
# edit its own hooks. The manifest is protected too — deleting it to unlock the
# gates is itself blocked, and it is what update/uninstall trust.
# NOTE: every append must keep the whole pattern inside ONE group — callers embed
# it as `...${PROTECTED_RE}` in a larger regex, so a top-level `|` would leak out
# and match the bare path anywhere in the command.
if [ -f "$(dirname "${BASH_SOURCE[0]}")/../harness-manifest.txt" ]; then
  PROTECTED_RE="(${PROTECTED_RE}|\.claude/(hooks/|settings\.json|harness-manifest\.txt))"
fi
PROTECTED_RE="(${PROTECTED_RE}|specs/\.checklist-active)"

# Single-source hardcoded-secret CONTENT pattern (GUARD-04). Sourced by
# pretool-guard.sh to scan write content. Length-anchored so ordinary prose or a
# bare `sk-` word does not false-positive. One definition — do not redefine.
SECRETS_RE='(AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{36,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.)'

# Single-source dangerous-command patterns (GUARD-05). Sourced by
# pretool-guard.sh to block Bash commands safety.md/AGENTS.md forbid outright.
# Command-position anchored — a commit message or grep that merely mentions a
# flag must not match (same best-effort ceiling as GUARD-03).
# CMD_PFX: launcher words that prefix a command without changing what it runs
# (`env git push --force`, `sudo rm -rf /`, `FOO=1 git push -f`). Without it every
# danger pattern below is one word away from a bypass.
CMD_PFX='(((env|sudo|nohup|time|command|builtin|exec)[[:space:]]+)|([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+))*'
# DANGER_RM_RE + DANGER_RM_TARGET_RE: recursive delete aimed at a critical target
# (safety.md — "rm -rf on the project root or critical directories"). Flags match
# in any spelling (`-rf`, `-r -f`, `--recursive`) so a split flag is not a bypass.
# BOTH must match to block, so `rm -rf ./build` or `rm -rf "$TMP"` stays allowed.
DANGER_RM_RE='(^|[;&|][[:space:]]*)'"$CMD_PFX"'rm[[:space:]]+([^|;&]*[[:space:]])?(-[a-zA-Z]*[rR]|--recursive)'
DANGER_RM_TARGET_RE='[[:space:]](/|\.|\.\.|~|/\*|\./\*|\$HOME|\$\{HOME\}|\$PWD|\$\{PWD\}|\$CLAUDE_PROJECT_DIR)([[:space:]]|$)'
# DANGER_RE: forbidden git ops, docker volume wipe, forced npm audit fix.
DANGER_RE='(^|[;&|][[:space:]]*)'"$CMD_PFX"'(git[[:space:]]+push[[:space:]]+([^|;&]*[[:space:]])?(--force(-with-lease)?|-f)([[:space:]]|$)|git[[:space:]]+reset[[:space:]][^|;&]*--hard|git[[:space:]]+commit[[:space:]][^|;&]*--no-verify|git[[:space:]]+filter-(branch|repo)|docker([[:space:]]+compose|-compose)[[:space:]]+down[^|;&]*[[:space:]](-v|--volumes)|npm[[:space:]]+audit[[:space:]]+fix[^|;&]*--force)'
# DANGER_PIPE_RE: remote script piped straight into a shell (injection vector).
DANGER_PIPE_RE='(^|[;&|][[:space:]]*)'"$CMD_PFX"'(curl|wget)[[:space:]][^|;&]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da)?sh([[:space:]]|$)'
# DANGER_SQL_RE + DANGER_SQL_KW_RE: destructive SQL only when a DB client runs it
# (echo/grep mentioning DROP stays allowed). Keyword match is case-insensitive.
DANGER_SQL_RE='(^|[;&|][[:space:]]*)(psql|mysql|mariadb|sqlite3)[[:space:]]'
DANGER_SQL_KW_RE='(DROP[[:space:]]+(TABLE|DATABASE|SCHEMA)|TRUNCATE[[:space:]])'

# Project-specific extensions (optional): one ERE per line, OR-appended.
# Written by `install.sh setup` (or by hand). These files are NOT shipped in the
# manifest, so update-mode overlay copies preserve them — customization survives
# harness updates without merging.
_lib_dir="$(dirname "${BASH_SOURCE[0]}")"
if [ -f "$_lib_dir/protected-extra.regex" ]; then
  while IFS= read -r _rx; do
    [ -n "$_rx" ] && PROTECTED_RE="(${PROTECTED_RE}|$_rx)"
  done < "$_lib_dir/protected-extra.regex"
fi
if [ -f "$_lib_dir/secrets-extra.regex" ]; then
  while IFS= read -r _rx; do
    [ -n "$_rx" ] && SECRETS_RE="(${SECRETS_RE}|$_rx)"
  done < "$_lib_dir/secrets-extra.regex"
fi
unset _lib_dir _rx
