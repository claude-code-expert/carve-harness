// scripts/score.mjs — carve-harness 종합 품질 점수 (레이어 A 자기 채점, 6축 100점).
// 측정기 먼저: 축은 "최종 상태" 기준으로 정의한다 — 개선 전에는 90 미만이 정상이며,
// 각 Phase가 점수를 끌어올려 총점 ≥ 90에 수렴한다. (벤치 6축 문서의 축 5·6을 실행 가능 축으로 구체화)
//
// 실행: node scripts/score.mjs [--json] [--min 90] [--axes tests,quality,audit,antislop,redundancy,template]
//   --axes  일부 축만 실행(테스트 내부에서 tests/quality 축 재귀 spawn 방지용)
//   --min   총점 게이트. 전체 축 실행 시 기본 90, 일부 축 실행 시 명시한 경우에만 게이트.
// 종료 코드: 0 = 게이트 통과(또는 게이트 없음), 1 = 총점 < min.
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync, readFileSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { analyze } from '../src/analyzer.ts';
import { design } from '../src/designer.ts';
import { generate } from '../src/generator.ts';
import { generateClaudeBase } from '../src/claudebase.ts';
import { audit, errorsOf } from '../src/auditor.ts';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const rel = (p) => p.startsWith(ROOT) ? p.slice(ROOT.length) : p;

// ── CLI 인자 ────────────────────────────────────────────────────
const argv = process.argv.slice(2);
const asJson = argv.includes('--json');
const minIdx = argv.indexOf('--min');
const explicitMin = minIdx >= 0 ? Number(argv[minIdx + 1]) : null;
const axesIdx = argv.indexOf('--axes');
const AXIS_NAMES = ['tests', 'quality', 'audit', 'antislop', 'redundancy', 'template'];
const selected = axesIdx >= 0 ? argv[axesIdx + 1].split(',').map((s) => s.trim()).filter(Boolean) : AXIS_NAMES;
for (const a of selected) {
  if (!AXIS_NAMES.includes(a)) {
    console.error(`알 수 없는 축: ${a} (가능: ${AXIS_NAMES.join(',')})`);
    process.exit(2);
  }
}
const allAxes = AXIS_NAMES.every((a) => selected.includes(a));
const gateMin = explicitMin ?? (allAxes ? 90 : null);

