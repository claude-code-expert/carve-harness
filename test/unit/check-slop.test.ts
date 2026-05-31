// test/unit/check-slop.test.ts — anti-ai-slop 린터 게이트 검증.
// check-slop.mjs를 서브프로세스로 실행해 확장자 디스패치(html/css·svg·md)와
// exit code(0 clean / 1 violation / 2 bad invocation)를 검증한다.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const LINTER = fileURLToPath(
  new URL('../../.claude/skills/clean-html/scripts/check-slop.mjs', import.meta.url),
);
const fixture = (name: string) =>
  fileURLToPath(new URL(`../fixtures/slop/${name}`, import.meta.url));

function lint(...args: string[]) {
  return spawnSync(process.execPath, [LINTER, ...args], { encoding: 'utf8' });
}

// ── 클린 산출물: exit 0 ──
for (const f of ['clean.svg', 'clean.md', 'clean.html']) {
  test(`${f} → 위반 없음 (exit 0)`, () => {
    const r = lint(fixture(f));
    assert.equal(r.status, 0);
    assert.match(r.stdout, /clean/);
  });
}

// ── SVG 모드: 그라데이션 정의 + blur 필터 차단 ──
test('slop.svg → gradient + svg-filter ERROR (exit 1)', () => {
  const r = lint(fixture('slop.svg'));
  assert.equal(r.status, 1);
  assert.match(r.stdout, /\[svg\]/); // 확장자 디스패치 확인
  assert.match(r.stdout, /ERROR.*\[gradient\]/);
  assert.match(r.stdout, /ERROR.*\[svg-filter\]/);
  assert.match(r.stdout, /\[svg-offpalette\]/); // 팔레트 밖 색 WARN
});

// ── Markdown 모드: 영어 + 한국어 마케팅 버즈워드 차단 ──
test('slop.md → marketing(EN+KO) ERROR (exit 1)', () => {
  const r = lint(fixture('slop.md'));
  assert.equal(r.status, 1);
  assert.match(r.stdout, /\[md\]/);
  assert.match(r.stdout, /marketing.*seamlessly/i);
  assert.match(r.stdout, /marketing.*차원이 다른/);
});

// ── HTML/CSS 모드: 기존 동작 회귀 보존 ──
test('slop.html → gradient + keyframes ERROR (exit 1, 회귀)', () => {
  const r = lint(fixture('slop.html'));
  assert.equal(r.status, 1);
  assert.match(r.stdout, /\[htmlcss\]/);
  assert.match(r.stdout, /ERROR.*\[gradient\]/);
  assert.match(r.stdout, /ERROR.*\[keyframes\]/);
});

// ── CSS 룰 전반 발화 (모든 MUST-NOT 룰이 실제로 잡히는지) ──
test('slop.css → 모든 핵심 CSS 룰 발화 (exit 1)', () => {
  const r = lint(fixture('slop.css'));
  assert.equal(r.status, 1);
  for (const rule of [
    'colored-shadow', 'big-shadow', 'gloss-ring', 'glassmorphism',
    'gradient-text', 'slow-transition', 'motion-decor', 'accent-bar', 'hover-transform',
  ]) {
    assert.match(r.stdout, new RegExp(`ERROR.*\\[${rule}\\]`), `${rule} 미발화`);
  }
  // 휴리스틱 WARN
  assert.match(r.stdout, /\[transition-scope\]/);
  assert.match(r.stdout, /\[font-default\]/);
});

// ── 잘못된 호출: exit 2 ──
test('인자 없음 → exit 2', () => {
  const r = lint();
  assert.equal(r.status, 2);
});

// ── 다중 파일: 하나라도 위반이면 exit 1 ──
test('clean + slop 혼합 → exit 1', () => {
  const r = lint(fixture('clean.svg'), fixture('slop.md'));
  assert.equal(r.status, 1);
});
