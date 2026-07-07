#!/usr/bin/env bash
# Single-source protected-path pattern (D-04). Sourced by pretool-guard.sh and
# log-event.sh so the regex has exactly ONE definition — do not redefine it
# anywhere else. Pure data: no shebang logic, no side effects.
# Matches `.env` only when followed by end/`.`/`/` so `src/environment.ts` is
# not a false positive.
PROTECTED_RE='(\.env($|[./])|application-prod|secret|db/migration/)'
