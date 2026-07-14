#!/usr/bin/env bash
# caveman — SessionStart activation (harness-vendored, no node dependency)
#
# Emits the caveman ruleset as SessionStart context and writes a flag file the
# statusline can read. Mirrors ponytail's activation but stays in bash: the
# caveman source we vendor is a single SKILL.md, so there is nothing to compile.
#
# Default level: CAVEMAN_DEFAULT_MODE env (lite|full|ultra|off), else full.
# "off" skips activation entirely. Turn off mid-session with "stop caveman".
set -euo pipefail

MODE="${CAVEMAN_DEFAULT_MODE:-full}"
[ "$MODE" = "off" ] && exit 0

SKILL="${CLAUDE_PROJECT_DIR:-.}/vendor/caveman/skills/caveman/SKILL.md"
[ -f "$SKILL" ] || exit 0

FLAG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.caveman-active"
mkdir -p "$(dirname "$FLAG")" 2>/dev/null || true
printf '%s' "$MODE" > "$FLAG" 2>/dev/null || true

echo "CAVEMAN MODE ACTIVE — level: $MODE"
echo
# Strip YAML frontmatter, emit the ruleset body verbatim (all levels described;
# the banner above names the active one). ponytail: no per-level filtering —
# body is small, model reads the active level off the banner.
awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{f=0;next} !f' "$SKILL"
