// test/unit/metrics.test.ts — opt-in 로컬 텔레메트리 검증 (M10, TELEM-01..03).
// 차단 로직 불변(opt-out no-op) + opt-in emit + 리댁션 + no-network + bash -n.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { mkdtempSync, mkdirSync, rmSync, existsSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const hook = (name: string) =>
  fileURLToPath(new URL(`../../assets/hooks/${name}`, import.meta.url));

// 계측 대상 헬퍼 + 6개 효과 훅.
const HELPER = '_metrics.sh';
const HOOKS = [
  'block-destructive.sh', 'protect-secrets.sh', 'pre-commit-lint.sh',
  'pre-push-test.sh', 'auto-format.sh', 'anti-slop.sh',
];

const DANGER = 'rm -rf /';
const payload = JSON.stringify({ tool_input: { command: DANGER } });

// ── opt-out (기본 OFF): 차단(exit 2)은 그대로, jsonl은 안 생김 ──
test('opt-out 기본 OFF: block-destructive 여전히 exit 2 + jsonl 미생성', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'carve-metrics-'));
  try {
    const env = { ...process.env };
    delete env.CARVE_METRICS;
    const r = spawnSync('bash', [hook('block-destructive.sh')], {
      input: payload, encoding: 'utf8', cwd, env,
    });
    assert.equal(r.status, 2); // 차단 불변
    assert.equal(existsSync(join(cwd, '.claude', '.carve-metrics.jsonl')), false);
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

// ── opt-in (CARVE_METRICS=on): exit 2 그대로 + jsonl 한 줄(리댁션) ──
test('opt-in CARVE_METRICS=on: exit 2 + 리댁션된 {ts,hook,event} 한 줄', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'carve-metrics-'));
  mkdirSync(join(cwd, '.claude'), { recursive: true });
  try {
    const r = spawnSync('bash', [hook('block-destructive.sh')], {
      input: payload, encoding: 'utf8', cwd,
      env: { ...process.env, CARVE_METRICS: 'on' },
    });
    assert.equal(r.status, 2); // 차단 불변
    const jsonl = join(cwd, '.claude', '.carve-metrics.jsonl');
    assert.ok(existsSync(jsonl));
    const lines = readFileSync(jsonl, 'utf8').split('\n').filter((l) => l.trim());
    assert.equal(lines.length, 1);
    const line = lines[0];
    assert.ok(line);
    const obj = JSON.parse(line);
    assert.deepEqual(Object.keys(obj).sort(), ['event', 'hook', 'ts']);
    assert.equal(obj.hook, 'block-destructive');
    assert.equal(obj.event, 'block');
    assert.equal(typeof obj.ts, 'number');
    // 리댁션: 위험 명령 본문이 절대 기록되지 않는다.
    assert.equal(line.includes('rm -rf'), false);
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

// ── no-network: 헬퍼 + 6개 훅에 curl/wget/nc 없음 ──
test('no-network: _metrics.sh + 6개 훅에 curl/wget/nc 없음', () => {
  for (const f of [HELPER, ...HOOKS]) {
    const src = readFileSync(hook(f), 'utf8');
    assert.equal(/curl|wget|[^a-z]nc[^a-z]/.test(src), false, `${f} contains network call`);
  }
});

// ── bash -n: 헬퍼 + 6개 훅 문법 OK ──
for (const f of [HELPER, ...HOOKS]) {
  test(`${f} bash 문법 OK`, () => {
    assert.equal(spawnSync('bash', ['-n', hook(f)]).status, 0);
  });
}
