// test/e2e/poc.e2e.test.ts — PoC 합격 시나리오 통합 검증 (Milestone 6).
// "임의 프로젝트 → carve install → 생성된 검증 훅이 위반을 결정적으로 차단" 한 줄을 끝까지 검증.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  mkdtempSync, rmSync, existsSync, readFileSync, writeFileSync, mkdirSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { cmdInstall, cmdUninstall } from '../../src/commands.ts';
import { readManifest } from '../../src/manifest.ts';

function silentIO() {
  return { log: () => {}, error: () => {} };
}

/** web+TS fixture 프로젝트 생성 */
function makeWebProject(): string {
  const root = mkdtempSync(join(tmpdir(), 'carve-poc-'));
  writeFileSync(join(root, 'package.json'), JSON.stringify({
    name: 'poc-app', scripts: { test: 'vitest', lint: 'eslint .' },
    dependencies: { react: '^19.0.0' }, devDependencies: { typescript: '^5.0.0', vite: '^6.0.0' },
  }));
  writeFileSync(join(root, 'tsconfig.json'), '{}');
  return root;
}

function runHook(path: string, payload: unknown, env: Record<string, string> = {}) {
  return spawnSync('bash', [path], {
    input: JSON.stringify(payload), encoding: 'utf8', env: { ...process.env, ...env },
  });
}

test('PoC: install → 생성물·훅 등록·문서', () => {
  const root = makeWebProject();
  try {
    assert.equal(cmdInstall(root, silentIO()), 0);
    // 생성물
    assert.ok(existsSync(join(root, 'flight-rules.md')));
    assert.ok(existsSync(join(root, 'evaluation-criteria.md')));
    assert.ok(existsSync(join(root, 'CLAUDE.md')));
    assert.ok(existsSync(join(root, 'HARNESS-GUIDE.md')));
    // TS 프로젝트 → flight-rules에 any 금지
    assert.match(readFileSync(join(root, 'flight-rules.md'), 'utf8'), /any.*금지/);
    // 훅 등록
    const settings = JSON.parse(readFileSync(join(root, '.claude/settings.json'), 'utf8'));
    assert.ok(settings.hooks.PreToolUse.length > 0);
    // manifest
    assert.ok(readManifest(root));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('PoC 핵심: 생성된 PreToolUse 훅이 rm -rf /를 exit 2로 차단', () => {
  const root = makeWebProject();
  try {
    cmdInstall(root, silentIO());
    const hook = join(root, '.claude/hooks/carve-block-destructive.sh');
    assert.ok(existsSync(hook));
    assert.equal(runHook(hook, { tool_input: { command: 'rm -rf /' } }).status, 2);
    assert.equal(runHook(hook, { tool_input: { command: 'ls -la' } }).status, 0);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('PoC: 설치된 anti-slop 훅이 vendored 린터로 SVG 슬롭 탐지(경고, 비차단)', () => {
  const root = makeWebProject();
  try {
    cmdInstall(root, silentIO());
    // vendored 린터가 함께 설치됐는지
    assert.ok(existsSync(join(root, '.claude/skills/clean-html/scripts/check-slop.mjs')));
    writeFileSync(join(root, 'diagram.svg'), '<svg><linearGradient id="g"/></svg>');
    const hook = join(root, '.claude/hooks/carve-anti-slop.sh');
    const r = runHook(hook, { tool_input: { file_path: join(root, 'diagram.svg') } }, { CLAUDE_PROJECT_DIR: root });
    assert.equal(r.status, 0); // 경고 — 차단 아님
    assert.match(r.stderr, /ERROR/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('PoC: 재설치 멱등 + uninstall 클린 제거', () => {
  const root = makeWebProject();
  try {
    cmdInstall(root, silentIO());
    const m1 = readManifest(root);
    cmdInstall(root, silentIO()); // 재설치
    const settings = JSON.parse(readFileSync(join(root, '.claude/settings.json'), 'utf8'));
    // 훅 중복 없음 (PreToolUse 그룹 수가 폭증하지 않음)
    assert.ok(settings.hooks.PreToolUse.length === m1!.hooks.filter((h) => h.event === 'PreToolUse').length);
    cmdUninstall(root, silentIO());
    assert.equal(readManifest(root), null);
    assert.ok(!existsSync(join(root, '.claude/hooks/carve-block-destructive.sh')));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('PoC: 사용자 CLAUDE.md 보존(.bak) 후 uninstall 복원', () => {
  const root = makeWebProject();
  try {
    writeFileSync(join(root, 'CLAUDE.md'), 'USER OWN CLAUDE\n');
    cmdInstall(root, silentIO());
    assert.equal(readFileSync(join(root, 'CLAUDE.md.bak'), 'utf8'), 'USER OWN CLAUDE\n');
    cmdUninstall(root, silentIO());
    assert.equal(readFileSync(join(root, 'CLAUDE.md'), 'utf8'), 'USER OWN CLAUDE\n');
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
