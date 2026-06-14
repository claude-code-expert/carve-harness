// src/installer.ts — 대상 프로젝트에 자산 설치/제거 (레이어 A, M6). 멱등성 필수.
// - 사용자 파일은 .bak로 1회 보존 후 기록.
// - settings.json 훅은 idempotent 병합(carve 마커). uninstall 시 정확 제거.
import {
  readFileSync, writeFileSync, existsSync, mkdirSync, rmSync, rmdirSync, chmodSync, copyFileSync, constants,
} from 'node:fs';
import { join, dirname } from 'node:path';
import type { Artifact } from './generator.ts';
import type { HarnessLevel } from './designer.ts';
import {
  readManifest, writeManifest, removeManifest, hashContent, SCHEMA_VERSION,
  CARVE_VERSION, type Manifest, type ManifestFile,
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
  } catch (e) {
    // 손상 JSON을 {}로 삼키면 mergeSettings가 사용자 settings 전체를 carve 항목만으로 덮어쓴다(데이터 손실).
    // 조용히 진행하지 않고 중단한다 — cli.run()의 에러 경계가 사유 + exit 1로 보고.
    throw new Error(`.claude/settings.json 파싱 실패(손상된 JSON) — 수동 수정 후 재시도: ${(e as Error).message}`);
  }
}

function writeSettings(root: string, s: Settings): void {
  const p = join(root, SETTINGS_REL);
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, JSON.stringify(s, null, 2) + '\n');
}

