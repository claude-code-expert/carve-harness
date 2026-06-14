// bench/collect.mjs — 라이브 측정 수집 파서 (축 1 효율 · 축 4 컨텍스트, M11-A3).
// 라이브 호출(claude/ccusage)은 하지 않는다 — stdin/파일로 받은 출력만 파싱한다(결정론·테스트 가능).
// 인식 못 한 입력은 빈 값으로 둔다(추정 금지 — 측정값만, criteria §10).
//
// 사용(라이브):
//   npx ccusage@latest --json | node bench/collect.mjs ccusage      → {tokensPerTask, costPerTask}
//   pbpaste | node bench/collect.mjs context                        → {contextOccupancy}
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const num = (v) => (typeof v === 'number' && Number.isFinite(v) ? v : null);

/**
 * ccusage --json 출력에서 태스크별 토큰·비용을 추출한다.
 * ccusage 스키마가 버전마다 달라 방어적으로 흡수한다: sessions/daily/blocks/data 중 첫 배열,
 * 또는 top-level 배열. 각 행에서 totalTokens|tokens|total_tokens, totalCost|cost|total_cost.
 */
export function parseCcusage(input) {
  let data;
  try {
    data = typeof input === 'string' ? JSON.parse(input) : input;
  } catch {
    return { tokensPerTask: [], costPerTask: [] };
  }
  const rows = [data?.sessions, data?.daily, data?.blocks, data?.data, Array.isArray(data) ? data : null]
    .find((x) => Array.isArray(x)) ?? [];
  const tokensPerTask = [];
  const costPerTask = [];
  for (const r of rows) {
    const tok = num(r?.totalTokens) ?? num(r?.tokens) ?? num(r?.total_tokens);
    const cost = num(r?.totalCost) ?? num(r?.cost) ?? num(r?.total_cost);
    if (tok !== null) tokensPerTask.push(tok);
    if (cost !== null) costPerTask.push(Math.round(cost * 1e4) / 1e4);
  }
  return { tokensPerTask, costPerTask };
}

/**
 * Claude Code /context 출력에서 컨텍스트 점유율(%)을 추출한다.
 * 우선 명시 백분율(예 "(23%)") → 없으면 "used / total" 비율 계산. 인식 못 하면 null(추정 금지).
 */
export function parseContext(text) {
  if (typeof text !== 'string') return null;
  const pct = text.match(/(\d+(?:\.\d+)?)\s*%/);
  if (pct) return Math.round(Number(pct[1]) * 10) / 10;
  const ratio = text.match(/([\d,]+)\s*\/\s*([\d,]+)/);
  if (ratio) {
    const used = Number(ratio[1].replace(/,/g, ''));
    const total = Number(ratio[2].replace(/,/g, ''));
    if (total > 0) return Math.round((used / total) * 1000) / 10;
  }
  return null;
}

// CLI: node bench/collect.mjs <ccusage|context> [file]  (file 없으면 stdin)
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const mode = process.argv[2];
  const file = process.argv[3];
  const input = file ? readFileSync(file, 'utf8') : readFileSync(0, 'utf8');
  if (mode === 'ccusage') {
    console.log(JSON.stringify(parseCcusage(input)));
  } else if (mode === 'context') {
    console.log(JSON.stringify({ contextOccupancy: parseContext(input) }));
  } else {
    console.error('사용법: node bench/collect.mjs <ccusage|context> [file]  (file 없으면 stdin)');
    process.exit(1);
  }
}
