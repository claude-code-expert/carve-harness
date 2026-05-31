// src/installer.ts — 대상 프로젝트에 자산 설치/제거 (레이어 A, M6). 멱등성 필수.
// - 사용자 파일은 .bak로 1회 보존 후 기록.
// - settings.json 훅은 idempotent 병합(carve 마커). uninstall 시 정확 제거.
import {
  readFileSync, writeFileSync, existsSync, mkdirSync, rmSync, chmodSync, copyFileSync,
} from 'node:fs';
import { join, dirname } from 'node:path';
import type { Artifact } from './generator.ts';
import {
  readManifest, writeManifest, removeManifest, type Manifest,
} from './manifest.ts';

const SETTINGS_REL = '.claude/settings.json';

export interface HookReg {
  event: string;
  command: string;
  matcher?: string;
}

export interface InstallResult {
  written: string[];
  backedUp: string[];
  hooks: number;
}

export interface UninstallResult {
  removed: string[];
  restored: string[];
}

// ── settings.json 타입 (최소) ──
interface HookEntry { type: string; command: string; _carve?: boolean }
interface HookGroup { matcher?: string; hooks: HookEntry[] }
interface Settings { hooks?: Record<string, HookGroup[]>; [k: string]: unknown }

function readSettings(root: string): Settings {
  const p = join(root, SETTINGS_REL);
  if (!existsSync(p)) return {};
  try {
    return JSON.parse(readFileSync(p, 'utf8')) as Settings;
  } catch {
    return {};
  }
}

function writeSettings(root: string, s: Settings): void {
  const p = join(root, SETTINGS_REL);
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, JSON.stringify(s, null, 2) + '\n');
}

function mergeHooks(root: string, regs: HookReg[]): void {
  const s = readSettings(root);
  const hooks = (s.hooks ??= {});
  for (const r of regs) {
    const arr = (hooks[r.event] ??= []);
    const present = arr.some((g) => g.hooks.some((h) => h.command === r.command));
    if (!present) {
      arr.push({ matcher: r.matcher ?? '', hooks: [{ type: 'command', command: r.command, _carve: true }] });
    }
  }
  writeSettings(root, s);
}

function stripCarveHooks(root: string): void {
  const p = join(root, SETTINGS_REL);
  if (!existsSync(p)) return;
  const s = readSettings(root);
  if (!s.hooks) return;
  for (const event of Object.keys(s.hooks)) {
    const groups = s.hooks[event];
    if (!groups) continue;
    const kept = groups
      .map((g) => ({ ...g, hooks: g.hooks.filter((h) => !h._carve) }))
      .filter((g) => g.hooks.length > 0);
    if (kept.length > 0) s.hooks[event] = kept;
    else delete s.hooks[event];
  }
  writeSettings(root, s);
}

/** 자산을 멱등 설치한다. */
export function install(root: string, artifacts: Artifact[], hooks: HookReg[] = []): InstallResult {
  const prev = readManifest(root);
  const prevFiles = new Set(prev?.files ?? []);
  const written: string[] = [];
  const backedUp: string[] = [...(prev?.backups ?? [])];

  for (const a of artifacts) {
    const full = join(root, a.path);
    mkdirSync(dirname(full), { recursive: true });
    // 사용자 파일(이전 carve 설치가 아님)이면 1회 .bak 보존
    if (existsSync(full) && !prevFiles.has(a.path)) {
      const bak = full + '.bak';
      if (!existsSync(bak)) {
        copyFileSync(full, bak);
        backedUp.push(a.path + '.bak');
      }
    }
    writeFileSync(full, a.content);
    if (a.executable) chmodSync(full, 0o755);
    written.push(a.path);
  }

  if (hooks.length) mergeHooks(root, hooks);

  const manifest: Manifest = {
    version: '1.1.0',
    files: written,
    backups: backedUp,
    hooks: hooks.map((h) => ({ event: h.event, command: h.command })),
  };
  writeManifest(root, manifest);
  return { written, backedUp: backedUp.slice(prev?.backups?.length ?? 0), hooks: hooks.length };
}

/** manifest 기준으로 carve 자산을 제거하고 .bak를 복원한다. */
export function uninstall(root: string): UninstallResult {
  const m = readManifest(root);
  if (!m) return { removed: [], restored: [] };
  const removed: string[] = [];
  const restored: string[] = [];

  for (const f of m.files) {
    const full = join(root, f);
    if (existsSync(full)) {
      rmSync(full);
      removed.push(f);
    }
    const bak = full + '.bak';
    if (existsSync(bak)) {
      copyFileSync(bak, full);
      rmSync(bak);
      restored.push(f);
    }
  }

  stripCarveHooks(root);
  removeManifest(root);
  return { removed, restored };
}
