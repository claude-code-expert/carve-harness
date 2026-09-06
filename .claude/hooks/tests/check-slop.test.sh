#!/usr/bin/env bash
# Assertions for check-slop.mjs (anti-ai-slop deterministic linter).
# Executes the REAL linter against per-rule fixtures — never re-implements a rule.
# Covers: the exit-code contract (0/1/2), every ERROR rule firing at least once,
# the integer/ratio boundaries where an off-by-one silently flips a verdict, and
# the extension dispatch (htmlcss · svg · md).
#
# Boundary values are the point of this suite. A linter that reports `radius 9px`
# but not `9px` — or that flips ERROR/WARN one step early — is worse than none:
# it produces confident wrong verdicts. Contrast thresholds were computed from the
# WCAG relative-luminance formula (#949494 = 3.033:1 WARN, #959595 = 2.995:1 ERROR).
#
# node-gated: the linter is Node; the suite skips cleanly when node is absent.

HOOK="$(cd "$(dirname "$0")/../../.." && pwd)/.claude/hooks/check-slop.mjs"
fail=0
pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

[ -f "$HOOK" ] && ok "check-slop.mjs present" || { no "check-slop.mjs missing"; }

if ! command -v node >/dev/null 2>&1; then
  echo "SKIP: node not found — linter assertions require Node"
  printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ]; exit
fi

W=$(mktemp -d)
out=''; RC=0

scan() {  # <file> — run linter, capture output + exit code
  out=$(node "$HOOK" "$1" 2>&1); RC=$?
}
errs() {  # <rule> — rule fired at ERROR severity?
  printf '%s' "$out" | grep -q "ERROR.*\[$1\]"
}
warns() { # <rule> — rule fired at WARN severity?
  printf '%s' "$out" | grep -q "warn .*\[$1\]"
}

# fires <label> <rule> <file> — the fixture must trip <rule> as ERROR and exit 1
fires() {
  scan "$3"
  if errs "$2" && [ "$RC" -eq 1 ]; then ok "$1"
  else no "$1 (rc=$RC) — $(printf '%s' "$out" | grep -c ERROR) error(s)"; fi
}

css() {   # <name> — wrap stdin as an html file, echo its path
  local p="$W/$1"
  { echo '<!doctype html><html><head><style>'; cat; echo '</style></head><body><p>x</p></body></html>'; } > "$p"
  printf '%s' "$p"
}

# ── (1) exit-code contract ───────────────────────────────────────────────
out=$(node "$HOOK" 2>&1); RC=$?
[ "$RC" -eq 2 ] && ok "no args -> exit 2" || no "no args expected 2, got $RC"

out=$(node "$HOOK" "$W/does-not-exist.html" 2>&1); RC=$?
[ "$RC" -eq 2 ] && ok "unreadable file -> exit 2" || no "unreadable expected 2, got $RC"

printf '<!doctype html><html><body><p>Plain text.</p></body></html>' > "$W/clean.html"
scan "$W/clean.html"
[ "$RC" -eq 0 ] && ok "clean file -> exit 0" || no "clean expected 0, got $RC ($out)"

printf '%s' "$out" | grep -q '\[carve-harness:check-slop\]' \
  && ok "output carries the harness prefix" || no "harness prefix missing"

# ── (2) every ERROR rule fires ───────────────────────────────────────────
fires "gradient"        gradient        "$(echo '.a{background:linear-gradient(90deg,#a5f,#e59)}' | css g.html)"
fires "gradient-text"   gradient-text   "$(echo '.a{background-clip:text}'                        | css gt.html)"
fires "glassmorphism"   glassmorphism   "$(echo '.a{backdrop-filter:blur(8px)}'                   | css gm.html)"
fires "colored-shadow"  colored-shadow  "$(echo '.a{box-shadow:0 1px 2px rgba(236,72,153,.5)}'    | css cs.html)"
fires "big-shadow"      big-shadow      "$(echo '.a{box-shadow:0 0 24px rgba(0,0,0,.06)}'         | css bs.html)"
fires "gloss-ring"      gloss-ring      "$(echo '.a{box-shadow:inset 0 1px 0 rgba(255,0,0,.4)}'   | css gr.html)"
fires "accent-bar"      accent-bar      "$(echo '.a{border-top:4px solid #2563eb}'                | css ab.html)"
fires "slow-transition" slow-transition "$(echo '.a{transition:color 300ms ease}'                 | css st.html)"
fires "motion-decor"    motion-decor    "$(echo '.a{animation:pulse 2s infinite}'                 | css md.html)"
fires "keyframes"       keyframes       "$(echo '@keyframes pulse{from{opacity:0}}'               | css kf.html)"
fires "hover-transform" hover-transform "$(echo '.a:hover{transform:translateY(-4px)}'            | css ht.html)"
fires "radius-cap"      radius-cap      "$(echo '.a{border-radius:16px}'                          | css rc.html)"
fires "tiny-font"       tiny-font       "$(echo '.a{font-size:8px}'                               | css tf.html)"

printf '<!doctype html><html><body><h1>Seamlessly Elevate your workflow</h1></body></html>' > "$W/mk.html"
fires "marketing (en)"  marketing  "$W/mk.html"
printf '<!doctype html><html><body><p>차원이 다른 경험</p></body></html>' > "$W/mkko.html"
fires "marketing (ko)"  marketing  "$W/mkko.html"

