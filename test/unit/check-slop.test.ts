// test/unit/check-slop.test.ts — anti-ai-slop 린터 게이트 검증.
// check-slop.mjs를 서브프로세스로 실행해 확장자 디스패치(html/css·svg·md)와
// exit code(0 clean / 1 violation / 2 bad invocation)를 검증한다.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

// 출처(assets) 사본을 테스트한다 — 대상 프로젝트에 vendoring되는 원본.
// 리포 자신의 .claude/ 사본과의 동일성은 assets.test.ts가 가드한다.
const LINTER = fileURLToPath(
  new URL('../../assets/antislop/clean-html/scripts/check-slop.mjs', import.meta.url),
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

// ── 고도화 룰: 타이포그래피 ──
test('slop-typography.html → tiny-font ERROR + line-height-body/heading-skip/multi-h1 WARN', () => {
  const r = lint(fixture('slop-typography.html'));
  assert.equal(r.status, 1);
  assert.match(r.stdout, /ERROR.*\[tiny-font\].*8px/);
  assert.match(r.stdout, /warn.*\[tiny-font\].*11px/); // 10~11px는 WARN(라벨 합법 케이스)
  assert.match(r.stdout, /\[line-height-body\]/);
  assert.match(r.stdout, /\[heading-skip\].*h1→h3/);
  assert.match(r.stdout, /\[multi-h1\]/);
});

// ── 고도화 룰: WCAG 대비 ──
test('slop-contrast.css → 3.0 미만 ERROR · 3.0~4.5 WARN · 4.5+ 및 대형 텍스트는 미발화', () => {
  const r = lint(fixture('slop-contrast.css'));
  assert.equal(r.status, 1);
  assert.match(r.stdout, /ERROR.*\[contrast-aa\].*#c7cdd4/);
  assert.match(r.stdout, /warn.*\[contrast-aa\].*#949494/);
  assert.doesNotMatch(r.stdout, /contrast-aa.*#6b7280/); // 4.5:1 이상 → 미발화
  assert.doesNotMatch(r.stdout, /contrast-aa.*#8a8a8a/); // 대형(32px) → 3:1 기준 통과
});

// ── 고도화 룰: 카피라이팅 톤 ──
test('slop-copy.md → ai-contrast(EN+KO)·superlative·exclamation ERROR·ai-stock·em-dash 발화', () => {
  const r = lint(fixture('slop-copy.md'));
  assert.equal(r.status, 1);
  assert.equal((r.stdout.match(/\[ai-contrast\]/g) || []).length, 2); // 한·영 각 1회
  assert.match(r.stdout, /\[superlative\].*놀라운/);
  assert.match(r.stdout, /ERROR.*\[exclamation\].*5회/);
  assert.match(r.stdout, /\[ai-stock-phrase\]/);
  assert.match(r.stdout, /\[em-dash\].*3회/);
});

// ── 고도화 룰: 레이아웃 스멜 ──
test('slop-layout.css → radius-cap ERROR + uniform-radius/centered-everything/multi-accent WARN', () => {
  const r = lint(fixture('slop-layout.css'));
  assert.equal(r.status, 1);
  assert.match(r.stdout, /ERROR.*\[radius-cap\].*16px/);
  assert.match(r.stdout, /\[uniform-radius\]/);
  assert.match(r.stdout, /\[centered-everything\]/);
  assert.match(r.stdout, /\[multi-accent\].*3종/);
});

// ── 캘리브레이션: 포맷 문서의 GOOD 예시 패턴은 ERROR가 아니다 ──
test('good-presentation.css: 11px 라벨·헤딩 line-height 1.12 → ERROR 없음 (exit 0)', () => {
  const r = lint(fixture('good-presentation.css'));
  assert.equal(r.status, 0); // WARN은 허용, ERROR 0
  assert.doesNotMatch(r.stdout, /ERROR/);
});

// ── 한국어 관례 보호: 공백 양쪽 em-dash(`용어 — 설명`)는 미발화 ──
test('스페이스드 em-dash 한국어 관례는 em-dash 룰 미발화', () => {
  const r = lint(fixture('clean.md'));
  assert.equal(r.status, 0);
  assert.doesNotMatch(r.stdout, /\[em-dash\]/);
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
