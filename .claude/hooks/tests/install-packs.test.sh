#!/usr/bin/env bash
# Assertions for language-pack installation (LP2): HARNESS_PACKS selection, auto
# detection, exclusion of unselected pack paths, harness-packs record, LSP toggle,
# `install.sh pack list|add|remove`, update filtering, uninstall. Offline via
# HARNESS_SRC_DIR; every case uses a temp target. Network never touched.

REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }
inst() { # <dir> [env assignments...] -> runs install.sh quietly, echoes exit code
  local d="$1"; shift
  ( cd "$d" && env "$@" HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" ) >/dev/null 2>&1; echo $?
}
plugin() { jq -r --arg k "$2" '.enabledPlugins[$k]' "$1/.claude/settings.json" 2>/dev/null; }

# (1) HARNESS_PACKS=python: python assets land, every other pack's paths are absent,
#     core (bash stack, common rules, safety) stays, audit passes.
T1=$(mktemp -d)
code=$(inst "$T1" HARNESS_PACKS=python)
if [ "$code" -eq 0 ] \
   && [ -f "$T1/.claude/stacks/python.sh" ] && [ -f "$T1/.claude/stacks/bash.sh" ] \
   && [ -d "$T1/docs/evaluator/python-example" ] && [ -f "$T1/docs/rules/code-convention/dev-stack-python.md" ] \
   && [ ! -e "$T1/.claude/rules/java-spring" ] && [ ! -e "$T1/.claude/rules/react-next" ] \
   && [ ! -e "$T1/.claude/hooks/eval-java.sh" ] && [ ! -e "$T1/.claude/stacks/typescript.sh" ] \
   && [ ! -e "$T1/.claude/stacks/go.sh" ] && [ ! -e "$T1/docs/rules/code-convention/dev-stack-typescript.md" ] \
   && [ -f "$T1/.claude/rules/safety.md" ] && [ -d "$T1/.claude/rules/common" ]; then
  ok "HARNESS_PACKS=python -> only python pack paths + core (exit 0)"
else
  no "python-only install (exit $code)"
fi
[ "$(cat "$T1/.claude/harness-packs" 2>/dev/null)" = "python" ] && ok "harness-packs records 'python'" || no "harness-packs: $(cat "$T1/.claude/harness-packs" 2>/dev/null)"
grep -q 'harness-packs' "$T1/.gitignore" && ok "harness-packs gitignored" || no "harness-packs not in .gitignore"
! grep -q 'java-spring' "$T1/.claude/harness-manifest.txt" && grep -q 'python' "$T1/.claude/harness-manifest.txt" \
  && ok "manifest excludes unselected pack paths" || no "manifest pack scope"
[ "$(plugin "$T1" pyright@claude-code-lsps)" = "true" ] && [ "$(plugin "$T1" jdtls@claude-code-lsps)" = "false" ] \
  && [ "$(plugin "$T1" vtsls@claude-code-lsps)" = "false" ] \
  && ok "LSP toggle: pyright on, jdtls/vtsls off" || no "LSP toggle (pyright=$(plugin "$T1" pyright@claude-code-lsps) jdtls=$(plugin "$T1" jdtls@claude-code-lsps))"
( cd "$T1" && CLAUDE_PROJECT_DIR="$T1" bash .claude/hooks/harness-audit.sh ) 2>&1 | grep -q ' 0 failed' \
  && ok "audit passes on a python-only install (AUDIT-07/08 self-skip)" || no "audit on python-only install"
# The Stop gate still works with a reduced stack set (bash core + python).
printf '{"stop_hook_active":true}' | CLAUDE_PROJECT_DIR="$T1" bash "$T1/.claude/hooks/stop-verify.sh" >/dev/null 2>&1 \
  && ok "stop-verify runs with a partial stack set" || no "stop-verify broken on partial stacks"

# (2) HARNESS_PACKS=none: no pack path at all, core gates intact.
T2=$(mktemp -d)
code=$(inst "$T2" HARNESS_PACKS=none)
if [ "$code" -eq 0 ] && [ -f "$T2/.claude/stacks/bash.sh" ] && [ "$(ls "$T2/.claude/stacks"/*.sh | wc -l | tr -d ' ')" = "1" ] \
   && [ ! -e "$T2/.claude/rules/java-spring" ] && [ ! -e "$T2/.claude/rules/database.md" ] \
   && [ ! -s "$T2/.claude/harness-packs" ] && [ -f "$T2/.claude/hooks/pretool-guard.sh" ]; then
  ok "HARNESS_PACKS=none -> core only (bash stack, no pack paths)"
else
  no "none install (exit $code)"
fi
rm -rf "$T2"

# (3) auto detection: a go.mod project (no tty, HARNESS_PACKS unset) gets exactly the go pack.
T3=$(mktemp -d); printf 'module x\n' > "$T3/go.mod"
code=$(inst "$T3")
if [ "$code" -eq 0 ] && [ "$(cat "$T3/.claude/harness-packs")" = "go" ] \
   && [ -f "$T3/.claude/stacks/go.sh" ] && [ ! -e "$T3/.claude/stacks/python.sh" ] \
   && [ "$(plugin "$T3" gopls@claude-code-lsps)" = "true" ]; then
  ok "no env + no tty -> auto: go.mod project installs the go pack only"
else
  no "auto detect go (exit $code, packs='$(cat "$T3/.claude/harness-packs" 2>/dev/null)')"
fi
rm -rf "$T3"

# (4) HARNESS_COMPONENTS set without HARNESS_PACKS keeps the legacy full install (regression guard).
T4=$(mktemp -d)
code=$(inst "$T4" HARNESS_COMPONENTS=all)
[ "$code" -eq 0 ] && [ -d "$T4/.claude/rules/java-spring" ] && [ -f "$T4/.claude/stacks/rust.sh" ] \
  && [ "$(grep -c . "$T4/.claude/harness-packs")" = "6" ] \
  && ok "HARNESS_COMPONENTS=all without HARNESS_PACKS -> all packs (legacy guard)" || no "legacy full install (exit $code)"
rm -rf "$T4"

# (5) interactive answer: manual mode ('2'), TUI confirmed by EOF... then the pack prompt
#     reads 'typescript,go'. stdin: "2\n" (setup mode) + "\n" (menu enter) + "typescript,go\n".
T5=$(mktemp -d)
printf '2\n\ntypescript,go\n' | ( cd "$T5" && HARNESS_SETUP_STDIN=1 HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" ) >/dev/null 2>&1
code=$?
if [ "$code" -eq 0 ] && [ "$(tr '\n' ' ' < "$T5/.claude/harness-packs")" = "go typescript " ] \
   && [ -f "$T5/.claude/stacks/typescript.sh" ] && [ -f "$T5/.claude/stacks/go.sh" ] && [ ! -e "$T5/.claude/stacks/python.sh" ]; then
  ok "interactive pack prompt: 'typescript,go' -> those two packs"
else
  no "interactive pack prompt (exit $code, packs='$(cat "$T5/.claude/harness-packs" 2>/dev/null | tr '\n' ' ')')"
fi
rm -rf "$T5"

# (6) unknown pack name -> WARN, ignored, install still succeeds.
T6=$(mktemp -d)
out=$( cd "$T6" && HARNESS_PACKS=python,cobol HARNESS_SRC_DIR="$REPO" bash "$REPO/install.sh" 2>&1 ); code=$?
[ "$code" -eq 0 ] && printf '%s' "$out" | grep -q '알 수 없는 언어팩 무시: cobol' && [ "$(cat "$T6/.claude/harness-packs")" = "python" ] \
  && ok "unknown pack name -> WARN + ignored" || no "unknown pack handling (exit $code)"
rm -rf "$T6"

# (7) pack add on the python-only install: java-spring paths land, manifest + record + LSP.
out=$( cd "$T1" && HARNESS_SRC_DIR="$REPO" bash install.sh pack add java-spring 2>&1 ); code=$?
if [ "$code" -eq 0 ] && [ -d "$T1/.claude/rules/java-spring/archunit" ] && [ -f "$T1/.claude/hooks/eval-java.sh" ] \
   && [ -f "$T1/.claude/stacks/java-spring.sh" ] && grep -qx '.claude/stacks/java-spring.sh' "$T1/.claude/harness-manifest.txt" \
   && [ "$(tr '\n' ' ' < "$T1/.claude/harness-packs")" = "java-spring python " ] \
   && [ "$(plugin "$T1" jdtls@claude-code-lsps)" = "true" ]; then
  ok "pack add java-spring -> paths + manifest + record + jdtls on"
else
  no "pack add (exit $code): $(printf '%s' "$out" | grep -E 'FAIL|fail' | head -2)"
fi
printf '%s' "$out" | grep -q ' 0 failed' && ok "audit passes after pack add (AUDIT-08 edge intact)" || no "audit after pack add"

# (8) pack list shows installed/detected marks.
out=$( cd "$T1" && bash install.sh pack list 2>&1 )
printf '%s' "$out" | grep -E '^ *java-spring +\[x\]' >/dev/null && printf '%s' "$out" | grep -E '^ *rust +\[ \]' >/dev/null \
  && ok "pack list marks installed packs" || no "pack list output: $(printf '%s' "$out" | head -3 | tr '\n' '|')"

# (9) pack remove python: paths pruned with backup (rollback-able), record + LSP updated.
out=$( cd "$T1" && bash install.sh pack remove python 2>&1 ); code=$?
if [ "$code" -eq 0 ] && [ ! -e "$T1/.claude/stacks/python.sh" ] && [ ! -e "$T1/docs/evaluator/python-example" ] \
   && [ "$(cat "$T1/.claude/harness-packs")" = "java-spring" ] && [ "$(plugin "$T1" pyright@claude-code-lsps)" = "false" ] \
   && ls -d "$T1"/logs/harness-backup/v*/.claude/stacks/python.sh >/dev/null 2>&1; then
  ok "pack remove python -> pruned, backed up, record + pyright off"
else
  no "pack remove (exit $code)"
fi
( cd "$T1" && bash install.sh rollback ) >/dev/null 2>&1
[ -f "$T1/.claude/stacks/python.sh" ] && ok "rollback restores a removed pack" || no "rollback after pack remove"

# (10) update: a new file under an UNINSTALLED pack is skipped; under an installed pack it lands.
#      T1 now has java-spring (+python restored by rollback, record still java-spring only).
S2=$(mktemp -d); cp -R "$REPO/." "$S2/"
printf 'x\n' > "$S2/.claude/rules/react-next/zz-new.md"          # typescript pack: not installed
printf 'y\n' > "$S2/.claude/rules/java-spring/zz-new.md"         # java-spring pack: installed
printf '9.9.9\n' > "$S2/VERSION"
out=$( cd "$T1" && HARNESS_SRC_DIR="$S2" bash install.sh update 2>&1 ); code=$?
if [ "$code" -eq 0 ] && [ -f "$T1/.claude/rules/java-spring/zz-new.md" ] && [ ! -e "$T1/.claude/rules/react-next/zz-new.md" ] \
   && [ ! -e "$T1/.claude/rules/react-next" ]; then
  ok "update: installed-pack file lands, uninstalled-pack file skipped"
else
  no "update pack filter (exit $code): $(printf '%s' "$out" | grep -E 'zz-new|react-next' | tr '\n' '|')"
fi
rm -rf "$S2"

# (11) uninstall removes pack paths and the record.
( cd "$T1" && bash uninstall.sh --yes ) >/dev/null 2>&1
[ ! -e "$T1/.claude/stacks" ] && [ ! -e "$T1/docs/evaluator" ] && [ ! -e "$T1/.claude/harness-packs" ] \
  && ok "uninstall removes pack paths + harness-packs" || no "uninstall left pack residue"
rm -rf "$T1"

printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
