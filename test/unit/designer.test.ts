// test/unit/designer.test.ts — catalog + designer 검증 (Milestone 2 게이트)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CATALOG, applicableTo, forType, byId, statusOf, type CatalogComponent } from '../../src/catalog.ts';
import { design, harnessLevel, applySignalWeights } from '../../src/designer.ts';
import type { ProjectProfile, ProjectType } from '../../src/types.ts';

function profile(over: Partial<ProjectProfile>): ProjectProfile {
  return {
    root: '/x', type: 'unknown', languages: [], packageManager: null,
    testCmd: null, lintCmd: null, formatCmd: null, ci: null, hasGit: false, signals: [],
    workspaces: [], container: { dockerfile: false, compose: false, makefile: false },
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

// ── 라이프사이클 (wave-1 fade-out) ──
test('wave-1: deprecated 3종은 available 포함(선택 가능)·recommended 제외', () => {
  const WAVE1 = ['changelog', 'security-scan', 'coordinator'];
  for (const id of WAVE1) {
    const c = byId(id);
    assert.ok(c, `${id} 카탈로그 부재`);
    assert.equal(statusOf(c), 'deprecated', `${id} 상태`);
    assert.ok(c.replacedBy, `${id} replacedBy 부재`);
  }
  const d = design(profile({ type: 'web', ci: 'github-actions', languages: ['ts', 'js'] })); // full
  for (const id of WAVE1) {
    assert.ok(d.available.includes(id), `${id}가 available에서 빠짐(hidden 아님)`);
    assert.ok(!d.recommended.includes(id), `${id}가 추천됨(deprecated 위반)`);
  }
});

test('hidden 4종(memory·pr·verify·review)은 available·recommended에서 완전 제외 (내장 슬래시 충돌 회피)', () => {
  const HIDDEN = ['memory', 'pr', 'verify', 'review'];
  for (const id of HIDDEN) {
    const c = byId(id);
    assert.ok(c, `${id} 카탈로그 부재`);
    assert.equal(statusOf(c), 'hidden', `${id} 상태`);
  }
  // full 레벨이라도 hidden은 설치 후보(available)·추천(recommended) 양쪽에서 빠진다 → 신규 설치 시 내장 슬래시와 충돌 없음
  const d = design(profile({ type: 'web', ci: 'github-actions', languages: ['ts', 'js'] }));
  for (const id of HIDDEN) {
    assert.ok(!d.available.includes(id), `${id}가 available에 노출(hidden 위반)`);
    assert.ok(!d.recommended.includes(id), `${id}가 추천됨(hidden 위반)`);
  }
});

test('훅 카탈로그: PreToolUse/PostToolUse 훅은 matcher 메타 보유(단일 출처), Stop/PreCompact는 불필요', () => {
  for (const c of CATALOG.filter((x) => x.kind === 'hook')) {
    if (c.event === 'Stop' || c.event === 'PreCompact') {
      assert.equal(c.matcher, undefined, `${c.id}: Stop/PreCompact에 matcher 불필요`);
    } else {
      assert.ok(c.matcher, `${c.id}: matcher 메타 누락`);
    }
  }
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
  assert.ok(!d.recommended.includes('iterate')); // full에서만
  assert.ok(!d.recommended.includes('auto-commit'));
});

test('full: 추가 스킬(test-gen·iterate 등) 포함 — deprecated·hidden·optional은 미추천', () => {
  const d = design(profile({ type: 'web', ci: 'github-actions', languages: ['ts', 'js'] }));
  assert.equal(d.level, 'full');
  assert.ok(d.recommended.includes('test-gen'));
  assert.ok(d.recommended.includes('iterate'));
  assert.ok(!d.recommended.includes('security-scan')); // wave-1 deprecated → 추천 제외
  assert.ok(!d.recommended.includes('evaluator-tuning')); // optional 강등 → 직접 선택만
});

test('recommended ⊆ available, auto-commit은 어떤 레벨에서도 미추천', () => {
  for (const t of ['cli', 'web', 'mobile', 'desktop', 'batch', 'library', 'unknown'] as ProjectType[]) {
    const d = design(profile({ type: t, ci: 'x', languages: ['a', 'b'] }));
    assert.ok(d.recommended.every((id) => d.available.includes(id)), `${t}: recommended ⊄ available`);
    assert.ok(!d.recommended.includes('auto-commit'), `${t}: auto-commit 추천됨`);
  }
});

// ── applySignalWeights (시그널 가중, INTEL-03) ──
const COORD_IDS = ['parallel-agents', 'coordinator'];

test('applySignalWeights: 모노레포 시그널 → 조정 컴포넌트 가중 (coordination 메타 단일 출처, active만)', () => {
  // 워크스페이스 비어있지 않음(monorepo) → coordination 메타의 active 컴포넌트만 추가
  const base = ['commit', 'review'];
  const available = [...base, ...COORD_IDS];
  const out = applySignalWeights(profile({ workspaces: ['pnpm-workspace'], ci: null }), base, available);
  assert.ok(out.includes('parallel-agents'));
  assert.ok(!out.includes('coordinator')); // wave-1 deprecated → 가중 안 함
  // base 멤버십 보존
  assert.ok(base.every((id) => out.includes(id)));
});

test('applySignalWeights: CI 시그널만으로도 가중', () => {
  const base = ['commit'];
  const available = [...base, ...COORD_IDS];
  const out = applySignalWeights(profile({ workspaces: [], ci: 'github-actions' }), base, available);
  assert.ok(out.includes('parallel-agents'));
  assert.ok(!out.includes('coordinator')); // deprecated 미가중
});

test('applySignalWeights: 시그널 없으면 base 멤버십 불변', () => {
  const base = ['commit', 'review'];
  const available = [...base, ...COORD_IDS];
  const out = applySignalWeights(profile({ workspaces: [], ci: null }), base, available);
  assert.equal(new Set(out).size, new Set(base).size);
  assert.ok(base.every((id) => out.includes(id)));
  assert.ok(!out.includes('parallel-agents'));
  assert.ok(!out.includes('coordinator'));
});

test('applySignalWeights: available에 없는 id는 추가하지 않음 (no-op)', () => {
  const base = ['commit'];
  const available = ['commit']; // 조정 id 미포함
  const out = applySignalWeights(profile({ workspaces: ['turbo'], ci: 'github-actions' }), base, available);
  assert.ok(!out.includes('parallel-agents'));
  assert.ok(!out.includes('coordinator'));
});

test('applySignalWeights: 멱등 — 이미 있으면 중복 없음', () => {
  const base = ['commit', 'parallel-agents'];
  const available = [...base, 'coordinator'];
  const out = applySignalWeights(profile({ workspaces: ['turbo'], ci: null }), base, available);
  assert.equal(out.filter((id) => id === 'parallel-agents').length, 1);
});

// ── design() 통합 (시그널 가중) ──
test('design: 모노레포+CI → 조정 컴포넌트 추천 (single-package의 strict superset)', () => {
  const mono = design(profile({ type: 'web', workspaces: ['turbo'], ci: 'github-actions', languages: ['ts', 'js'] }));
  assert.ok(mono.recommended.includes('parallel-agents'));
  assert.ok(!mono.recommended.includes('coordinator')); // deprecated — 가중 대상에서 자동 탈락
});

test('design: single-package(web) → 조정 컴포넌트 미추천 (회귀 가드)', () => {
  const single = design(profile({ type: 'web' }));
  assert.ok(!single.recommended.includes('parallel-agents'));
  assert.ok(!single.recommended.includes('coordinator'));
});
