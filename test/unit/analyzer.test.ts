// test/unit/analyzer.test.ts — analyzer 결정적 탐지 검증 (Milestone 1 게이트)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { mkdtempSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { analyze } from '../../src/analyzer.ts';

const FIXTURES = fileURLToPath(new URL('../fixtures/', import.meta.url));

/** 임시 프로젝트 디렉토리를 만들고 콜백 실행 후 정리한다. */
function withTempProject(
  files: Record<string, string>,
  fn: (root: string) => void,
): void {
  const root = mkdtempSync(join(tmpdir(), 'carve-an-'));
  try {
    for (const [rel, content] of Object.entries(files)) {
      const full = join(root, rel);
      mkdirSync(join(full, '..'), { recursive: true });
      writeFileSync(full, content);
    }
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

// ---- fixtures 5종: type/language 정확 판정 (핵심 게이트) ----

test('fixture cli → type=cli, ts+js, testCmd', () => {
  const p = analyze(join(FIXTURES, 'cli'));
  assert.equal(p.type, 'cli');
  assert.deepEqual(p.languages.sort(), ['javascript', 'typescript']);
  assert.equal(p.packageManager, 'npm');
  assert.equal(p.testCmd, 'npm run test');
  assert.equal(p.lintCmd, 'npm run lint');
});

test('fixture web → type=web, github-actions CI', () => {
  const p = analyze(join(FIXTURES, 'web'));
  assert.equal(p.type, 'web');
  assert.ok(p.languages.includes('typescript'));
  assert.equal(p.packageManager, 'pnpm');
  assert.equal(p.ci, 'github-actions');
  assert.equal(p.formatCmd, 'npm run format');
});

test('fixture mobile → type=mobile, dart', () => {
  const p = analyze(join(FIXTURES, 'mobile'));
  assert.equal(p.type, 'mobile');
  assert.deepEqual(p.languages, ['dart']);
  assert.equal(p.testCmd, null);
});

test('fixture desktop → type=desktop, electron', () => {
  const p = analyze(join(FIXTURES, 'desktop'));
  assert.equal(p.type, 'desktop');
  assert.deepEqual(p.languages, ['javascript']);
  assert.equal(p.packageManager, 'yarn');
});

test('fixture batch → type=batch, python', () => {
  const p = analyze(join(FIXTURES, 'batch'));
  assert.equal(p.type, 'batch');
  assert.deepEqual(p.languages, ['python']);
  assert.equal(p.packageManager, 'pip');
});

// ---- 폴백 및 대체 시그널 경로 (커버리지) ----

test('빈 디렉토리 → unknown', () => {
  withTempProject({}, (root) => {
    const p = analyze(root);
    assert.equal(p.type, 'unknown');
    assert.equal(p.packageManager, null);
    assert.equal(p.hasGit, false);
  });
});

test('exports만 있는 package.json → library', () => {
  withTempProject(
    { 'package.json': JSON.stringify({ name: 'lib', exports: './index.js' }) },
    (root) => {
      assert.equal(analyze(root).type, 'library');
    },
  );
});

test('commander 의존(=bin 없음) → cli', () => {
  withTempProject(
    {
      'package.json': JSON.stringify({
        name: 'c',
        dependencies: { commander: '^12.0.0' },
      }),
    },
    (root) => {
      assert.equal(analyze(root).type, 'cli');
    },
  );
});

test('react-native 의존 → mobile', () => {
  withTempProject(
    {
      'package.json': JSON.stringify({
        name: 'rn',
        dependencies: { 'react-native': '^0.76.0', react: '^19.0.0' },
      }),
    },
    (root) => {
      assert.equal(analyze(root).type, 'mobile');
    },
  );
});

test('node-cron 의존 → batch', () => {
  withTempProject(
    {
      'package.json': JSON.stringify({
        name: 'b',
        dependencies: { 'node-cron': '^3.0.0' },
      }),
    },
    (root) => {
      assert.equal(analyze(root).type, 'batch');
    },
  );
});

test('잘못된 package.json은 안전하게 무시 → unknown', () => {
  withTempProject({ 'package.json': '{ not valid json' }, (root) => {
    assert.equal(analyze(root).type, 'unknown');
  });
});

test('go.mod → go 언어 + go 패키지매니저', () => {
  withTempProject({ 'go.mod': 'module demo\n', 'go.sum': '' }, (root) => {
    const p = analyze(root);
    assert.ok(p.languages.includes('go'));
    assert.equal(p.packageManager, 'go');
  });
});

test('.gitlab-ci.yml → gitlab-ci', () => {
  withTempProject({ '.gitlab-ci.yml': 'stages: [test]\n' }, (root) => {
    assert.equal(analyze(root).ci, 'gitlab-ci');
  });
});

test('.git 디렉토리 → hasGit=true', () => {
  withTempProject({ '.git/HEAD': 'ref: refs/heads/main\n' }, (root) => {
    assert.equal(analyze(root).hasGit, true);
  });
});
