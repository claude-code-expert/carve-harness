// test/unit/commands.test.ts — classify() 3-way 분류 단위 테스트 (M8).
// 검증: 4가지 상태(unchanged/carve-updated/user-modified/new-recommended) + 미마이그레이션·삭제 케이스.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { classify, cmdReport, cmdList, cmdInstall, type DiffEntry } from '../../src/commands.ts';
import { hashContent, type Manifest, type ManifestFile } from '../../src/manifest.ts';
import type { Artifact } from '../../src/generator.ts';
import type { IO } from '../../src/cli.ts';

function captureIO(): { io: IO; msgs: string[] } {
  const msgs: string[] = [];
  const io: IO = { log: (m: string) => msgs.push(m), error: (m: string) => msgs.push(m) };
  return { io, msgs };
}

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

// ── 라이프사이클 표면화 (cmdList·cmdInstall --only) ──
test('cmdList: fade-out 7종 삭제 후 비추천 태그 없음 + 삭제 컴포넌트 미표시', () => {
  const { io, msgs } = captureIO();
  assert.equal(cmdList(io), 0);
  const out = msgs.join('\n');
  // deprecated/hidden이 0개라 비추천 태그가 어디에도 없다.
  assert.ok(!/비추천/.test(out), '비추천 태그 잔존 — 삭제 누락');
  // 삭제된 7종은 목록에 나오지 않는다.
  for (const id of ['memory', 'verify', 'pr', 'review', 'changelog', 'security-scan', 'coordinator']) {
    assert.ok(!new RegExp(`\\[skill\\] ${id} \\(`).test(out), `${id}가 목록에 표시됨`);
  }
});

test('cmdInstall --only: 미등재 id는 조용히 버리지 않고 안내한다', () => {
  withTemp((root) => {
    writeFileSync(join(root, 'package.json'), '{"name":"x"}');
    const { io, msgs } = captureIO();
    assert.equal(cmdInstall(root, io, ['commit', 'no-such-id']), 0);
    assert.ok(msgs.some((m) => m.includes('무시된 id') && m.includes('no-such-id')));
  });
});

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

// --- cmdReport (TELEM-04): 로컬 텔레메트리 집계 ---

test('cmdReport: 메트릭 파일 없음 → 기록 없음 + return 0', () => {
  withTemp((root) => {
    const { io, msgs } = captureIO();
    assert.equal(cmdReport(root, io), 0);
    assert.match(msgs.join('\n'), /기록 없음/);
  });
});

test('cmdReport: 집계 — 훅별 발화·차단, 손상 줄 무시', () => {
  withTemp((root) => {
    const lines = [
      JSON.stringify({ ts: 1, hook: 'block-destructive', event: 'block' }),
      JSON.stringify({ ts: 2, hook: 'block-destructive', event: 'allow' }),
      JSON.stringify({ ts: 3, hook: 'protect-secrets', event: 'block' }),
      '{ not valid json',                       // 손상 줄 — 무시
      JSON.stringify({ ts: 4, foo: 'bar' }),    // 필드 누락 — 무시
      '',                                       // 빈 줄 — 무시
    ];
    writeFile(root, '.claude/.carve-metrics.jsonl', lines.join('\n') + '\n');
    const { io, msgs } = captureIO();
    assert.equal(cmdReport(root, io), 0);
    const out = msgs.join('\n');
    // block-destructive: 발화 2 · 차단 1
    assert.match(out, /block-destructive[^\n]*2[^\n]*1/);
    // protect-secrets: 발화 1 · 차단 1
    assert.match(out, /protect-secrets[^\n]*1[^\n]*1/);
  });
});

test('cmdReport: 0-fire 훅을 매니페스트로 탐지', () => {
  withTemp((root) => {
    const lines = [
      JSON.stringify({ ts: 1, hook: 'block-destructive', event: 'block' }),
    ];
    writeFile(root, '.claude/.carve-metrics.jsonl', lines.join('\n') + '\n');
    // 매니페스트: 두 훅 설치됨. auto-format은 메트릭이 없음 → 0-fire(노이즈 후보).
    const m = manifest([
      mf('.claude/hooks/carve-block-destructive.sh', 'x'),
      mf('.claude/hooks/carve-auto-format.sh', 'y'),
    ]);
    writeFile(root, 'carve-manifest.json', JSON.stringify(m));
    const { io, msgs } = captureIO();
    assert.equal(cmdReport(root, io), 0);
    const out = msgs.join('\n');
    assert.match(out, /auto-format/); // 0-fire 목록에 등장
  });
});
