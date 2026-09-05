#!/usr/bin/env bash
# eval-state.sh — deterministic STATE-assert grader for carve-eval golden sets.
# Grades the environment (files, commands, git diff), never the agent's prose —
# the anti-reward-hacking counterpart of the pure-text grader in carve-eval.js.
#   usage: eval-state.sh <workdir> <asserts-json-file>
#          eval-state.sh <workdir> <goldenset-file> --case <case-id>
# stdout: {"failed":["<type>:<value>", ...]}  (empty array = all state asserts pass)
# Non-state assert types in the input are ignored (text/llm graded elsewhere).
# Fail-closed: unusable input emits {"failed":["eval-state:unusable"]} and exit 1,
# unknown state-looking types and probe errors count as failed, never as passed.
#
# --case reads the asserts straight out of the golden-set file. Prefer it: relaying
# assert values through an LLM prompt re-serializes them, and every JSON round trip
# doubles a backslash — `\+` becomes `\\+`, which matches nothing and scores 0 for
# reasons that have nothing to do with the agent. Escaping must never leave the file.

STATE_TYPES='file_exists|file_contains|cmd_exit0|git_diff_contains'

W="$1"; AF="$2"; CASE=""
[ "${3:-}" = "--case" ] && CASE="${4:-}"

if ! command -v jq >/dev/null 2>&1 || [ -z "$W" ] || [ ! -d "$W" ] || [ ! -f "$AF" ] \
  || ! jq empty "$AF" >/dev/null 2>&1; then
  echo '{"failed":["eval-state:unusable"]}'
  exit 1
fi
if [ "${3:-}" = "--case" ] && ! jq -e --arg id "$CASE" \
     '[.cases[]? | select(.id == $id)] | length == 1' "$AF" >/dev/null 2>&1; then
  echo '{"failed":["eval-state:unusable"]}'   # unknown or duplicated case id
  exit 1
fi

# --case narrows the file down to that case's assert array first, so the reader
# below is shared by both modes — the byte-exact contract has one definition.
if [ -n "$CASE" ]; then
  TMP_AF=$(mktemp)
  jq --arg id "$CASE" '[.cases[] | select(.id == $id) | .assert[]?]' "$AF" > "$TMP_AF" 2>/dev/null
  AF="$TMP_AF"
fi

failed=()
# NUL-delimited, not @tsv: @tsv escapes backslashes and newlines, which silently
# corrupts any cmd_exit0 containing `\n` (a stub script, a printf) and turns a
# passing case into a phantom failure — `\+` arrived as `\\+` and matched nothing,
# scoring three golden-set cases 0. Values must reach bash byte-for-byte.
while IFS= read -r -d '' type && IFS= read -r -d '' value; do
  [ -n "$type" ] || continue
  if [ -z "$value" ]; then                                      # empty value never passes
    printf '%s' "$type" | grep -Eqx "$STATE_TYPES" && failed+=("$type:<empty>")
    continue
  fi
  printf '%s' "$type" | grep -Eqx "$STATE_TYPES" || continue   # non-state types: not ours
  ok=0
  case "$type" in
    file_exists)
      [ -e "$W/$value" ] && ok=1 ;;
    file_contains)
      # value = "<relative-path>::<literal needle>"
      p="${value%%::*}"; needle="${value#*::}"
      [ "$p" != "$value" ] && [ -f "$W/$p" ] && grep -qF "$needle" "$W/$p" && ok=1 ;;
    cmd_exit0)
      ( cd "$W" && bash -c "$value" ) >/dev/null 2>&1 && ok=1 ;;
    git_diff_contains)
      ( cd "$W" && git diff HEAD 2>/dev/null | grep -qF "$value" ) && ok=1 ;;
  esac
  [ "$ok" = 1 ] || failed+=("$type:$value")
done < <(jq -j '.[] | (.type|tostring) + "\u0000" + (.value|tostring) + "\u0000"' "$AF" 2>/dev/null)

[ -n "${TMP_AF:-}" ] && rm -f "$TMP_AF"

# Emit via jq only — never string-interpolate values into JSON by hand.
printf '%s\n' "${failed[@]:-}" | jq -R . | jq -cs '{failed: [.[] | select(. != "")]}'
exit 0
