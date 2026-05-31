// test/unit/generator.test.ts — generator 검증 (Milestone 3 게이트)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { render, generate, hookRegsFor, mcpRegsFor, type Artifact } from '../../src/generator.ts';
import type { HarnessDesign } from '../../src/designer.ts';
import { design } from '../../src/designer.ts';
import type { ProjectProfile } from '../../src/types.ts';

function profile(over: Partial<ProjectProfile>): ProjectProfile {
  return {
    root: '/x', type: 'web', languages: ['typescript'], packageManager: 'npm',
    testCmd: 'npm test', lintCmd: 'npm run lint', formatCmd: null,
    ci: null, hasGit: true, signals: [], ...over,
  };
}
const find = (arts: Artifact[], p: string) => arts.find((a) => a.path === p);

test('render: {{KEY}} 치환 + 미정의 키는 빈 문자열', () => {
  assert.equal(render('a {{X}} b {{Y}}', { X: '1' }), 'a 1 b ');
});

test('generate: flight-rules + evaluation-criteria 항상 생성, 변수 치환', () => {
  const p = profile({});
  const arts = generate(p, design(p));
  const fr = find(arts, 'flight-rules.md');
  assert.ok(fr);
  assert.match(fr.content, /npm test/); // TEST_CMD 치환
  assert.match(fr.content, /any.*금지/); // typescript LANG_RULES
  assert.equal(fr.executable, false);
  assert.ok(find(arts, 'evaluation-criteria.md'));
  assert.ok(find(arts, 'sprint-contract.md')); // v1.3 #2
});

test('generate: squad-evaluator 에이전트 + 커맨드 emit (v1.3 #1)', () => {
  const p = profile({});
  const arts = generate(p, design(p));
  assert.ok(find(arts, '.claude/agents/squad-evaluator.md'));
  assert.ok(find(arts, '.claude/commands/squad-evaluator.md'));
});

test('generate: 추천 시 결정적 차단 훅 + anti-slop 훅 생성(executable)', () => {
  const p = profile({});
  const arts = generate(p, design(p)); // web → standard, anti-slop 추천
  const bd = find(arts, '.claude/hooks/carve-block-destructive.sh');
  assert.ok(bd);
  assert.equal(bd.executable, true);
  assert.ok(find(arts, '.claude/hooks/carve-protect-secrets.sh'));
  assert.ok(find(arts, '.claude/hooks/carve-anti-slop.sh'));
});

test('generate: anti-slop 미추천이면 anti-slop 섹션·훅 없음', () => {
  const noSlop: HarnessDesign = {
    level: 'minimal',
    recommended: ['block-destructive', 'protect-secrets'],
    available: [],
    rationale: [],
  };
  const arts = generate(profile({ languages: ['go'] }), noSlop);
  assert.ok(!find(arts, '.claude/hooks/carve-anti-slop.sh'));
  const fr = find(arts, 'flight-rules.md');
  assert.ok(fr && !/anti-ai-slop/.test(fr.content));
  assert.ok(fr && !/any.*금지/.test(fr.content)); // go → LANG_RULES 없음
});

test('generate: anti-slop 팩 vendoring — check-slop.mjs + 마스터 스킬 emit', () => {
  const p = profile({});
  const arts = generate(p, design(p));
  assert.ok(find(arts, '.claude/skills/clean-html/scripts/check-slop.mjs')?.executable);
  assert.ok(find(arts, '.claude/skills/SKILL.md')); // anti-ai-slop 마스터
  assert.ok(find(arts, '.claude/skills/svg-image.md'));
});

test('generate: standard 레벨 7 필수 훅 전부 생성 + 변수 치환', () => {
  const p = profile({ lintCmd: 'npm run lint' });
  const arts = generate(p, design(p));
  for (const id of ['block-destructive', 'protect-secrets', 'pre-commit-lint', 'pre-push-test', 'auto-format', 'slack-notify', 'precompact-handoff']) {
    assert.ok(find(arts, `.claude/hooks/carve-${id}.sh`), `${id} 미생성`);
  }
  const lint = find(arts, '.claude/hooks/carve-pre-commit-lint.sh');
  assert.ok(lint && lint.content.includes('npm run lint')); // HOOK_LINT_CMD 치환
  assert.ok(lint && !lint.content.includes('{{')); // 미치환 placeholder 없음
});

