#!/usr/bin/env bash
# test-all.sh — 구성요소 스크립트 전체 + 테스트 스위트 + 6축 벤치를 순차 실행.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

for s in test-hooks test-antislop test-squad test-install; do
  echo ""; echo "════════ $s.sh ════════"
  bash "$ROOT/scripts/$s.sh" || fail=1
done

echo ""; echo "════════ npm test (단위+E2E) ════════"
( cd "$ROOT" && npm test ) >/tmp/_carve_npmtest.log 2>&1 \
  && grep -E '^ℹ (tests|pass|fail)' /tmp/_carve_npmtest.log || { cat /tmp/_carve_npmtest.log; fail=1; }
rm -f /tmp/_carve_npmtest.log

echo ""; echo "════════ bench/run.mjs (6축 점수) ════════"
( cd "$ROOT" && node --disable-warning=ExperimentalWarning bench/run.mjs 2>/dev/null | sed -n '/축별 점수/,$p' ) || fail=1

echo ""; [ "$fail" -eq 0 ] && echo "✅ 전체 통과" || echo "❌ 일부 실패"
exit $fail
