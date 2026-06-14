// test/e2e/update.e2e.test.ts — carve update / carve migrate E2E (M8 LIFE-03/04/05).
// 검증: carve-updated 갱신, user-modified 보존/강제, new-recommended 제안만,
//       audit-gate-before-write 원자성, 미마이그레이션 거부, migrate 위임·멱등.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  mkdtempSync, rmSync, existsSync, readFileSync, writeFileSync, mkdirSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import {
  cmdUpdate, cmdMigrate, cmdInstall, cmdInitClaude, cmdDoctor, cmdDiff, cmdUninstall, cmdReport,
} from '../../src/commands.ts';
import {
  readManifest, writeManifest, hashContent, manifestPath,
  type Manifest, type ManifestFile,
} from '../../src/manifest.ts';
import type { IO } from '../../src/cli.ts';

function withTemp(fn: (root: string) => void): void {
  const root = mkdtempSync(join(tmpdir(), 'carve-upd-'));
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

function read(root: string, rel: string): string {
  return readFileSync(join(root, rel), 'utf8');
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

function mf(path: string, hash: string): ManifestFile {
  return { path, hash, assetVersion: '1.0.0' };
}

function v2Manifest(files: ManifestFile[]): Manifest {
  return { schemaVersion: 2, version: '1.0.0', files, backups: [], hooks: [] };
}

// ── cmdUpdate ──

test('cmdUpdate: 미마이그레이션(v1, 빈 해시) → 1 반환, migrate 안내, 쓰기 없음', () => {
  withTemp((root) => {
    const flight = join(root, 'flight-rules.md');
    writeFile(root, 'flight-rules.md', 'ORIGINAL\n');
    // 해시 ''인 항목 = 미마이그레이션
    writeManifest(root, v2Manifest([mf('flight-rules.md', '')]));
    const before = read(root, 'flight-rules.md');
    const { io, cap } = captureIO();
    const code = cmdUpdate(root, io);
    assert.equal(code, 1);
    assert.ok(cap.errs.some((e) => e.includes('carve migrate')), 'migrate 안내 없음');
    assert.equal(read(root, 'flight-rules.md'), before, '파일이 변경됨');
    assert.equal(existsSync(flight + '.bak'), false, '.bak 생성됨(쓰기 발생)');
  });
});

test('cmdUpdate: 설치 없음(manifest null) → 0, 안내', () => {
  withTemp((root) => {
    const { io, cap } = captureIO();
    const code = cmdUpdate(root, io);
    assert.equal(code, 0);
    assert.ok(cap.logs.some((l) => l.includes('carve install')));
  });
});

test('cmdUpdate: 일부 항목만 빈 해시여도 미마이그레이션으로 거부(보수적)', () => {
  withTemp((root) => {
    // readManifest는 디스크 v1을 항상 schemaVersion=2로 정규화하므로,
    // 실제 미마이그레이션 신호는 "빈 해시"다. 한 항목이라도 빈 해시면 거부한다.
    writeFile(root, 'flight-rules.md', 'X\n');
    writeManifest(root, v2Manifest([
      mf('flight-rules.md', hashContent('X\n')),
      mf('.claude/legacy.md', ''), // v1 잔재 — 빈 해시
    ]));
    const { io, cap } = captureIO();
    assert.equal(cmdUpdate(root, io), 1);
    assert.ok(cap.errs.some((e) => e.includes('carve migrate')));
  });
});

test('cmdUpdate: carve-updated 자산 갱신 + 매니페스트 해시 교체, 미변경 항목 보존', () => {
  withTemp((root) => {
    // flight-rules.md: 디스크=매니페스트(=설치 시점) 동일, carve 자산은 새 콘텐츠.
    // classify는 generate()의 현재 콘텐츠와 비교하므로, 디스크/매니페스트를 "옛 carve 콘텐츠"로 맞춰
    // generate()가 만드는 현재 콘텐츠와 다르게 한다 → carve-updated.
    // 핵심: 디스크 콘텐츠 해시 === 매니페스트 해시(=orig) && generate next !== orig.
    // 실제 generate 콘텐츠를 모르므로, 디스크/매니페스트에 임의의 동일 "옛" 콘텐츠를 둔다.
    const oldContent = 'OLD CARVE CONTENT — definitely not what generate produces\n';
    writeFile(root, 'flight-rules.md', oldContent);
    // 미변경 보존 검증용 추가 파일: 매니페스트에만 있고 generate 추천 집합엔 없음(분류 대상 아님).
    const untouched = mf('.claude/keepme.md', hashContent('keep\n'));
    writeManifest(root, v2Manifest([
      mf('flight-rules.md', hashContent(oldContent)),
      untouched,
    ]));

    const { io, cap } = captureIO();
    const code = cmdUpdate(root, io);
    assert.equal(code, 0);

    const after = read(root, 'flight-rules.md');
    assert.notEqual(after, oldContent, 'flight-rules.md가 갱신되지 않음');
    // 사용자 원본(옛 carve 콘텐츠)은 .bak로 보존
    assert.ok(existsSync(join(root, 'flight-rules.md.bak')));

    const m2 = readManifest(root);
    assert.ok(m2);
    const fr = m2.files.find((f) => f.path === 'flight-rules.md');
    assert.ok(fr);
    assert.equal(fr.hash, hashContent(after), '매니페스트 해시가 새 콘텐츠와 불일치');
    // 분류 대상이 아니던 항목은 그대로 보존됨(매니페스트 완전성)
    const keep = m2.files.find((f) => f.path === '.claude/keepme.md');
    assert.ok(keep && keep.hash === untouched.hash, '미변경 매니페스트 항목 손실');
    assert.equal(m2.schemaVersion, 2);
    assert.ok(cap.logs.some((l) => l.includes('업데이트 완료')));
  });
});

test('cmdUpdate: user-modified는 기본 보존(건드리지 않음), --force면 .bak 1회 후 덮어씀', () => {
  withTemp((root) => {
    // 사용자가 수정 → 디스크 해시 != 매니페스트 해시(orig). next도 다름 → user-modified.
    const userContent = 'USER EDITED — keep me by default\n';
    writeFile(root, 'flight-rules.md', userContent);
    writeManifest(root, v2Manifest([
      mf('flight-rules.md', hashContent('original installed content\n')),
    ]));

    // 기본: 보존
    const { io } = captureIO();
    assert.equal(cmdUpdate(root, io), 0);
    assert.equal(read(root, 'flight-rules.md'), userContent, '기본 모드에서 사용자 파일이 변경됨');
    assert.equal(existsSync(join(root, 'flight-rules.md.bak')), false, '기본 모드에서 .bak 생성됨');

    // --force: .bak에 사용자 콘텐츠 보존 후 덮어씀
    const { io: io2, cap: cap2 } = captureIO();
    assert.equal(cmdUpdate(root, io2, { force: true }), 0);
    assert.equal(read(root, 'flight-rules.md.bak'), userContent, '사용자 콘텐츠가 .bak에 보존되지 않음');
    assert.notEqual(read(root, 'flight-rules.md'), userContent, '--force인데 덮어쓰지 않음');
    assert.ok(cap2.logs.some((l) => l.includes('강제 덮어씀')));
  });
});

// ── M12: 텔레메트리 기반 제안 표면화 (제안만 — write 경로 불변) ──

test('cmdUpdate: 0-fire 훅 → 텔레메트리 제안 표면화 + carve-updated write 경로 불변', () => {
  withTemp((root) => {
    // carve-updated 1건(기존 패턴) + manifest에 계측·미발화 훅(0-fire) + metrics jsonl.
    const oldContent = 'OLD CARVE CONTENT — not what generate produces\n';
    writeFile(root, 'flight-rules.md', oldContent);
    writeManifest(root, v2Manifest([
      mf('flight-rules.md', hashContent(oldContent)),
      mf('.claude/hooks/carve-pre-push-test.sh', hashContent('x')), // 계측·미발화 → 0-fire
    ]));
    // metrics: pre-push-test 미등장 → 0-fire 후보.
    writeFile(root, '.claude/.carve-metrics.jsonl',
      `${JSON.stringify({ ts: 1, hook: 'block-destructive', event: 'block' })}\n`);

    const { io, cap } = captureIO();
    assert.equal(cmdUpdate(root, io), 0);
    // 제안 표면화(제안만)
    assert.ok(
      cap.logs.some((l) => l.includes('텔레메트리 제안') && l.includes('pre-push-test')),
      '0-fire 제안이 표면화되지 않음',
    );
    // write 경로 불변: carve-updated는 여전히 갱신됨(metrics가 write를 막지 않음)
    assert.notEqual(read(root, 'flight-rules.md'), oldContent, 'metrics 존재가 carve-updated write를 바꿈');
  });
});

test('cmdUpdate: metrics 없으면 제안 무출력 (하위호환 — 기존 동작 동일)', () => {
  withTemp((root) => {
    const oldContent = 'OLD CARVE CONTENT — not what generate produces\n';
    writeFile(root, 'flight-rules.md', oldContent);
    writeManifest(root, v2Manifest([mf('flight-rules.md', hashContent(oldContent))]));
    const { io, cap } = captureIO();
    assert.equal(cmdUpdate(root, io), 0);
    assert.ok(!cap.logs.some((l) => l.includes('텔레메트리 제안')), 'metrics 없는데 제안 출력됨');
  });
});

// ── 회귀: CLAUDE.md append-merge 센티넬(빈 해시)이 v1 미마이그레이션과 충돌하지 않아야 함 ──

test('cmdUpdate: CLAUDE.md 센티넬(빈 해시)만 있으면 차단 안 함 (회귀: init-claude→update 데드락)', () => {
  withTemp((root) => {
    writeFile(root, 'flight-rules.md', 'X\n');
    writeManifest(root, v2Manifest([
      mf('flight-rules.md', hashContent('X\n')),
      mf('CLAUDE.md', ''), // init-claude가 남기는 append-merge 센티넬 — v1 신호 아님
    ]));
    const { io, cap } = captureIO();
    const code = cmdUpdate(root, io);
    assert.equal(code, 0, 'CLAUDE.md 센티넬로 update가 잘못 차단됨');
    assert.ok(!cap.errs.some((e) => e.includes('carve migrate')), 'CLAUDE.md 센티넬에 migrate 오안내');
  });
});

test('회귀: 실제 install → init-claude → update/diff/doctor 가 데드락되지 않음', () => {
  withTemp((root) => {
    writeFile(root, 'package.json', '{"name":"d","scripts":{"test":"echo ok"}}');
    const { io } = captureIO();
    assert.equal(cmdInstall(root, io), 0);
    assert.equal(cmdInitClaude(root, io), 0);
    // update: 센티넬 때문에 차단되면 안 됨
    const { io: io2, cap: cap2 } = captureIO();
    assert.equal(cmdUpdate(root, io2), 0, 'init-claude 후 update가 차단됨');
    assert.ok(!cap2.errs.some((e) => e.includes('migrate')));
    // doctor: 미마이그레이션 오안내 없음
    const { io: io3, cap: cap3 } = captureIO();
    cmdDoctor(root, io3);
    assert.ok(!cap3.logs.some((l) => l.includes('미마이그레이션')), 'doctor 미마이그레이션 오안내');
    // diff: CLAUDE.md를 user-modified/미마이그레이션으로 잘못 분류하지 않음
    const { io: io4, cap: cap4 } = captureIO();
    cmdDiff(root, io4);
    assert.ok(!cap4.logs.some((l) => l.includes('미마이그레이션 항목')), 'diff 미마이그레이션 오분류');
  });
});

test('회귀: install → init-claude → 재설치 → uninstall 후 claude-base 비고아 (manifest union)', () => {
  withTemp((root) => {
    writeFile(root, 'package.json', '{"name":"d"}');
    const { io } = captureIO();
    cmdInstall(root, io);
    cmdInitClaude(root, io);
    cmdInstall(root, io); // 재설치 — union 전엔 manifest.files를 덮어써 claude-base 누락
    const m = readManifest(root);
    assert.ok(m && m.files.some((f) => f.path === '.claude/CLAUDE.md'), '재설치 후 claude-base가 매니페스트에서 누락');
    cmdUninstall(root, io);
    assert.equal(existsSync(join(root, '.claude/CLAUDE.md')), false, 'uninstall이 claude-base를 제거 못함(고아)');
  });
});

// ── 회귀: cmdReport는 비계측 훅(slack-notify/codesight-refresh)을 0-fire 노이즈로 오탐하지 않음 ──

test('cmdReport: 비계측 훅은 0-fire 노이즈 후보에서 제외 (회귀: slack-notify 오탐)', () => {
  withTemp((root) => {
    writeFile(root, '.claude/.carve-metrics.jsonl',
      `${JSON.stringify({ ts: 1, hook: 'block-destructive', event: 'block' })}\n`);
    writeManifest(root, v2Manifest([
      mf('.claude/hooks/carve-block-destructive.sh', hashContent('a')),
      mf('.claude/hooks/carve-slack-notify.sh', hashContent('b')),     // 비계측
      mf('.claude/hooks/carve-codesight-refresh.sh', hashContent('c')), // 비계측
      mf('.claude/hooks/carve-pre-push-test.sh', hashContent('d')),     // 계측·0회 발화 → 후보여야 함
    ]));
    const { io, cap } = captureIO();
    assert.equal(cmdReport(root, io), 0);
    const zeroLine = cap.logs.find((l) => l.includes('발화 0회 훅')) ?? '';
    assert.ok(!zeroLine.includes('slack-notify'), 'slack-notify가 0-fire 오탐됨');
    assert.ok(!zeroLine.includes('codesight-refresh'), 'codesight-refresh가 0-fire 오탐됨');
    assert.ok(zeroLine.includes('pre-push-test'), '계측·미발화 훅은 후보로 보고돼야 함');
  });
});

// ── 회귀: --level 영속 → update/diff가 동일 레벨로 재현 ──

test('회귀: --level full 설치 시 manifest.level 영속 + update가 동일 레벨 재현', () => {
  withTemp((root) => {
    writeFile(root, 'package.json', '{"name":"d"}'); // auto=minimal
    const { io } = captureIO();
    cmdInstall(root, io, undefined, false, 'full'); // --level full 강제
    const m = readManifest(root);
    assert.equal(m?.level, 'full', 'manifest에 level 미기록');
    assert.ok(m?.files.some((f) => f.path === '.claude/skills/test-gen/SKILL.md'), 'full 컴포넌트(test-gen) 미설치');
    // update가 m.level(full)로 재현 → test-gen을 신규 추천으로 오판하지 않음
    const { io: io2, cap: cap2 } = captureIO();
    assert.equal(cmdUpdate(root, io2), 0);
    assert.ok(!cap2.logs.some((l) => l.includes('test-gen') && l.includes('신규 추천')), 'full 컴포넌트가 신규 추천으로 오판');
  });
});

// ── cmdMigrate ──

test('cmdMigrate: v1 매니페스트 → 해시 back-fill(schemaVersion 2) + 한계 안내', () => {
  withTemp((root) => {
    writeFile(root, 'flight-rules.md', 'CONTENT\n');
    // 디스크에 v1 형태 직접 기록(schemaVersion 부재, files=string[])
    writeFileSync(manifestPath(root), JSON.stringify({
      version: '1.0.0',
      files: ['flight-rules.md'],
      backups: [], hooks: [],
    }, null, 2));

    const { io, cap } = captureIO();
    assert.equal(cmdMigrate(root, io), 0);
    const m = readManifest(root);
    assert.ok(m && m.schemaVersion === 2);
    const fr = m.files.find((f) => f.path === 'flight-rules.md');
    assert.ok(fr && fr.hash === hashContent('CONTENT\n'), '해시 back-fill 안 됨');
    assert.ok(cap.logs.some((l) => l.includes('한계')), '한계 안내 없음');
  });
});

test('cmdMigrate: 이미 v2 → no-op, 0, "이미 최신" 안내', () => {
  withTemp((root) => {
    writeFile(root, 'flight-rules.md', 'CONTENT\n');
    writeManifest(root, v2Manifest([mf('flight-rules.md', hashContent('CONTENT\n'))]));
    const before = readFileSync(manifestPath(root), 'utf8');
    const { io, cap } = captureIO();
    assert.equal(cmdMigrate(root, io), 0);
    assert.ok(cap.logs.some((l) => l.includes('이미 최신')));
    // 멱등: 매니페스트 파일이 byte-identical
    assert.equal(readFileSync(manifestPath(root), 'utf8'), before, 'v2 매니페스트가 재기록됨');
  });
});

test('cmdMigrate: 설치 없음 → 0, 안내', () => {
  withTemp((root) => {
    const { io, cap } = captureIO();
    assert.equal(cmdMigrate(root, io), 0);
    assert.ok(cap.logs.some((l) => l.includes('carve install')));
  });
});
