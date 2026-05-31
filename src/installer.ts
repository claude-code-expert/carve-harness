// src/installer.ts — 대상 프로젝트에 자산 설치/제거 (레이어 A, M6). 멱등성 필수.
// - 사용자 파일은 .bak로 1회 보존 후 기록.
// - settings.json 훅은 idempotent 병합(carve 마커). uninstall 시 정확 제거.
import {
  readFileSync, writeFileSync, existsSync, mkdirSync, rmSync, chmodSync, copyFileSync,
} from 'node:fs';
import { join, dirname } from 'node:path';
import type { Artifact } from './generator.ts';
import {
  readManifest, writeManifest, removeManifest, CARVE_VERSION, type Manifest,
} from './manifest.ts';

const SETTINGS_REL = '.claude/settings.json';

export interface HookReg {
  event: string;
  command: string;
  matcher?: string;
}

export interface McpReg {
  name: string;
  command: string;
  args: string[];
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
interface McpServer { command: string; args: string[] }
interface Settings { hooks?: Record<string, HookGroup[]>; mcpServers?: Record<string, McpServer>; [k: string]: unknown }

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

function applyHooks(s: Settings, regs: HookReg[]): void {
  const hooks = (s.hooks ??= {});
  for (const r of regs) {
    const arr = (hooks[r.event] ??= []);
    const present = arr.some((g) => g.hooks.some((h) => h.command === r.command));
    if (!present) {
      arr.push({ matcher: r.matcher ?? '', hooks: [{ type: 'command', command: r.command, _carve: true }] });
    }
  }
}

function applyMcp(s: Settings, mcps: McpReg[]): void {
  const servers = (s.mcpServers ??= {});
  for (const m of mcps) {
    if (!servers[m.name]) servers[m.name] = { command: m.command, args: m.args };
  }
}

/** 훅·MCP를 settings.json에 1회 read/write로 멱등 병합한다. */
function mergeSettings(root: string, hooks: HookReg[], mcps: McpReg[]): void {
  if (hooks.length === 0 && mcps.length === 0) return;
  const s = readSettings(root);
  if (hooks.length) applyHooks(s, hooks);
  if (mcps.length) applyMcp(s, mcps);
  writeSettings(root, s);
}

/** artifacts를 쓰고, carve가 만든 적 없는 사용자 파일은 1회 .bak 보존한다. written 경로 반환. */
function writeArtifacts(root: string, artifacts: Artifact[], prevFiles: Set<string>, backedUp: string[]): string[] {
  const written: string[] = [];
  for (const a of artifacts) {
    const full = join(root, a.path);
    mkdirSync(dirname(full), { recursive: true });
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
  return written;
}

function stripCarveMcp(root: string, names: string[]): void {
  if (names.length === 0) return;
  const p = join(root, SETTINGS_REL);
  if (!existsSync(p)) return;
  const s = readSettings(root);
  if (!s.mcpServers) return;
  for (const n of names) delete s.mcpServers[n];
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
export function install(root: string, artifacts: Artifact[], hooks: HookReg[] = [], mcps: McpReg[] = []): InstallResult {
  const prev = readManifest(root);
  const prevFiles = new Set(prev?.files ?? []);
  const backedUp: string[] = [...(prev?.backups ?? [])];

  const written = writeArtifacts(root, artifacts, prevFiles, backedUp);
  mergeSettings(root, hooks, mcps);

  const manifest: Manifest = {
    version: CARVE_VERSION,
    files: written,
    backups: backedUp,
    hooks: hooks.map((h) => ({ event: h.event, command: h.command })),
    mcps: mcps.map((m) => m.name),
  };
  writeManifest(root, manifest);
  return { written, backedUp: backedUp.slice(prev?.backups?.length ?? 0), hooks: hooks.length };
}

const ROOT_CLAUDE = 'CLAUDE.md';

/**
 * CLAUDE.md 베이스라인 + .claude/rules/* 를 멱등 설치한다 (carve init-claude).
 * - 기존 manifest.files를 보존하고 신규 파일을 union (클린 제거 유지).
 * - 루트 CLAUDE.md에 import 블록을 marker 기준으로 멱등 추가한다.
 */
export function installClaudeBase(
  root: string, artifacts: Artifact[], importBlock: string, marker: string,
): InstallResult {
  const prev = readManifest(root);
  const prevFiles = new Set(prev?.files ?? []);
  const backedUp: string[] = [...(prev?.backups ?? [])];

  const written = writeArtifacts(root, artifacts, prevFiles, backedUp);

  // 루트 CLAUDE.md에 @import 블록을 멱등 추가 (전체 파일이 아닌 append라 별도 처리)
  const rootFull = join(root, ROOT_CLAUDE);
  const rootContent = existsSync(rootFull) ? readFileSync(rootFull, 'utf8') : '';
  if (!rootContent.includes(marker)) {
    if (existsSync(rootFull) && !prevFiles.has(ROOT_CLAUDE)) {
      const bak = rootFull + '.bak';
      if (!existsSync(bak)) {
        copyFileSync(rootFull, bak);
        backedUp.push(ROOT_CLAUDE + '.bak');
      }
    }
    const next = rootContent.length
      ? rootContent.replace(/\s*$/, '\n') + importBlock
      : `# CLAUDE.md\n${importBlock}`;
    writeFileSync(rootFull, next);
  }
  if (!written.includes(ROOT_CLAUDE)) written.push(ROOT_CLAUDE);

  const manifest: Manifest = {
    version: CARVE_VERSION,
    files: [...new Set([...(prev?.files ?? []), ...written])],
    backups: [...new Set(backedUp)],
    hooks: prev?.hooks ?? [],
    mcps: prev?.mcps ?? [],
  };
  writeManifest(root, manifest);
  return { written, backedUp: backedUp.slice(prev?.backups?.length ?? 0), hooks: 0 };
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
  stripCarveMcp(root, m.mcps ?? []);
  removeManifest(root);
  return { removed, restored };
}
