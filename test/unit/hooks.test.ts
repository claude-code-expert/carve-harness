// test/unit/hooks.test.ts — 생성되는 결정적 훅의 동작 검증 (Milestone 3 게이트, PoC 핵심).
// 훅에 JSON을 stdin으로 주입해 exit code(2=차단 / 0=허용)를 단언한다.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { mkdtempSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const hook = (name: string) =>
  fileURLToPath(new URL(`../../assets/hooks/${name}`, import.meta.url));

function runHook(name: string, payload: unknown, env: Record<string, string> = {}) {
  return spawnSync('bash', [hook(name)], {
    input: JSON.stringify(payload),
    encoding: 'utf8',
    env: { ...process.env, ...env },
  });
}

// ── 문법 (전체 8개 훅) ──
for (const h of [
  'block-destructive.sh', 'protect-secrets.sh', 'anti-slop.sh',
  'pre-commit-lint.sh', 'pre-push-test.sh', 'auto-format.sh', 'slack-notify.sh', 'precompact-handoff.sh',
  'codesight-refresh.sh',
]) {
  test(`${h} bash 문법 OK`, () => {
    assert.equal(spawnSync('bash', ['-n', hook(h)]).status, 0);
  });
}

// ── block-destructive: exit 2 차단 ──
const bd = (cmd: string) => runHook('block-destructive.sh', { tool_input: { command: cmd } }).status;
test('block-destructive: 위험 명령 차단(exit 2)', () => {
  assert.equal(bd('rm -rf /'), 2);
  assert.equal(bd('sudo rm -rf ~'), 2);
  assert.equal(bd('rm -rf *'), 2);
  assert.equal(bd(':(){ :|:& };:'), 2);
  assert.equal(bd('git push --force origin main'), 2);
});
test('block-destructive: 안전 명령 허용(exit 0)', () => {
  assert.equal(bd('rm -rf ./build'), 0);
  assert.equal(bd('rm file.txt'), 0);
  assert.equal(bd('ls -la'), 0);
  assert.equal(bd('confirm -rf something'), 0); // 'rm' 부분문자열 오탐 방지
  assert.equal(bd('git push origin feature'), 0);
});

// ── protect-secrets: exit 2 차단 ──
const ps = (p: string) => runHook('protect-secrets.sh', { tool_input: { file_path: p } }).status;
test('protect-secrets: 비밀 파일 차단(exit 2)', () => {
  assert.equal(ps('.env'), 2);
  assert.equal(ps('config/.env.local'), 2);
  assert.equal(ps('certs/server.pem'), 2);
  assert.equal(ps('/home/u/.ssh/id_rsa'), 2);
  assert.equal(ps('app/credentials.json'), 2);
});
test('protect-secrets: 안전 파일 허용(exit 0)', () => {
  assert.equal(ps('.env.example'), 0);
  assert.equal(ps('src/index.ts'), 0);
  assert.equal(ps('README.md'), 0);
});

// ── anti-slop: 경고 모드(차단 안 함, exit 0) ──
test('anti-slop: 비대상 파일은 즉시 통과(exit 0)', () => {
  assert.equal(runHook('anti-slop.sh', { tool_input: { file_path: 'src/x.ts' } }).status, 0);
});
test('anti-slop: 슬롭 .md여도 차단 아님(exit 0) + 경고 출력', () => {
  const root = fileURLToPath(new URL('../../', import.meta.url));
  const r = runHook(
    'anti-slop.sh',
    { tool_input: { file_path: `${root}test/fixtures/slop/slop.md` } },
    { CLAUDE_PROJECT_DIR: root.replace(/\/$/, '') },
  );
  assert.equal(r.status, 0); // 경고 모드 — 절대 차단하지 않음
  assert.match(r.stderr, /anti-slop/);
});

// ── pre-commit-lint / pre-push-test: 결정적 차단(exit 2) ──
test('pre-commit-lint: git commit + 린트 실패→2, 성공→0, 비-git→0', () => {
  const f = (c: string, env = {}) => runHook('pre-commit-lint.sh', { tool_input: { command: c } }, env).status;
  assert.equal(f('git commit -m x', { CARVE_LINT_CMD: 'false' }), 2);
  assert.equal(f('git commit -m x', { CARVE_LINT_CMD: 'true' }), 0);
  assert.equal(f('ls -la'), 0);
});
test('pre-push-test: git push + 테스트 실패→2, 성공→0, 비-push→0', () => {
  const f = (c: string, env = {}) => runHook('pre-push-test.sh', { tool_input: { command: c } }, env).status;
  assert.equal(f('git push origin main', { CARVE_TEST_CMD: 'false' }), 2);
  assert.equal(f('git push origin main', { CARVE_TEST_CMD: 'true' }), 0);
  assert.equal(f('git status'), 0);
});

// ── 비차단 훅: 항상 exit 0 ──
test('auto-format: 비차단(exit 0)', () => {
  assert.equal(runHook('auto-format.sh', { tool_input: { file_path: 'x.ts' } }, { CARVE_FORMAT_CMD: 'true' }).status, 0);
  assert.equal(runHook('auto-format.sh', { tool_input: {} }).status, 0);
});
test('slack-notify: 웹훅 없으면 통과(exit 0)', () => {
  assert.equal(runHook('slack-notify.sh', {}).status, 0);
});
test('codesight-refresh: 비-git 명령은 즉시 통과(exit 0, npx 미실행)', () => {
  assert.equal(runHook('codesight-refresh.sh', { tool_input: { command: 'ls -la' } }).status, 0);
});

test('precompact-handoff: 핸드오프 파일 append (exit 0)', () => {
  const root = mkdtempSync(join(tmpdir(), 'carve-hook-'));
  try {
    const r = runHook('precompact-handoff.sh', {}, { CLAUDE_PROJECT_DIR: root });
    assert.equal(r.status, 0);
    assert.ok(existsSync(join(root, '.carve-handoff.md')));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
