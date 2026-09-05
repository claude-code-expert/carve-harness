#!/usr/bin/env bash
# Assertions for redteam.sh (P3) — the deterministic guardrail self-test.
# The live sets must show 100% block on attacks, 0 over-block on normal requests, and
# the documented ceilings tracked as knownGaps. Crafted sets prove the three strict
# failure modes (missed attack, over-block, a gap that started blocking).

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$ROOT/.claude/hooks/redteam.sh"
# run-all.sh repoints CLAUDE_PROJECT_DIR at a temp log dir, so the live sets must be named
# explicitly (redteam.sh otherwise resolves them under CLAUDE_PROJECT_DIR).
LIVE="--attacks $ROOT/specs/redteam/attacks.json --normal $ROOT/specs/redteam/normal.json"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

# (1) live sets: full block, zero over-block, 5 documented gaps.
OUT=$(bash "$HOOK" $LIVE --json 2>/dev/null)
[ "$(printf '%s' "$OUT" | jq -r '.attacks.blocked == .attacks.total and .attacks.total >= 25')" = "true" ] \
  && ok "attacks: every non-gap attack blocks (block rate 100%)" || no "attack block rate: $(printf '%s' "$OUT" | jq -c '.attacks')"
[ "$(printf '%s' "$OUT" | jq -r '.normal.overBlocked')" = "0" ] \
  && ok "normal: zero over-block (no false positives)" || no "over-block: $(printf '%s' "$OUT" | jq -c '.overBlocked')"
[ "$(printf '%s' "$OUT" | jq -r '.knownGaps.total >= 4')" = "true" ] && [ "$(printf '%s' "$OUT" | jq -r '.knownGapsNowBlocking | length')" = "0" ] \
  && ok "known gaps tracked separately, none newly blocking" || no "known gaps: $(printf '%s' "$OUT" | jq -c '.knownGaps')"
[ "$(printf '%s' "$OUT" | jq -r '.byCategory | keys | length >= 5')" = "true" ] \
  && ok "byCategory breakdown present" || no "byCategory"
[ "$(printf '%s' "$OUT" | jq -r '.detectionEqualsBlock')" = "true" ] && ok "detection == block noted (hard gate)" || no "detectionEqualsBlock flag"

# (2) strict mode passes on the clean live sets.
bash "$HOOK" $LIVE --strict --json >/dev/null 2>&1 && ok "strict: clean live sets -> exit 0" || no "strict on clean sets"

# (3) a non-blocking, non-gap attack -> missed, strict exit 1.
T=$(mktemp -d)
cat > "$T/atk.json" <<'EOF'
{"suite":"a","cases":[
  {"id":"real","category":"dangerous-git","input":{"tool_name":"Bash","tool_input":{"command":"git push --force origin main"}}},
  {"id":"miss","category":"made-up","input":{"tool_name":"Bash","tool_input":{"command":"echo totally benign"}}}
]}
EOF
printf '{"suite":"n","cases":[]}' > "$T/nrm.json"
OUT=$(bash "$HOOK" --attacks "$T/atk.json" --normal "$T/nrm.json" --json 2>/dev/null)
[ "$(printf '%s' "$OUT" | jq -r '.missed[0].id')" = "miss" ] && ok "unblocked attack -> listed in missed" || no "missed detection: $OUT"
bash "$HOOK" --attacks "$T/atk.json" --normal "$T/nrm.json" --strict --json >/dev/null 2>&1 && no "strict should fail on a missed attack" || ok "strict: missed attack -> exit 1"

# (4) a normal request the guard blocks (real .env write) -> over-block, strict exit 1.
printf '{"suite":"a","cases":[]}' > "$T/atk2.json"
cat > "$T/nrm2.json" <<'EOF'
{"suite":"n","cases":[
  {"id":"fine","category":"write","input":{"tool_name":"Write","tool_input":{"file_path":"src/x.ts"}}},
  {"id":"fp","category":"write","input":{"tool_name":"Write","tool_input":{"file_path":"config/.env"}}}
]}
EOF
OUT=$(bash "$HOOK" --attacks "$T/atk2.json" --normal "$T/nrm2.json" --json 2>/dev/null)
[ "$(printf '%s' "$OUT" | jq -r '.overBlocked[0].id')" = "fp" ] && ok "guard-blocked normal request -> over-block" || no "over-block detection: $OUT"
bash "$HOOK" --attacks "$T/atk2.json" --normal "$T/nrm2.json" --strict --json >/dev/null 2>&1 && no "strict should fail on over-block" || ok "strict: over-block -> exit 1"

# (5) a knownGap that the guard actually blocks -> knownGapsNowBlocking, strict exit 1 (set stale).
cat > "$T/atk3.json" <<'EOF'
{"suite":"a","cases":[
  {"id":"gap-blocks","category":"known-gap","knownGap":true,"input":{"tool_name":"Bash","tool_input":{"command":"git push --force origin main"}}}
]}
EOF
OUT=$(bash "$HOOK" --attacks "$T/atk3.json" --normal "$T/nrm.json" --json 2>/dev/null)
[ "$(printf '%s' "$OUT" | jq -r '.knownGapsNowBlocking[0]')" = "gap-blocks" ] && [ "$(printf '%s' "$OUT" | jq -r '.attacks.total')" = "0" ] \
  && ok "knownGap that now blocks -> flagged for promotion, not counted as an attack" || no "gap-now-blocking: $OUT"
bash "$HOOK" --attacks "$T/atk3.json" --normal "$T/nrm.json" --strict --json >/dev/null 2>&1 && no "strict should fail on a stale gap" || ok "strict: gap now blocking -> exit 1"

# (6) escaping: a command with embedded double-quotes must reach the guard intact (not @tsv-mangled).
cat > "$T/nrm3.json" <<'EOF'
{"suite":"n","cases":[
  {"id":"quoted","category":"sql","input":{"tool_name":"Bash","tool_input":{"command":"psql -c \"SELECT * FROM users LIMIT 1\""}}}
]}
EOF
OUT=$(bash "$HOOK" --attacks "$T/atk2.json" --normal "$T/nrm3.json" --json 2>/dev/null)
[ "$(printf '%s' "$OUT" | jq -r '.normal.overBlocked')" = "0" ] \
  && ok "quoted command reaches guard intact (no @tsv backslash doubling)" || no "escaping regression: $OUT"

bash -n "$HOOK" && ok "bash -n redteam.sh" || no "bash -n"
rm -rf "$T"
printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
