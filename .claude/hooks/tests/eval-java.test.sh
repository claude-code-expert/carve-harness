#!/usr/bin/env bash
# Assertions for eval-java.sh (deterministic Java/Spring scorer).
# Builds throwaway fixture projects with a stub gradlew + pre-made XML reports,
# so no real gradle/JDK is needed. Verifies: determinism (same input=same P),
# XML parsing, no-gradle fail-closed, compile-fail P=0, tool-absent skip.

HOOK="$(cd "$(dirname "$0")/.." && pwd)/eval-java.sh"
fail=0; pass=0

# mkfix <dir> — full fixture: stub gradlew(all-pass) + jacoco/pmd/archunit reports.
mkfix() {
  local d="$1"
  rm -rf "$d"; mkdir -p "$d/build/reports/jacoco" "$d/build/reports/pmd" \
    "$d/build/test-results" "$d/src/main/java"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$d/gradlew"; chmod +x "$d/gradlew"
  printf 'class A {\n int x;\n}\n' > "$d/src/main/java/A.java"
  printf '<report><counter type="LINE" missed="20" covered="80"/></report>\n' \
    > "$d/build/reports/jacoco/jacocoTestReport.xml"
  printf '<pmd><violation>x</violation></pmd>\n' > "$d/build/reports/pmd/main.xml"
  printf '<testsuite tests="8" failures="1" errors="0"></testsuite>\n' \
    > "$d/build/test-results/TEST-HarnessArchRulesTest.xml"
}

ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

T=$(mktemp -d)

# (1) determinism — same fixture, two runs, identical JSON verdict.
mkfix "$T/f1"
r1=$(CLAUDE_PROJECT_DIR="$T/f1" bash "$HOOK" --k 2 --json 2>/dev/null)
r2=$(CLAUDE_PROJECT_DIR="$T/f1" bash "$HOOK" --k 2 --json 2>/dev/null)
[ -n "$r1" ] && [ "$r1" = "$r2" ] && ok "deterministic — same input → same P" \
  || no "determinism (r1=$r1 / r2=$r2)"

# (2) parsing — coverage 80/100=0.8, archrules 7/8=0.875 (numeric compare; jq keeps 0.8000 literal).
if printf '%s' "$r1" | jq -e '(.metrics.coverage == 0.8) and (.metrics.archrules == 0.875)' >/dev/null 2>&1; then
  ok "XML parse (coverage=0.8, archrules=0.875)"
else
  no "XML parse ($(printf '%s' "$r1" | jq -c '.metrics'))"
fi

# (3) valid JSON verdict with required keys.
if printf '%s' "$r1" | jq -e '.verdict and (.P|type=="number") and (.metrics|type=="object")' >/dev/null 2>&1; then
  ok "verdict is valid JSON with P + metrics"
else
  no "verdict schema"
fi

# (4) no gradle → unable + exit 1 (fail-closed, not fake pass).
G="$T/nogradle"; mkdir -p "$G"
out=$(CLAUDE_PROJECT_DIR="$G" bash "$HOOK" --json 2>/dev/null); code=$?
v=$(printf '%s' "$out" | jq -r '.verdict' 2>/dev/null)
[ "$code" -eq 1 ] && [ "$v" = "unable" ] && ok "no gradle → unable + exit 1" \
  || no "no-gradle (exit $code verdict $v)"

# (5) compile fail → P=0, verdict fail, other metrics skipped.
CF="$T/failc"; mkdir -p "$CF"
printf '#!/usr/bin/env bash\n[ "$1" = compileJava ] && exit 1\nexit 0\n' > "$CF/gradlew"; chmod +x "$CF/gradlew"
out=$(CLAUDE_PROJECT_DIR="$CF" bash "$HOOK" --json 2>/dev/null)
p=$(printf '%s' "$out" | jq -r '.P'); v=$(printf '%s' "$out" | jq -r '.verdict')
[ "$p" = "0" ] && [ "$v" = "fail" ] && ok "compile fail → P=0 verdict=fail" \
  || no "compile-fail (P=$p verdict=$v)"