test('generate: 대상 CLAUDE.md + HARNESS-GUIDE 생성, COMPONENT_LIST 치환', () => {
  const p = profile({});
  const arts = generate(p, design(p));
  const cm = find(arts, 'CLAUDE.md');
  assert.ok(cm && /harness-architect/.test(cm.content)); // COMPONENT_LIST
  assert.ok(cm && !/\{\{/.test(cm.content)); // 미치환 placeholder 없음
  assert.ok(find(arts, 'HARNESS-GUIDE.md'));
});

test('generate: Squad 8 에이전트 + 커맨드 + 라우터/체이닝 훅 vendoring', () => {
  const p = profile({});
  const arts = generate(p, design(p));
  for (const id of ['squad-review', 'squad-qa', 'squad-audit']) {
    assert.ok(find(arts, `.claude/agents/${id}.md`), `${id} 에이전트 미생성`);
    assert.ok(find(arts, `.claude/commands/${id}.md`), `${id} 커맨드 미생성`);
  }
  assert.ok(find(arts, '.claude/commands/squad.md')); // 디스패처
  assert.ok(find(arts, '.claude/hooks/squad-router.sh')?.executable); // 키워드 라우터
  assert.ok(find(arts, '.claude/hooks/subagent-chain.sh')?.executable); // 체이닝/알림
});

test('generate: full 레벨 — 도입 스킬(tdd 등) emit + 커맨드 shim', () => {
  const p = profile({ ci: 'github-actions', languages: ['ts', 'js'] }); // → full
  const arts = generate(p, design(p));
  assert.ok(find(arts, '.claude/skills/tdd/SKILL.md'), 'tdd 스킬 미생성');
  assert.ok(find(arts, '.claude/commands/carve-tdd.md'), 'tdd shim 미생성');
  assert.ok(find(arts, '.claude/skills/caveman/SKILL.md'), 'caveman 미생성');
  assert.ok(find(arts, '.claude/skills/model-route/SKILL.md'), 'model-route 미생성'); // v1.4
});

test('generate: 핵심 스킬 커맨드 shim emit', () => {
  const p = profile({});
  const arts = generate(p, design(p));
  assert.ok(find(arts, '.claude/commands/carve-commit.md'));
  assert.ok(find(arts, '.claude/commands/carve-harness-architect.md'));
});

test('토큰 효율 기본 탑재: codesight/lsp 스킬 + MCP + flight-rules 지침', () => {
  const p = profile({});
  const arts = generate(p, design(p));
  assert.ok(find(arts, '.claude/skills/codesight/SKILL.md'));
  assert.ok(find(arts, '.claude/skills/lsp/SKILL.md'));
  assert.ok(find(arts, '.claude/hooks/carve-codesight-refresh.sh')?.executable);
  const fr = find(arts, 'flight-rules.md');
  assert.ok(fr && /codesight/.test(fr.content) && /LSP|findReferences/.test(fr.content));
  // MCP 등록 목록
  const mcps = mcpRegsFor(design(p));
  assert.ok(mcps.some((m) => m.name === 'codesight'));
  assert.ok(mcps.some((m) => m.name === 'cclsp'));
});

test('hookRegsFor: Squad 추천 시 라우터/체이닝 등록(UserPromptSubmit·SubagentStart/Stop)', () => {
  const p = profile({});
  const regs = hookRegsFor(design(p));
  assert.ok(regs.some((r) => r.event === 'UserPromptSubmit' && /squad-router/.test(r.command)));
  assert.ok(regs.some((r) => r.event === 'SubagentStart'));
  assert.ok(regs.some((r) => r.event === 'SubagentStop'));
});

test('generate: testCmd 미탐지 시 기본값 사용', () => {
  const arts = generate(profile({ testCmd: null }), design(profile({ testCmd: null })));
  const fr = find(arts, 'flight-rules.md');
  assert.ok(fr && /npm test/.test(fr.content));
});
