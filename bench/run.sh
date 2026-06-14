#!/usr/bin/env bash
# bench/run.sh — carve-harness 벤치 오케스트레이터.
#   1) 결정론적 자기측정(run.mjs)  2) 축2 carve↔no-harness 결정적 비교
#   3) 라이브 비교(축 1·3·4·5 cross-harness)는 harnesses/·tasksets/ 셋업 + API 필요(안내).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$ROOT/assets/hooks"; S="$ROOT/bench/seeds"

echo "═══ 1) 자기측정 (결정론, node bench/run.mjs) ═══"
node --disable-warning=ExperimentalWarning "$ROOT/bench/run.mjs" 2>/dev/null | sed -n '/축별 점수/,$p'

echo ""; echo "═══ 2) 축 2 결정적 비교 — carve(결정적 훅) vs no-harness(권고만) ═══"
blocked=0; total=0
while IFS= read -r c; do
  [ -z "$c" ] && continue; total=$((total+1))
  echo "{\"tool_input\":{\"command\":\"$c\"}}" | bash "$H/block-destructive.sh" >/dev/null 2>&1 || blocked=$((blocked+1))
done < "$S/danger.txt"
while IFS= read -r p; do
  [ -z "$p" ] && continue; total=$((total+1))
  echo "{\"tool_input\":{\"file_path\":\"$p\"}}" | bash "$H/protect-secrets.sh" >/dev/null 2>&1 || blocked=$((blocked+1))
done < "$S/secret-bad.txt"
carve_leak=$(( (total - blocked) * 100 / total ))
echo "  carve:      위험 ${total}건 중 ${blocked}건 차단 → 누출률 ${carve_leak}%"
echo "  no-harness: 훅 없음 → 0건 차단 → 누출률 100% (CLAUDE.md 권고만, 결정적 차단 부재)"
echo "  → 차별점: 'exit code 2가 유일한 진짜 차단 수단' (누출 ${carve_leak}% vs 100%)"

echo ""; echo "═══ 3) 트리거 정확도 (결정적, bench/test-trigger.sh) ═══"
bash "$ROOT/bench/test-trigger.sh"

echo ""; echo "═══ 4) 라이브 비교 (보류 — 셋업·API 필요) ═══"
echo "  축 1(토큰·\$·시간)·4(컨텍스트 점유율)·cross-harness 5(E2E)는 LLM 실행 필요:"
echo "   1. bench/harnesses/README.md 따라 A~E 환경 셋업"
echo "   2. bench/tasksets/{crud,multi,refactor,explore}.md 를 각 하네스로 n>=5 실행"
echo "      (대형 코드베이스 무대: node bench/gen-fixture.mjs --modules 200 --out <dir>)"
echo "   3. 수집 → bench/results/<harness>.json (스키마: report.mjs 헤더):"
echo "        npx ccusage@latest --json | node bench/collect.mjs ccusage   # 토큰·\$"
echo "        <\"/context\" 출력> | node bench/collect.mjs context           # 컨텍스트 점유율(축4)"
echo "   4. node bench/report.mjs → 스코어카드(중앙값·IQR, 트리거·컨텍스트 열 포함)"
