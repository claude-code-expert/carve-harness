#!/usr/bin/env bash
# test-hooks.sh — 훅 단위 테스트. stdin에 JSON 주입 → exit code 단언.
#   2 = 차단(PreToolUse), 0 = 허용/비차단.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$ROOT/assets/hooks"
PASS=0; FAIL=0
ok(){ printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
no(){ printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

# expect <name> <expected-exit> <json> <hook.sh> [ENV=val ...]
expect(){
  local name="$1" exp="$2" json="$3" hook="$4"; shift 4
  local got
  echo "$json" | env "$@" bash "$H/$hook" >/dev/null 2>&1; got=$?
  if [ "$got" = "$exp" ]; then ok "$name (exit $got)"; else no "$name (exit $got, 기대 $exp)"; fi
}

echo "== block-destructive (위험=2 / 안전=0) =="
expect "rm -rf / 차단"              2 '{"tool_input":{"command":"rm -rf /"}}'                  block-destructive.sh
expect "포크밤 차단"                2 '{"tool_input":{"command":":(){ :|:& };:"}}'             block-destructive.sh
expect "git push --force main 차단" 2 '{"tool_input":{"command":"git push --force origin main"}}' block-destructive.sh
expect "ls 허용"                    0 '{"tool_input":{"command":"ls -la"}}'                     block-destructive.sh
expect "rm -rf ./build 허용"        0 '{"tool_input":{"command":"rm -rf ./build"}}'            block-destructive.sh

echo "== protect-secrets =="
expect ".env 차단"            2 '{"tool_input":{"file_path":".env"}}'                 protect-secrets.sh
expect "credentials.json 차단" 2 '{"tool_input":{"file_path":"app/credentials.json"}}' protect-secrets.sh
expect ".env.example 허용"    0 '{"tool_input":{"file_path":".env.example"}}'         protect-secrets.sh
expect "src/index.ts 허용"    0 '{"tool_input":{"file_path":"src/index.ts"}}'         protect-secrets.sh

echo "== pre-commit-lint / pre-push-test (실패=2) =="
expect "commit+lint실패 차단" 2 '{"tool_input":{"command":"git commit -m x"}}' pre-commit-lint.sh CARVE_LINT_CMD=false
expect "commit+lint성공 통과" 0 '{"tool_input":{"command":"git commit -m x"}}' pre-commit-lint.sh CARVE_LINT_CMD=true
expect "비-commit 통과"       0 '{"tool_input":{"command":"ls"}}'              pre-commit-lint.sh
expect "push+test실패 차단"   2 '{"tool_input":{"command":"git push origin x"}}' pre-push-test.sh CARVE_TEST_CMD=false

echo "== 비차단 훅 (항상 0) =="
expect "auto-format 비차단" 0 '{"tool_input":{"file_path":"a.ts"}}' auto-format.sh CARVE_FORMAT_CMD=true
expect "slack-notify(웹훅 없음) 통과" 0 '{}' slack-notify.sh
TMP="$(mktemp -d)"
expect "precompact-handoff 통과" 0 '{}' precompact-handoff.sh CLAUDE_PROJECT_DIR="$TMP"
rm -rf "$TMP"

echo "== bash 문법 =="
for f in "$H"/*.sh; do bash -n "$f" && ok "bash -n $(basename "$f")" || no "bash -n $(basename "$f")"; done

echo ""; echo "결과: $PASS PASS / $FAIL FAIL"; [ "$FAIL" -eq 0 ]
