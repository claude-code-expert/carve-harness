#!/usr/bin/env bash
# Assertions for the stack-definition layer (LP1): .claude/stacks/<pack>.sh files
# sourced by stop-verify.sh and posttool-format.sh. Pins the contract every stack
# file must honor, and the pack-level property that motivated the split: removing
# one stack file removes exactly that gate and nothing else.
# Toolchains are stubbed on PATH — assertions are about the gate, not about go/cargo.

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
STACKS="$ROOT/.claude/stacks"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(mktemp -d)}"

# (1) contract: every stack file is bash -n clean, side-effect free on source,
#     and defines STACK_ID (== filename), STACK_CHANGE_RE and stack_gate.
want="bash go java-spring python rust typescript"
have=$(ls "$STACKS"/*.sh | xargs -n1 basename | sed 's/\.sh$//' | tr '\n' ' ' | sed 's/ $//')
[ "$have" = "$want" ] && ok "six stack files present" || no "stack files: $have"
for f in "$STACKS"/*.sh; do
  n=$(basename "$f" .sh)
  bash -n "$f" 2>/dev/null || no "bash -n $n"
  out=$(bash -c "unset -f stack_gate; STACK_ID=; STACK_CHANGE_RE=; source '$f'; \
    [ \"\$STACK_ID\" = '$n' ] && [ -n \"\$STACK_CHANGE_RE\" ] && declare -f stack_gate >/dev/null && echo ok" 2>&1)
  [ "$out" = "ok" ] && ok "contract: $n (STACK_ID·STACK_CHANGE_RE·stack_gate, silent source)" \
                    || no "contract: $n -> '$out'"
done

# (2) pack-level property: delete one stack file -> only that gate disappears.
#     Copy the hooks+stacks tree, remove go.sh, run stop-verify on a Go fixture with a
#     failing stub `go`: the gate must now PASS (no Go stack) while a Rust fixture with a
#     failing stub `cargo` still BLOCKS (rust.sh intact).
if command -v git >/dev/null 2>&1; then
  H=$(mktemp -d); mkdir -p "$H/.claude"
  cp -r "$ROOT/.claude/hooks" "$H/.claude/hooks"; cp -r "$STACKS" "$H/.claude/stacks"
  rm "$H/.claude/stacks/go.sh"
  HOOK="$H/.claude/hooks/stop-verify.sh"
  stub=$(mktemp -d)
  mk_stub() { printf '#!/bin/sh\nexit %s\n' "$2" > "$stub/$1"; chmod +x "$stub/$1"; }
  gate_in() { ( cd "$1" && printf '{}' | PATH="$stub:$PATH" CLAUDE_PROJECT_DIR="$H" bash "$HOOK" >/dev/null 2>&1; echo $? ); }
  gdir=$(mktemp -d)
  ( cd "$gdir" && git init -q && git config user.email t@t && git config user.name t )
  printf 'module x\n' > "$gdir/go.mod"; printf 'package main\n' > "$gdir/main.go"
  mk_stub go 1; mk_stub cargo 1
  [ "$(gate_in "$gdir")" -eq 0 ] && ok "go.sh removed -> Go fixture no longer gated (exit 0)" \
                                 || no "go.sh removed but Go still gated"
  rdir=$(mktemp -d)
  ( cd "$rdir" && git init -q && git config user.email t@t && git config user.name t )
  printf '[package]\nname="x"\n' > "$rdir/Cargo.toml"; mkdir -p "$rdir/src"; printf 'fn main(){}\n' > "$rdir/src/main.rs"
  [ "$(gate_in "$rdir")" -eq 2 ] && ok "rust.sh intact -> Rust fixture still blocked (exit 2)" \
                                 || no "rust gate lost after removing go.sh"
  # And with the full tree the Go fixture blocks — proves (2) measured the file, not the fixture.
  cp "$STACKS/go.sh" "$H/.claude/stacks/go.sh"
  [ "$(gate_in "$gdir")" -eq 2 ] && ok "go.sh restored -> Go fixture blocked again (exit 2)" \
                                 || no "go.sh restored but not gated"
  rm -rf "$H" "$stub" "$gdir" "$rdir"
else
  echo "SKIP: stack removal fixture (git absent)"
fi

# (3) formatter routing comes from the stack file too: with a stub gofmt on PATH a
#     .go write logs format-ok (tool gofmt); remove go.sh and the same write logs
#     format-skip — the extension is only known through the stack file.
H=$(mktemp -d); mkdir -p "$H/.claude"
cp -r "$ROOT/.claude/hooks" "$H/.claude/hooks"; cp -r "$STACKS" "$H/.claude/stacks"
FMT="$H/.claude/hooks/posttool-format.sh"
daily() { printf '%s/logs/%s.jsonl' "$1" "$(date -u +%F)"; }
cwd=$(mktemp -d); logd=$(mktemp -d); stub=$(mktemp -d)
printf '#!/bin/sh\nexit 0\n' > "$stub/gofmt"; chmod +x "$stub/gofmt"
( cd "$cwd" && printf '%s' '{"tool_input":{"file_path":"main.go"}}' | PATH="$stub:$PATH" CLAUDE_PROJECT_DIR="$logd" bash "$FMT" >/dev/null 2>&1 )
[ "$(tail -1 "$(daily "$logd")" 2>/dev/null | jq -r '.decision+":"+.tool')" = "format-ok:gofmt" ] \
  && ok "go.sh present + stub gofmt -> format-ok (tool gofmt)" || no "go format routing: $(tail -1 "$(daily "$logd")" 2>/dev/null)"
rm "$H/.claude/stacks/go.sh"
( cd "$cwd" && printf '%s' '{"tool_input":{"file_path":"main.go"}}' | PATH="$stub:$PATH" CLAUDE_PROJECT_DIR="$logd" bash "$FMT" >/dev/null 2>&1 )
[ "$(tail -1 "$(daily "$logd")" 2>/dev/null | jq -r '.decision')" = "format-skip" ] \
  && ok "go.sh removed -> .go write logs format-skip" || no "go.sh removed but still routed"
rm -rf "$H" "$cwd" "$logd" "$stub"

# (4) every language pack lists its stack file (pack <-> stack 1:1).
# shellcheck source=/dev/null
source "$ROOT/.claude/hooks/lib-packs.sh"
miss=""
for n in typescript java-spring python go rust; do
  pack_paths "$n" | grep -qx ".claude/stacks/$n.sh" || miss="$miss $n"
done
[ -z "$miss" ] && ok "each language pack lists .claude/stacks/<pack>.sh" || no "packs missing stack path:$miss"

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
