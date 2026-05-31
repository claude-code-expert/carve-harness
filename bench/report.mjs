// bench/report.mjs — bench/results/*.json(하네스별 측정)을 §7 스코어카드로 합산.
// 입력 스키마(파일당 1 하네스, 측정 반복은 배열로):
//   { "harness":"carve", "tokensPerTask":[..], "costPerTask":[..], "e2ePass":[..%], "blockLeak":[..%] }
// 라이브 실측 데이터가 없으면 안내만 출력한다(추정 금지).
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const DIR = fileURLToPath(new URL('./results/', import.meta.url));
const median = (a) => {
  if (!a || a.length === 0) return null;
  const s = [...a].sort((x, y) => x - y);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};

const files = existsSync(DIR) ? readdirSync(DIR).filter((f) => f.endsWith('.json')) : [];
if (files.length === 0) {
  console.log('measured 데이터 없음 — bench/results/<harness>.json 생성 후 재실행.');
  console.log('하네스: No-Harness · OpenHarness · ECC · Squad · carve (각 n>=5).');
  console.log('수집: npx ccusage@latest (토큰·$), /context (점유율). 추정치 기재 금지.');
  process.exit(0);
}

const rows = files.map((f) => {
  const d = JSON.parse(readFileSync(DIR + f, 'utf8'));
  return {
    harness: d.harness ?? f.replace(/\.json$/, ''),
    tok: median(d.tokensPerTask),
    cost: median(d.costPerTask),
    e2e: median(d.e2ePass),
    leak: median(d.blockLeak),
  };
});

const cell = (v, unit = '') => (v == null ? '—' : `${v}${unit}`);
console.log('\n=== 스코어카드 (중앙값, n>=5) ===');
console.log('harness        | 토큰/태스크 | $/태스크 | E2E PASS% | 누출%');
console.log('---------------|-------------|----------|-----------|------');
for (const r of rows) {
  console.log(
    `${r.harness.padEnd(14)} | ${cell(r.tok).padEnd(11)} | ${cell(r.cost).padEnd(8)} | ${cell(r.e2e, '%').padEnd(9)} | ${cell(r.leak, '%')}`,
  );
}
console.log('\n해석 규칙(기준 §7): carve가 모든 축 1위일 필요 없음 — 효율·구성정확도 우위 + 안전·기능 동등이면 "맞춤 경량" 입증.');
