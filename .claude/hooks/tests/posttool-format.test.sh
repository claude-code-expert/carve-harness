#!/usr/bin/env bash
# Assertions for posttool-format.sh (OBS-02, C8): every fire records exactly one
# outcome (format-ok / format-fail / format-skip) in the JSONL, the hook stays
# exit 0 (PostToolUse exit 2 is non-blocking), and the formatter's own stdout
# stays silenced. "Formatter absent" is simulated with a gradlew-less temp CWD;
# format-ok / format-fail:error use a stub ./gradlew — no PATH surgery.

HOOK="$(cd "$(dirname "$0")/.." && pwd)/posttool-format.sh"
fail=0; pass=0
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }
daily() { printf '%s/logs/%s.jsonl' "$1" "$(date -u +%F)"; }
lines() { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }

# fire <cwd> <logdir> <json>  (exit code = the hook's)
fire() { ( cd "$1" && printf '%s' "$3" | CLAUDE_PROJECT_DIR="$2" bash "$HOOK" >/dev/null 2>&1 ); }

# (1) recognized ext + formatter ABSENT -> format-fail:missing, exit 0, delta==1.
cwd=$(mktemp -d); logd=$(mktemp -d); L="$(daily "$logd")"
before=$(lines "$L")
fire "$cwd" "$logd" '{"tool_input":{"file_path":"Foo.java"}}'; code=$?
after=$(lines "$L")
if [ "$code" -eq 0 ] && [ "$((after - before))" -eq 1 ] \
   && [ "$(tail -1 "$L" | jq -r '.decision')" = "format-fail" ] \
   && [ "$(tail -1 "$L" | jq -r '.reason')" = "missing" ] \
   && [ "$(tail -1 "$L" | jq -r '.target')" = "Foo.java" ]; then
  ok "format-fail:missing (no gradlew) + exit 0 + delta==1"
else
  bad "format-fail:missing"
fi
rm -rf "$cwd" "$logd"

# (2) unrecognized ext -> format-skip, exit 0, delta==1.
cwd=$(mktemp -d); logd=$(mktemp -d); L="$(daily "$logd")"
before=$(lines "$L")
fire "$cwd" "$logd" '{"tool_input":{"file_path":"README.md"}}'; code=$?
after=$(lines "$L")
if [ "$code" -eq 0 ] && [ "$((after - before))" -eq 1 ] \
   && [ "$(tail -1 "$L" | jq -r '.decision')" = "format-skip" ]; then
  ok "format-skip (unrecognized ext) + exit 0 + delta==1"
else
  bad "format-skip"
fi
rm -rf "$cwd" "$logd"

# (3) recognized ext + stub gradlew exit 0 -> format-ok.
cwd=$(mktemp -d); logd=$(mktemp -d); L="$(daily "$logd")"
printf '#!/usr/bin/env bash\nexit 0\n' > "$cwd/gradlew"; chmod +x "$cwd/gradlew"
before=$(lines "$L")
fire "$cwd" "$logd" '{"tool_input":{"file_path":"Foo.java"}}'; code=$?
after=$(lines "$L")
if [ "$code" -eq 0 ] && [ "$((after - before))" -eq 1 ] \
   && [ "$(tail -1 "$L" | jq -r '.decision')" = "format-ok" ] \
   && [ "$(tail -1 "$L" | jq -r '.target')" = "Foo.java" ]; then
  ok "format-ok (stub gradlew exit 0)"
else
  bad "format-ok"
fi
rm -rf "$cwd" "$logd"

# (4) recognized ext + stub gradlew exit 1 -> format-fail:error.
cwd=$(mktemp -d); logd=$(mktemp -d); L="$(daily "$logd")"
printf '#!/usr/bin/env bash\nexit 1\n' > "$cwd/gradlew"; chmod +x "$cwd/gradlew"
before=$(lines "$L")
fire "$cwd" "$logd" '{"tool_input":{"file_path":"Foo.java"}}'; code=$?
after=$(lines "$L")
if [ "$code" -eq 0 ] && [ "$((after - before))" -eq 1 ] \
   && [ "$(tail -1 "$L" | jq -r '.decision')" = "format-fail" ] \
   && [ "$(tail -1 "$L" | jq -r '.reason')" = "error" ]; then
  ok "format-fail:error (stub gradlew exit 1)"
else
  bad "format-fail:error"
fi
rm -rf "$cwd" "$logd"

# (5) behavioral: formatter chatter must not reach the hook's own stdout/stderr.
# This used to be `grep -q '2>/dev/null' "$HOOK"` — a file-wide grep that the jq
# line satisfied on its own, so it stayed green while the formatter invocations
# leaked stdout for real. Assert the observable behavior, never the source text.
cwd=$(mktemp -d); logd=$(mktemp -d)
printf '#!/usr/bin/env bash\necho NOISE_OUT\necho NOISE_ERR >&2\nexit 0\n' > "$cwd/gradlew"
chmod +x "$cwd/gradlew"
leak=$( ( cd "$cwd" && printf '%s' '{"tool_input":{"file_path":"Foo.java"}}' \
          | CLAUDE_PROJECT_DIR="$logd" bash "$HOOK" ) 2>&1 )
printf '%s' "$leak" | grep -q 'NOISE_' \
  && bad "formatter output leaked into the hook stream: $leak" \
  || ok "formatter stdout+stderr silenced (behavioral)"
rm -rf "$cwd" "$logd"

# (6) source guards: no exit 2; bash -n clean.
grep -q 'exit 2' "$HOOK" && bad "unexpected exit 2 present (must stay non-blocking)" || ok "no exit 2 (PostToolUse non-blocking)"
bash -n "$HOOK" 2>/dev/null && ok "bash -n clean" || bad "bash -n"

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
