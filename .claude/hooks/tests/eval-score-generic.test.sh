#!/usr/bin/env bash
# Assertions for eval-score.sh (LP4) — the language-agnostic scorecard driven by
# .claude/stacks/*.sh adapters. Toolchains are stubbed on PATH, so this is about the
# scoring logic (gates, veto, skips, multi-stack min), not about having go/cargo installed.

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$ROOT/.claude/hooks/eval-score.sh"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

STUB=$(mktemp -d)
# mk_stub <name> <script body>  — a fake toolchain binary
mk_stub() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$STUB/$1"; chmod +x "$STUB/$1"; }
run() { # <dir> [args...] -> JSON on stdout, exit code in $RC
  local d="$1"; shift
  OUT=$( cd "$d" && PATH="$STUB:$PATH" CLAUDE_PROJECT_DIR="$d" bash "$HOOK" --json --out "$d/SCORE.json" "$@" 2>/dev/null ); RC=$?
}
gitfix() { ( cd "$1" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm init ) >/dev/null 2>&1; }

# (1) adapter contract: every language stack defines detect/build/test/lint/coverage + coverage min.
for n in typescript java-spring python go rust; do
  out=$(bash -c "source '$ROOT/.claude/stacks/$n.sh'; for fn in stack_detect stack_build stack_test stack_lint stack_coverage; do declare -f \$fn >/dev/null || echo missing:\$fn; done; [ -n \"\$STACK_COVERAGE_MIN\" ] || echo missing:STACK_COVERAGE_MIN" 2>&1)
  [ -z "$out" ] && ok "adapter contract: $n" || no "adapter contract: $n -> $out"
done

# (2) Go: stub `go` obeys control files. Clean project -> PASS with coverage measured.
G=$(mktemp -d); printf 'module x\n' > "$G/go.mod"; printf 'package x\n' > "$G/x.go"; gitfix "$G"
mk_stub go 'case "$1" in
  build) [ -f BUILDFAIL ] && exit 1; exit 0 ;;
  vet)   [ -f VETFAIL ] && exit 1; exit 0 ;;
  test)  [ -f TESTFAIL ] && exit 1; for a in "$@"; do case "$a" in -coverprofile=*) echo "mode: set" > "${a#-coverprofile=}";; esac; done; exit 0 ;;
  tool)  echo "total:	(statements)	${COVPCT:-85.0}%"; exit 0 ;;
esac; exit 0'
run "$G"
[ "$RC" -eq 0 ] && [ "$(printf '%s' "$OUT" | jq -r '.verdict')" = "PASS" ] \
  && [ "$(printf '%s' "$OUT" | jq -r '.stacks.go.total')" = "90" ] \
  && ok "go clean -> PASS, total 90 (antislop skipped, max 90)" || no "go clean: $OUT"
[ "$(printf '%s' "$OUT" | jq -r '.stacks.go.items.coverage')" = "5" ] && ok "coverage 85% >= 80 -> 5" || no "coverage points: $OUT"
[ -f "$G/SCORE.json" ] && jq -e '.stacks.go' "$G/SCORE.json" >/dev/null && ok "SCORE.json written" || no "SCORE.json missing"

# (3) veto: build failure -> G1=0, verdict FAIL, tests not run.
touch "$G/BUILDFAIL"; run "$G"
[ "$(printf '%s' "$OUT" | jq -r '.verdict')" = "FAIL" ] && [ "$(printf '%s' "$OUT" | jq -r '.stacks.go.gates.G1')" = "0" ] \
  && [ "$(printf '%s' "$OUT" | jq -r '.stacks.go.gates.G2')" = "0" ] \
  && ok "build failure -> G1=0 veto, FAIL, G2 not run" || no "build veto: $OUT"
rm -f "$G/BUILDFAIL"

# (4) test failure -> G2=0 FAIL even with everything else green; regression follows G2.
touch "$G/TESTFAIL"; run "$G"
[ "$(printf '%s' "$OUT" | jq -r '.verdict')" = "FAIL" ] && [ "$(printf '%s' "$OUT" | jq -r '.stacks.go.gates.G2')" = "0" ] \
  && [ "$(printf '%s' "$OUT" | jq -r '.stacks.go.items.regression')" = "0" ] \
  && ok "test failure -> G2=0, regression 0, FAIL" || no "test veto: $OUT"
rm -f "$G/TESTFAIL"

# (5) coverage below the floor -> 0 points but no veto; lint failure -> lint 0, still PASS? (90-10-5=75/90 < 0.9 -> FAIL)
COVPCT=50.0 run "$G"
[ "$(printf '%s' "$OUT" | jq -r '.stacks.go.items.coverage')" = "0" ] && [ "$(printf '%s' "$OUT" | jq -r '.stacks.go.gates.G1')" = "25" ] \
  && ok "coverage 50% < 80 -> 0 points, no veto" || no "coverage floor: $OUT"
touch "$G/VETFAIL"; COVPCT=50.0 run "$G"
[ "$(printf '%s' "$OUT" | jq -r '.stacks.go.items.lint')" = "0" ] && [ "$(printf '%s' "$OUT" | jq -r '.verdict')" = "FAIL" ] \
  && ok "lint fail + low coverage -> 75/90 < 90% -> FAIL without veto" || no "lint/coverage arithmetic: $OUT"
rm -f "$G/VETFAIL"

