// src/analyzer.ts — 프로젝트를 읽기 전용으로 스캔해 ProjectProfile을 만든다 (레이어 A).
// 결정적 휴리스틱만 사용한다. 파일을 수정하지 않는다.
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import type { ProjectProfile, ProjectType } from './types.ts';

/** 루트의 파일을 안전하게 읽는다. 없으면 null. */
function readIf(root: string, name: string): string | null {
  const p = join(root, name);
  return existsSync(p) ? readFileSync(p, 'utf8') : null;
}

interface PackageJson {
  bin?: unknown;
  scripts?: Record<string, string>;
  dependencies?: Record<string, string>;
  devDependencies?: Record<string, string>;
  exports?: unknown;
  main?: unknown;
}

function parsePackageJson(raw: string | null): PackageJson | null {
  if (raw === null) return null;
  try {
    return JSON.parse(raw) as PackageJson;
  } catch {
    return null;
  }
}

/** package.json의 모든 의존성(런타임+개발) 키 집합 */
function allDeps(pkg: PackageJson | null): Set<string> {
  const set = new Set<string>();
  for (const k of Object.keys(pkg?.dependencies ?? {})) set.add(k);
  for (const k of Object.keys(pkg?.devDependencies ?? {})) set.add(k);
  return set;
}

function hasAny(deps: Set<string>, names: string[]): boolean {
  return names.some((n) => deps.has(n));
}

function detectLanguages(
  root: string,
  pkg: PackageJson | null,
  deps: Set<string>,
): string[] {
  const langs = new Set<string>();
  if (pkg !== null) {
    langs.add('javascript');
    if (existsSync(join(root, 'tsconfig.json')) || deps.has('typescript')) {
      langs.add('typescript');
    }
  }
  if (existsSync(join(root, 'pubspec.yaml'))) langs.add('dart');
  if (
    existsSync(join(root, 'pyproject.toml')) ||
    existsSync(join(root, 'requirements.txt')) ||
    existsSync(join(root, 'setup.py'))
  ) {
    langs.add('python');
  }
  if (existsSync(join(root, 'go.mod'))) langs.add('go');
  if (existsSync(join(root, 'Cargo.toml'))) langs.add('rust');
  if (existsSync(join(root, 'pom.xml')) || existsSync(join(root, 'build.gradle'))) {
    langs.add('java');
  }
  return [...langs];
}

function detectPackageManager(root: string): string | null {
  const lockmap: Array<[string, string]> = [
    ['pnpm-lock.yaml', 'pnpm'],
    ['yarn.lock', 'yarn'],
    ['bun.lockb', 'bun'],
    ['package-lock.json', 'npm'],
    ['poetry.lock', 'poetry'],
    ['Cargo.lock', 'cargo'],
    ['go.sum', 'go'],
  ];
  for (const [file, mgr] of lockmap) {
    if (existsSync(join(root, file))) return mgr;
  }
  if (existsSync(join(root, 'requirements.txt'))) return 'pip';
  if (existsSync(join(root, 'package.json'))) return 'npm';
  if (existsSync(join(root, 'go.mod'))) return 'go';
  return null;
}

/** package.json scripts에서 키 이름으로 명령을 고른다. */
function scriptCmd(pkg: PackageJson | null, names: string[]): string | null {
  const scripts = pkg?.scripts ?? {};
  for (const n of names) {
    if (typeof scripts[n] === 'string') return `npm run ${n}`;
  }
  return null;
}

function detectType(
  root: string,
  pkg: PackageJson | null,
  deps: Set<string>,
  signals: string[],
): ProjectType {
  const dirHas = (d: string): boolean => existsSync(join(root, d));

  // 1. mobile
  if (existsSync(join(root, 'pubspec.yaml'))) {
    const raw = readIf(root, 'pubspec.yaml') ?? '';
    if (raw.includes('flutter')) {
      signals.push('pubspec.yaml(flutter)');
      return 'mobile';
    }
  }
  if (hasAny(deps, ['react-native', 'expo', '@capacitor/core', 'nativescript'])) {
    signals.push('mobile 프레임워크 의존');
    return 'mobile';
  }
  if (dirHas('android') && dirHas('ios')) {
    signals.push('android/ + ios/ 디렉토리');
    return 'mobile';
  }

  // 2. desktop
  if (hasAny(deps, ['electron', '@tauri-apps/api', '@tauri-apps/cli'])) {
    signals.push('desktop 프레임워크 의존');
    return 'desktop';
  }
  if (existsSync(join(root, 'src-tauri'))) {
    signals.push('src-tauri/');
    return 'desktop';
  }

  // 3. web
  if (
    hasAny(deps, [
      'react', 'vue', 'svelte', '@angular/core', 'next', 'nuxt', 'vite',
      'solid-js', 'astro', '@sveltejs/kit',
    ])
  ) {
    signals.push('web 프레임워크 의존');
    return 'web';
  }

  // 4. cli
  if (pkg?.bin !== undefined) {
    signals.push('package.json bin 필드');
    return 'cli';
  }
  if (hasAny(deps, ['commander', 'yargs', 'oclif', '@clack/prompts', 'inquirer'])) {
    signals.push('cli 프레임워크 의존');
    return 'cli';
  }
  {
    const py = readIf(root, 'pyproject.toml') ?? '';
    if (py.includes('click') || py.includes('typer') || py.includes('argparse')) {
      signals.push('python cli 프레임워크');
      return 'cli';
    }
  }

  // 5. batch (스케줄러 시그널)
  if (
    hasAny(deps, ['node-cron', 'cron', 'bull', 'bullmq', 'agenda', 'node-schedule'])
  ) {
    signals.push('batch 스케줄러 의존');
    return 'batch';
  }
  {
    const py = readIf(root, 'pyproject.toml') ?? '';
    if (py.includes('apscheduler') || py.includes('celery')) {
      signals.push('python 스케줄러');
      return 'batch';
    }
  }

  // 6. library
  if (pkg !== null && (pkg.exports !== undefined || pkg.main !== undefined)) {
    signals.push('package.json exports/main (앱·cli 시그널 없음)');
    return 'library';
  }

  signals.push('분류 시그널 없음');
  return 'unknown';
}

/**
 * 프로젝트 루트를 분석해 ProjectProfile을 반환한다.
 * @param root  분석할 프로젝트 절대경로
 */
export function analyze(root: string): ProjectProfile {
  const signals: string[] = [];
  const pkg = parsePackageJson(readIf(root, 'package.json'));
  const deps = allDeps(pkg);

  const type = detectType(root, pkg, deps, signals);
  const languages = detectLanguages(root, pkg, deps);
  const packageManager = detectPackageManager(root);

  const testCmd = scriptCmd(pkg, ['test']);
  const lintCmd = scriptCmd(pkg, ['lint']);
  const formatCmd = scriptCmd(pkg, ['format', 'fmt']);

  let ci: string | null = null;
  if (existsSync(join(root, '.github', 'workflows'))) {
    try {
      if (readdirSync(join(root, '.github', 'workflows')).length > 0) {
        ci = 'github-actions';
      }
    } catch {
      ci = 'github-actions';
    }
  } else if (existsSync(join(root, '.gitlab-ci.yml'))) {
    ci = 'gitlab-ci';
  }

  const hasGit = existsSync(join(root, '.git'));

  return {
    root,
    type,
    languages,
    packageManager,
    testCmd,
    lintCmd,
    formatCmd,
    ci,
    hasGit,
    signals,
  };
}
