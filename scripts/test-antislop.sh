#!/usr/bin/env bash
# test-antislop.sh — anti-slop 린터 단위 테스트. check-slop.mjs → exit 1(위반)/0(clean).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINT="$ROOT/.claude/skills/clean-html/scripts/check-slop.mjs"
FX="$ROOT/test/fixtures/slop"
PASS=0; FAIL=0
ok(){ printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
no(){ printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

# chk <name> <expected-exit> <fixture>
chk(){
  local name="$1" exp="$2" f="$3" got
  node "$LINT" "$FX/$f" >/dev/null 2>&1; got=$?
  if [ "$got" = "$exp" ]; then ok "$name (exit $got)"; else no "$name (exit $got, 기대 $exp)"; fi
}

echo "== 슬롭 = 위반(1) / 클린 = 통과(0) =="
chk "슬롭 SVG (그라데이션·blur)" 1 slop.svg
chk "클린 SVG (평면·팔레트)"     0 clean.svg
chk "슬롭 MD (마케팅·이모지)"    1 slop.md
chk "클린 MD"                    0 clean.md
chk "슬롭 HTML (gradient·keyframes)" 1 slop.html
chk "클린 HTML"                  0 clean.html
chk "슬롭 CSS (그림자·모션 등)"  1 slop.css

echo ""; echo "결과: $PASS PASS / $FAIL FAIL"; [ "$FAIL" -eq 0 ]
