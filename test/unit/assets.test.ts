// test/unit/assets.test.ts — 카탈로그 ↔ 자산 정합 가드.
// 카탈로그에 등재된 스킬/에이전트가 실제 설치 자산을 갖는지 검증한다.
// (GAP-1: 자산 없는 카탈로그 항목은 설치 시 조용히 누락되므로 회귀 방지)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { CATALOG } from '../../src/catalog.ts';

const asset = (rel: string) => fileURLToPath(new URL(`../../assets/${rel}`, import.meta.url));

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
