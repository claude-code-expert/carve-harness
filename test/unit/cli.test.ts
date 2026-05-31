// test/unit/cli.test.ts — CLI 코어 단위 테스트 (Milestone 0 게이트)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { run, loadVersion, USAGE, type IO } from '../../src/cli.ts';

/** 출력을 캡처하는 io 채널 */
function capture(): { io: IO; out: { log: string; error: string } } {
  const out = { log: '', error: '' };
  return {
    io: {
      log: (s: string) => (out.log += s + '\n'),
      error: (s: string) => (out.error += s + '\n'),
    },
    out,
  };
}

test('loadVersion는 package.json의 버전과 일치한다', () => {
  const pkg = JSON.parse(
    readFileSync(new URL('../../package.json', import.meta.url), 'utf8'),
  ) as { version: string };
  assert.equal(loadVersion(), pkg.version);
});

test('--version은 버전을 출력하고 0을 반환한다', () => {
  const { io, out } = capture();
  const code = run(['--version'], io);
  assert.equal(code, 0);
  assert.match(out.log.trim(), /^\d+\.\d+\.\d+/);
});

test('-v 단축 플래그도 동작한다', () => {
  const { io, out } = capture();
  assert.equal(run(['-v'], io), 0);
  assert.match(out.log.trim(), /^\d+\.\d+\.\d+/);
});

test('인자 없음은 사용법을 출력하고 0을 반환한다', () => {
  const { io, out } = capture();
  assert.equal(run([], io), 0);
  assert.equal(out.log.trim(), USAGE);
});

test('--help는 사용법을 출력한다', () => {
  const { io, out } = capture();
  assert.equal(run(['--help'], io), 0);
  assert.equal(out.log.trim(), USAGE);
});

test('list는 카탈로그를 출력한다', () => {
  const { io, out } = capture();
  assert.equal(run(['list'], io), 0);
  assert.match(out.log, /harness-architect/);
});

test('install→doctor→uninstall 라운드트립 (임시 디렉토리)', () => {
  const root = mkdtempSync(join(tmpdir(), 'carve-cli-'));
  try {
    // 빈 디렉토리 doctor → 설치 없음
    const d0 = capture();
    run(['doctor', root], d0.io);
    assert.match(d0.out.log, /설치 없음/);
    // install → 매니페스트·파일 생성
    const inst = capture();
    assert.equal(run(['install', root], inst.io), 0);
    assert.match(inst.out.log, /설치 완료/);
    assert.ok(existsSync(join(root, 'carve-manifest.json')));
    assert.ok(existsSync(join(root, 'flight-rules.md')));
    assert.ok(existsSync(join(root, '.claude/skills/harness-architect/SKILL.md')));
    // doctor → 설치됨
    const d1 = capture();
    run(['doctor', root], d1.io);
    assert.match(d1.out.log, /설치됨/);
    assert.match(d1.out.log, /훅 문법 OK/); // harness-audit: 설치 훅 셸 문법 점검
    // uninstall → 매니페스트 제거
    assert.equal(run(['uninstall', root], capture().io), 0);
    assert.ok(!existsSync(join(root, 'carve-manifest.json')));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('알 수 없는 명령은 에러와 함께 1을 반환한다', () => {
  const { io, out } = capture();
  const code = run(['nonsense'], io);
  assert.equal(code, 1);
  assert.match(out.error, /알 수 없는 명령/);
});
