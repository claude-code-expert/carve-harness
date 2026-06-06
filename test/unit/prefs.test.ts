// test/unit/prefs.test.ts — 사용자 선택 영속화(.carve-prefs.json) 라운드트립 + 선호 반영 (INTEL-04)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { readPrefs, writePrefs, applyPrefs, type CarvePrefs } from '../../src/prefs.ts';
import type { HarnessDesign } from '../../src/designer.ts';

function withTemp(fn: (root: string) => void): void {
  const root = mkdtempSync(join(tmpdir(), 'carve-prefs-'));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function makeDesign(over: Partial<HarnessDesign>): HarnessDesign {
  return {
    level: 'standard',
    recommended: ['a', 'b', 'c'],
    available: ['a', 'b', 'c', 'd'],
    rationale: [],
    ...over,
  };
}

test('writePrefs → readPrefs 라운드트립', () => {
  withTemp((root) => {
    const prefs: CarvePrefs = { deselected: ['b'], selected: ['d'], updatedAt: 't' };
    writePrefs(root, prefs);
    assert.deepEqual(readPrefs(root), prefs);
  });
});

test('readPrefs: prefs 파일 없음 → null', () => {
  withTemp((root) => {
    assert.equal(readPrefs(root), null);
  });
});

test('readPrefs: 손상된 JSON → null (throw 안 함)', () => {
  withTemp((root) => {
    mkdirSync(join(root, '.claude'), { recursive: true });
    writeFileSync(join(root, '.claude/.carve-prefs.json'), '{ not json');
    assert.equal(readPrefs(root), null);
  });
});

test('readPrefs: 형태 불일치(배열 아님) → null', () => {
  withTemp((root) => {
    mkdirSync(join(root, '.claude'), { recursive: true });
    writeFileSync(join(root, '.claude/.carve-prefs.json'), JSON.stringify({ deselected: 'x', selected: [] }));
    assert.equal(readPrefs(root), null);
  });
});

test('applyPrefs: deselected 제거 + selected 추가 (available 교집합)', () => {
  const d = makeDesign({});
  const prefs: CarvePrefs = { deselected: ['b'], selected: ['d'], updatedAt: 't' };
  const checked = new Set(applyPrefs(d, prefs));
  assert.deepEqual(checked, new Set(['a', 'c', 'd']));
});

test('applyPrefs: prefs null → recommended 그대로', () => {
  const d = makeDesign({});
  assert.deepEqual(applyPrefs(d, null), d.recommended);
});

test('applyPrefs: available 밖 id(selected:[z])는 절대 체크 안 함', () => {
  const d = makeDesign({});
  const prefs: CarvePrefs = { deselected: [], selected: ['z'], updatedAt: 't' };
  assert.ok(!applyPrefs(d, prefs).includes('z'));
});
