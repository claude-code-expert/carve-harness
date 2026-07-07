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
