// test/e2e/report.e2e.test.ts — carve report E2E (M10 TELEM-04).
// 검증: cli run('report') 경로로 jsonl 집계(발화·차단), 매니페스트 기준 0-fire 목록,
//       메트릭 파일 없음 시 graceful degrade(기록 없음 + return 0).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  mkdtempSync, rmSync, writeFileSync, mkdirSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { run, type IO } from '../../src/cli.ts';
import { MANIFEST_NAME, type Manifest } from '../../src/manifest.ts';

function withTemp(fn: (root: string) => void): void {
  const root = mkdtempSync(join(tmpdir(), 'carve-rep-e2e-'));
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

interface Captured { logs: string[]; errs: string[] }
function captureIO(): { io: IO; cap: Captured } {
  const cap: Captured = { logs: [], errs: [] };
  const io: IO = {
    log: (m: string) => cap.logs.push(m),
    error: (m: string) => cap.errs.push(m),
  };
  return { io, cap };
}

test('report E2E: jsonl 집계 + 매니페스트 0-fire 목록', () => {
  withTemp((root) => {
    const lines = [
      { ts: 1, hook: 'block-destructive', event: 'block' },
      { ts: 2, hook: 'block-destructive', event: 'allow' },
      { ts: 3, hook: 'protect-secrets', event: 'block' },
      { ts: 4, hook: 'protect-secrets', event: 'block' },
    ].map((o) => JSON.stringify(o));
    writeFile(root, '.claude/.carve-metrics.jsonl', lines.join('\n') + '\n');

    // 매니페스트: auto-format은 설치됐지만 메트릭이 없음 → 0-fire(노이즈 후보).
    const m: Manifest = {
      schemaVersion: 2,
      version: '2.0.0',
      files: [
        { path: '.claude/hooks/carve-block-destructive.sh', hash: 'x', assetVersion: '2.0.0' },
        { path: '.claude/hooks/carve-protect-secrets.sh', hash: 'y', assetVersion: '2.0.0' },
        { path: '.claude/hooks/carve-auto-format.sh', hash: 'z', assetVersion: '2.0.0' },
      ],
      backups: [],
      hooks: [],
    };
    writeFile(root, MANIFEST_NAME, JSON.stringify(m, null, 2));

    const { io, cap } = captureIO();
    assert.equal(run(['report', root], io), 0);
    const out = cap.logs.join('\n');
    // 발화·차단 집계 (block-destructive: 발화 2 · 차단 1)
    assert.match(out, /block-destructive[^\n]*2[^\n]*1/);
    assert.match(out, /protect-secrets[^\n]*2[^\n]*2/);
    // 0-fire 목록에 auto-format 등장
    assert.match(out, /노이즈 후보[^\n]*auto-format/);
  });
});

test('report E2E: 메트릭 파일 없음 → 기록 없음 + return 0', () => {
  withTemp((root) => {
    const { io, cap } = captureIO();
    assert.equal(run(['report', root], io), 0);
    assert.match(cap.logs.join('\n'), /기록 없음/);
  });
});