fires "contrast-aa" contrast-aa "$(echo '.a{color:#959595;background:#FFFFFF}' | css ca.html)"

# ── (3) boundaries — one step apart must flip the verdict ────────────────
scan "$(echo '.a{border-radius:8px}' | css r8.html)"
[ "$RC" -eq 0 ] && ok "radius 8px clean (cap boundary)" || no "radius 8px should pass ($out)"
scan "$(echo '.a{border-radius:9px}' | css r9.html)"
errs radius-cap && ok "radius 9px -> ERROR" || no "radius 9px should fail"

scan "$(echo '.a{font-size:10px}' | css f10.html)"
! errs tiny-font && warns tiny-font && ok "font 10px -> WARN not ERROR" || no "font 10px band wrong ($out)"
scan "$(echo '.a{font-size:9px}' | css f9.html)"
errs tiny-font && ok "font 9px -> ERROR" || no "font 9px should fail"

scan "$(echo '.a{transition:color 150ms ease}' | css t150.html)"
! errs slow-transition && ok "transition 150ms clean" || no "150ms should pass ($out)"
scan "$(echo '.a{transition:color 151ms ease}' | css t151.html)"
errs slow-transition && ok "transition 151ms -> ERROR" || no "151ms should fail"

scan "$(echo '.a{box-shadow:0 0 19px rgba(0,0,0,.06)}' | css s19.html)"
! errs big-shadow && ok "shadow blur 19px clean" || no "19px should pass ($out)"
scan "$(echo '.a{box-shadow:0 0 20px rgba(0,0,0,.06)}' | css s20.html)"
errs big-shadow && ok "shadow blur 20px -> ERROR" || no "20px should fail"

scan "$(echo '.a{color:#949494;background:#FFFFFF}' | css c30.html)"
! errs contrast-aa && warns contrast-aa && ok "contrast 3.03:1 -> WARN not ERROR" || no "3.03 band wrong ($out)"
scan "$(echo '.a{color:#767676;background:#FFFFFF}' | css c45.html)"
! errs contrast-aa && ! warns contrast-aa && ok "contrast 4.54:1 clean (AA boundary)" || no "4.54 should pass ($out)"

printf 'Wow! Great! Nice! Fine!\n' > "$W/x4.md"
scan "$W/x4.md"
! errs exclamation && warns exclamation && ok "4 exclamations -> WARN not ERROR" || no "4-excl band wrong ($out)"
printf 'Wow! Great! Nice! Fine! Done!\n' > "$W/x5.md"
scan "$W/x5.md"
errs exclamation && ok "5 exclamations -> ERROR" || no "5 exclamations should fail"

# ── (4) extension dispatch ───────────────────────────────────────────────
scan "$W/clean.html"
printf '%s' "$out" | grep -q '\[htmlcss\]' && ok "dispatch .html -> htmlcss" || no "html dispatch ($out)"

printf '<svg viewBox="0 0 10 10"><defs><linearGradient id="g"/></defs></svg>' > "$W/a.svg"
scan "$W/a.svg"
printf '%s' "$out" | grep -q '\[svg\]' && errs gradient \
  && ok "dispatch .svg -> svg rules (gradient element)" || no "svg dispatch ($out)"

printf '<svg viewBox="0 0 10 10"><filter><feGaussianBlur stdDeviation="6"/></filter></svg>' > "$W/f.svg"
fires "svg-filter" svg-filter "$W/f.svg"

printf '<svg><rect fill="#111"/></svg>' > "$W/nv.svg"
scan "$W/nv.svg"
warns svg-viewbox && ok "svg without viewBox -> WARN" || no "viewBox check ($out)"

printf 'Text with a gradient: linear-gradient(90deg,#fff,#000) is fine in prose.\n' > "$W/p.md"
scan "$W/p.md"
printf '%s' "$out" | grep -q '\[md\]' && [ "$RC" -eq 0 ] \
  && ok "dispatch .md -> md rules (css text not flagged)" || no "md dispatch ($out)"

# ── (5) md code fences are exempt across ALL scans ──────────────────────
# REGRESSION: marketing/superlative/emoji used to ignore fences while the copy-tone
# scans honoured them, so a rule document listing its own banned words scored ERROR
# — the linter failed its own skill docs. The fence convention must be one rule.
printf 'Banned words:\n\n```text\nseamlessly, elevate, empower, 차원이 다른\n```\n' > "$W/fenced.md"
scan "$W/fenced.md"
[ "$RC" -eq 0 ] && ok "marketing words inside an md fence are exempt" || no "fence exemption ($out)"

printf 'This will seamlessly elevate your workflow.\n' > "$W/unfenced.md"
scan "$W/unfenced.md"
errs marketing && ok "marketing outside a fence still ERROR" || no "fence fix over-suppressed"

# ── (6) HTML/CSS rules must not fire on prose that merely mentions them ──
printf 'The rule bans box-shadow with color and @keyframes animations.\n' > "$W/doc.md"
scan "$W/doc.md"
[ "$RC" -eq 0 ] && ok "md prose mentioning css rules stays clean" || no "md false positive ($out)"

rm -rf "$W"
printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
