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

// Marketing boilerplate. English = whole-word; Korean = substring (no \b in CJK).
const MARKETING_EN = ['seamlessly', 'seamless', 'elevate', 'unlock', 'empower', 'supercharge', 'effortlessly', 'cutting-edge', 'game-changer', 'revolutionize', 'next-level'];
const MARKETING_KO = ['차원이 다른', '혁신적인', '획기적인', '압도적인', '게임체인저', '초격차', '완벽한 솔루션'];

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

  // ── shared per-line scans (all kinds): marketing + emoji ─────
  const scanShared = (line, i) => {
    for (const w of MARKETING_EN) {
      if (new RegExp('\\b' + w.replace('-', '\\-') + '\\b', 'i').test(line)) {
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
    if (EMOJI_RE.test(line)) {
      add('WARN', 'emoji', '이모지 사용 — 불릿/장식이면 제거, 의미 전달이면 유지', i);
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
  lines.forEach((line, i) => {
    const low = line.toLowerCase();
    scanShared(line, i);
    if (kind === 'htmlcss') scanHtmlCss(line, i, low);
    else if (kind === 'svg') scanSvg(line, i, low);
    // md: shared only
  });

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
