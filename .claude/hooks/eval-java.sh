#!/usr/bin/env bash
# eval-java.sh — deterministic Java/Spring output-verification scorer.
# Runs gradle graders, parses their XML reports, and emits a reproducible
# quality probability P in [0,1] with an error bar. NO LLM — same input → same P
# (the only intentional non-determinism is pass^k, which surfaces test flakiness).
#
#   bash eval-java.sh [--k N] [--json]
#     --k N   test runs for pass^k (default 5)
#     --json  emit only the JSON verdict line (no human summary)
#
# Emits one compact JSON verdict via jq -cn (log-event.sh schema style). A missing
# grader/report EXCLUDES that metric from P and is listed in .skipped — never a
# silent pass. No gradle → verdict "unable" + exit 1 (fail-closed, not fake-pass).
#
# Metrics (each normalized 0..1): compile, passk(=green_runs/k), coverage,
# violations(=1-density/threshold), archrules(=passed/total), nplus1(best-effort).
# Weights: .claude/eval-weights.json if present, else defaults below.
set -o pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
K=5
JSON_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --k) K="${2:-5}"; shift 2 ;;
    --json) JSON_ONLY=1; shift ;;
    *) shift ;;
  esac
done
case "$K" in ''|*[!0-9]*) K=5 ;; esac
[ "$K" -lt 1 ] && K=1

emit_unable() {  # $1=reason — fail-closed verdict, never a fake pass
  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg r "$1" '{verdict:"unable", P:null, reason:$r}'
  else
    printf '{"verdict":"unable","P":null,"reason":"%s"}\n' "$1"
  fi
  exit 1
}

command -v jq >/dev/null 2>&1 || emit_unable "jq 미설치 — 결정적 파싱 불가 (fail-closed)"

# Locate gradle wrapper (stop-verify.sh convention).
GDIR=""
[ -f "$ROOT/gradlew" ] && GDIR="$ROOT"
[ -z "$GDIR" ] && [ -f "$ROOT/backend/gradlew" ] && GDIR="$ROOT/backend"
[ -n "$GDIR" ] || emit_unable "gradlew 없음 — Java 빌드 대상 아님"
GW="./gradlew"

# ── grader helpers — each echoes a normalized 0..1 score, or "skip" ──

# compile ∈ {0,1}
metric_compile() {
  ( cd "$GDIR" && $GW compileJava -q ) >/dev/null 2>&1 && echo "1" || echo "0"
}

# pass^k rate = green_runs / K. Deterministic tests → 0 or 1; flaky → in between.
metric_passk() {
  local green=0 i
  for ((i = 0; i < K; i++)); do
    ( cd "$GDIR" && $GW test -q ) >/dev/null 2>&1 && green=$((green + 1))
  done
  awk -v g="$green" -v k="$K" 'BEGIN{ printf "%.4f", g/k }'
}

# coverage = covered/(covered+missed) from JaCoCo report-level LINE counter.
metric_coverage() {
  local xml
  xml=$(find "$GDIR/build/reports/jacoco" -name '*.xml' 2>/dev/null | head -1)
  [ -n "$xml" ] || { echo "skip"; return; }
  local line covered missed
  line=$(grep -oE '<counter type="LINE"[^/]*/>' "$xml" 2>/dev/null | tail -1)
  [ -n "$line" ] || { echo "skip"; return; }
  covered=$(printf '%s' "$line" | grep -oE 'covered="[0-9]+"' | grep -oE '[0-9]+')
  missed=$(printf '%s' "$line" | grep -oE 'missed="[0-9]+"' | grep -oE '[0-9]+')
  awk -v c="${covered:-0}" -v m="${missed:-0}" 'BEGIN{ t=c+m; if(t==0){print "skip"} else printf "%.4f", c/t }'
}

# violations = 1 - density/threshold (density = violations / KLOC). 10/KLOC 이상 → 0.
metric_violations() {
  if [ ! -d "$GDIR/build/reports/pmd" ] && [ ! -d "$GDIR/build/reports/checkstyle" ] && [ ! -d "$GDIR/build/reports/spotbugs" ]; then
    echo "skip"; return
  fi
  local pmd cs sb total kloc
  pmd=$(find "$GDIR/build/reports/pmd" -name '*.xml' -exec grep -oE '<violation' {} + 2>/dev/null | wc -l)
  cs=$(find "$GDIR/build/reports/checkstyle" -name '*.xml' -exec grep -oE '<error ' {} + 2>/dev/null | wc -l)
  sb=$(find "$GDIR/build/reports/spotbugs" -name '*.xml' -exec grep -oE '<BugInstance' {} + 2>/dev/null | wc -l)
  total=$(( pmd + cs + sb ))
  kloc=$(find "$GDIR/src/main" -name '*.java' -exec cat {} + 2>/dev/null | grep -cvE '^[[:space:]]*$')
  awk -v v="$total" -v loc="${kloc:-0}" 'BEGIN{
    if(loc==0){print "skip"; exit}
    d = v / (loc/1000.0); s = 1 - d/10.0;
    if(s<0)s=0; if(s>1)s=1; printf "%.4f", s
  }'
}

# archrules = passed/total for HarnessArchRulesTest (JUnit test-results XML).
metric_archrules() {
  local xml tests failures errors
  xml=$(find "$GDIR/build/test-results" -name '*HarnessArchRulesTest*.xml' 2>/dev/null | head -1)
  [ -n "$xml" ] || { echo "skip"; return; }
  tests=$(grep -oE 'tests="[0-9]+"' "$xml" | head -1 | grep -oE '[0-9]+')
  failures=$(grep -oE 'failures="[0-9]+"' "$xml" | head -1 | grep -oE '[0-9]+')
  errors=$(grep -oE 'errors="[0-9]+"' "$xml" | head -1 | grep -oE '[0-9]+')
  awk -v t="${tests:-0}" -v f="${failures:-0}" -v e="${errors:-0}" 'BEGIN{
    if(t==0){print "skip"; exit}
    printf "%.4f", (t-f-e)/t
  }'
}

