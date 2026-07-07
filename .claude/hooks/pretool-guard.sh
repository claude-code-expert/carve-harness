#!/usr/bin/env bash
# PreToolUse: block edits to protected files/commands (block MUST be exit 2, allow exit 0).
# Fail-closed: when jq is missing or JSON is malformed, the write paths block unconditionally
# (D-01, GUARD-01). Stderr messages stay Korean to match the existing [guard] convention.

# (1) FAIL-CLOSED PREAMBLE with cause-specific messages (D-03).
# jq present-check runs BEFORE reading stdin (cat), so a missing jq blocks here immediately.
if ! command -v jq >/dev/null 2>&1; then
  echo "[guard] jq 미설치 → fail-closed 차단 (jq 설치 후 재시도)" >&2
  exit 2
fi
input=$(cat)
if ! printf '%s' "$input" | jq empty >/dev/null 2>&1; then
  echo "[guard] JSON 파싱 실패 → fail-closed 차단" >&2
  exit 2
fi

# (2) SINGLE-SOURCE protected-path pattern. Replicates the prior glob
# (*.env|*.env.*|*application-prod*|*secret*|*db/migration/*) but matches `.env` only when
# followed by end/`.`/`/` so `src/environment.ts` is not a false positive. Both branches
# (file and Bash) consume this ONE variable — no second definition, no drift.
PROTECTED_RE='(\.env($|[./])|application-prod|secret|db/migration/)'

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')

# (3a) Bash: block only when a WRITE OPERATOR targets a protected path (GUARD-03).
# Never a bare substring match — a read that merely mentions a protected keyword (grep,
# git log, git commit -m) or an fd redirect (2>/dev/null) is allowed. Pipe/variable/heredoc
# indirection is a documented ceiling (CONTEXT Claude's-Discretion; STATE C4) — best-effort.
if [ "$tool" = "Bash" ]; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
  if printf '%s' "$cmd" | grep -Eq "(>>?|(^|[[:space:]])tee[[:space:]])[[:space:]]*['\"]?[^[:space:]|;&<>]*${PROTECTED_RE}" \
    || printf '%s' "$cmd" | grep -Eq "(sed|perl)[[:space:]]+-i[^|;&]*${PROTECTED_RE}" \
    || printf '%s' "$cmd" | grep -Eq "(^|[;&|][[:space:]]*)(cp|mv|install)[[:space:]][^|;&]*${PROTECTED_RE}"; then
    echo "[guard] Bash 쓰기 차단(보호 경로): $cmd" >&2
    exit 2
  fi
  # The command string is treated as opaque data — never eval / sh -c.
  exit 0
fi

# (3b) Write tools (Write/Edit/MultiEdit/NotebookEdit): read file_path OR notebook_path.
# NotebookEdit uses notebook_path, so BOTH keys must be read (GUARD-02, Pitfall 2).
p=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
if printf '%s' "$p" | grep -Eq "$PROTECTED_RE"; then
  echo "[guard] 보호 파일 수정 차단: $p" >&2
  exit 2
fi

exit 0