# (6) safety gate: a secret literal in added lines -> G3=0 veto.
printf 'key = "AKIA%s"\n' "ABCDEFGHIJKLMNOP" > "$G/cfg.go"
run "$G"
[ "$(printf '%s' "$OUT" | jq -r '.stacks.go.gates.G3')" = "0" ] && [ "$(printf '%s' "$OUT" | jq -r '.verdict')" = "FAIL" ] \
  && ok "secret in diff -> G3=0 veto" || no "safety gate: $OUT"
rm -f "$G/cfg.go"

# (7) regression: deleting a test file with tests green -> regression 0.
printf 'package x\n' > "$G/x_test.go"; ( cd "$G" && git add -A && git -c user.email=t@t -c user.name=t commit -qm t ) >/dev/null 2>&1
rm "$G/x_test.go"; run "$G"
[ "$(printf '%s' "$OUT" | jq -r '.stacks.go.items.regression')" = "0" ] && ok "deleted test file -> regression 0" || no "regression on deleted test: $OUT"
( cd "$G" && git checkout -q -- x_test.go )

# (8) --k: second run fails -> G2=0.
mk_stub go 'case "$1" in test) [ -f .ran ] && exit 1; touch .ran; exit 0 ;; tool) echo "total: (statements) 90.0%";; esac; exit 0'
rm -f "$G/.ran"; run "$G" --k 2
[ "$(printf '%s' "$OUT" | jq -r '.stacks.go.gates.G2')" = "0" ] && ok "--k 2: flaky second run -> G2=0" || no "k runs: $OUT"

# (9) no stack detected -> unable, exit 1, no SCORE.json.
E=$(mktemp -d); run "$E"
[ "$RC" -eq 1 ] && [ "$(printf '%s' "$OUT" | jq -r '.verdict')" = "unable" ] && [ ! -f "$E/SCORE.json" ] \
  && ok "no stack -> unable, exit 1, nothing written" || no "unable path (rc $RC): $OUT"

# (10) python: no pytest on PATH -> G2 skipped (not 0), compileall as G1, ruff absent -> lint skipped.
P=$(mktemp -d); printf 'x = 1\n' > "$P/app.py"; : > "$P/requirements.txt"; gitfix "$P"
NOPATH=$(mktemp -d); for b in bash jq python3 git awk sed grep mktemp basename dirname tail head tr cat rm mkdir printf; do p=$(command -v $b) && ln -s "$p" "$NOPATH/$b"; done
OUT=$( cd "$P" && PATH="$NOPATH" CLAUDE_PROJECT_DIR="$P" bash "$HOOK" --json --out "$P/SCORE.json" 2>/dev/null ); RC=$?
[ "$RC" -eq 0 ] && [ "$(printf '%s' "$OUT" | jq -r '.stacks.python.gates.G1')" = "25" ] \
  && printf '%s' "$OUT" | jq -e '.stacks.python.skipped | index("G2") and index("lint") and index("coverage")' >/dev/null \
  && ok "python w/o pytest/ruff -> G2/lint/coverage skipped, G1 from compileall" || no "python skips (rc $RC): $OUT"

# (11) multi-stack: go + rust in one repo; rust stub fails check -> overall FAIL, total = min.
mk_stub go 'case "$1" in tool) echo "total: (statements) 90.0%";; esac; exit 0'
mk_stub cargo 'case "$1" in check) exit 1 ;; *) exit 0 ;; esac'
printf '[package]\nname="x"\n' > "$G/Cargo.toml"; mkdir -p "$G/src"; printf 'fn main(){}\n' > "$G/src/main.rs"
run "$G"
[ "$(printf '%s' "$OUT" | jq -r '.verdict')" = "FAIL" ] && [ "$(printf '%s' "$OUT" | jq -r '.stacks | keys | join(",")')" = "go,rust" ] \
  && [ "$(printf '%s' "$OUT" | jq -r '.total')" = "$(printf '%s' "$OUT" | jq -r '[.stacks[].total] | min')" ] \
  && ok "multi-stack: go+rust scored, verdict AND, total = min" || no "multi-stack: $OUT"
run "$G" --stack go
[ "$(printf '%s' "$OUT" | jq -r '.stacks | keys | join(",")')" = "go" ] && ok "--stack go limits scoring to one stack" || no "--stack filter: $OUT"

# (12) java delegates coverage to eval-java.sh: stub gradlew + jacoco XML -> coverage from the Java scorer.
J=$(mktemp -d); printf '#!/usr/bin/env bash\nexit 0\n' > "$J/gradlew"; chmod +x "$J/gradlew"
mkdir -p "$J/build/reports/jacoco" "$J/src/main/java"; printf 'class A {}\n' > "$J/src/main/java/A.java"
printf '<report><counter type="LINE" missed="10" covered="90"/></report>\n' > "$J/build/reports/jacoco/jacocoTestReport.xml"
gitfix "$J"; run "$J"
[ "$(printf '%s' "$OUT" | jq -r '.stacks."java-spring".items.coverage')" = "5" ] \
  && ok "java-spring coverage via eval-java.sh (90% -> 5)" || no "java delegation: $OUT"

# (13) determinism + bash -n.
run "$G" --stack go; a="$OUT"; run "$G" --stack go; b="$OUT"
[ "$a" = "$b" ] && ok "deterministic: same input -> same JSON" || no "determinism"
bash -n "$HOOK" && ok "bash -n eval-score.sh" || no "bash -n"

rm -rf "$STUB" "$G" "$E" "$P" "$NOPATH" "$J"
printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
