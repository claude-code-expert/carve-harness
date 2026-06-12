#!/usr/bin/env node

/**
 * check-slop.js — Anti-AI-Slop linter (HTML/CSS · SVG · Markdown).
 *
 * Enforces the visual/document "AI slop" bans from the anti-ai-slop skill
 * (.claude/skills/SKILL.md + format files) and reports each hit with a
 * file:line location. Deterministic, dependency-free (Node stdlib only).
 *
 * File-type dispatch (by extension):
 *   .html/.htm/.css → HTML/CSS rules (gradients, glow, motion, …)
 *   .svg            → SVG rules (gradient elements, blur/glow filters, off-palette, viewBox)
 *   .md/.markdown   → document rules (marketing boilerplate, decorative emoji)
 * Marketing + emoji checks are shared across all kinds.
 *
 * Usage:
 *   node check-slop.js <file> [<file> ...]
 *
 * Exit codes:
 *   0 — no MUST-NOT violations (warnings may still be printed)
 *   1 — at least one MUST-NOT violation found
 *   2 — bad invocation / file not readable
 *
 * Severities:
 *   ERROR — a MUST-NOT rule. Fails the run.
 *   WARN  — heuristic; needs human/agent judgement. Does not fail the run.
 */

import fs from 'fs';

const files = process.argv.slice(2).filter((a) => !a.startsWith('--'));
if (files.length === 0) {
  console.error('usage: node check-slop.js <file> [<file> ...]');
  process.exit(2);
}

// ── color helpers ──────────────────────────────────────────────
// A shadow/accent color is "chromatic" (banned) when its RGB channels are
// not roughly equal. Pure grey/black/white shadows are allowed.
function parseColor(tok) {
  tok = tok.trim();
  let m;
  if ((m = tok.match(/^#([0-9a-f]{3})$/i))) {
    const h = m[1];
    return [h[0], h[1], h[2]].map((c) => parseInt(c + c, 16));
  }
  if ((m = tok.match(/^#([0-9a-f]{6})$/i))) {
    const h = m[1];
    return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16));
  }
  if ((m = tok.match(/^rgba?\(([^)]+)\)$/i))) {
    const parts = m[1].split(/[,\s/]+/).filter(Boolean);
    return parts.slice(0, 3).map((p) => (p.endsWith('%') ? Math.round(parseFloat(p) * 2.55) : parseFloat(p)));
  }
  if ((m = tok.match(/^hsla?\(([^)]+)\)$/i))) {
    const parts = m[1].split(/[,\s/]+/).filter(Boolean);
    const s = parseFloat(parts[1]); // saturation %
    return s > 8 ? [255, 0, 0] : [128, 128, 128]; // chromatic iff saturated
  }
  return null;
}
function isChromatic(tok) {
  const rgb = parseColor(tok);
  if (!rgb) return false;
  const [r, g, b] = rgb;
  return Math.max(r, g, b) - Math.min(r, g, b) > 12;
}
function findColorTokens(value) {
  const out = [];
  const re = /#[0-9a-f]{3,6}\b|rgba?\([^)]*\)|hsla?\([^)]*\)/gi;
  let m;
  while ((m = re.exec(value))) out.push(m[0]);
  return out;
}

