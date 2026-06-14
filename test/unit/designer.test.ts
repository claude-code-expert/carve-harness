// test/unit/designer.test.ts — catalog + designer 검증 (Milestone 2 게이트)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CATALOG, applicableTo, forType, byId, statusOf, type CatalogComponent } from '../../src/catalog.ts';
import { design, harnessLevel, applySignalWeights, applyMetricsWeights } from '../../src/designer.ts';
import type { ProjectProfile, ProjectType } from '../../src/types.ts';
import type { MetricsAggregate } from '../../src/metrics.ts';

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

// ── 라이프사이클 (fade-out 완료: v1.5.0에서 deprecated/hidden 7종 삭제) ──
test('fade-out 완료: 카탈로그에 deprecated/hidden 컴포넌트가 없다 + 삭제 7종 부재', () => {
  // 7종(memory·verify·pr·review·changelog·security-scan·coordinator)을 카탈로그·자산에서 삭제했다.
  // 잔여 deprecated/hidden이 없어야 lifecycle 머시너리가 미래 fade-out용으로만 남는다.
  for (const c of CATALOG) {
    assert.equal(statusOf(c), 'active', `${c.id}: 잔여 deprecated/hidden — 삭제 누락`);
  }
  for (const id of ['memory', 'verify', 'pr', 'review', 'changelog', 'security-scan', 'coordinator']) {
    assert.equal(byId(id), undefined, `${id}: 삭제됐어야 함`);
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

test('full: 추가 스킬(test-gen·iterate 등) 포함 — optional은 미추천', () => {
  const d = design(profile({ type: 'web', ci: 'github-actions', languages: ['ts', 'js'] }));
  assert.equal(d.level, 'full');
  assert.ok(d.recommended.includes('test-gen'));
  assert.ok(d.recommended.includes('iterate'));
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

// ── applyMetricsWeights (M12 텔레메트리 제안 — 추천 집합은 불변, 제안만) ──
function agg(over: Partial<MetricsAggregate>): MetricsAggregate {
  return { perHook: new Map(), zeroFire: [], totalFires: 0, totalBlocks: 0, ...over };
}

test('applyMetricsWeights: metrics null → 빈 배열 (opt-out 하위호환)', () => {
  assert.deepEqual(applyMetricsWeights(null), []);
});

test('applyMetricsWeights: zeroFire 비어있으면 제안 없음', () => {
  assert.deepEqual(applyMetricsWeights(agg({})), []);
});

test('applyMetricsWeights: zeroFire → demote 제안(정렬·근거)', () => {
  const out = applyMetricsWeights(agg({ zeroFire: ['pre-push-test', 'auto-format'] }));
  assert.equal(out.length, 2);
  assert.deepEqual(out.map((s) => s.id), ['auto-format', 'pre-push-test']); // 결정적 정렬
  assert.ok(out.every((s) => s.kind === 'demote'));
  assert.ok(out.every((s) => s.reason.includes('제외')));
});

test('applyMetricsWeights: 결정적 — 같은 입력 같은 출력', () => {
  const a = agg({ zeroFire: ['b', 'a'] });
  assert.deepEqual(applyMetricsWeights(a), applyMetricsWeights(a));
});

test('design()는 metrics와 무관 — applyMetricsWeights가 추천을 바꾸지 않음(하위호환 봉인)', () => {
  // 추천 집합은 design()이 단독 결정. M12 제안은 별도 채널이라 recommended에 영향 없음.
  const d = design(profile({ type: 'web' }));
  const before = [...d.recommended];
  applyMetricsWeights(agg({ zeroFire: ['slack-notify'] }));
  assert.deepEqual(d.recommended, before);
});
