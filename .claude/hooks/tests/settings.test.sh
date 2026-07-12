#!/usr/bin/env bash
# jq/grep assertions for settings.json wiring:
# GUARD-02 (matcher), GATE-02 (Stop timeout > 600), CFG-02 (${CLAUDE_PROJECT_DIR} ×5),
# CFG-04 ($schema), plus SC#4 subdirectory resolution of the guard.
root=$(cd "$(dirname "$0")/../../.." && pwd)
S="$root/.claude/settings.json"
fail=0
pass=0
ok() { echo "PASS: $1"; pass=$((pass + 1)); }
no() { echo "FAIL: $1"; fail=$((fail + 1)); }

jq . "$S" >/dev/null 2>&1 && ok "settings.json parses" || no "settings.json parses"

jq -e '."$schema"' "$S" >/dev/null 2>&1 && ok '$schema present (CFG-04)' || no '$schema present (CFG-04)'

[ "$(jq -r '.hooks.PreToolUse[0].matcher' "$S")" = "Write|Edit|MultiEdit|NotebookEdit|Bash" ] \
  && ok "PreToolUse matcher covers write tools + Bash (GUARD-02)" \
  || no "PreToolUse matcher (GUARD-02)"

jq -e '.hooks.Stop[0].hooks[0].timeout > 600' "$S" >/dev/null 2>&1 \
  && ok "Stop timeout > 600 (GATE-02)" || no "Stop timeout > 600 (GATE-02)"

[ "$(grep -o 'CLAUDE_PROJECT_DIR' "$S" | wc -l | tr -d ' ')" = "6" ] \
  && ok "6x CLAUDE_PROJECT_DIR across hook commands (CFG-02)" \
  || no "6x CLAUDE_PROJECT_DIR (CFG-02)"

[ "$(jq -r '.hooks.SessionEnd[0].hooks[0].command' "$S")" = "bash \${CLAUDE_PROJECT_DIR}/.claude/hooks/session-handoff.sh save SessionEnd" ] \
  && ok "SessionEnd registered -> session-handoff.sh save SessionEnd (STATE-02/D-09)" \
  || no "SessionEnd registration (STATE-02/D-09)"

# LSP + plugins declared: marketplaces + enabledPlugins (vtsls, jdtls, ponytail, frontend-design).
jq -e '.extraKnownMarketplaces["claude-code-lsps"] and .extraKnownMarketplaces["ponytail"] and .extraKnownMarketplaces["claude-code-plugins"]' "$S" >/dev/null 2>&1 \
  && ok "LSP/ponytail/plugins marketplaces declared" || no "extraKnownMarketplaces (LSP/ponytail/plugins)"
jq -e '.enabledPlugins["vtsls@claude-code-lsps"] and .enabledPlugins["jdtls@claude-code-lsps"] and .enabledPlugins["ponytail@ponytail"] and .enabledPlugins["frontend-design@claude-code-plugins"]' "$S" >/dev/null 2>&1 \
  && ok "vtsls + jdtls + ponytail + frontend-design plugins enabled" || no "enabledPlugins (vtsls/jdtls/ponytail/frontend-design)"

# SC#4: from a non-root cwd, the ${CLAUDE_PROJECT_DIR}-resolved guard still blocks a protected write.
sub=$(mktemp -d)
( cd "$sub" && CLAUDE_PROJECT_DIR="$root" bash -c \
  'printf "%s" "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"x/.env.production\"}}" | bash "$CLAUDE_PROJECT_DIR/.claude/hooks/pretool-guard.sh"' ) >/dev/null 2>&1
sc=$?
rm -rf "$sub"
[ "$sc" -eq 2 ] && ok "subdir \${CLAUDE_PROJECT_DIR} guard fires -> exit 2 (SC#4)" \
  || no "subdir resolution (expected 2, got $sc)"

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
