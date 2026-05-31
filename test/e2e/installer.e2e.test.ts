// test/e2e/installer.e2e.test.ts — 설치 왕복(install→재설치→uninstall) E2E (Milestone 4 게이트).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  mkdtempSync, rmSync, existsSync, readFileSync, writeFileSync, mkdirSync, statSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { install, uninstall, type HookReg, type McpReg } from '../../src/installer.ts';
import { readManifest } from '../../src/manifest.ts';
import type { Artifact } from '../../src/generator.ts';

function withTemp(fn: (root: string) => void): void {
  const root = mkdtempSync(join(tmpdir(), 'carve-inst-'));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

const ARTIFACTS: Artifact[] = [
  { path: 'flight-rules.md', content: 'CARVE RULES\n', executable: false },
  { path: '.claude/hooks/carve-x.sh', content: '#!/usr/bin/env bash\nexit 0\n', executable: true },
];
const HOOKS: HookReg[] = [
  { event: 'PreToolUse', command: 'bash .claude/hooks/carve-x.sh', matcher: 'Bash' },
];

test('fresh install: 파일·settings 훅·manifest 생성, 실행권한', () => {
  withTemp((root) => {
    const r = install(root, ARTIFACTS, HOOKS);
    assert.equal(r.written.length, 2);
    assert.ok(existsSync(join(root, 'flight-rules.md')));
    const sh = join(root, '.claude/hooks/carve-x.sh');
    assert.ok((statSync(sh).mode & 0o111) !== 0, '실행권한 없음');
    const settings = JSON.parse(readFileSync(join(root, '.claude/settings.json'), 'utf8'));
    assert.equal(settings.hooks.PreToolUse.length, 1);
    const m = readManifest(root);
    assert.ok(m && m.files.length === 2 && m.hooks.length === 1);
  });
});

test('재설치 멱등: 훅 중복 없음, 추가 .bak 없음', () => {
  withTemp((root) => {
    install(root, ARTIFACTS, HOOKS);
    const r2 = install(root, ARTIFACTS, HOOKS);
    assert.equal(r2.backedUp.length, 0);
    const settings = JSON.parse(readFileSync(join(root, '.claude/settings.json'), 'utf8'));
    assert.equal(settings.hooks.PreToolUse.length, 1); // 중복 미발생
  });
});

test('사용자 파일 보존: .bak 백업 → uninstall 시 복원', () => {
  withTemp((root) => {
    // 사용자가 이미 flight-rules.md를 갖고 있음
    writeFileSync(join(root, 'flight-rules.md'), 'USER CONTENT\n');
    const r = install(root, ARTIFACTS, HOOKS);
    assert.ok(r.backedUp.includes('flight-rules.md.bak'));
    assert.equal(readFileSync(join(root, 'flight-rules.md.bak'), 'utf8'), 'USER CONTENT\n');
    assert.equal(readFileSync(join(root, 'flight-rules.md'), 'utf8'), 'CARVE RULES\n');
    // uninstall → 사용자 원본 복원
    uninstall(root);
    assert.equal(readFileSync(join(root, 'flight-rules.md'), 'utf8'), 'USER CONTENT\n');
    assert.ok(!existsSync(join(root, 'flight-rules.md.bak')));
  });
});

test('uninstall: carve 파일·훅 제거, 사용자 훅 보존, manifest 삭제', () => {
  withTemp((root) => {
    // 사용자 훅 사전 존재
    mkdirSync(join(root, '.claude'), { recursive: true });
    writeFileSync(
      join(root, '.claude/settings.json'),
      JSON.stringify({ hooks: { PreToolUse: [{ matcher: 'Edit', hooks: [{ type: 'command', command: 'user-hook' }] }] } }, null, 2),
    );
    install(root, ARTIFACTS, HOOKS);
    const res = uninstall(root);
    assert.ok(res.removed.includes('.claude/hooks/carve-x.sh'));
    assert.ok(!existsSync(join(root, '.claude/hooks/carve-x.sh')));
    assert.equal(readManifest(root), null);
    // 사용자 훅은 살아있고 carve 훅은 사라짐
    const settings = JSON.parse(readFileSync(join(root, '.claude/settings.json'), 'utf8'));
    const cmds = settings.hooks.PreToolUse.flatMap((g: { hooks: { command: string }[] }) => g.hooks.map((h) => h.command));
    assert.ok(cmds.includes('user-hook'));
    assert.ok(!cmds.includes('bash .claude/hooks/carve-x.sh'));
  });
});

test('MCP 서버 병합·멱등·uninstall 제거 (codesight/cclsp)', () => {
  withTemp((root) => {
    const mcps: McpReg[] = [
      { name: 'codesight', command: 'npx', args: ['codesight', '--mcp'] },
      { name: 'cclsp', command: 'npx', args: ['cclsp@latest'] },
    ];
    install(root, ARTIFACTS, HOOKS, mcps);
    let s = JSON.parse(readFileSync(join(root, '.claude/settings.json'), 'utf8'));
    assert.ok(s.mcpServers.codesight && s.mcpServers.cclsp);
    assert.deepEqual(readManifest(root)!.mcps, ['codesight', 'cclsp']);
    // 재설치 멱등
    install(root, ARTIFACTS, HOOKS, mcps);
    s = JSON.parse(readFileSync(join(root, '.claude/settings.json'), 'utf8'));
    assert.equal(Object.keys(s.mcpServers).length, 2);
    // uninstall → MCP 제거
    uninstall(root);
    s = JSON.parse(readFileSync(join(root, '.claude/settings.json'), 'utf8'));
    assert.ok(!s.mcpServers?.codesight && !s.mcpServers?.cclsp);
  });
});

test('manifest 없는 곳에서 uninstall은 무해', () => {
  withTemp((root) => {
    const r = uninstall(root);
    assert.deepEqual(r, { removed: [], restored: [] });
  });
});
