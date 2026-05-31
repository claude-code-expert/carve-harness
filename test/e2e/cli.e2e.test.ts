// test/e2e/cli.e2e.test.ts — bin/carve.ts를 실제 서브프로세스로 실행하는 E2E 스모크 테스트.
// src/cli.ts 단위 테스트가 닿지 못하는 엔트리포인트(프로세스 경계)를 검증한다.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const BIN = fileURLToPath(new URL('../../bin/carve.ts', import.meta.url));

/** carve를 실행하고 {status, stdout, stderr} 반환 (bin shebang과 동일한 플래그 사용) */
function carve(args: string[]) {
  return spawnSync(
    process.execPath,
    ['--disable-warning=ExperimentalWarning', BIN, ...args],
    { encoding: 'utf8' },
  );
}

test('E2E: carve --version → 버전 출력 + exit 0', () => {
  const r = carve(['--version']);
  assert.equal(r.status, 0);
  assert.match(r.stdout.trim(), /^\d+\.\d+\.\d+$/);
});

test('E2E: carve (인자 없음) → 사용법 + exit 0', () => {
  const r = carve([]);
  assert.equal(r.status, 0);
  assert.match(r.stdout, /사용법/);
});

test('E2E: carve list → 구성요소 출력 + exit 0', () => {
  const r = carve(['list']);
  assert.equal(r.status, 0);
  assert.match(r.stdout, /harness-architect/);
});

test('E2E: carve bogus → 에러 + exit 1', () => {
  const r = carve(['bogus']);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /알 수 없는 명령/);
});