# (6) tool absent → metric skipped + listed, P from remaining axes (no silent pass).
S="$T/nostatic"
rm -rf "$S"; mkdir -p "$S/build/reports/jacoco" "$S/build/test-results" "$S/src/main/java"
printf '#!/usr/bin/env bash\nexit 0\n' > "$S/gradlew"; chmod +x "$S/gradlew"
printf 'class A {}\n' > "$S/src/main/java/A.java"
printf '<report><counter type="LINE" missed="0" covered="10"/></report>\n' > "$S/build/reports/jacoco/jacocoTestReport.xml"
# no pmd/checkstyle/spotbugs dirs, no archunit result → violations + archrules + nplus1 skipped
out=$(CLAUDE_PROJECT_DIR="$S" bash "$HOOK" --k 1 --json 2>/dev/null)
if printf '%s' "$out" | jq -e '.skipped | index("violations") and index("archrules")' >/dev/null 2>&1 \
   && [ "$(printf '%s' "$out" | jq -r '.P|type')" = "number" ]; then
  ok "tool absent → metric skipped + listed, P still computed"
else
  no "tool-absent skip ($out)"
fi

# (7) composite P: run the REAL awk formula with the REAL weights on known metrics.
# The fixtures above only assert parsed metric values and the verdict label, so any
# weight could be changed without a single test failing. Both the weights line and
# the <composite-p> block come from the source — nothing is re-implemented here.
eval "$(grep -m1 '^w_compile=' "$HOOK")"
PROG="$(sed -n '/# <composite-p>/,/# <\/composite-p>/p' "$HOOK")"
runp() { # runp <compile> <passk> <coverage> <violations> <archrules> <nplus1>
  awk -v compile="$1" -v passk="$2" -v coverage="$3" -v violations="$4" \
      -v archrules="$5" -v nplus1="$6" \
      -v wc="$w_compile" -v wp="$w_passk" -v wv="$w_coverage" -v wl="$w_violations" \
      -v wa="$w_archrules" -v wn="$w_nplus1" "$PROG" </dev/null
}
[ -n "$PROG" ] && ok "<composite-p> block extractable" || no "<composite-p> block missing"
[ "$(printf '%s\n' "$w_compile $w_passk $w_coverage $w_violations $w_archrules $w_nplus1" \
     | awk '{printf "%.2f", $1+$2+$3+$4+$5+$6}')" = "1.00" ] \
  && ok "weights sum to 1.00" || no "weights do not sum to 1.00"
# 0.15·1 + 0.25·0.5 + 0.20·0.8 + 0.15·1 + 0.20·0.875 + 0.05·1 = 0.8100 ; err = 0.25·0.5
[ "$(runp 1 0.5 0.8 1 0.875 1)" = "0.8100 0.1250 -" ] \
  && ok "P weighted sum on known metrics = 0.8100 (err 0.1250)" || no "P sum ($(runp 1 0.5 0.8 1 0.875 1))"
# a skipped metric renormalizes the divisor instead of counting as zero.
# Only P and the skip list are asserted — the err digit rounds differently across awks.
[ "$(runp 1 0.5 skip 1 0.875 1 | awk '{print $1, $3}')" = "0.8125 coverage" ] \
  && ok "skipped metric renormalizes weights" || no "renormalize ($(runp 1 0.5 skip 1 0.875 1))"
[ "$(runp 0 0 0 0 0 0)" = "0.0000 0.0000 -" ] \
  && ok "all-zero metrics -> P=0" || no "zero floor ($(runp 0 0 0 0 0 0))"

# (8) bash -n + syntax clean (self-guard).
bash -n "$HOOK" 2>/dev/null && ok "bash -n clean" || no "bash -n"

rm -rf "$T"
printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