# nplus1_free ∈ {0,1} — best-effort: only if the project ships an N+1 assertion test.
metric_nplus1() {
  local xml
  xml=$(find "$GDIR/build/test-results" \( -iname '*nplus1*.xml' -o -iname '*querycount*.xml' \) 2>/dev/null | head -1)
  [ -n "$xml" ] || { echo "skip"; return; }
  local failures errors
  failures=$(grep -oE 'failures="[0-9]+"' "$xml" | head -1 | grep -oE '[0-9]+')
  errors=$(grep -oE 'errors="[0-9]+"' "$xml" | head -1 | grep -oE '[0-9]+')
  [ "${failures:-0}" -eq 0 ] && [ "${errors:-0}" -eq 0 ] && echo "1" || echo "0"
}

# ── weights (override via .claude/eval-weights.json) ──
w_compile=0.15; w_passk=0.25; w_coverage=0.20; w_violations=0.15; w_archrules=0.20; w_nplus1=0.05
WF="$ROOT/.claude/eval-weights.json"
if [ -f "$WF" ]; then
  for kkey in compile passk coverage violations archrules nplus1; do
    v=$(jq -r --arg k "$kkey" '.[$k] // empty' "$WF" 2>/dev/null)
    [ -n "$v" ] && eval "w_$kkey=$v"
  done
fi

# ── run graders ──
m_compile=$(metric_compile)
# 컴파일 실패면 나머지 grader 무의미 — P=0, 조기 종료(테스트 k회 낭비 방지)
if [ "$m_compile" = "0" ]; then
  verdict=$(jq -cn '{verdict:"fail", P:0, error:0, metrics:{compile:0},
                     skipped:["passk","coverage","violations","archrules","nplus1"],
                     reason:"컴파일 실패 — 나머지 metric 무의미"}')
  printf '%s\n' "$verdict"
  [ "$JSON_ONLY" -eq 1 ] || echo "[eval-java] P=0.00 — 컴파일 실패. gradlew compileJava 먼저 통과 필요." >&2
  exit 0
fi
m_passk=$(metric_passk)
m_coverage=$(metric_coverage)
m_violations=$(metric_violations)
m_archrules=$(metric_archrules)
m_nplus1=$(metric_nplus1)

# ── composite P = Σ wᵢ·mᵢ over non-skipped metrics (weights renormalized) ──
# 오차: pass^k가 0<rate<1이면 불안정 → 오차 = w_passk·min(rate,1-rate) 근사(그 외 metric은 결정적).
read -r P ERR SKIPPED < <(awk \
  -v compile="$m_compile" -v passk="$m_passk" -v coverage="$m_coverage" \
  -v violations="$m_violations" -v archrules="$m_archrules" -v nplus1="$m_nplus1" \
  -v wc="$w_compile" -v wp="$w_passk" -v wv="$w_coverage" -v wl="$w_violations" \
  -v wa="$w_archrules" -v wn="$w_nplus1" '
  function add(name, val, w) {
    if (val == "skip") { skipped = skipped (skipped==""?"":",") name; return }
    sum += w * val; wsum += w
    if (name == "passk") { r = val + 0; e = w * (r < 1-r ? r : 1-r) }
  }
  BEGIN {
    add("compile", compile, wc); add("passk", passk, wp); add("coverage", coverage, wv)
    add("violations", violations, wl); add("archrules", archrules, wa); add("nplus1", nplus1, wn)
    P = (wsum > 0) ? sum / wsum : 0
    ERR = (wsum > 0) ? e / wsum : 0
    printf "%.4f %.4f %s", P, ERR, (skipped==""?"-":skipped)
  }')

[ "$SKIPPED" = "-" ] && SKIPPED=""
skipped_json=$(printf '%s' "$SKIPPED" | jq -R 'split(",") | map(select(length>0))')
verdict=$(jq -cn \
  --arg P "$P" --arg ERR "$ERR" \
  --arg compile "$m_compile" --arg passk "$m_passk" --arg coverage "$m_coverage" \
  --arg violations "$m_violations" --arg archrules "$m_archrules" --arg nplus1 "$m_nplus1" \
  --arg k "$K" --argjson skipped "$skipped_json" '
  def num(x): if x=="skip" then null else (x|tonumber) end;
  { verdict: (if ($P|tonumber) >= 0.8 then "pass" elif ($P|tonumber) >= 0.6 then "warn" else "fail" end),
    P: ($P|tonumber), error: ($ERR|tonumber), k: ($k|tonumber),
    metrics: { compile: num($compile), passk: num($passk), coverage: num($coverage),
               violations: num($violations), archrules: num($archrules), nplus1: num($nplus1) },
    skipped: $skipped }')

printf '%s\n' "$verdict"
[ "$JSON_ONLY" -eq 1 ] && exit 0

# human summary — 어떤 축이 P를 끌어내렸는지
{
  echo "[eval-java] P=$(printf '%.2f' "$P") ± $(printf '%.2f' "$ERR")  (k=$K)"
  printf '  compile=%s passk=%s coverage=%s violations=%s archrules=%s nplus1=%s\n' \
    "$m_compile" "$m_passk" "$m_coverage" "$m_violations" "$m_archrules" "$m_nplus1"
  [ -n "$SKIPPED" ] && echo "  skipped(도구 미배선): $SKIPPED — P는 남은 축으로 산출됨"
} >&2
exit 0
