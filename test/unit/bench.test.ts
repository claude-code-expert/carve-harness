// test/unit/bench.test.ts — 벤치 측정 인프라 검증 (M11 Phase A).
// bench/*.mjs·*.sh는 tsconfig include 밖(런타임 외부 도구)이라, check-slop 관례대로
// 서브프로세스(process.execPath / bash)로 실행해 stdout·exit code를 검증한다(import 안 함 → tsc 무관).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const bench = (rel: string) => fileURLToPath(new URL(`../../bench/${rel}`, import.meta.url));
const COLLECT = bench('collect.mjs');
const GENFIX = bench('gen-fixture.mjs');
const REPORT = bench('report.mjs');
const TRIGGER = bench('test-trigger.sh');

const node = (script: string, args: string[], input?: string) =>
  spawnSync(process.execPath, [script, ...args], { input, encoding: 'utf8' });

// ── collect.mjs: ccusage·context 순수 파서 ──

test('collect ccusage: sessions 토큰·비용 추출', () => {
  const input = JSON.stringify({ sessions: [{ totalTokens: 1000, totalCost: 0.12 }, { totalTokens: 2000, totalCost: 0.24 }] });
  const r = node(COLLECT, ['ccusage'], input);
  assert.equal(r.status, 0);
  const out = JSON.parse(r.stdout);
  assert.deepEqual(out.tokensPerTask, [1000, 2000]);
  assert.deepEqual(out.costPerTask, [0.12, 0.24]);
});

test('collect ccusage: 손상 JSON → 빈 배열(추정 금지)', () => {
  const r = node(COLLECT, ['ccusage'], '{ not json');
  assert.equal(r.status, 0);
  assert.deepEqual(JSON.parse(r.stdout), { tokensPerTask: [], costPerTask: [] });
});

test('collect context: 명시 백분율·used/total 비율·미인식 null', () => {
  assert.equal(JSON.parse(node(COLLECT, ['context'], 'Context: 45,231 / 200,000 tokens (23%)').stdout).contextOccupancy, 23);
  assert.equal(JSON.parse(node(COLLECT, ['context'], '45000 / 90000 used').stdout).contextOccupancy, 50);
  assert.equal(JSON.parse(node(COLLECT, ['context'], 'no numbers here').stdout).contextOccupancy, null);
});

// ── gen-fixture.mjs: 결정적 생성 ──

test('gen-fixture --print: 같은 (modules,seed) → 동일 출력(결정론)', () => {
  const a = node(GENFIX, ['--print', '--modules', '5', '--seed', '1']);
  const b = node(GENFIX, ['--print', '--modules', '5', '--seed', '1']);
  assert.equal(a.status, 0);
  assert.equal(a.stdout, b.stdout);
});

test('gen-fixture --print: 다른 seed → 다른 참조 그래프', () => {
  const a = node(GENFIX, ['--print', '--modules', '8', '--seed', '1']);
  const b = node(GENFIX, ['--print', '--modules', '8', '--seed', '2']);
  assert.notEqual(a.stdout, b.stdout);
});

// ── report.mjs: 축 3·4 열 + 하위호환 ──

test('report: 트리거·컨텍스트 열 + 신필드 중앙값 + 구 4필드 하위호환(—)', () => {
  const dir = mkdtempSync(join(tmpdir(), 'carve-bench-rep-'));
  try {
    // 신필드 포함(carve): trigger median(100,100)=100, ctx median(20,30)=25
    writeFileSync(join(dir, 'carve.json'), JSON.stringify({
      harness: 'carve', tokensPerTask: [7000], costPerTask: [0.15],
      triggerAccuracy: [100, 100], contextOccupancy: [20, 30],
    }));
    // 구 4필드(old): trigger·ctx 없음 → '—'
    writeFileSync(join(dir, 'old.json'), JSON.stringify({
      harness: 'old', tokensPerTask: [3000], e2ePass: [100], blockLeak: [0],
    }));
    const r = node(REPORT, [dir]);
    assert.equal(r.status, 0);
    assert.match(r.stdout, /트리거%/);
    assert.match(r.stdout, /컨텍스트%/);
    assert.match(r.stdout, /carve[^\n]*100%[^\n]*25%/); // 신필드 중앙값
    assert.match(r.stdout, /old[^\n]*—/);               // 미측정 → —
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

// ── test-trigger.sh: 결정적 라우팅 정확도 ──

test('test-trigger.sh: bash 문법 OK', () => {
  assert.equal(spawnSync('bash', ['-n', TRIGGER]).status, 0);
});

test('test-trigger.sh: 라우팅 정확도 100% · 오발화 0% (jq 있을 때만)', () => {
  const r = spawnSync('bash', [TRIGGER], { encoding: 'utf8' });
  assert.equal(r.status, 0);
  if (r.stdout.includes('jq 없음')) return; // graceful skip — 환경에 jq 없음
  assert.match(r.stdout, /라우팅 정확도:.*= 100%/);
  assert.match(r.stdout, /오발화율:.*= 0%/);
});
