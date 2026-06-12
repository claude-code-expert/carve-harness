// test/unit/assets.test.ts — 카탈로그 ↔ 자산 정합 가드.
// 카탈로그에 등재된 스킬/에이전트가 실제 설치 자산을 갖는지 검증한다.
// (GAP-1: 자산 없는 카탈로그 항목은 설치 시 조용히 누락되므로 회귀 방지)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { CATALOG } from '../../src/catalog.ts';

const asset = (rel: string) => fileURLToPath(new URL(`../../assets/${rel}`, import.meta.url));
const repo = (rel: string) => fileURLToPath(new URL(`../../${rel}`, import.meta.url));

test('모든 카탈로그 스킬은 assets/skills/<id>/SKILL.md 를 가진다', () => {
  for (const c of CATALOG.filter((x) => x.kind === 'skill')) {
    assert.ok(existsSync(asset(`skills/${c.id}/SKILL.md`)), `${c.id}: SKILL.md 자산 없음`);
  }
});

test('모든 카탈로그 에이전트는 assets/squad/agents/<id>.md 를 가진다', () => {
  for (const c of CATALOG.filter((x) => x.kind === 'agent')) {
    assert.ok(existsSync(asset(`squad/agents/${c.id}.md`)), `${c.id}: 에이전트 자산 없음`);
  }
});

test('등재 스킬은 커맨드 shim도 가진다', () => {
  for (const c of CATALOG.filter((x) => x.kind === 'skill')) {
    assert.ok(existsSync(asset(`commands/carve-${c.id}.md`)), `${c.id}: 커맨드 shim 없음`);
  }
});

test('anti-slop 팩 자산(린터 포함) 존재', () => {
  assert.ok(existsSync(asset('antislop/clean-html/scripts/check-slop.mjs')));
  assert.ok(existsSync(asset('antislop/SKILL.md')));
});

test('anti-ai-slop 규칙 패리티: SKILL.md(출처)와 claude-base 요약본이 동일 룰 키워드를 포함한다', () => {
  // 요약본은 의도적 압축이라 본문 동일성 대신 룰 "키워드" 패리티만 강제한다.
  // 한쪽에만 룰을 추가하면 이 테스트가 깨진다 — 두 파일 동시 갱신을 강제하는 가드.
  const RULE_KEYWORDS = [
    // 금지 룰
    'linear-gradient', 'radial-gradient', 'conic-gradient', 'background-clip',
    'backdrop-filter', 'box-shadow', 'border-top', '워터마크', '이모지',
    'Seamlessly', 'Elevate', 'Unlock', 'Empower', 'Supercharge',
    // 강제 룰 (타이포·간격·대비·카피 — 고도화 추가분 포함)
    '액센트 1색', '1px solid', 'border-radius', 'line-height', '4/8px', '4.5:1', '느낌표',
  ];
  const skill = readFileSync(asset('antislop/SKILL.md'), 'utf8');
  const rule = readFileSync(asset('claude-base/rules/anti-ai-slop.md'), 'utf8');
  for (const kw of RULE_KEYWORDS) {
    assert.ok(skill.includes(kw), `SKILL.md에 룰 키워드 없음: "${kw}"`);
    assert.ok(rule.includes(kw), `claude-base 요약본에 룰 키워드 없음: "${kw}"`);
  }
});

test('check-slop.mjs: assets 원본과 리포 .claude 사본이 byte-identical (드리프트 가드)', () => {
  // 원본은 assets/antislop/... — 수정 시 .claude/skills/... 사본에 cp로 동기화한다.
  const src = readFileSync(asset('antislop/clean-html/scripts/check-slop.mjs'), 'utf8');
  const copy = readFileSync(repo('.claude/skills/clean-html/scripts/check-slop.mjs'), 'utf8');
  assert.equal(copy, src, 'assets ↔ .claude 린터 사본 드리프트 — assets 수정 후 cp 누락');
});

test('모든 카탈로그 훅은 assets/hooks/<id>.sh 를 가진다 (generator 컨벤션 가드)', () => {
  // generator가 HOOK_ASSETS 테이블 대신 `hooks/<id>.sh` 컨벤션을 쓰므로, 자산 누락 = 조용한 미설치.
  for (const c of CATALOG.filter((x) => x.kind === 'hook')) {
    assert.ok(existsSync(asset(`hooks/${c.id}.sh`)), `${c.id}: 훅 스크립트 자산 없음`);
  }
});