/** 훅 command의 스크립트 파일명(identity). 경로 표기(상대/절대)가 바뀌어도 같은 훅으로 본다. */
function hookScriptName(command: string): string {
  const m = /([^/\s"']+\.sh)\b/.exec(command);
  return m?.[1] ?? command;
}

function applyHooks(s: Settings, regs: HookReg[]): void {
  const hooks = (s.hooks ??= {});
  for (const r of regs) {
    const existing = hooks[r.event];
    // 사용자 손편집으로 배열이 아니면 TypeError 대신 맥락 있는 에러로 중단(사용자 settings 불가침).
    if (existing !== undefined && !Array.isArray(existing)) {
      throw new Error(`.claude/settings.json hooks.${r.event}가 배열이 아닙니다 — 수동 수정 후 재시도`);
    }
    let arr = (hooks[r.event] ??= []);
    const script = hookScriptName(r.command);
    // 같은 스크립트의 기존 _carve 항목은 제자리 갱신(경로 rel→abs 드리프트·스테일 matcher 교정).
    // 과거 버그로 이중 등록된 중복 _carve 항목은 자가 수리(첫 항목만 유지).
    let matched = false;
    const emptied = new Set<HookGroup>();
    for (const g of arr) {
      if (!Array.isArray(g.hooks)) {
        throw new Error(`.claude/settings.json hooks.${r.event}의 그룹 hooks가 배열이 아닙니다 — 수동 수정 후 재시도`);
      }
      const kept: HookEntry[] = [];
      for (const h of g.hooks) {
        if (h._carve && hookScriptName(h.command) === script) {
          if (matched) continue; // 중복 항목 제거
          matched = true;
          h.command = r.command;
          // matcher는 그룹 단위 — 사용자 훅이 섞인 그룹은 건드리지 않는다(외과적).
          if (g.hooks.every((x) => x._carve)) g.matcher = r.matcher ?? '';
        }
        kept.push(h);
      }
      if (kept.length !== g.hooks.length) {
        g.hooks = kept;
        if (kept.length === 0) emptied.add(g);
      }
    }
    if (emptied.size > 0) {
      arr = arr.filter((g) => !emptied.has(g));
      hooks[r.event] = arr;
    }
    if (!matched) {
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

/**
 * artifacts를 쓰고, carve가 만든 적 없는 사용자 파일은 1회 .bak 보존한다.
 * 해시는 installer가 쓰는 시점에 계산한다(generator/Artifact는 순수 값객체 유지).
 * ManifestFile[] 반환 — 경로별 {path, hash, assetVersion}.
 */
/**
 * 대상 파일을 .bak로 1회 보존한다. COPYFILE_EXCL로 존재 검사·복사가 원자적(TOCTOU 제거).
 * @returns 새로 백업했으면 true, 이미 .bak가 있으면 false. EEXIST 외 오류는 그대로 던진다.
 */
export function backupOnce(full: string): boolean {
  try {
    copyFileSync(full, full + '.bak', constants.COPYFILE_EXCL);
    return true;
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code === 'EEXIST') return false;
    throw e;
  }
}

function writeArtifacts(root: string, artifacts: Artifact[], prevFiles: Set<string>, backedUp: string[]): ManifestFile[] {
  const written: ManifestFile[] = [];
  for (const a of artifacts) {
    const full = join(root, a.path);
    mkdirSync(dirname(full), { recursive: true });
    if (existsSync(full) && !prevFiles.has(a.path)) {
      if (backupOnce(full)) backedUp.push(a.path + '.bak');
    }
    writeFileSync(full, a.content);
    if (a.executable) chmodSync(full, 0o755);
    written.push({ path: a.path, hash: hashContent(a.content), assetVersion: CARVE_VERSION });
  }
  return written;
}

/** ManifestFile[] 두 개를 경로 기준으로 합친다(뒤 항목이 앞을 덮음 → 재설치 시 해시 갱신). */
function unionFiles(a: ManifestFile[], b: ManifestFile[]): ManifestFile[] {
  const byPath = new Map<string, ManifestFile>();
  for (const f of a) byPath.set(f.path, f);
  for (const f of b) byPath.set(f.path, f);
  return [...byPath.values()];
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

// 구버전 carve가 settings.json에 박은 상대경로 훅 명령 → $CLAUDE_PROJECT_DIR 절대경로.
// cwd≠프로젝트 루트일 때 상대경로 훅이 "No such file"로 죽는 문제를 1회 교정한다(gotchas 참조).
const REL_HOOK_PREFIX = 'bash .claude/hooks/';
const ABS_HOOK_PREFIX = 'bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/';

/**
 * 기존 설치의 상대경로 _carve 훅을 $CLAUDE_PROJECT_DIR 절대경로로 제자리 교정한다(멱등).
 * settings.json과 manifest.hooks의 command를 함께 갱신 — uninstall은 _carve 플래그로 제거하므로
 * manifest 갱신은 제거 정확성이 아니라 기록 정합성(설치 내역이 실제 settings와 일치)을 위한 것. 이미 절대경로면 no-op.
 * @returns 교정한 settings.json 훅 항목 수.
 */
export function migrateHookPaths(root: string): number {
  let changed = 0;

  // 1) settings.json — _carve 마커가 붙은 carve 훅만 건드린다(사용자 훅 불가침).
  if (existsSync(join(root, SETTINGS_REL))) {
    const s = readSettings(root);
    if (s.hooks) {
      for (const event of Object.keys(s.hooks)) {
        for (const g of s.hooks[event] ?? []) {
          for (const h of g.hooks) {
            if (h._carve && h.command.startsWith(REL_HOOK_PREFIX)) {
              h.command = ABS_HOOK_PREFIX + h.command.slice(REL_HOOK_PREFIX.length);
              changed += 1;
            }
          }
        }
      }
      if (changed > 0) writeSettings(root, s);
    }
  }

  // 2) manifest.hooks — carve가 기록한 훅뿐이라 _carve 검사 없이 prefix만으로 안전.
  const m = readManifest(root);
  if (m?.hooks?.length) {
    let mChanged = false;
    const hooks = m.hooks.map((h) => {
      if (h.command.startsWith(REL_HOOK_PREFIX)) {
        mChanged = true;
        return { ...h, command: ABS_HOOK_PREFIX + h.command.slice(REL_HOOK_PREFIX.length) };
      }
      return h;
    });
    if (mChanged) writeManifest(root, { ...m, hooks });
  }

  return changed;
}

// 라이프사이클 fade-out의 최종 단계로 카탈로그·자산에서 삭제된 컴포넌트 id (tombstone).
// 컴포넌트를 삭제할 때 그 id를 여기에 append하면 carve update가 기존 설치의 잔여(orphan)를 1회 정리한다.
// 명시 목록을 쓰는 이유: "카탈로그 미등재 = orphan"으로 판정하면 비카탈로그 자산(anti-slop clean-html 등)을
// 오삭제한다. 삭제 대상을 명시해 그 위험을 차단한다(카탈로그와 항상 일관 — 삭제 릴리스에서만 함께 채운다).
export const REMOVED_COMPONENTS: readonly string[] = [
  // v1.5.0 fade-out 최종 삭제: hidden 4종(내장 슬래시 충돌) + deprecated 3종(squad 위임 일원화).
  'memory', 'verify', 'pr', 'review', 'changelog', 'security-scan', 'coordinator',
];

export interface OrphanCleanupResult {
  /** 삭제한 파일 경로 */
  removed: string[];
  /** 사용자 수정(해시 불일치)으로 보존한 파일 경로 */
  preserved: string[];
}

/** orphan 후보 경로 → 컴포넌트 id. skill SKILL.md면 isSkillDir=true(빈 디렉터리 정리 대상). */
function orphanRef(path: string): { id: string; isSkillDir: boolean } | null {
  const skill = /^\.claude\/skills\/([^/]+)\/SKILL\.md$/.exec(path);
  if (skill?.[1] !== undefined) return { id: skill[1], isSkillDir: true };
  const cmd = /^\.claude\/commands\/carve-(.+)\.md$/.exec(path);
  if (cmd?.[1] !== undefined) return { id: cmd[1], isSkillDir: false };
  return null;
}

/**
 * 삭제된(tombstone) 컴포넌트의 잔여 파일을 기존 설치에서 1회 정리한다(멱등). carve update가 호출.
 * 안전 가드:
 *  - tombstone에 명시된 id만 대상(비카탈로그 자산 clean-html 등은 절대 건드리지 않는다).
 *  - manifest 기록 해시와 디스크 콘텐츠 해시가 일치하는 carve 소유·미수정 파일만 삭제한다.
 *    사용자가 수정한 파일(해시 불일치)은 보존하고 안내한다. 해시 미상('' — v1 back-fill 전)은 carve 소유로 본다.
 * manifest.files에서도 제거 항목을 빼 기록 정합을 맞춘다(uninstall은 manifest 기반이므로 정합 유지 필수).
 */
export function removeOrphanedComponents(
  root: string,
  tombstone: readonly string[] = REMOVED_COMPONENTS,
): OrphanCleanupResult {
  const removed: string[] = [];
  const preserved: string[] = [];
  const m = readManifest(root);
  if (!m) return { removed, preserved };

  const dead = new Set(tombstone);
  const kept: ManifestFile[] = [];
  for (const f of m.files) {
    const ref = orphanRef(f.path);
    if (ref === null || !dead.has(ref.id)) {
      kept.push(f);
      continue;
    }
    const full = join(root, f.path);
    if (!existsSync(full)) continue; // 디스크엔 이미 없음 → manifest에서만 빠짐
    // 해시 가드: 설치 시점 해시(f.hash)와 현재 콘텐츠 불일치 = 사용자 수정 → 보존.
    if (f.hash !== '' && f.hash !== hashContent(readFileSync(full, 'utf8'))) {
      preserved.push(f.path);
      kept.push(f);
      continue;
    }
    rmSync(full);
    removed.push(f.path);
    if (ref.isSkillDir) {
      try { rmdirSync(dirname(full)); } catch { /* 비어있지 않으면 둔다 */ }
    }
  }
  if (kept.length !== m.files.length) writeManifest(root, { ...m, files: kept });
  return { removed, preserved };
}

/** 자산을 멱등 설치한다. level=적용 레벨(update/diff 재현용으로 영속). */
export function install(root: string, artifacts: Artifact[], hooks: HookReg[] = [], mcps: McpReg[] = [], level?: HarnessLevel): InstallResult {
  const prev = readManifest(root);
  const prevFiles = new Set((prev?.files ?? []).map((f) => f.path));
  const backedUp: string[] = [...(prev?.backups ?? [])];

  const written = writeArtifacts(root, artifacts, prevFiles, backedUp);
  mergeSettings(root, hooks, mcps);

  const manifest: Manifest = {
    schemaVersion: SCHEMA_VERSION,
    version: CARVE_VERSION,
    level: level ?? prev?.level,
    // 기존 files를 union 보존 — 재설치/혼합(init-claude) 시 claude-base 파일이 누락돼 클린 제거가 깨지는 것을 방지.
    files: unionFiles(prev?.files ?? [], written),
    backups: backedUp,
    hooks: hooks.map((h) => ({ event: h.event, command: h.command })),
    mcps: mcps.map((m) => m.name),
  };
  // manifest-last = 부분 실패 시 이전 상태 보존 (artifacts·settings가 모두 쓰인 뒤 마지막에 기록)
  writeManifest(root, manifest);
  return { written: written.map((f) => f.path), backedUp: backedUp.slice(prev?.backups?.length ?? 0), hooks: hooks.length };
}

/** 루트 CLAUDE.md — carve가 @import만 append-merge하는 비소유 파일(매니페스트에 hash:'' 센티넬로 기록). */
export const ROOT_CLAUDE = 'CLAUDE.md';

/**
 * CLAUDE.md 베이스라인 + .claude/rules/* 를 멱등 설치한다 (carve init-claude).
 * - 기존 manifest.files를 보존하고 신규 파일을 union (클린 제거 유지).
 * - 루트 CLAUDE.md에 import 블록을 marker 기준으로 멱등 추가한다.
 */
export function installClaudeBase(
  root: string, artifacts: Artifact[], importBlock: string, marker: string,
): InstallResult {
  const prev = readManifest(root);
  const prevFiles = new Set((prev?.files ?? []).map((f) => f.path));
  const backedUp: string[] = [...(prev?.backups ?? [])];

  const written = writeArtifacts(root, artifacts, prevFiles, backedUp);

  // 루트 CLAUDE.md에 @import 블록을 멱등 추가 (전체 파일이 아닌 append라 별도 처리)
  const rootFull = join(root, ROOT_CLAUDE);
  const rootContent = existsSync(rootFull) ? readFileSync(rootFull, 'utf8') : '';
  if (!rootContent.includes(marker)) {
    if (existsSync(rootFull) && !prevFiles.has(ROOT_CLAUDE)) {
      if (backupOnce(rootFull)) backedUp.push(ROOT_CLAUDE + '.bak');
    }
    const next = rootContent.length
      ? rootContent.replace(/\s*$/, '\n') + importBlock
      : `# CLAUDE.md\n${importBlock}`;
    writeFileSync(rootFull, next);
  }
  // CLAUDE.md는 append-merge(전체 파일을 carve가 소유하지 않음)라 hash diff 대상에서 제외 → hash ''.
  if (!written.some((f) => f.path === ROOT_CLAUDE)) {
    written.push({ path: ROOT_CLAUDE, hash: '', assetVersion: CARVE_VERSION });
  }

  const manifest: Manifest = {
    schemaVersion: SCHEMA_VERSION,
    version: CARVE_VERSION,
    level: prev?.level,
    files: unionFiles(prev?.files ?? [], written),
    backups: [...new Set(backedUp)],
    hooks: prev?.hooks ?? [],
    mcps: prev?.mcps ?? [],
  };
  // manifest-last = 부분 실패 시 이전 상태 보존
  writeManifest(root, manifest);
  return { written: written.map((f) => f.path), backedUp: backedUp.slice(prev?.backups?.length ?? 0), hooks: 0 };
}

/** manifest 기준으로 carve 자산을 제거하고 .bak를 복원한다. */
export function uninstall(root: string): UninstallResult {
  const m = readManifest(root);
  if (!m) return { removed: [], restored: [] };
  const removed: string[] = [];
  const restored: string[] = [];

  // readManifest는 v1도 정규화 v2로 돌려주므로 {path} 구조분해가 v1/v2 모두 안전.
  for (const { path } of m.files) {
    const full = join(root, path);
    if (existsSync(full)) {
      rmSync(full);
      removed.push(path);
    }
    const bak = full + '.bak';
    if (existsSync(bak)) {
      copyFileSync(bak, full);
      rmSync(bak);
      restored.push(path);
    }
  }

  stripCarveHooks(root);
  stripCarveMcp(root, m.mcps ?? []);
  removeManifest(root);
  return { removed, restored };
}
