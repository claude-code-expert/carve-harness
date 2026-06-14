// bench/report.mjs — bench/results/*.json(하네스별 측정)을 §7 스코어카드로 합산.
// 입력 스키마(파일당 1 하네스, 측정 반복은 배열로):
//   { "harness":"carve", "tokensPerTask":[..], "costPerTask":[..], "e2ePass":[..%], "blockLeak":[..%],
//     "triggerAccuracy":[..%], "contextOccupancy":[..%] }   // 뒤 2필드는 옵셔널(축 3·4, M11-A4)
// 라이브 실측 데이터가 없으면 안내만 출력한다(추정 금지).
// 사용: node bench/report.mjs [resultsDir]   (생략 시 bench/results/)
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const median = (a) => {
  if (!a || a.length === 0) return null;
  const s = [...a].sort((x, y) => x - y);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};

/** 결과 객체 배열 → 스코어카드 행(중앙값). 축 1(토큰·$)·3(트리거)·4(컨텍스트)·5(E2E)·2(누출). */
export function summarize(datas) {
  return datas.map((d) => ({
    harness: d.harness ?? 'unknown',
    tok: median(d.tokensPerTask),
    cost: median(d.costPerTask),
    trigger: median(d.triggerAccuracy),
    ctx: median(d.contextOccupancy),
    e2e: median(d.e2ePass),
    leak: median(d.blockLeak),
  }));
}

/** 행 배열 → 사람이 읽는 표 문자열. 미측정 필드는 '—'(추정 금지). */
export function render(rows) {
  const cell = (v, unit = '') => (v == null ? '—' : `${v}${unit}`);
  const out = [
    '\n=== 스코어카드 (중앙값, n>=5) ===',
    'harness        | 토큰/태스크 | $/태스크 | 트리거% | 컨텍스트% | E2E PASS% | 누출%',
    '---------------|-------------|----------|---------|-----------|-----------|------',
  ];
  for (const r of rows) {
    out.push(
      `${r.harness.padEnd(14)} | ${cell(r.tok).padEnd(11)} | ${cell(r.cost).padEnd(8)} | `
      + `${cell(r.trigger, '%').padEnd(7)} | ${cell(r.ctx, '%').padEnd(9)} | `
      + `${cell(r.e2e, '%').padEnd(9)} | ${cell(r.leak, '%')}`,
    );
  }
  out.push('\n해석 규칙(기준 §7): carve가 모든 축 1위일 필요 없음 — 효율·구성정확도 우위 + 안전·기능 동등이면 "맞춤 경량" 입증.');
  return out.join('\n');
}

// CLI
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const dir = process.argv[2]
    ? resolve(process.argv[2])
    : fileURLToPath(new URL('./results/', import.meta.url));
  const files = existsSync(dir) ? readdirSync(dir).filter((f) => f.endsWith('.json')) : [];
  if (files.length === 0) {
    console.log('measured 데이터 없음 — bench/results/<harness>.json 생성 후 재실행.');
    console.log('하네스: No-Harness · OpenHarness · ECC · Squad · carve (각 n>=5).');
    console.log('수집: node bench/collect.mjs (ccusage 토큰·$ · /context 점유율). 추정치 기재 금지.');
    process.exit(0);
  }
  const datas = files.map((f) => JSON.parse(readFileSync(resolve(dir, f), 'utf8')));
  console.log(render(summarize(datas)));
}
