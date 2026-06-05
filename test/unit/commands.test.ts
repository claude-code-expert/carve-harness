// test/unit/commands.test.ts — classify() 3-way 분류 단위 테스트 (M8).
// 검증: 4가지 상태(unchanged/carve-updated/user-modified/new-recommended) + 미마이그레이션·삭제 케이스.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { classify, type DiffEntry } from '../../src/commands.ts';
import { hashContent, type Manifest, type ManifestFile } from '../../src/manifest.ts';
import type { Artifact } from '../../src/generator.ts';

function withTemp(fn: (root: string) => void): void {
  const root = mkdtempSync(join(tmpdir(), 'carve-cmd-'));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function writeFile(root: string, rel: string, content: string): void {
  const full = join(root, rel);
  mkdirSync(dirname(full), { recursive: true });
  writeFileSync(full, content);
}

function mf(path: string, hash: string): ManifestFile {
  return { path, hash, assetVersion: '2.0.0' };
}

function manifest(files: ManifestFile[]): Manifest {
  return { schemaVersion: 2, version: '2.0.0', files, backups: [], hooks: [] };
}

function art(path: string, content: string): Artifact {
  return { path, content, executable: false };
}

function statusOf(entries: DiffEntry[], path: string): DiffEntry['status'] | undefined {
  return entries.find((e) => e.path === path)?.status;
}

test('classify: 디스크=매니페스트=자산 → unchanged', () => {
  withTemp((root) => {
    const content = 'same';
    writeFile(root, '.claude/a.md', content);
    const m = manifest([mf('.claude/a.md', hashContent(content))]);
    const entries = classify(root, m, [art('.claude/a.md', content)]);
    assert.equal(statusOf(entries, '.claude/a.md'), 'unchanged');
  });
});

test('classify: 디스크=매니페스트, 자산만 변경 → carve-updated', () => {
  withTemp((root) => {
    const orig = 'v1';
    writeFile(root, '.claude/b.md', orig);
    const m = manifest([mf('.claude/b.md', hashContent(orig))]);
    const entries = classify(root, m, [art('.claude/b.md', 'v2-new')]);
    assert.equal(statusOf(entries, '.claude/b.md'), 'carve-updated');
  });
});

test('classify: 디스크가 매니페스트와 다름(사용자 수정) → user-modified', () => {
  withTemp((root) => {
    writeFile(root, '.claude/c.md', 'user-edited');
    const m = manifest([mf('.claude/c.md', hashContent('original'))]);
    const entries = classify(root, m, [art('.claude/c.md', 'carve-next')]);
    assert.equal(statusOf(entries, '.claude/c.md'), 'user-modified');
  });
});

test('classify: 매니페스트에 없는 자산 → new-recommended', () => {
  withTemp((root) => {
    const m = manifest([]);
    const entries = classify(root, m, [art('.claude/new.md', 'fresh')]);
    assert.equal(statusOf(entries, '.claude/new.md'), 'new-recommended');
  });
});

test('classify: 미마이그레이션(orig 빈 해시) → user-modified + unmigrated', () => {
  withTemp((root) => {
    writeFile(root, '.claude/d.md', 'whatever');
    const m = manifest([mf('.claude/d.md', '')]);
    const entries = classify(root, m, [art('.claude/d.md', 'whatever')]);
    const e = entries.find((x) => x.path === '.claude/d.md');
    assert.equal(e?.status, 'user-modified');
    assert.equal(e?.unmigrated, true);
  });
});

test('classify: 디스크에서 삭제된 파일 → carve-updated(복원), throw 없음', () => {
  withTemp((root) => {
    const m = manifest([mf('.claude/gone.md', hashContent('installed'))]);
    const entries = classify(root, m, [art('.claude/gone.md', 'installed')]);
    assert.equal(statusOf(entries, '.claude/gone.md'), 'carve-updated');
  });
});

test('classify: 매니페스트 없음(null) → 모든 자산 new-recommended', () => {
  withTemp((root) => {
    const entries = classify(root, null, [art('.claude/x.md', 'a'), art('.claude/y.md', 'b')]);
    assert.equal(entries.length, 2);
    assert.ok(entries.every((e) => e.status === 'new-recommended'));
  });
});