// ── WCAG 대비 (정적으로 fg·bg를 둘 다 알 수 있는 블록만) ───────
// hsl은 parseColor가 정확한 RGB를 내지 않으므로 대비 계산에서 제외한다.
function relLuminance([r, g, b]) {
  const f = (c) => {
    const s = c / 255;
    return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  };
  return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
}
function contrastRatio(a, b) {
  const [hi, lo] = [relLuminance(a), relLuminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
}

// Marketing boilerplate. English = whole-word; Korean = substring (no \b in CJK).
const MARKETING_EN = ['seamlessly', 'seamless', 'elevate', 'unlock', 'empower', 'supercharge', 'effortlessly', 'cutting-edge', 'game-changer', 'revolutionize', 'next-level', 'stunning', 'breathtaking', 'world-class', 'best-in-class', 'unparalleled', 'unrivaled', 'transformative'];
const MARKETING_KO = ['차원이 다른', '혁신적인', '획기적인', '압도적인', '게임체인저', '초격차', '완벽한 솔루션', '세계 최고', '유일무이', '독보적인'];

// 연성 최상급/주관 수식어 — 기술 문장에서 합법일 수 있어 WARN (rule: superlative).
const SOFT_EN = ['powerful', 'amazing', 'incredible', 'beautiful', 'blazing', 'magical', 'delightful', 'gorgeous'];
const SOFT_KO = ['놀라운', '강력한', '환상적인', '아름다운'];
// 영문 단어 스캔은 파일·라인마다 반복 — \b…\b 정규식을 모듈 로드 시 1회만 컴파일한다.
const MARKETING_EN_RES = MARKETING_EN.map((w) => [w, new RegExp('\\b' + w.replace('-', '\\-') + '\\b', 'i')]);
const SOFT_EN_RES = SOFT_EN.map((w) => [w, new RegExp('\\b' + w + '\\b', 'i')]);

// AI 상투 문형 — "단순한 X가 아니라 Y" 류 대비 구문 (WARN, 사실 서술로 재작성 권고).
const AI_CONTRAST_RES = [
  /\bnot (just|only|merely)\b[^.!?\n]{0,80}\b(but|it'?s|it is|rather)\b/i,
  /\b(isn'?t|aren'?t) (just|only|merely)\b/i,
  /단순한? ?[^,.\n]{0,30}(이|가) 아니라/,
  /(을|를) 넘어선?[ ,]/,
];

// AI 상투어구 (md 전용 WARN) — 블로그체 도입부·과장 전환어.
const AI_STOCK_EN = ["let's dive in", 'dive into', 'delve into', "in today's", 'ever-evolving', 'fast-paced world', "let's explore"];
const AI_STOCK_KO = ['여정을 시작', '함께 알아보', '~의 시대'];

// Decorative emoji ranges (covers most pictographs incl. ✨ U+2728).
// Reported as WARN since emoji can be content.
const EMOJI_RE = /[☀-➿⬀-⯿\u{1F000}-\u{1FAFF}\u{FE0F}]/u;

const FONT_DEFAULTS = /\b(inter|roboto|arial|system-ui|-apple-system|segoe ui|space grotesk|helvetica neue)\b/i;

// svg-image.md 5-color semantic palette (+ amber-dark D97706). Chromatic hex
// outside this set is flagged WARN. Neutrals are non-chromatic so never flagged.
const SVG_PALETTE = new Set(['#6b7280', '#7c3aed', '#0d9488', '#f59e0b', '#ef4444', '#d97706']);

function kindOf(file) {
  if (/\.svg$/i.test(file)) return 'svg';
  if (/\.(md|markdown)$/i.test(file)) return 'md';
  return 'htmlcss';
}

let totalErrors = 0;
let totalWarns = 0;

for (const file of files) {
  let text;
  try {
    text = fs.readFileSync(file, 'utf8');
  } catch (e) {
    console.error(`✗ cannot read ${file}: ${e.message}`);
    process.exit(2);
  }
  const kind = kindOf(file);
  const lines = text.split(/\r?\n/);
  const findings = []; // { sev, rule, msg, line }

  const add = (sev, rule, msg, lineIdx) => {
    findings.push({ sev, rule, msg, line: lineIdx + 1 });
    if (sev === 'ERROR') totalErrors++;
    else totalWarns++;
  };

  // ── shared per-line scans (all kinds): marketing + emoji + 연성 최상급 ─────
  const scanShared = (line, i) => {
    for (const [w, re] of MARKETING_EN_RES) {
      if (re.test(line)) {
        add('ERROR', 'marketing', `마케팅 보일러플레이트 단어: "${w}"`, i);
        break;
      }
    }
    for (const w of MARKETING_KO) {
      if (line.includes(w)) {
        add('ERROR', 'marketing', `마케팅 보일러플레이트 문구: "${w}"`, i);
        break;
      }
    }
    for (const [w, re] of SOFT_EN_RES) {
      if (re.test(line)) {
        add('WARN', 'superlative', `주관 수식어: "${w}" — 수치·사실로 대체 가능한지 확인`, i);
        break;
      }
    }
    for (const w of SOFT_KO) {
      if (line.includes(w)) {
        add('WARN', 'superlative', `주관 수식어: "${w}" — 수치·사실로 대체 가능한지 확인`, i);
        break;
      }
    }
    if (EMOJI_RE.test(line)) {
      add('WARN', 'emoji', '이모지 사용 — 불릿/장식이면 제거, 의미 전달이면 유지', i);
    }
  };

  // ── copy tone scans (md + htmlcss의 <style>/<script> 밖 텍스트) ─────
  // 파일 단위 카운터: 느낌표 밀도·무공백 em-dash. fenced code block(```)은 제외.
  let exclamations = 0;
  let firstExclLine = 0;
  let emDashes = 0;
  let firstDashLine = 0;
  const scanCopyTone = (line, i, inFence) => {
    if (inFence) return;
    for (const re of AI_CONTRAST_RES) {
      if (re.test(line)) {
        add('WARN', 'ai-contrast', '"단순한 X가 아니라 Y" 류 대비 문형 — 사실 서술로 재작성', i);
        break;
      }
    }
    // 문장 끝 느낌표만 센다 (`![`(이미지)·`!=`·`!important`·`<!--` 제외)
    const excl = (line.match(/[가-힣a-zA-Z0-9)\]"']!(?=["')\]]|\s|$)/g) || []).length;
    if (excl > 0 && exclamations === 0) firstExclLine = i;
    exclamations += excl;
    // 무공백 em-dash(영문 AI 문체 신호)만 — 한국어 `용어 — 설명` 관례(공백 양쪽)는 합법
    const dash = (line.match(/\S—\S/g) || []).length;
    if (dash > 0 && emDashes === 0) firstDashLine = i;
    emDashes += dash;
  };
  const scanMdOnly = (line, i, inFence) => {
    if (inFence) return;
    const low = line.toLowerCase();
    for (const w of AI_STOCK_EN) {
      if (low.includes(w)) {
        add('WARN', 'ai-stock-phrase', `AI 상투어구: "${w}"`, i);
        break;
      }
    }
    for (const w of AI_STOCK_KO) {
      if (line.includes(w)) {
        add('WARN', 'ai-stock-phrase', `AI 상투어구: "${w}"`, i);
        break;
      }
    }
  };

  // ── HTML/CSS per-line scans ─────────────────────────────────
  const scanHtmlCss = (line, i, low) => {
    // gradients (incl. repeating)
    if (/\b(repeating-)?(linear|radial|conic)-gradient\s*\(/i.test(line)) {
      add('ERROR', 'gradient', 'gradient 함수 사용 (단색 + border로 대체)', i);
    }
    // gradient text
    if (/background-clip\s*:\s*text/i.test(low) || /-webkit-text-fill-color\s*:\s*transparent/i.test(low)) {
      add('ERROR', 'gradient-text', 'background-clip:text / 투명 텍스트 채움 (그라데이션 텍스트)', i);
    }
    // glassmorphism
    if (/backdrop-filter\s*:\s*[^;]*blur/i.test(low)) {
      add('ERROR', 'glassmorphism', 'backdrop-filter: blur (글래스모피즘)', i);
    }
    // box-shadow analysis
    const sh = line.match(/box-shadow\s*:\s*([^;]+);?/i);
    if (sh && !/box-shadow\s*:\s*none/i.test(sh[0])) {
      const val = sh[1];
      const colored = findColorTokens(val).some(isChromatic);
      if (colored) add('ERROR', 'colored-shadow', '색이 들어간 box-shadow (글로우)', i);
      const lens = (val.match(/(\d+(?:\.\d+)?)px/g) || []).map((p) => parseFloat(p));
      if (lens.some((n) => n >= 20)) add('ERROR', 'big-shadow', 'blur/offset ≥ 20px 큰 그림자', i);
      if (/inset/i.test(val) && colored) add('ERROR', 'gloss-ring', 'inset 컬러 광택 링', i);
    }
    // top accent bar
    const bt = line.match(/border-top\s*:\s*(\d+(?:\.\d+)?)px\s+solid\s+([^;!]+)/i);
    if (bt && parseFloat(bt[1]) >= 2 && isChromatic(bt[2])) {
      add('ERROR', 'accent-bar', '카드 상단 컬러 액센트 바 (border-top)', i);
    }
    // transition duration > 150ms
    const tr = low.match(/transition[^:]*:\s*([^;]+);?/);
    if (tr) {
      const durs = (tr[1].match(/(\d+(?:\.\d+)?)(ms|s)\b/g) || []).map((d) => {
        const n = parseFloat(d);
        return d.endsWith('ms') ? n : n * 1000;
      });
      if (durs.some((ms) => ms > 150)) add('ERROR', 'slow-transition', 'transition > 150ms', i);
      if (/transition\s*:\s*all\b/i.test(tr[0]) || /\btransform\b/.test(tr[1])) {
        add('WARN', 'transition-scope', 'transition이 all/transform에 적용 — 색·투명도 등 기능적 변화로 한정', i);
      }
    }
    // decorative animation names
    if (/(animation(-name)?\s*:[^;]*\b(pulse|shimmer|float|glow|fade(in|out)?|stagger|bounce|wiggle|spin)\b)/i.test(low)) {
      add('ERROR', 'motion-decor', '장식 모션 (pulse/shimmer/float/glow/fade/…)', i);
    }
    // mask fade / dot-grid pattern
    if (/(-webkit-)?mask-image\s*:\s*[^;]*gradient/i.test(low)) {
      add('WARN', 'fade-mask', '페이드 마스크(mask-image gradient) — 콘텐츠 전달 목적인지 확인', i);
    }
    // huge faint watermark text
    const fz = line.match(/font-size\s*:\s*(\d+(?:\.\d+)?)px/i);
    if (fz && parseFloat(fz[1]) >= 120 && /position\s*:\s*absolute/i.test(low)) {
      add('WARN', 'watermark', `거대 텍스트(${fz[1]}px) + position:absolute — 배경 워터마크인지 확인`, i);
    }
    // font convergence
    const ff = line.match(/font-family\s*:\s*([^;}{]+)/i);
    if (ff) {
      const first = ff[1].split(',')[0].replace(/['"]/g, '').trim();
      if (FONT_DEFAULTS.test(first)) {
        add('WARN', 'font-default', `폰트가 기본값으로 수렴(${first}) — 목적에 맞는 폰트를 의도적으로 선택`, i);
      }
    }
    // 타이포: 극소 폰트 (<10px ERROR, 10~11px WARN — 11px 라벨은 합법 케이스가 있어 확인 요청)
    const sizes = [];
    let fm;
    const fzRe = /font-size\s*:\s*(\d+(?:\.\d+)?)px/gi;
    while ((fm = fzRe.exec(line))) sizes.push(parseFloat(fm[1]));
    const shorthand = line.match(/\bfont\s*:\s*[^;{}]*?(\d+(?:\.\d+)?)px\s*(?:\/\s*(\d+(?:\.\d+)?))?/i);
    if (shorthand) sizes.push(parseFloat(shorthand[1]));
    for (const s of sizes) {
      if (s < 10) add('ERROR', 'tiny-font', `font-size ${s}px < 10px — 읽을 수 없는 텍스트`, i);
      else if (s < 12) add('WARN', 'tiny-font', `font-size ${s}px — 캡션/라벨 용도인지 확인(본문이면 16px 이상)`, i);
    }
    // 타이포: 본문 행간 (같은 줄에 본문급 font-size ≤ 20px가 있을 때만 — 헤딩 1.1~1.3은 합법)
    const bodySize = sizes.find((s) => s <= 20);
    if (bodySize !== undefined) {
      const lh = line.match(/line-height\s*:\s*(\d+(?:\.\d+)?)\s*[;}]/i);
      const lhVal = shorthand && shorthand[2] !== undefined ? parseFloat(shorthand[2]) : (lh ? parseFloat(lh[1]) : null);
      if (lhVal !== null && lhVal >= 0.5 && lhVal < 1.4) {
        add('WARN', 'line-height-body', `본문(${bodySize}px) line-height ${lhVal} < 1.4 — 가독성 확인`, i);
      }
    }
    // 레이아웃: border-radius 상한 (전역 MUST 0~8px). pill(9999px·50%)은 남발 확인 WARN.
    const br = line.match(/border-radius\s*:\s*([^;{}]+)/i);
    if (br) {
      const pxVals = (br[1].match(/(\d+(?:\.\d+)?)px/g) || []).map(parseFloat);
      if (/50%/.test(br[1]) || pxVals.some((v) => v >= 999)) {
        add('WARN', 'pill', 'pill/원형 radius — 아바타·원형 의도인지 확인(뱃지 pill 남발 금지)', i);
      } else if (pxVals.some((v) => v > 8)) {
        add('ERROR', 'radius-cap', `border-radius ${Math.max(...pxVals)}px > 8px — 전역 표준은 0~8px`, i);
      }
    }
  };

  // ── SVG per-line scans ──────────────────────────────────────
  const scanSvg = (line, i, low) => {
    // gradient definitions / mesh
    if (/<(linear|radial|mesh)gradient\b/i.test(low)) {
      add('ERROR', 'gradient', 'SVG 그라데이션 정의 (<linearGradient>/<radialGradient>) — 단색 fill로 대체', i);
    }
    // CSS gradient inside style attribute
    if (/\b(repeating-)?(linear|radial|conic)-gradient\s*\(/i.test(line)) {
      add('ERROR', 'gradient', 'gradient 함수 사용 (단색 fill로 대체)', i);
    }
    // blur / glow / drop-shadow filters
    if (/<fe(gaussianblur|dropshadow|flood)\b/i.test(low) || /filter\s*:\s*[^;"']*(blur|drop-shadow)\s*\(/i.test(low)) {
      add('ERROR', 'svg-filter', 'glow/blur 필터 (feGaussianBlur/feDropShadow/filter blur) — 평면 단색으로', i);
    }
    // off-palette chromatic colors (hex only; neutrals are non-chromatic → skip)
    for (const tok of findColorTokens(line)) {
      if (/^#[0-9a-f]{3,6}$/i.test(tok) && isChromatic(tok) && !SVG_PALETTE.has(tok.toLowerCase())) {
        add('WARN', 'svg-offpalette', `팔레트 밖 색 ${tok} — svg-image.md 5색 의미 체계 사용`, i);
      }
    }
  };

  // ── dispatch per-line ───────────────────────────────────────
  let inFence = false; // md ``` 코드 펜스
  let inStyle = false; // htmlcss <style>/<script> 내부 (카피 톤 검사 제외 구간)
  lines.forEach((line, i) => {
    const low = line.toLowerCase();
    if (kind === 'md' && /^\s*```/.test(line)) inFence = !inFence;
    scanShared(line, i);
    if (kind === 'htmlcss') {
      scanHtmlCss(line, i, low);
      if (/<(style|script)\b/.test(low)) inStyle = true;
      if (!inStyle) scanCopyTone(line, i, false);
      if (/<\/(style|script)>/.test(low)) inStyle = false;
    } else if (kind === 'svg') {
      scanSvg(line, i, low);
    } else {
      scanCopyTone(line, i, inFence);
      scanMdOnly(line, i, inFence);
    }
  });

  // 카피 톤 파일 단위 판정 (md·htmlcss)
  if (kind !== 'svg') {
    if (exclamations >= 5) add('ERROR', 'exclamation', `느낌표 ${exclamations}회 — 과장 톤(사실 서술로 재작성)`, firstExclLine);
    else if (exclamations >= 2) add('WARN', 'exclamation', `느낌표 ${exclamations}회 — 꼭 필요한지 확인`, firstExclLine);
    if (emDashes >= 3) add('WARN', 'em-dash', `무공백 em-dash ${emDashes}회 — AI 문체 신호(쉼표·마침표로 분리)`, firstDashLine);
  }

  // ── whole-text scans (multi-line) ───────────────────────────
  if (kind === 'htmlcss') {
    let km;
    const kmRe = /@(-webkit-)?keyframes\b/gi;
    while ((km = kmRe.exec(text))) {
      const lineNo = text.slice(0, km.index).split(/\r?\n/).length - 1;
      add('ERROR', 'keyframes', '@keyframes (모션 장식)', lineNo);
    }
    let hv;
    const hvRe = /:hover[^{}]*\{[^{}]*transform\s*:[^{}]*(translate|scale|rotate|skew)/gi;
    while ((hv = hvRe.exec(text))) {
      const lineNo = text.slice(0, hv.index).split(/\r?\n/).length - 1;
      add('ERROR', 'hover-transform', 'hover 시 transform: translate/scale (모션 장식)', lineNo);
    }

    // WCAG 대비: 같은 CSS 블록에 color·background 리터럴이 둘 다 있을 때만 정적 판정.
    // (상속·투명도·CSS 변수·이미지는 판정 불가 — 보수적으로 건너뜀)
    let bm;
    const blockRe = /\{[^{}]*\}/g;
    while ((bm = blockRe.exec(text))) {
      const block = bm[0];
      const fgM = block.match(/[^-\w]color\s*:\s*(#[0-9a-f]{3,6}\b|rgba?\([^)]*\))/i) || block.match(/^\{?\s*color\s*:\s*(#[0-9a-f]{3,6}\b|rgba?\([^)]*\))/i);
      const bgM = block.match(/background(?:-color)?\s*:\s*(#[0-9a-f]{3,6}\b|rgba?\([^)]*\))/i);
      if (!fgM || !bgM) continue;
      const fg = parseColor(fgM[1]);
      const bg = parseColor(bgM[1]);
      if (!fg || !bg) continue;
      const ratio = contrastRatio(fg, bg);
      // 대형 텍스트(≥24px, 또는 ≥19px+bold)는 3:1 기준
      const fz = block.match(/font-size\s*:\s*(\d+(?:\.\d+)?)px/i);
      const bold = /font-weight\s*:\s*(bold|[7-9]00)/i.test(block);
      const size = fz ? parseFloat(fz[1]) : 16;
      const large = size >= 24 || (size >= 19 && bold);
      const lineNo = text.slice(0, bm.index).split(/\r?\n/).length - 1;
      const r2 = Math.round(ratio * 100) / 100;
      if (ratio < 3.0) {
        add('ERROR', 'contrast-aa', `대비 ${r2}:1 < 3.0 (${fgM[1]} on ${bgM[1]}) — WCAG 최저선 미달`, lineNo);
      } else if (!large && ratio < 4.5) {
        add('WARN', 'contrast-aa', `대비 ${r2}:1 < 4.5 (${fgM[1]} on ${bgM[1]}) — 본문 텍스트면 AA 미달`, lineNo);
      }
    }

    // 레이아웃 스멜: 단조로운 radius·만능 중앙정렬·다중 액센트
    const radii = (text.match(/border-radius\s*:\s*(\d+(?:\.\d+)?)px/gi) || [])
      .map((d) => parseFloat(d.replace(/[^\d.]/g, '')));
    if (radii.length >= 5 && new Set(radii).size === 1) {
      add('WARN', 'uniform-radius', `border-radius ${radii[0]}px ×${radii.length} 전부 동일 — 위계 없는 기본값인지 확인`, 0);
    }
    const centers = (text.match(/text-align\s*:\s*center/gi) || []).length;
    if (centers >= 5) {
      add('WARN', 'centered-everything', `text-align:center ${centers}회 — 만능 중앙정렬(본문은 좌측 정렬) 확인`, 0);
    }
    // multi-accent는 강한 채도만 센다(채널차 > 40) — 푸른 기 도는 표준 회색(#6B7280·#374151 등)은 액센트가 아니다.
    const isStrongChroma = (tok) => {
      const rgb = parseColor(tok);
      if (!rgb) return false;
      return Math.max(...rgb) - Math.min(...rgb) > 40;
    };
    const accents = new Set(findColorTokens(text).filter((t) => /^#/.test(t) && isStrongChroma(t)).map((t) => t.toLowerCase()));
    if (accents.size > 2) {
      add('WARN', 'multi-accent', `유채색 ${accents.size}종(${[...accents].slice(0, 4).join(' ')}…) — 전역 표준은 액센트 1색`, 0);
    }

    // 타이포: 헤딩 위계 (h1 다중·레벨 건너뛰기)
    const heads = [];
    let hm;
    const headRe = /<h([1-6])[\s>]/gi;
    while ((hm = headRe.exec(text))) {
      heads.push({ level: Number(hm[1]), lineNo: text.slice(0, hm.index).split(/\r?\n/).length - 1 });
    }
    if (heads.filter((h) => h.level === 1).length > 1) {
      add('WARN', 'multi-h1', `<h1> ${heads.filter((h) => h.level === 1).length}개 — 문서당 1개 권장`, heads[0].lineNo);
    }
    for (let k = 1; k < heads.length; k++) {
      if (heads[k].level - heads[k - 1].level > 1) {
        add('WARN', 'heading-skip', `헤딩 레벨 건너뛰기 h${heads[k - 1].level}→h${heads[k].level} — 위계 단계 유지`, heads[k].lineNo);
      }
    }
  } else if (kind === 'svg') {
    // <svg> without a viewBox → not portable (svg-image.md MUST)
    const svgTag = text.match(/<svg\b[^>]*>/i);
    if (svgTag && !/viewBox\s*=/i.test(svgTag[0])) {
      const lineNo = text.slice(0, text.indexOf(svgTag[0])).split(/\r?\n/).length - 1;
      add('WARN', 'svg-viewbox', '<svg>에 viewBox 없음 — 스케일 이식성 위해 viewBox 지정', lineNo);
    }
  }

  // ── report ──────────────────────────────────────────────────
  findings.sort((a, b) => a.line - b.line);
  const errs = findings.filter((f) => f.sev === 'ERROR');
  const warns = findings.filter((f) => f.sev === 'WARN');

  console.log(`\n── ${file} [${kind}]`);
  if (findings.length === 0) {
    console.log('  ✓ clean — no AI-slop patterns detected');
  } else {
    for (const f of findings) {
      const tag = f.sev === 'ERROR' ? 'ERROR' : 'warn ';
      console.log(`  ${tag} L${String(f.line).padEnd(4)} [${f.rule}] ${f.msg}`);
    }
    console.log(`  ─ ${errs.length} error(s), ${warns.length} warning(s)`);
  }
}

console.log(`\n총계: ${totalErrors} error(s), ${totalWarns} warning(s) across ${files.length} file(s)`);
if (totalErrors > 0) {
  console.log('→ MUST-NOT 위반이 있습니다. 제거 후 재작성하세요.');
  process.exit(1);
}
process.exit(0);
