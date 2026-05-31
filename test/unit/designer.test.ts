// test/unit/designer.test.ts — catalog + designer 검증 (Milestone 2 게이트)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CATALOG, applicableTo, forType, byId, type CatalogComponent } from '../../src/catalog.ts';
import { design, harnessLevel } from '../../src/designer.ts';
import type { ProjectProfile, ProjectType } from '../../src/types.ts';

function profile(over: Partial<ProjectProfile>): ProjectProfile {
  return {
    root: '/x', type: 'unknown', languages: [], packageManager: null,
    testCmd: null, lintCmd: null, formatCmd: null, ci: null, hasGit: false, signals: [],
    ...over,
  };
}

// ── 카탈로그 무결성 ──
test('모든 카탈로그 항목 점수 ≥75 (등재 기준)', () => {
  for (const c of CATALOG) assert.ok(c.score >= 75, `${c.id} score=${c.score}`);
});

test('id는 유일하다', () => {
  const ids = CATALOG.map((c) => c.id);
  assert.equal(new Set(ids).size, ids.length);
});

test('필수 훅 7개 + 선택 훅 1개', () => {
  const hooks = CATALOG.filter((c) => c.kind === 'hook');
  assert.equal(hooks.filter((c) => c.core).length, 7);
  assert.equal(hooks.filter((c) => c.optional).length, 1);
});

test('Squad 9종(+evaluator) + anti-ai-slop 팩 존재', () => {
  assert.equal(CATALOG.filter((c) => c.kind === 'agent').length, 9);
  assert.ok(byId('squad-evaluator'));
  assert.ok(byId('anti-ai-slop'));
});

// ── applicableTo 두 분기 ──
test('applicableTo: all과 배열 분기', () => {
  const all = { applicable: 'all' } as CatalogComponent;
  const webOnly = { applicable: ['web'] } as CatalogComponent;
  assert.equal(applicableTo(all, 'cli'), true);
  assert.equal(applicableTo(webOnly, 'web'), true);
  assert.equal(applicableTo(webOnly, 'cli'), false);
});

test('forType은 적합 컴포넌트만 반환', () => {
  assert.equal(forType('web').length, CATALOG.length); // 현재 전부 all
  assert.ok(forType('cli').every((c) => applicableTo(c, 'cli')));
});

// ── harnessLevel ──
test('harnessLevel: cli→minimal, web→standard, ci+다언어→full', () => {
  assert.equal(harnessLevel(profile({ type: 'cli' })), 'minimal');
  assert.equal(harnessLevel(profile({ type: 'web' })), 'standard');
  assert.equal(
    harnessLevel(profile({ type: 'web', ci: 'github-actions', languages: ['typescript', 'javascript'] })),
    'full',
  );
});

// ── design ──
test('minimal(cli): 코어 스킬 + 필수 훅만 + anti-slop, slack/auto-commit 제외', () => {
  const d = design(profile({ type: 'cli' }));
  assert.equal(d.level, 'minimal');
  assert.ok(d.recommended.includes('commit'));
  assert.ok(d.recommended.includes('block-destructive'));
  assert.ok(d.recommended.includes('anti-ai-slop'));
  assert.ok(!d.recommended.includes('slack-notify')); // minimal 미포함
  assert.ok(!d.recommended.includes('auto-commit')); // 선택 컴포넌트
});

test('standard(web): 7 필수 훅 + Squad 추천, 추가 스킬은 미추천', () => {
  const d = design(profile({ type: 'web' }));
  assert.equal(d.level, 'standard');
  assert.ok(d.recommended.includes('slack-notify'));
  assert.ok(d.recommended.includes('squad-review'));
  assert.ok(!d.recommended.includes('verify')); // full에서만
  assert.ok(!d.recommended.includes('auto-commit'));
});

test('full: 추가 스킬(verify 등) 포함', () => {
  const d = design(profile({ type: 'web', ci: 'github-actions', languages: ['ts', 'js'] }));
  assert.equal(d.level, 'full');
  assert.ok(d.recommended.includes('verify'));
  assert.ok(d.recommended.includes('security-scan'));
});

test('recommended ⊆ available, auto-commit은 어떤 레벨에서도 미추천', () => {
  for (const t of ['cli', 'web', 'mobile', 'desktop', 'batch', 'library', 'unknown'] as ProjectType[]) {
    const d = design(profile({ type: t, ci: 'x', languages: ['a', 'b'] }));
    assert.ok(d.recommended.every((id) => d.available.includes(id)), `${t}: recommended ⊄ available`);
    assert.ok(!d.recommended.includes('auto-commit'), `${t}: auto-commit 추천됨`);
  }
});
