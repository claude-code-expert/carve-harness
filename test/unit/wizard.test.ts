// test/unit/wizard.test.ts — 대화형 선택 로직 + --only 선택 설치 (Milestone 4/wizard 게이트)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { buildChoices } from '../../src/wizard.ts';
import { design } from '../../src/designer.ts';
import { parseOnly, run, type IO } from '../../src/cli.ts';
import type { ProjectProfile } from '../../src/types.ts';

function profile(over: Partial<ProjectProfile>): ProjectProfile {
  return {
    root: '/x', type: 'web', languages: ['typescript'], packageManager: 'npm',
    testCmd: 'npm test', lintCmd: null, formatCmd: null, ci: null, hasGit: true, signals: [], ...over,
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

test('parseOnly: --only a,b 및 --only=a,b 파싱', () => {
  assert.deepEqual(parseOnly(['install', 'dir', '--only', 'commit,handoff']), ['commit', 'handoff']);
  assert.deepEqual(parseOnly(['install', '--only=pr']), ['pr']);
  assert.equal(parseOnly(['install', 'dir']), undefined);
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
