#!/usr/bin/env bash
# Single-source protected-path pattern (D-04). Sourced by pretool-guard.sh and
# log-event.sh so the regex has exactly ONE definition — do not redefine it
# anywhere else. Pure data: no shebang logic, no side effects.
# Matches `.env` only when followed by end/`.`/`/` so `src/environment.ts` is
# not a false positive.
PROTECTED_RE='(\.env($|[./])|application-prod|secret|db/migration/)'

# Single-source hardcoded-secret CONTENT pattern (GUARD-04). Sourced by
# pretool-guard.sh to scan write content. Length-anchored so ordinary prose or a
# bare `sk-` word does not false-positive. One definition — do not redefine.
SECRETS_RE='(AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{36,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.)'

# Single-source dangerous-command patterns (GUARD-05). Sourced by
# pretool-guard.sh to block Bash commands safety.md/AGENTS.md forbid outright.
# Command-position anchored — a commit message or grep that merely mentions a
# flag must not match (same best-effort ceiling as GUARD-03).
# DANGER_RE: forbidden git ops, docker volume wipe, forced npm audit fix.
DANGER_RE='(^|[;&|][[:space:]]*)(git[[:space:]]+push[[:space:]]+([^|;&]*[[:space:]])?(--force(-with-lease)?|-f)([[:space:]]|$)|git[[:space:]]+reset[[:space:]][^|;&]*--hard|git[[:space:]]+commit[[:space:]][^|;&]*--no-verify|git[[:space:]]+filter-(branch|repo)|docker([[:space:]]+compose|-compose)[[:space:]]+down[^|;&]*[[:space:]](-v|--volumes)|npm[[:space:]]+audit[[:space:]]+fix[^|;&]*--force)'
# DANGER_PIPE_RE: remote script piped straight into a shell (injection vector).
DANGER_PIPE_RE='(^|[;&|][[:space:]]*)(curl|wget)[[:space:]][^|;&]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da)?sh([[:space:]]|$)'
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
    [ -n "$_rx" ] && PROTECTED_RE="$PROTECTED_RE|$_rx"
  done < "$_lib_dir/protected-extra.regex"
fi
if [ -f "$_lib_dir/secrets-extra.regex" ]; then
  while IFS= read -r _rx; do
    [ -n "$_rx" ] && SECRETS_RE="$SECRETS_RE|$_rx"
  done < "$_lib_dir/secrets-extra.regex"
fi
unset _lib_dir _rx
