// test/unit/score.test.ts — 종합 품질 점수 스크립트(scripts/score.mjs) 검증.
// tests/quality 축은 npm test를 재귀 spawn하므로 여기서는 절대 실행하지 않는다(--axes로 제외).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const SCORE = fileURLToPath(new URL('../../scripts/score.mjs', import.meta.url));
const CHEAP_AXES = 'audit,antislop,redundancy,template';

function score(...args: string[]) {
  return spawnSync(process.execPath, [SCORE, ...args], { encoding: 'utf8' });
}

test('score --json --axes: 선택 축별 점수 + total/max 출력', () => {
  const r = score('--json', '--axes', CHEAP_AXES);
  const j = JSON.parse(r.stdout) as {
    axes: Record<string, { score: number; max: number }>;
    total: number; max: number; min: number | null; pass: boolean;
  };
  assert.deepEqual(Object.keys(j.axes).sort(), ['antislop', 'audit', 'redundancy', 'template']);
  for (const a of Object.values(j.axes)) {
    assert.equal(typeof a.score, 'number');
    assert.ok(a.score >= 0 && a.score <= a.max);
  }
  assert.equal(j.max, 55); // audit 15 + antislop 15 + redundancy 15 + template 10
  assert.equal(j.total, Object.values(j.axes).reduce((s, a) => s + a.score, 0));
  // 일부 축 실행 + --min 미지정 → 게이트 없음(exit 0)
  assert.equal(j.min, null);
  assert.equal(r.status, 0);
});

test('score --min 초과 게이트 → exit 1', () => {
  const r = score('--json', '--axes', CHEAP_AXES, '--min', '101');
  assert.equal(r.status, 1);
  const j = JSON.parse(r.stdout) as { pass: boolean; min: number };
  assert.equal(j.pass, false);
  assert.equal(j.min, 101);
});

test('알 수 없는 축 → exit 2', () => {
  const r = score('--axes', 'nope');
  assert.equal(r.status, 2);
});

test('redundancy: 의도적 요약쌍(antislop SKILL ↔ rules/anti-ai-slop)은 감점하지 않는다', () => {
  const r = score('--json', '--axes', 'redundancy');
  const j = JSON.parse(r.stdout) as { axes: { redundancy: { pairs: { a: string; b: string }[] } } };
  const offending = j.axes.redundancy.pairs.filter(
    (p) =>
      [p.a, p.b].includes('assets/antislop/SKILL.md') &&
      [p.a, p.b].includes('assets/claude-base/rules/anti-ai-slop.md'),
  );
  assert.deepEqual(offending, []);
});
