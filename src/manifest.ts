// src/manifest.ts — 설치 내역 추적 (레이어 A, M6→M8). 클린 언인스톨 + 라이프사이클(diff/update)의 근거.
import { readFileSync, writeFileSync, existsSync, rmSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join } from 'node:path';

export const MANIFEST_NAME = 'carve-manifest.json';

/** 매니페스트 스키마 버전 — v2부터 파일별 {path, hash, assetVersion} 기록. */
export const SCHEMA_VERSION = 2;

/** 매니페스트에 찍는 carve 버전 — package.json 단일 출처. */
export const CARVE_VERSION: string = (
  JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8')) as { version: string }
).version;

export interface ManifestHook {
  event: string;
  command: string;
}

/** 설치한 파일 1건 — 경로·설치 시점 콘텐츠 해시·자산 버전. */
export interface ManifestFile {
  /** 대상 루트 기준 상대경로 */
  path: string;
  /** 설치 콘텐츠의 sha256 hex (v1 마이그레이션 시엔 빈 문자열일 수 있음) */
  hash: string;
  /** 이 파일을 깐 carve(자산) 버전 */
  assetVersion: string;
}

export interface Manifest {
  /** 매니페스트 스키마 버전 (v2부터) */
  schemaVersion: number;
  version: string;
  /** 설치 시 적용된 하네스 레벨 (update/diff가 동일 레벨로 재생성하도록 영속). 미기록=auto. */
  level?: string;
  /** carve가 설치한 파일 (v2: 경로+해시+자산버전) */
  files: ManifestFile[];
  /** 사용자 파일을 보존한 .bak 경로 */
  backups: string[];
  /** settings.json에 등록한 carve 훅 */
  hooks: ManifestHook[];
  /** settings.json에 등록한 carve MCP 서버 이름 (uninstall용) */
  mcps?: string[];
}

/**
 * 디스크의 원시 매니페스트 형태 — 신뢰 불가(손편집·구버전 가능).
 * files는 v1(string[])·v2(ManifestFile[])가 섞일 수 있다.
 */
interface RawManifest {
  schemaVersion?: number;
  version?: string;
  level?: string;
  files?: (string | ManifestFile)[];
  backups?: string[];
  hooks?: ManifestHook[];
  mcps?: string[];
}

export function manifestPath(root: string): string {
  return join(root, MANIFEST_NAME);
}

/** 콘텐츠 문자열의 sha256 hex. 결정적(salt 없음). */
export function hashContent(content: string): string {
  return createHash('sha256').update(content, 'utf8').digest('hex');
}

/**
 * 유일한 하위호환 지점 — 디스크의 원시 매니페스트(v1 또는 v2)를 정규화한 v2 Manifest로 변환.
 * raw는 신뢰 불가(unknown)이므로 typeof로 좁힌다. any·non-null `!` 금지.
 * v1 탐지: schemaVersion 부재 OR files가 문자열 배열. v1의 각 경로는
 * {path, hash:'', assetVersion: 기존 top-level version}으로 승급(파일별 버전이 v1엔 없었음).
 */
export function normalizeManifest(raw: unknown): Manifest {
  const r: RawManifest = (typeof raw === 'object' && raw !== null) ? (raw as RawManifest) : {};
  const version = typeof r.version === 'string' ? r.version : '';
  const rawFiles = Array.isArray(r.files) ? r.files : [];
  const files: ManifestFile[] = rawFiles.map((f) => {
    if (typeof f === 'string') {
      // v1 항목: 설치 시점 해시 미상 → 빈 해시, 자산버전은 옛 top-level version
      return { path: f, hash: '', assetVersion: version };
    }
    // v2 항목: 그대로 통과
    return { path: f.path, hash: f.hash, assetVersion: f.assetVersion };
  });
  return {
    schemaVersion: SCHEMA_VERSION,
    version,
    level: typeof r.level === 'string' ? r.level : undefined,
    files,
    backups: Array.isArray(r.backups) ? r.backups : [],
    hooks: Array.isArray(r.hooks) ? r.hooks : [],
    mcps: Array.isArray(r.mcps) ? r.mcps : undefined,
  };
}

export function readManifest(root: string): Manifest | null {
  const p = manifestPath(root);
  if (!existsSync(p)) return null;
  try {
    const parsed: unknown = JSON.parse(readFileSync(p, 'utf8'));
    return normalizeManifest(parsed);
  } catch {
    return null;
  }
}

export function writeManifest(root: string, m: Manifest): void {
  writeFileSync(manifestPath(root), JSON.stringify(m, null, 2) + '\n');
}

export function removeManifest(root: string): void {
  rmSync(manifestPath(root), { force: true });
}

/**
 * 디스크의 v1 매니페스트를 v2로 승급한다(파일별 해시 back-fill).
 * 한계: 설치 시점의 원본 해시는 복구 불가하므로, 현재 디스크 콘텐츠를 기준선으로 해시한다.
 *   → 사용자가 수정한 파일은 그 수정된 상태로 해시된다(이후 diff에서 'unchanged'로 보일 수 있음).
 * 멱등: 이미 v2(schemaVersion===2)면 파일을 다시 쓰지 않고 no-op 반환(byte-identical).
 * @returns migrated: 실제로 v1→v2 변환했는지, from: 원본 스키마 버전, filled: 디스크에서 해시를 채운 파일 수.
 */
export function migrateManifest(root: string): { migrated: boolean; from: number; filled: number } {
  const p = manifestPath(root);
  if (!existsSync(p)) return { migrated: false, from: 0, filled: 0 };

  let raw: RawManifest;
  try {
    raw = JSON.parse(readFileSync(p, 'utf8')) as RawManifest;
  } catch {
    return { migrated: false, from: 0, filled: 0 };
  }

  // 원시 스키마 기준으로 판정 (정규화 전) — 이미 v2면 재기록 없이 멱등 no-op
  if (raw.schemaVersion === SCHEMA_VERSION) {
    return { migrated: false, from: SCHEMA_VERSION, filled: 0 };
  }

  const m = normalizeManifest(raw);
  let filled = 0;
  for (const f of m.files) {
    const full = join(root, f.path);
    if (existsSync(full)) {
      f.hash = hashContent(readFileSync(full, 'utf8'));
      filled += 1;
    }
    // 디스크에 없으면 hash='' 유지 (위 한계 주석 참고)
  }
  writeManifest(root, m);
  return { migrated: true, from: 1, filled };
}
