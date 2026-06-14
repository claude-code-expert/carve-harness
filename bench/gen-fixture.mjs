// bench/gen-fixture.mjs — 대형 코드베이스 fixture 생성기 (축 1 토큰효율 무대, M11-A1).
// 결정론: 인덱스 기반 생성(Math.random 없음). 같은 (modules, seed) → 같은 트리.
// 상호 import·참조가 깊은 모듈 그래프를 만들어 codesight/LSP(구조맵·findReferences) vs grep
// 탐색 비용을 측정할 무대를 깐다. 실제 토큰 측정은 라이브(Phase B) — 이 파일은 무대만 만든다.
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

/** 모듈 i가 의존할 대상 인덱스(0~2개, 자기 자신·중복 제외). seed는 참조 패턴만 바꾼다(결정적). */
function depsFor(i, n, step) {
  const cands = [(i + 1) % n, (i * step + 3) % n];
  const deps = [];
  for (const c of cands) if (c !== i && !deps.includes(c)) deps.push(c);
  return deps;
}

/**
 * fixture 파일 맵을 계획한다(디스크 쓰기 없음 — 순수·테스트 가능).
 * @returns Map<상대경로, 내용> (삽입 순서: mod0..modN, index — 결정적)
 */
export function planFixture({ modules = 50, seed = 1 } = {}) {
  const n = Math.max(1, Math.floor(modules));
  const step = 2 * Math.floor(seed) + 3;
  const files = new Map();
  for (let i = 0; i < n; i++) {
    const deps = depsFor(i, n, step);
    const head = deps.map((d) => `import { f${d} } from './mod${d}.ts';`).join('\n');
    const callExpr = deps.length ? deps.map((d) => `f${d}(x)`).join(' + ') : '0';
    files.set(`mod${i}.ts`,
      `${head ? head + '\n' : ''}export function f${i}(x: number): number {\n  return x + ${callExpr};\n}\n`);
  }
  const idx = Array.from({ length: n }, (_, i) => `import { f${i} } from './mod${i}.ts';`).join('\n');
  const body = Array.from({ length: n }, (_, i) => `f${i}(${i})`).join(' + ');
  files.set('index.ts', `${idx}\nexport const total = ${body};\n`);
  return files;
}

/** 계획을 디스크에 쓴다(디렉토리 생성). 파일 수 반환. */
export function writeFixture(dir, plan) {
  mkdirSync(dir, { recursive: true });
  for (const [rel, content] of plan) writeFileSync(join(dir, rel), content);
  return plan.size;
}

// CLI: node bench/gen-fixture.mjs [--modules N] [--seed S] [--out dir] [--print]
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const arg = (name, def) => {
    const i = process.argv.indexOf(name);
    return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : def;
  };
  const modules = Number(arg('--modules', '200'));
  const seed = Number(arg('--seed', '1'));
  const plan = planFixture({ modules, seed });
  if (process.argv.includes('--print')) {
    // 결정성 검증·미리보기용: 디스크에 쓰지 않고 계획만 출력(삽입 순서 = 결정적).
    console.log(JSON.stringify([...plan.entries()]));
  } else {
    const out = arg('--out', join(process.cwd(), 'bench/fixtures/large'));
    const written = writeFixture(out, plan);
    console.log(`fixture 생성: ${written}파일 → ${out} (modules=${modules}, seed=${seed})`);
  }
}
