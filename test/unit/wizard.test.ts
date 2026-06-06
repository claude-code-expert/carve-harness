// test/unit/wizard.test.ts — 대화형 선택 로직 + --only 선택 설치 (Milestone 4/wizard 게이트)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { buildChoices } from '../../src/wizard.ts';
import { design } from '../../src/designer.ts';
import { parseOnly, parseLevel, run, type IO } from '../../src/cli.ts';
import type { ProjectProfile } from '../../src/types.ts';

function profile(over: Partial<ProjectProfile>): ProjectProfile {
  return {
    root: '/x', type: 'web', languages: ['typescript'], packageManager: 'npm',
    testCmd: 'npm test', lintCmd: null, formatCmd: null, ci: null, hasGit: true, signals: [],
    workspaces: [], container: { dockerfile: false, compose: false, makefile: false }, ...over,
  };
}
function capture() {
  const out = { log: '', error: '' };
  const io: IO = { log: (s) => (out.log += s + '\n'), error: (s) => (out.error += s + '\n') };
  return { io, out };
}

test('buildChoices: 추천 항목은 selected=true, 나머지는 false', () => {
  const d = design(profile({ type: 'web' }));
  const choices = buildChoices(d);
  assert.equal(choices.length, d.available.length);
  const commit = choices.find((c) => c.value === 'commit');
  assert.ok(commit?.selected); // 코어 → 추천
  const autocommit = choices.find((c) => c.value === 'auto-commit');
  assert.ok(autocommit && !autocommit.selected); // 선택 컴포넌트 → 미추천
});

test('buildChoices(design, prefs): deselected 항목은 selected=false', () => {
  const d = design(profile({ type: 'web' }));
  const choices = buildChoices(d, { deselected: ['commit'], selected: [], updatedAt: 't' });
  const commit = choices.find((c) => c.value === 'commit');
  assert.ok(commit && !commit.selected); // 추천이었지만 끔 → false
  // 다른 추천 항목은 여전히 selected=true (handoff는 코어 스킬)
  const handoff = choices.find((c) => c.value === 'handoff');
  assert.ok(handoff?.selected);
});

test('buildChoices(design, prefs): selected 항목은 selected=true', () => {
  const d = design(profile({ type: 'web' }));
  const choices = buildChoices(d, { deselected: [], selected: ['auto-commit'], updatedAt: 't' });
  const autocommit = choices.find((c) => c.value === 'auto-commit');
  assert.ok(autocommit?.selected); // 보통 미추천이지만 사용자가 켬 → true
});

test('parseOnly: --only a,b 및 --only=a,b 파싱', () => {
  assert.deepEqual(parseOnly(['install', 'dir', '--only', 'commit,handoff']), ['commit', 'handoff']);
  assert.deepEqual(parseOnly(['install', '--only=pr']), ['pr']);
  assert.equal(parseOnly(['install', 'dir']), undefined);
});

test('parseLevel: 유효/무효/부재', () => {
  assert.equal(parseLevel(['install', '--level', 'full']), 'full');
  assert.equal(parseLevel(['install', '--level=minimal']), 'minimal');
  assert.equal(parseLevel(['install', '--level', 'huge']), 'invalid');
  assert.equal(parseLevel(['install']), undefined);
});

test('install --level full: 단일언어 프로젝트도 병렬 에이전트 가이드 설치', () => {
  const root = mkdtempSync(join(tmpdir(), 'carve-lvl-'));
  try {
    const { io } = capture();
    // 기본(standard)에선 parallel-agents 미설치
    run(['install', root], io);
    assert.ok(!existsSync(join(root, '.claude/skills/parallel-agents/SKILL.md')));
    run(['uninstall', root], capture().io);
    // --level full → parallel-agents·coordinator 설치
    assert.equal(run(['install', root, '--level', 'full'], capture().io), 0);
    assert.ok(existsSync(join(root, '.claude/skills/parallel-agents/SKILL.md')));
    assert.ok(existsSync(join(root, '.claude/skills/coordinator/SKILL.md')));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('install --level 무효값 → exit 1', () => {
  assert.equal(run(['install', '/tmp/nope', '--level', 'huge'], capture().io), 1);
});

test('install --only: 고른 것만 설치 (일괄 아님)', () => {
  const root = mkdtempSync(join(tmpdir(), 'carve-wiz-'));
  try {
    const { io } = capture();
    assert.equal(run(['install', root, '--only', 'commit,handoff'], io), 0);
    // 선택한 스킬만 설치
    assert.ok(existsSync(join(root, '.claude/skills/commit/SKILL.md')));
    assert.ok(existsSync(join(root, '.claude/skills/handoff/SKILL.md')));
    // 선택 안 한 것은 미설치
    assert.ok(!existsSync(join(root, '.claude/skills/pr/SKILL.md')));
    assert.ok(!existsSync(join(root, '.claude/hooks/carve-block-destructive.sh')));
    assert.ok(!existsSync(join(root, '.claude/agents/squad-review.md')));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
