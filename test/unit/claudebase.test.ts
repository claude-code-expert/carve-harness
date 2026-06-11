// test/unit/claudebase.test.ts — CLAUDE.md 베이스라인 + 스택별 rules 생성 (carve init-claude)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { selectStack, selectTypeOverlay, generateClaudeBase } from '../../src/claudebase.ts';
import { run, type IO } from '../../src/cli.ts';
import type { ProjectProfile } from '../../src/types.ts';

function profile(over: Partial<ProjectProfile>): ProjectProfile {
  return {
    root: '/x', type: 'cli', languages: [], packageManager: null,
    testCmd: null, lintCmd: null, formatCmd: null, ci: null, hasGit: true, signals: [],
    workspaces: [], container: { dockerfile: false, compose: false, makefile: false }, ...over,
  };
}
function capture() {
  const out = { log: '', error: '' };
  const io: IO = { log: (s) => (out.log += s + '\n'), error: (s) => (out.error += s + '\n') };
  return { io, out };
}

test('selectStack: 언어별 번들 선택 + js→typescript + 우선순위 + 미탐지 _default', () => {
  assert.equal(selectStack(profile({ languages: ['typescript'] })), 'typescript');
  assert.equal(selectStack(profile({ languages: ['javascript'] })), 'typescript');
  assert.equal(selectStack(profile({ languages: ['python'] })), 'python');
  assert.equal(selectStack(profile({ languages: ['go'] })), 'go');
  assert.equal(selectStack(profile({ languages: ['rust'] })), 'rust');
  assert.equal(selectStack(profile({ languages: ['java'] })), 'java');
  assert.equal(selectStack(profile({ languages: ['dart'] })), 'dart');
  // 다중 언어 → 우선순위(typescript 우선)
  assert.equal(selectStack(profile({ languages: ['python', 'typescript'] })), 'typescript');
  assert.equal(selectStack(profile({ languages: [] })), '_default');
});

test('generateClaudeBase: 베이스라인 + 6 stack rules + 공용 anti-ai-slop, 변수 치환', () => {
  const arts = generateClaudeBase(profile({ type: 'cli', languages: ['typescript'], packageManager: 'pnpm' }));
  const paths = arts.map((a) => a.path);
  assert.ok(paths.includes('.claude/CLAUDE.md'));
  for (const f of ['techstack', 'project-structure', 'commands', 'code-style', 'safety', 'gotchas']) {
    assert.ok(paths.includes(`.claude/rules/${f}.md`), `${f} 누락`);
  }
  assert.ok(paths.includes('.claude/rules/anti-ai-slop.md'), '공용 anti-ai-slop 규칙 누락');
  const commands = arts.find((a) => a.path === '.claude/rules/commands.md')!;
  assert.match(commands.content, /pnpm/); // {{PKG_MANAGER}} 치환됨
  assert.doesNotMatch(commands.content, /\{\{PKG_MANAGER\}\}/); // 미치환 잔여 없음
});

test('selectTypeOverlay: p.type별 오버레이 선택 + unknown/미매핑은 _default', () => {
  for (const t of ['cli', 'web', 'mobile', 'desktop', 'batch', 'library'] as const) {
    assert.equal(selectTypeOverlay(profile({ type: t })), t);
  }
  assert.equal(selectTypeOverlay(profile({ type: 'unknown' })), '_default');
});

test('generateClaudeBase: 프로젝트 타입 오버레이(project-type.md) 생성 + 타입별 내용', () => {
  const web = generateClaudeBase(profile({ type: 'web', languages: ['typescript'] }));
  const overlay = web.find((a) => a.path === '.claude/rules/project-type.md');
  assert.ok(overlay, 'project-type.md 누락');
  assert.match(overlay!.content, /Web/); // web 오버레이 내용
  // unknown 타입 → _default 오버레이(General)
  const unk = generateClaudeBase(profile({ type: 'unknown', languages: [] }));
  const unkOverlay = unk.find((a) => a.path === '.claude/rules/project-type.md');
  assert.match(unkOverlay!.content, /General/);
});

test('generateClaudeBase: _default 폴백(미지원 언어)도 모든 rule이 비어있지 않고 미치환 변수 없음', () => {
  const arts = generateClaudeBase(profile({ type: 'cli', languages: ['kotlin'] })); // 미지원 → _default
  const rules = arts.filter((a) => a.path.startsWith('.claude/rules/'));
  assert.ok(rules.length >= 7, 'rule 수 부족');
  for (const a of rules) {
    assert.ok(a.content.trim().length > 0, `${a.path} 비어있음`);
    assert.doesNotMatch(a.content, /\{\{\w+\}\}/, `${a.path} 미치환 변수 잔여`);
  }
});

