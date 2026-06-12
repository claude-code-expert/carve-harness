// test/unit/cli.test.ts — CLI 코어 단위 테스트 (Milestone 0 게이트)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { run, loadVersion, USAGE, KNOWN_COMMANDS, isInteractiveInstall, installDir, type IO } from '../../src/cli.ts';

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

test('isInteractiveInstall: TTY에서 인자없음·install은 대화형, 그 외는 아님', () => {
  // TTY + (bare | install) → 대화형
  assert.equal(isInteractiveInstall([], true), true);
  assert.equal(isInteractiveInstall(['install'], true), true);
  assert.equal(isInteractiveInstall(['install', './proj'], true), true);
  // --only/--yes는 비대화형 의도 → run()
  assert.equal(isInteractiveInstall(['install', '--yes'], true), false);
  assert.equal(isInteractiveInstall(['install', '--only', 'commit'], true), false);
  assert.equal(isInteractiveInstall(['install', '--only=commit'], true), false);
  // 다른 명령·플래그 → 아님
  assert.equal(isInteractiveInstall(['list'], true), false);
  assert.equal(isInteractiveInstall(['--help'], true), false);
  assert.equal(isInteractiveInstall(['-v'], true), false);
  // 비TTY(파이프·CI)면 인자없음·install이라도 아님 → run()이 help/설치 처리
  assert.equal(isInteractiveInstall([], false), false);
  assert.equal(isInteractiveInstall(['install'], false), false);
});

test('installDir: 첫 비플래그 위치인자, 없으면 cwd', () => {
  assert.equal(installDir(['install', './proj']), './proj');
  assert.equal(installDir(['./proj']), './proj');
  assert.equal(installDir(['install', '--lsp-servers', 'pkg']), 'pkg');
  assert.equal(installDir(['install']), process.cwd());
  assert.equal(installDir([]), process.cwd());
});

test('list는 카탈로그를 출력한다', () => {
  const { io, out } = capture();
  assert.equal(run(['list'], io), 0);
  assert.match(out.log, /harness-architect/);
});

test('report: 빈 디렉토리 → 기록 없음 + 0 (KNOWN_COMMANDS·USAGE 포함)', () => {
  const root = mkdtempSync(join(tmpdir(), 'carve-cli-rep-'));
  try {
    const { io, out } = capture();
    assert.equal(run(['report', root], io), 0);
    assert.match(out.log, /기록 없음/);
    assert.ok(KNOWN_COMMANDS.includes('report'));
    assert.match(USAGE, /carve report/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('run 에러 경계: 손상 manifest로 doctor → exit 1 + 진단(스택 노출 없음, "설치 없음" 오인 금지)', () => {
  const root = mkdtempSync(join(tmpdir(), 'carve-cli-'));
  try {
    writeFileSync(join(root, 'carve-manifest.json'), '{corrupt');
    const { io, out } = capture();
    assert.equal(run(['doctor', root], io), 1);
    assert.match(out.error, /오류: carve-manifest\.json 파싱 실패/);
    assert.doesNotMatch(out.log, /설치 없음/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
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

test('KNOWN_COMMANDS는 라이프사이클 명령(update/diff/migrate)을 포함한다', () => {
  for (const c of ['update', 'diff', 'migrate']) {
    assert.ok((KNOWN_COMMANDS as readonly string[]).includes(c), `KNOWN_COMMANDS에 ${c} 없음`);
  }
});

test('USAGE는 라이프사이클 명령(diff/update/migrate)을 안내한다', () => {
  for (const c of ['diff', 'update', 'migrate']) {
    assert.match(USAGE, new RegExp(`carve ${c}`), `USAGE에 carve ${c} 없음`);
  }
});

test('diff/migrate/update는 설치 없는 빈 디렉토리에서 0을 반환한다(올바른 핸들러로 디스패치)', () => {
  const root = mkdtempSync(join(tmpdir(), 'carve-cli-life-'));
  try {
    // 설치 없음 → 각 핸들러는 안내 후 0 반환 (cmdDiff/cmdMigrate/cmdUpdate의 manifest null 경로)
    const diff = capture();
    assert.equal(run(['diff', root], diff.io), 0);
    assert.match(diff.out.log, /carve 설치 없음|carve install/);

    const migrate = capture();
    assert.equal(run(['migrate', root], migrate.io), 0);
    assert.match(migrate.out.log, /carve install/);

    const update = capture();
    assert.equal(run(['update', root], update.io), 0);
    assert.match(update.out.log, /carve install/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('update는 --force·--yes 플래그를 cmdUpdate로 전달한다(설치본 강제 갱신)', () => {
  const root = mkdtempSync(join(tmpdir(), 'carve-cli-force-'));
  try {
    // 설치 후 사용자가 한 파일을 수정 → user-modified
    assert.equal(run(['install', root], capture().io), 0);
    writeFileSync(join(root, 'flight-rules.md'), 'USER EDIT — should be forced over\n');
    // --force 없이: 보존(건너뜀)
    const noForce = capture();
    assert.equal(run(['update', root], noForce.io), 0);
    assert.equal(readFileSync(join(root, 'flight-rules.md'), 'utf8'), 'USER EDIT — should be forced over\n');
    // --force --yes: 강제 덮어씀 + .bak 보존 → 플래그가 전달되었음을 증명
    const forced = capture();
    assert.equal(run(['update', root, '--force', '--yes'], forced.io), 0);
    assert.match(forced.out.log, /강제 덮어씀/);
    assert.equal(readFileSync(join(root, 'flight-rules.md.bak'), 'utf8'), 'USER EDIT — should be forced over\n');
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
