#!/usr/bin/env bash
# Assertions for conformance-gate.sh: active-only gate semantics (contract §8),
# fail-closed on malformed/empty, loop guard (GATE-01), and jq-absent best-effort.
# jq-absence simulated via env -i PATH= + absolute bash — never uninstalls jq.

HOOK="$(cd "$(dirname "$0")/.." && pwd)/conformance-gate.sh"
BASH_BIN="$(command -v bash)"
fail=0
pass=0

# Build a throwaway project with one specs/<slug>/SCORE.json of the given body.
mk() {  # $1=score-json-body -> echoes project dir
  local d; d=$(mktemp -d)
  mkdir -p "$d/specs/demo"
  printf '%s' "$1" > "$d/specs/demo/SCORE.json"
  printf '%s' "$d"
}
run() {  # $1=project-dir [$2=stdin-json] -> sets $code, echoes stderr
  local stdin="${2:-{\}}"
  printf '%s' "$stdin" | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" 2>&1
}

# (1) no SCORE.json -> silent pass (exit 0, no output).
d=$(mktemp -d)
out=$(printf '{}' | CLAUDE_PROJECT_DIR="$d" bash "$HOOK" 2>&1); code=$?
[ "$code" -eq 0 ] && [ -z "$out" ] && { echo "PASS: no SCORE.json -> silent exit 0"; pass=$((pass+1)); } \
                                   || { echo "FAIL: no SCORE.json (exit $code, out='$out')"; fail=$((fail+1)); }
rm -rf "$d"

# (2) active:false -> pass (gate released even with a failing item).
d=$(mk '{"active":false,"threshold":95,"items":[{"id":"C1","score":10}]}')
out=$(run "$d"); code=$?
[ "$code" -eq 0 ] && { echo "PASS: active=false -> exit 0"; pass=$((pass+1)); } \
                  || { echo "FAIL: active=false (exit $code)"; fail=$((fail+1)); }
rm -rf "$d"

# (3) active:true + all items >= threshold -> pass.
d=$(mk '{"active":true,"threshold":95,"items":[{"id":"C1","score":97},{"id":"C2","score":95}]}')
out=$(run "$d"); code=$?
[ "$code" -eq 0 ] && { echo "PASS: all>=threshold -> exit 0"; pass=$((pass+1)); } \
                  || { echo "FAIL: all>=threshold (exit $code)"; fail=$((fail+1)); }
rm -rf "$d"

# (4) active:true + an item < threshold -> block (exit 2 + marker + item id).
d=$(mk '{"active":true,"threshold":95,"items":[{"id":"C1","score":97},{"id":"C2","score":80}]}')
out=$(run "$d"); code=$?
if [ "$code" -eq 2 ] && printf '%s' "$out" | grep -q '게이트 미통과' && printf '%s' "$out" | grep -q 'C2'; then
  echo "PASS: item<threshold -> exit 2 + C2 named"; pass=$((pass+1))
else
  echo "FAIL: item<threshold (exit $code)"; fail=$((fail+1))
fi
rm -rf "$d"

# (5) malformed JSON -> fail-closed (exit 2).
d=$(mk '{"active":true, this is not json')
out=$(run "$d"); code=$?
[ "$code" -eq 2 ] && printf '%s' "$out" | grep -q 'malformed' \
  && { echo "PASS: malformed -> fail-closed exit 2"; pass=$((pass+1)); } \
  || { echo "FAIL: malformed fail-closed (exit $code)"; fail=$((fail+1)); }
rm -rf "$d"

# (6) active:true + empty items -> fail-closed (nothing enumerated).
d=$(mk '{"active":true,"threshold":95,"items":[]}')
out=$(run "$d"); code=$?
[ "$code" -eq 2 ] && printf '%s' "$out" | grep -q '비어 있음' \
  && { echo "PASS: empty items -> fail-closed exit 2"; pass=$((pass+1)); } \
  || { echo "FAIL: empty items (exit $code)"; fail=$((fail+1)); }
rm -rf "$d"

# (7) active:true + item missing numeric score -> block.
d=$(mk '{"active":true,"threshold":95,"items":[{"id":"C1"}]}')
out=$(run "$d"); code=$?
[ "$code" -eq 2 ] && { echo "PASS: missing score -> exit 2"; pass=$((pass+1)); } \
                  || { echo "FAIL: missing score (exit $code)"; fail=$((fail+1)); }
rm -rf "$d"

# (8) stop_hook_active=true -> loop guard yields (exit 0 + 루프 방지 marker) despite a failing item.
d=$(mk '{"active":true,"threshold":95,"items":[{"id":"C1","score":10}]}')
out=$(run "$d" '{"stop_hook_active":true}'); code=$?
[ "$code" -eq 0 ] && printf '%s' "$out" | grep -q '루프 방지' \
  && { echo "PASS: loop guard yields (exit 0 + marker)"; pass=$((pass+1)); } \
  || { echo "FAIL: loop guard (exit $code)"; fail=$((fail+1)); }
rm -rf "$d"

# (9) jq absent + failing item -> best-effort skip (exit 0 + jq 미설치 marker).
d=$(mk '{"active":true,"threshold":95,"items":[{"id":"C1","score":10}]}')
out=$(printf '{}' | env -i PATH= CLAUDE_PROJECT_DIR="$d" "$BASH_BIN" "$HOOK" 2>&1); code=$?
[ "$code" -eq 0 ] && printf '%s' "$out" | grep -q 'jq 미설치' \
  && { echo "PASS: jq-absent -> best-effort exit 0"; pass=$((pass+1)); } \
  || { echo "FAIL: jq-absent (exit $code)"; fail=$((fail+1)); }
rm -rf "$d"

# (10) per-file threshold override: threshold 90, item 92 -> pass (env-independent).
d=$(mk '{"active":true,"threshold":90,"items":[{"id":"C1","score":92}]}')
out=$(run "$d"); code=$?
[ "$code" -eq 0 ] && { echo "PASS: per-file threshold 90 honored"; pass=$((pass+1)); } \
                  || { echo "FAIL: per-file threshold (exit $code)"; fail=$((fail+1)); }
rm -rf "$d"

# (11) multiple slugs: one passing, one failing -> block (any active failure blocks).
d=$(mktemp -d)
mkdir -p "$d/specs/ok" "$d/specs/bad"
printf '%s' '{"active":true,"threshold":95,"items":[{"id":"A","score":99}]}' > "$d/specs/ok/SCORE.json"
printf '%s' '{"active":true,"threshold":95,"items":[{"id":"B","score":70}]}' > "$d/specs/bad/SCORE.json"
out=$(run "$d"); code=$?
[ "$code" -eq 2 ] && printf '%s' "$out" | grep -q 'bad' \
  && { echo "PASS: multi-slug -> any failure blocks"; pass=$((pass+1)); } \
  || { echo "FAIL: multi-slug (exit $code)"; fail=$((fail+1)); }
rm -rf "$d"

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