test('generateClaudeBase: 전 스택(+_default) 모든 rule 비어있지 않음 · 미치환 변수 없음', () => {
  const cases: Array<[string, string[]]> = [
    ['typescript', ['typescript']], ['python', ['python']], ['go', ['go']],
    ['rust', ['rust']], ['java', ['java']], ['dart', ['dart']], ['_default', []],
  ];
  for (const [label, languages] of cases) {
    const arts = generateClaudeBase(profile({ type: 'cli', languages }));
    for (const a of arts.filter((x) => x.path.startsWith('.claude/rules/'))) {
      assert.ok(a.content.trim().length > 0, `${label}: ${a.path} 비어있음`);
      assert.doesNotMatch(a.content, /\{\{\w+\}\}/, `${label}: ${a.path} 미치환 변수`);
    }
  }
});

test('generateClaudeBase: 변수 폴백 — packageManager 미탐지 시 스택 기본값 사용', () => {
  const arts = generateClaudeBase(profile({ type: 'cli', languages: ['typescript'], packageManager: null }));
  const commands = arts.find((a) => a.path === '.claude/rules/commands.md')!;
  assert.match(commands.content, /npm/); // typescript 기본값
});

test('init-claude: 생성된 모든 rule 파일이 루트 @import 블록과 1:1 (project-type 포함)', () => {
  const root = mkdtempSync(join(tmpdir(), 'carve-claude-sync-'));
  try {
    writeFileSync(join(root, 'package.json'), JSON.stringify({ name: 't' }));
    writeFileSync(join(root, 'tsconfig.json'), '{}');
    run(['init-claude', root], capture().io);
    const rootClaude = readFileSync(join(root, 'CLAUDE.md'), 'utf8');
    assert.match(rootClaude, /@\.claude\/rules\/project-type\.md/);
    // 생성된 각 rules 파일이 @import에 존재해야 함(생성 목록 ↔ 블록 정합)
    for (const f of ['techstack', 'project-structure', 'commands', 'code-style', 'safety', 'gotchas', 'project-type', 'anti-ai-slop']) {
      assert.ok(existsSync(join(root, `.claude/rules/${f}.md`)), `${f}.md 미생성`);
      assert.ok(rootClaude.includes(`@.claude/rules/${f}.md`), `${f}.md @import 누락`);
    }
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('init-claude: .claude/CLAUDE.md + rules 생성, 루트 CLAUDE.md @import 연결', () => {
  const root = mkdtempSync(join(tmpdir(), 'carve-claude-'));
  try {
    writeFileSync(join(root, 'package.json'), JSON.stringify({ name: 't' }));
    writeFileSync(join(root, 'tsconfig.json'), '{}');
    const { io, out } = capture();
    assert.equal(run(['init-claude', root], io), 0);
    assert.ok(existsSync(join(root, '.claude/CLAUDE.md')));
    assert.ok(existsSync(join(root, '.claude/rules/safety.md')));
    assert.ok(existsSync(join(root, '.claude/rules/anti-ai-slop.md')));
    assert.match(out.log, /stack=typescript/);
    // 루트 CLAUDE.md가 생성되고 @import 블록을 포함
    const rootClaude = readFileSync(join(root, 'CLAUDE.md'), 'utf8');
    assert.match(rootClaude, /@\.claude\/CLAUDE\.md/);
    assert.match(rootClaude, /@\.claude\/rules\/techstack\.md/);
    assert.match(rootClaude, /@\.claude\/rules\/anti-ai-slop\.md/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('init-claude: 멱등 — 두 번 실행해도 import 블록은 1회', () => {
  const root = mkdtempSync(join(tmpdir(), 'carve-claude-idem-'));
  try {
    writeFileSync(join(root, 'pyproject.toml'), '[project]\nname="t"\n');
    run(['init-claude', root], capture().io);
    run(['init-claude', root], capture().io);
    const rootClaude = readFileSync(join(root, 'CLAUDE.md'), 'utf8');
    const markers = rootClaude.split('<!-- carve:claude-base -->').length - 1;
    assert.equal(markers, 1);
    // python 프로젝트 → python 번들 (commands에 pytest)
    assert.match(readFileSync(join(root, '.claude/rules/commands.md'), 'utf8'), /pytest/);
    // anti-ai-slop은 스택 무관 — python에서도 동일하게 설치된다
    assert.ok(existsSync(join(root, '.claude/rules/anti-ai-slop.md')));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('init-claude 후 uninstall: 생성 파일 제거', () => {
  const root = mkdtempSync(join(tmpdir(), 'carve-claude-rm-'));
  try {
    writeFileSync(join(root, 'go.mod'), 'module t\n');
    run(['init-claude', root], capture().io);
    assert.ok(existsSync(join(root, '.claude/rules/code-style.md')));
    run(['uninstall', root], capture().io);
    assert.ok(!existsSync(join(root, '.claude/rules/code-style.md')));
    assert.ok(!existsSync(join(root, '.claude/CLAUDE.md')));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