// ── 공용 헬퍼 ───────────────────────────────────────────────────
function walk(dir, exts) {
  const out = [];
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, e.name);
    if (e.isDirectory()) out.push(...walk(full, exts));
    else if (exts.some((x) => e.name.endsWith(x))) out.push(full);
  }
  return out;
}
// 대표 TS 웹 프로필 픽스처 (bench/run.mjs와 동일 패턴)
function tmpWeb() {
  const root = mkdtempSync(join(tmpdir(), 'carve-score-'));
  writeFileSync(join(root, 'package.json'), JSON.stringify({ name: 's', scripts: { test: 'vitest', lint: 'eslint .' }, dependencies: { react: '^19' }, devDependencies: { typescript: '^5' } }));
  writeFileSync(join(root, 'tsconfig.json'), '{}');
  return root;
}
// audit·template 축이 공유하는 풀 산출물 1회 생성 캐시 (runTestCov와 동일 패턴)
let artifactsCache = null;
function fullArtifacts() {
  if (artifactsCache) return artifactsCache;
  const root = tmpWeb();
  try {
    const prof = analyze(root);
    const d = design(prof);
    artifactsCache = { artifacts: [...generate(prof, d), ...generateClaudeBase(prof)], profile: prof };
    return artifactsCache;
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

// tests·quality 축이 공유하는 test:cov 1회 실행 캐시
let covResult = null;
function runTestCov() {
  if (!covResult) {
    const r = spawnSync('npm', ['run', 'test:cov'], { encoding: 'utf8', cwd: ROOT, maxBuffer: 64 * 1024 * 1024 });
    const out = (r.stdout ?? '') + (r.stderr ?? '');
    const num = (re) => Number((out.match(re) || [])[1] || 0);
    covResult = {
      status: r.status,
      pass: num(/(?:ℹ|#) pass (\d+)/),
      fail: num(/(?:ℹ|#) fail (\d+)/),
    };
  }
  return covResult;
}

// ── 축 1: 테스트 통과 (25) ─────────────────────────────────────
function axisTests() {
  const { pass, fail } = runTestCov();
  const total = pass + fail;
  const score = total === 0 ? 0 : Math.round((25 * pass) / total);
  return { score, detail: `pass ${pass}/${total}` };
}

// ── 축 2: 코드 품질 (20 = 타입체크 8 + 커버리지 게이트 12) ─────
function axisQuality() {
  const check = spawnSync('npm', ['run', 'check'], { encoding: 'utf8', cwd: ROOT, maxBuffer: 16 * 1024 * 1024 });
  const tsc = check.status === 0 ? 8 : 0;
  const cov = runTestCov().status === 0 ? 12 : 0;
  return { score: tsc + cov, detail: `tsc ${tsc}/8 · 커버리지 게이트(≥80) ${cov}/12 (린트 스크립트 없음 — tsc strict가 프록시)` };
}

// ── 축 3: audit 청결도 (15) ────────────────────────────────────
function axisAudit() {
  const { artifacts } = fullArtifacts();
  const errs = errorsOf(audit(artifacts));
  return { score: errs.length === 0 ? 15 : 0, detail: `풀 디자인 산출물 audit ERROR ${errs.length}건`, errors: errs.map((e) => `${e.path}: ${e.message}`) };
}

// ── 축 4: anti-slop 자기검사 (15, ERROR 파일당 −3) ─────────────
// 금지어를 의도적으로 인용하는 규칙 문서들은 제외(린터 자기참조 방지).
const ANTISLOP_EXCLUDE = [
  'assets/templates/_flight-rules-antislop.md',
  'assets/claude-base/rules/anti-ai-slop.md',
];
function axisAntislop() {
  const files = [
    ...walk(join(ROOT, 'assets/templates'), ['.md']),
    ...walk(join(ROOT, 'assets/claude-base'), ['.md']),
    ...walk(join(ROOT, 'assets/skills'), ['SKILL.md']),
  ].filter((f) => !ANTISLOP_EXCLUDE.includes(rel(f)));
  const r = spawnSync('node', [join(ROOT, 'assets/antislop/clean-html/scripts/check-slop.mjs'), ...files], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
  // 출력 파싱: "── <file> [kind]" 섹션의 "─ N error(s)" 줄로 파일별 ERROR 집계
  const failing = [];
  let current = null;
  for (const line of (r.stdout ?? '').split('\n')) {
    const head = line.match(/^── (.+) \[(?:htmlcss|svg|md)\]$/);
    if (head) { current = head[1]; continue; }
    const sum = line.match(/^\s+─ (\d+) error\(s\)/);
    if (sum && current && Number(sum[1]) > 0) failing.push(rel(current));
  }
  const score = Math.max(0, 15 - 3 * failing.length);
  return { score, detail: `검사 ${files.length}파일 · ERROR 파일 ${failing.length}개`, failing };
}

// ── 축 5: 카탈로그 중복지수 (15, 중복쌍당 −5) ──────────────────
// 정규화 라인셋 Jaccard ≥ 0.5 = 중복쌍. 의도적 요약쌍은 ALLOWED_PAIRS(별도 패리티 테스트가 가드).
const ALLOWED_PAIRS = new Set([
  pairKey('assets/antislop/SKILL.md', 'assets/claude-base/rules/anti-ai-slop.md'),
]);
function pairKey(a, b) {
  return [a, b].sort().join(' | ');
}
function lineSet(file) {
  const out = new Set();
  for (const line of readFileSync(file, 'utf8').split('\n')) {
    const t = line.trim().toLowerCase();
    if (t.length >= 8) out.add(t);
  }
  return out;
}
function jaccard(a, b) {
  let inter = 0;
  for (const x of a) if (b.has(x)) inter++;
  const union = a.size + b.size - inter;
  return union === 0 ? 0 : inter / union;
}
function axisRedundancy() {
  const files = [
    ...walk(join(ROOT, 'assets/skills'), ['SKILL.md']),
    ...walk(join(ROOT, 'assets/squad/agents'), ['.md']),
    join(ROOT, 'assets/antislop/SKILL.md'),
    join(ROOT, 'assets/claude-base/rules/anti-ai-slop.md'),
  ];
  const sets = files.map((f) => ({ file: rel(f), set: lineSet(f) }));
  const pairs = [];
  for (let i = 0; i < sets.length; i++) {
    for (let j = i + 1; j < sets.length; j++) {
      const sim = jaccard(sets[i].set, sets[j].set);
      if (sim >= 0.5 && !ALLOWED_PAIRS.has(pairKey(sets[i].file, sets[j].file))) {
        pairs.push({ a: sets[i].file, b: sets[j].file, jaccard: Math.round(sim * 100) / 100 });
      }
    }
  }
  const score = Math.max(0, 15 - 5 * pairs.length);
  return { score, detail: `비교 ${files.length}파일 · 중복쌍 ${pairs.length}개`, pairs };
}

// ── 축 6: 템플릿 완전성 (10 = 잔여변수 4 + 채점표 3 + Plan Quality 3) ──
function axisTemplate() {
  const { artifacts } = fullArtifacts();
  const residual = artifacts.filter((a) => /\{\{\w+\}\}/.test(a.content)).map((a) => a.path);
  const noResidual = residual.length === 0 ? 4 : 0;
  const evalArt = artifacts.find((a) => a.path === 'evaluation-criteria.md');
  const hasScoreTable = evalArt && /채점표/.test(evalArt.content) && /≥\s*90/.test(evalArt.content) ? 3 : 0;
  const contract = artifacts.find((a) => a.path === 'sprint-contract.md');
  const hasPlanQuality = contract && ['검증가능성', '범위 명확성', '위험·롤백'].every((k) => contract.content.includes(k)) ? 3 : 0;
  return {
    score: noResidual + hasScoreTable + hasPlanQuality,
    detail: `잔여 {{변수}} ${noResidual}/4 · evaluation 채점표(100점·≥90) ${hasScoreTable}/3 · Plan Quality 3기준 ${hasPlanQuality}/3`,
    residual,
  };
}

// ── 실행·집계 ───────────────────────────────────────────────────
const RUNNERS = { tests: axisTests, quality: axisQuality, audit: axisAudit, antislop: axisAntislop, redundancy: axisRedundancy, template: axisTemplate };
const MAX = { tests: 25, quality: 20, audit: 15, antislop: 15, redundancy: 15, template: 10 };

const axes = {};
let total = 0;
let max = 0;
for (const name of AXIS_NAMES) {
  if (!selected.includes(name)) continue;
  const r = RUNNERS[name]();
  axes[name] = { max: MAX[name], ...r };
  total += r.score;
  max += MAX[name];
}
const pass = gateMin === null ? true : total >= gateMin;

if (asJson) {
  console.log(JSON.stringify({ axes, total, max, min: gateMin, pass }, null, 2));
} else {
  console.log('=== carve-harness 품질 점수 ===');
  for (const [name, a] of Object.entries(axes)) {
    console.log(`${name.padEnd(10)} ${String(a.score).padStart(3)}/${a.max}  ${a.detail}`);
    if (a.failing?.length) for (const f of a.failing) console.log(`           · slop ERROR: ${f}`);
    if (a.pairs?.length) for (const p of a.pairs) console.log(`           · 중복쌍(J=${p.jaccard}): ${p.a} ↔ ${p.b}`);
    if (a.errors?.length) for (const e of a.errors) console.log(`           · audit: ${e}`);
    if (a.residual?.length) for (const p of a.residual) console.log(`           · 잔여 변수: ${p}`);
  }
  console.log(`총점: ${total}/${max}${gateMin !== null ? ` (게이트 ${gateMin}: ${pass ? 'PASS' : 'FAIL'})` : ''}`);
}
process.exit(pass ? 0 : 1);
