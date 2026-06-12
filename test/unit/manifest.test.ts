// test/unit/manifest.test.ts — 매니페스트 스키마 v2 단위 테스트 (M8).
// 검증: hashContent 결정성, normalize v1→v2 무손실, v2 passthrough, migrate 디스크 back-fill·멱등.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync, readFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import {
  hashContent,
  normalizeManifest,
  migrateManifest,
  manifestPath,
  readManifest,
  SCHEMA_VERSION,
  type Manifest,
  type ManifestFile,
} from '../../src/manifest.ts';

function withTemp(fn: (root: string) => void): void {
  const root = mkdtempSync(join(tmpdir(), 'carve-mf-'));
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

// ── readManifest: 손상 vs 부재 구분 ──
test('readManifest: 파일 없음 → null (기존 동작 유지)', () => {
  withTemp((root) => {
    assert.equal(readManifest(root), null);
  });
});

test('readManifest: 손상 JSON → 맥락 있는 throw (조용한 null 금지 — 재설치 고아화 방지)', () => {
  withTemp((root) => {
    writeFileSync(manifestPath(root), '{corrupt');
    assert.throws(() => readManifest(root), /carve-manifest\.json 파싱 실패/);
  });
});

// ── hashContent ──

test('hashContent: 결정적 — 같은 입력은 같은 해시', () => {
  assert.equal(hashContent('abc'), hashContent('abc'));
});

test('hashContent: 다른 입력은 다른 해시', () => {
  assert.notEqual(hashContent('abc'), hashContent('abd'));
});

test('hashContent: 64자 소문자 hex (sha256)', () => {
  const h = hashContent('hello carve');
  assert.match(h, /^[0-9a-f]{64}$/);
});

// ── normalizeManifest ──

test('normalize v1 → v2 무손실: 경로 보존, hash="", assetVersion=version, schemaVersion=2', () => {
  const v1 = {
    version: '1.0.0',
    files: ['flight-rules.md', '.claude/hooks/carve-x.sh'],
    backups: ['flight-rules.md.bak'],
    hooks: [{ event: 'PreToolUse', command: 'bash x.sh' }],
    mcps: ['codesight'],
  };
  const m = normalizeManifest(v1);
  assert.equal(m.schemaVersion, SCHEMA_VERSION);
  assert.equal(m.version, '1.0.0');
  assert.equal(m.files.length, 2);
  assert.deepEqual(
    m.files,
    [
      { path: 'flight-rules.md', hash: '', assetVersion: '1.0.0' },
      { path: '.claude/hooks/carve-x.sh', hash: '', assetVersion: '1.0.0' },
    ],
  );
  // backups/hooks/mcps 보존
  assert.deepEqual(m.backups, ['flight-rules.md.bak']);
  assert.deepEqual(m.hooks, [{ event: 'PreToolUse', command: 'bash x.sh' }]);
  assert.deepEqual(m.mcps, ['codesight']);
});

test('normalize v2 passthrough: files 엔트리·schemaVersion 불변', () => {
  const files: ManifestFile[] = [
    { path: 'a.md', hash: 'deadbeef', assetVersion: '2.0.0' },
  ];
  const v2: Manifest = {
    schemaVersion: 2,
    version: '2.0.0',
    files,
    backups: [],
    hooks: [],
    mcps: ['cclsp'],
  };
  const m = normalizeManifest(v2);
  assert.equal(m.schemaVersion, SCHEMA_VERSION);
  assert.deepEqual(m.files, files);
  assert.deepEqual(m.mcps, ['cclsp']);
});

// ── migrateManifest ──

test('migrate v1 → v2: 디스크 콘텐츠에서 해시 back-fill', () => {
  withTemp((root) => {
    writeFile(root, 'flight-rules.md', 'CARVE RULES\n');
    writeFile(root, '.claude/hooks/carve-x.sh', '#!/usr/bin/env bash\nexit 0\n');
    const v1 = {
      version: '1.0.0',
      files: ['flight-rules.md', '.claude/hooks/carve-x.sh'],
      backups: [],
      hooks: [],
    };
    writeFileSync(manifestPath(root), JSON.stringify(v1, null, 2) + '\n');

    const res = migrateManifest(root);
    assert.deepEqual(res, { migrated: true, from: 1, filled: 2 });

    const raw = JSON.parse(readFileSync(manifestPath(root), 'utf8')) as Manifest;
    assert.equal(raw.schemaVersion, 2);
    for (const f of raw.files) {
      assert.notEqual(f.hash, '');
      const disk = readFileSync(join(root, f.path), 'utf8');
      assert.equal(f.hash, hashContent(disk));
      assert.equal(f.assetVersion, '1.0.0');
    }
  });
});

test('migrate 멱등: 두 번째 실행은 no-op + byte-identical', () => {
  withTemp((root) => {
    writeFile(root, 'flight-rules.md', 'CARVE RULES\n');
    const v1 = { version: '1.0.0', files: ['flight-rules.md'], backups: [], hooks: [] };
    writeFileSync(manifestPath(root), JSON.stringify(v1, null, 2) + '\n');

    migrateManifest(root);
    const after1 = readFileSync(manifestPath(root), 'utf8');
    const res2 = migrateManifest(root);
    assert.deepEqual(res2, { migrated: false, from: 2, filled: 0 });
    const after2 = readFileSync(manifestPath(root), 'utf8');
    assert.equal(after1, after2, 'v2 재마이그레이션이 파일을 변경함');
  });
});

test('migrate 무손실: 엔트리 수·backups/hooks/mcps 보존', () => {
  withTemp((root) => {
    writeFile(root, 'a.md', 'A\n');
    writeFile(root, 'b.md', 'B\n');
    const v1 = {
      version: '1.0.0',
      files: ['a.md', 'b.md'],
      backups: ['a.md.bak'],
      hooks: [{ event: 'PreToolUse', command: 'bash x.sh' }],
      mcps: ['codesight'],
    };
    writeFileSync(manifestPath(root), JSON.stringify(v1, null, 2) + '\n');

    migrateManifest(root);
    const m = JSON.parse(readFileSync(manifestPath(root), 'utf8')) as Manifest;
    assert.equal(m.files.length, 2);
    assert.deepEqual(m.backups, ['a.md.bak']);
    assert.deepEqual(m.hooks, [{ event: 'PreToolUse', command: 'bash x.sh' }]);
    assert.deepEqual(m.mcps, ['codesight']);
  });
});

test('migrate: 디스크에 없는 파일은 hash="" 유지(한계), filled 미집계', () => {
  withTemp((root) => {
    writeFile(root, 'present.md', 'P\n');
    const v1 = { version: '1.0.0', files: ['present.md', 'missing.md'], backups: [], hooks: [] };
    writeFileSync(manifestPath(root), JSON.stringify(v1, null, 2) + '\n');

    const res = migrateManifest(root);
    assert.equal(res.filled, 1);
    const m = JSON.parse(readFileSync(manifestPath(root), 'utf8')) as Manifest;
    const missing = m.files.find((f) => f.path === 'missing.md');
    assert.ok(missing);
    assert.equal(missing.hash, '');
  });
});

test('migrate: 매니페스트 없으면 무해 no-op', () => {
  withTemp((root) => {
    assert.deepEqual(migrateManifest(root), { migrated: false, from: 0, filled: 0 });
  });
});
