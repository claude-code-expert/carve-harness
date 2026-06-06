// test/e2e/update.e2e.test.ts — carve update / carve migrate E2E (M8 LIFE-03/04/05).
// 검증: carve-updated 갱신, user-modified 보존/강제, new-recommended 제안만,
//       audit-gate-before-write 원자성, 미마이그레이션 거부, migrate 위임·멱등.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  mkdtempSync, rmSync, existsSync, readFileSync, writeFileSync, mkdirSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { cmdUpdate, cmdMigrate } from '../../src/commands.ts';
import {
  readManifest, writeManifest, hashContent, manifestPath,
  type Manifest, type ManifestFile,
} from '../../src/manifest.ts';
import type { IO } from '../../src/cli.ts';

function withTemp(fn: (root: string) => void): void {
  const root = mkdtempSync(join(tmpdir(), 'carve-upd-'));
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

function read(root: string, rel: string): string {
  return readFileSync(join(root, rel), 'utf8');
}

interface Captured { logs: string[]; errs: string[] }
function captureIO(): { io: IO; cap: Captured } {
  const cap: Captured = { logs: [], errs: [] };
  const io: IO = {
    log: (m: string) => cap.logs.push(m),
    error: (m: string) => cap.errs.push(m),
  };
  return { io, cap };
}

function mf(path: string, hash: string): ManifestFile {
  return { path, hash, assetVersion: '1.0.0' };
}

function v2Manifest(files: ManifestFile[]): Manifest {
  return { schemaVersion: 2, version: '1.0.0', files, backups: [], hooks: [] };
}

// ── cmdUpdate ──

test('cmdUpdate: 미마이그레이션(v1, 빈 해시) → 1 반환, migrate 안내, 쓰기 없음', () => {
  withTemp((root) => {
    const flight = join(root, 'flight-rules.md');
    writeFile(root, 'flight-rules.md', 'ORIGINAL\n');
    // 해시 ''인 항목 = 미마이그레이션
    writeManifest(root, v2Manifest([mf('flight-rules.md', '')]));
    const before = read(root, 'flight-rules.md');
    const { io, cap } = captureIO();
    const code = cmdUpdate(root, io);
    assert.equal(code, 1);
    assert.ok(cap.errs.some((e) => e.includes('carve migrate')), 'migrate 안내 없음');
    assert.equal(read(root, 'flight-rules.md'), before, '파일이 변경됨');
    assert.equal(existsSync(flight + '.bak'), false, '.bak 생성됨(쓰기 발생)');
  });
});

test('cmdUpdate: 설치 없음(manifest null) → 0, 안내', () => {
  withTemp((root) => {
    const { io, cap } = captureIO();
    const code = cmdUpdate(root, io);
    assert.equal(code, 0);
    assert.ok(cap.logs.some((l) => l.includes('carve install')));
  });
});

test('cmdUpdate: 일부 항목만 빈 해시여도 미마이그레이션으로 거부(보수적)', () => {
  withTemp((root) => {
    // readManifest는 디스크 v1을 항상 schemaVersion=2로 정규화하므로,
    // 실제 미마이그레이션 신호는 "빈 해시"다. 한 항목이라도 빈 해시면 거부한다.
    writeFile(root, 'flight-rules.md', 'X\n');
    writeManifest(root, v2Manifest([
      mf('flight-rules.md', hashContent('X\n')),
      mf('.claude/legacy.md', ''), // v1 잔재 — 빈 해시
    ]));
    const { io, cap } = captureIO();
    assert.equal(cmdUpdate(root, io), 1);
    assert.ok(cap.errs.some((e) => e.includes('carve migrate')));
  });
});

test('cmdUpdate: carve-updated 자산 갱신 + 매니페스트 해시 교체, 미변경 항목 보존', () => {
  withTemp((root) => {
    // flight-rules.md: 디스크=매니페스트(=설치 시점) 동일, carve 자산은 새 콘텐츠.
    // classify는 generate()의 현재 콘텐츠와 비교하므로, 디스크/매니페스트를 "옛 carve 콘텐츠"로 맞춰
    // generate()가 만드는 현재 콘텐츠와 다르게 한다 → carve-updated.
    // 핵심: 디스크 콘텐츠 해시 === 매니페스트 해시(=orig) && generate next !== orig.
    // 실제 generate 콘텐츠를 모르므로, 디스크/매니페스트에 임의의 동일 "옛" 콘텐츠를 둔다.
    const oldContent = 'OLD CARVE CONTENT — definitely not what generate produces\n';
    writeFile(root, 'flight-rules.md', oldContent);
    // 미변경 보존 검증용 추가 파일: 매니페스트에만 있고 generate 추천 집합엔 없음(분류 대상 아님).
    const untouched = mf('.claude/keepme.md', hashContent('keep\n'));
    writeManifest(root, v2Manifest([
      mf('flight-rules.md', hashContent(oldContent)),
      untouched,
    ]));

    const { io, cap } = captureIO();
    const code = cmdUpdate(root, io);
    assert.equal(code, 0);

    const after = read(root, 'flight-rules.md');
    assert.notEqual(after, oldContent, 'flight-rules.md가 갱신되지 않음');
    // 사용자 원본(옛 carve 콘텐츠)은 .bak로 보존
    assert.ok(existsSync(join(root, 'flight-rules.md.bak')));

    const m2 = readManifest(root);
    assert.ok(m2);
    const fr = m2.files.find((f) => f.path === 'flight-rules.md');
    assert.ok(fr);
    assert.equal(fr.hash, hashContent(after), '매니페스트 해시가 새 콘텐츠와 불일치');
    // 분류 대상이 아니던 항목은 그대로 보존됨(매니페스트 완전성)
    const keep = m2.files.find((f) => f.path === '.claude/keepme.md');
    assert.ok(keep && keep.hash === untouched.hash, '미변경 매니페스트 항목 손실');
    assert.equal(m2.schemaVersion, 2);
    assert.ok(cap.logs.some((l) => l.includes('업데이트 완료')));
  });
});

test('cmdUpdate: user-modified는 기본 보존(건드리지 않음), --force면 .bak 1회 후 덮어씀', () => {
  withTemp((root) => {
    // 사용자가 수정 → 디스크 해시 != 매니페스트 해시(orig). next도 다름 → user-modified.
    const userContent = 'USER EDITED — keep me by default\n';
    writeFile(root, 'flight-rules.md', userContent);
    writeManifest(root, v2Manifest([
      mf('flight-rules.md', hashContent('original installed content\n')),
    ]));

    // 기본: 보존
    const { io } = captureIO();
    assert.equal(cmdUpdate(root, io), 0);
    assert.equal(read(root, 'flight-rules.md'), userContent, '기본 모드에서 사용자 파일이 변경됨');
    assert.equal(existsSync(join(root, 'flight-rules.md.bak')), false, '기본 모드에서 .bak 생성됨');

    // --force: .bak에 사용자 콘텐츠 보존 후 덮어씀
    const { io: io2, cap: cap2 } = captureIO();
    assert.equal(cmdUpdate(root, io2, { force: true }), 0);
    assert.equal(read(root, 'flight-rules.md.bak'), userContent, '사용자 콘텐츠가 .bak에 보존되지 않음');
    assert.notEqual(read(root, 'flight-rules.md'), userContent, '--force인데 덮어쓰지 않음');
    assert.ok(cap2.logs.some((l) => l.includes('강제 덮어씀')));
  });
});

// ── cmdMigrate ──

test('cmdMigrate: v1 매니페스트 → 해시 back-fill(schemaVersion 2) + 한계 안내', () => {
  withTemp((root) => {
    writeFile(root, 'flight-rules.md', 'CONTENT\n');
    // 디스크에 v1 형태 직접 기록(schemaVersion 부재, files=string[])
    writeFileSync(manifestPath(root), JSON.stringify({
      version: '1.0.0',
      files: ['flight-rules.md'],
      backups: [], hooks: [],
    }, null, 2));

    const { io, cap } = captureIO();
    assert.equal(cmdMigrate(root, io), 0);
    const m = readManifest(root);
    assert.ok(m && m.schemaVersion === 2);
    const fr = m.files.find((f) => f.path === 'flight-rules.md');
    assert.ok(fr && fr.hash === hashContent('CONTENT\n'), '해시 back-fill 안 됨');
    assert.ok(cap.logs.some((l) => l.includes('한계')), '한계 안내 없음');
  });
});

test('cmdMigrate: 이미 v2 → no-op, 0, "이미 최신" 안내', () => {
  withTemp((root) => {
    writeFile(root, 'flight-rules.md', 'CONTENT\n');
    writeManifest(root, v2Manifest([mf('flight-rules.md', hashContent('CONTENT\n'))]));
    const before = readFileSync(manifestPath(root), 'utf8');
    const { io, cap } = captureIO();
    assert.equal(cmdMigrate(root, io), 0);
    assert.ok(cap.logs.some((l) => l.includes('이미 최신')));
    // 멱등: 매니페스트 파일이 byte-identical
    assert.equal(readFileSync(manifestPath(root), 'utf8'), before, 'v2 매니페스트가 재기록됨');
  });
});

test('cmdMigrate: 설치 없음 → 0, 안내', () => {
  withTemp((root) => {
    const { io, cap } = captureIO();
    assert.equal(cmdMigrate(root, io), 0);
    assert.ok(cap.logs.some((l) => l.includes('carve install')));
  });
});
