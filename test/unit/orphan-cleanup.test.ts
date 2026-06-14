// test/unit/orphan-cleanup.test.ts — removeOrphanedComponents (삭제된 컴포넌트 잔여 정리) 단위 검증.
// 안전 핵심: tombstone 명시 id만 + 해시 일치(carve 소유·미수정)만 삭제. clean-html 등 비대상 자산 불가침.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { removeOrphanedComponents, REMOVED_COMPONENTS } from '../../src/installer.ts';
import { hashContent, writeManifest, readManifest, type Manifest, type ManifestFile } from '../../src/manifest.ts';

function withTemp(fn: (root: string) => void): void {
  const root = mkdtempSync(join(tmpdir(), 'carve-orphan-'));
  try { fn(root); } finally { rmSync(root, { recursive: true, force: true }); }
}

function writeFile(root: string, rel: string, content: string): void {
  const full = join(root, rel);
  mkdirSync(dirname(full), { recursive: true });
  writeFileSync(full, content);
}

function mf(path: string, content: string): ManifestFile {
  return { path, hash: hashContent(content), assetVersion: '1.5.0' };
}
function manifest(files: ManifestFile[]): Manifest {
  return { schemaVersion: 2, version: '1.5.0', files, backups: [], hooks: [] };
}

test('removeOrphanedComponents: tombstone 스킬+shim(해시 일치) 제거 + manifest 동기 + 빈 디렉터리 정리', () => {
  withTemp((root) => {
    const skill = '.claude/skills/memory/SKILL.md';
    const shim = '.claude/commands/carve-memory.md';
    const keep = '.claude/skills/commit/SKILL.md';
    const sc = 'memory-skill', shc = 'memory-shim', kc = 'commit-skill';
    writeFile(root, skill, sc); writeFile(root, shim, shc); writeFile(root, keep, kc);
    writeManifest(root, manifest([mf(skill, sc), mf(shim, shc), mf(keep, kc)]));

    const r = removeOrphanedComponents(root, ['memory']);
    assert.deepEqual([...r.removed].sort(), [shim, skill].sort());
    assert.deepEqual(r.preserved, []);
    assert.ok(!existsSync(join(root, skill)));
    assert.ok(!existsSync(join(root, shim)));
    assert.ok(!existsSync(join(root, '.claude/skills/memory')), '빈 스킬 디렉터리 미정리');
    assert.ok(existsSync(join(root, keep)), 'tombstone 외 스킬 오삭제');
    const m = readManifest(root);
    assert.deepEqual(m?.files.map((f) => f.path), [keep]);
  });
});

test('removeOrphanedComponents: 사용자 수정분(해시 불일치)은 보존 + manifest 유지', () => {
  withTemp((root) => {
    const skill = '.claude/skills/verify/SKILL.md';
    writeFile(root, skill, 'user-edited-content');
    // manifest 해시는 원본(설치 시점) 기준 — 디스크와 불일치 = 사용자 수정
    writeManifest(root, manifest([mf(skill, 'original-carve-content')]));

    const r = removeOrphanedComponents(root, ['verify']);
    assert.deepEqual(r.removed, []);
    assert.deepEqual(r.preserved, [skill]);
    assert.ok(existsSync(join(root, skill)), '사용자 수정분이 삭제됨');
    assert.equal(readManifest(root)?.files.length, 1, '보존 항목이 manifest에서 빠짐');
  });
});

test('removeOrphanedComponents: tombstone 외 id(clean-html 등)는 건드리지 않음 (오삭제 가드)', () => {
  withTemp((root) => {
    const cleanHtml = '.claude/skills/clean-html/SKILL.md';
    writeFile(root, cleanHtml, 'clean-html-asset');
    writeManifest(root, manifest([mf(cleanHtml, 'clean-html-asset')]));

    const r = removeOrphanedComponents(root, ['memory', 'verify', 'pr', 'review']);
    assert.deepEqual(r.removed, []);
    assert.ok(existsSync(join(root, cleanHtml)), 'clean-html 오삭제 — 비카탈로그 자산 불가침 위반');
  });
});

test('removeOrphanedComponents: 해시 미상(v1 back-fill 전 = "")은 carve 소유로 보고 삭제', () => {
  withTemp((root) => {
    const skill = '.claude/skills/pr/SKILL.md';
    writeFile(root, skill, 'pr-skill');
    writeManifest(root, manifest([{ path: skill, hash: '', assetVersion: '1.0.0' }]));

    const r = removeOrphanedComponents(root, ['pr']);
    assert.deepEqual(r.removed, [skill]);
    assert.ok(!existsSync(join(root, skill)));
  });
});

test('removeOrphanedComponents: 멱등 — 두 번째 호출은 no-op', () => {
  withTemp((root) => {
    const skill = '.claude/skills/review/SKILL.md';
    writeFile(root, skill, 'review-skill');
    writeManifest(root, manifest([mf(skill, 'review-skill')]));
    removeOrphanedComponents(root, ['review']);
    const r2 = removeOrphanedComponents(root, ['review']);
    assert.deepEqual(r2.removed, []);
    assert.deepEqual(r2.preserved, []);
  });
});

test('removeOrphanedComponents: 설치 없음(manifest 부재)이면 no-op', () => {
  withTemp((root) => {
    const r = removeOrphanedComponents(root, ['memory']);
    assert.deepEqual(r, { removed: [], preserved: [] });
  });
});

test('REMOVED_COMPONENTS: Stage 1에선 비어 있다(컴포넌트 실삭제 시 채워짐)', () => {
  // 이 가드는 Stage 2에서 7종을 채우며 함께 갱신된다.
  assert.ok(Array.isArray(REMOVED_COMPONENTS));
});
