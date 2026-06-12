// test/unit/hooks.test.ts — 생성되는 결정적 훅의 동작 검증 (Milestone 3 게이트, PoC 핵심).
// 훅에 JSON을 stdin으로 주입해 exit code(2=차단 / 0=허용)를 단언한다.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { mkdtempSync, rmSync, existsSync, writeFileSync } from 'node:fs';
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

// ── 문법 (전체 10개 훅) ──
for (const h of [
  'block-destructive.sh', 'protect-secrets.sh', 'anti-slop.sh',
  'pre-commit-lint.sh', 'pre-push-test.sh', 'auto-format.sh', 'slack-notify.sh', 'precompact-handoff.sh',
  'codesight-refresh.sh', 'auto-commit.sh',
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
test('block-destructive: 인용부호 우회 차단(exit 2) — rm -rf "/", chmod -R 777 "/"', () => {
  assert.equal(bd('rm -rf "/"'), 2);
  assert.equal(bd("rm -rf '/'"), 2);
  assert.equal(bd('chmod -R 777 "/"'), 2);
});
test('block-destructive: chmod 변형 차단(exit 2) — 0777·멀티플래그·플래그없음', () => {
  assert.equal(bd('chmod 0777 /'), 2);
  assert.equal(bd('chmod -fR 777 /'), 2);
  assert.equal(bd('chmod 777 /'), 2);
});
test('block-destructive: chmod 안전 사용은 허용(exit 0)', () => {
  assert.equal(bd('chmod 755 script.sh'), 0);
  assert.equal(bd('chmod 777 ./tmp/sandbox'), 0); // 루트(/)가 아닌 대상
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
test('protect-secrets: 대소문자 우회 차단(exit 2) — .ENV, server.PEM, secrets.YAML', () => {
  assert.equal(ps('.ENV'), 2);
  assert.equal(ps('certs/server.PEM'), 2);
  assert.equal(ps('config/secrets.YAML'), 2);
});
test('protect-secrets: .env 구분자 변형 차단(exit 2) — .env-local, .env_ci', () => {
  assert.equal(ps('.env-local'), 2);
  assert.equal(ps('config/.env_ci'), 2);
  assert.equal(ps('.env.staging.local'), 2);
});
test('protect-secrets: 허용 확장 — .env.SAMPLE, .env.template, secrets.yaml.example (exit 0)', () => {
  assert.equal(ps('.env.SAMPLE'), 0);
  assert.equal(ps('.env.template'), 0);
  assert.equal(ps('secrets.yaml.example'), 0);
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
test('pre-commit-lint: 멀티워드 명령도 bash -c로 실행(eval 제거 회귀)', () => {
  const f = (env: Record<string, string>) =>
    runHook('pre-commit-lint.sh', { tool_input: { command: 'git commit -m x' } }, env).status;
  assert.equal(f({ CARVE_LINT_CMD: 'exit 1' }), 2);
  assert.equal(f({ CARVE_LINT_CMD: 'echo ok && exit 0' }), 0);
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

// ── auto-commit: 이중 옵트인 + tracked만 스테이징(-u) ──
test('auto-commit: 기본 OFF — 옵트인 없으면 no-op (exit 0)', () => {
  assert.equal(runHook('auto-commit.sh', {}).status, 0);
});
test('auto-commit: CARVE_AUTO_COMMIT=on — tracked 변경만 커밋, untracked 미포함', () => {
  const root = mkdtempSync(join(tmpdir(), 'carve-ac-'));
  const git = (...args: string[]) =>
    spawnSync('git', args, {
      cwd: root, encoding: 'utf8',
      env: {
        ...process.env,
        GIT_AUTHOR_NAME: 't', GIT_AUTHOR_EMAIL: 't@t', GIT_COMMITTER_NAME: 't', GIT_COMMITTER_EMAIL: 't@t',
      },
    });
  try {
    git('init', '-q');
    writeFileSync(join(root, 'tracked.txt'), 'v1\n');
    git('add', 'tracked.txt');
    git('commit', '-qm', 'init');
    writeFileSync(join(root, 'tracked.txt'), 'v2\n'); // tracked 수정
    writeFileSync(join(root, 'untracked.env'), 'SECRET=1\n'); // untracked — 포함되면 안 됨
    const r = spawnSync('bash', [hook('auto-commit.sh')], {
      input: '{}', encoding: 'utf8', cwd: root,
      env: {
        ...process.env, CARVE_AUTO_COMMIT: 'on',
        GIT_AUTHOR_NAME: 't', GIT_AUTHOR_EMAIL: 't@t', GIT_COMMITTER_NAME: 't', GIT_COMMITTER_EMAIL: 't@t',
      },
    });
    assert.equal(r.status, 0);
    const status = git('status', '--porcelain').stdout;
    assert.ok(!/tracked\.txt/.test(status), 'tracked 변경이 커밋되지 않음');
    assert.match(status, /\?\? untracked\.env/); // untracked는 그대로 남아야 함
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
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
