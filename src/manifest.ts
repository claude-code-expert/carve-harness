// src/manifest.ts — 설치 내역 추적 (레이어 A, M6). 클린 언인스톨의 근거.
import { readFileSync, writeFileSync, existsSync, rmSync } from 'node:fs';
import { join } from 'node:path';

export const MANIFEST_NAME = 'carve-manifest.json';

export interface ManifestHook {
  event: string;
  command: string;
}

export interface Manifest {
  version: string;
  /** carve가 설치한 파일 (대상 루트 기준 상대경로) */
  files: string[];
  /** 사용자 파일을 보존한 .bak 경로 */
  backups: string[];
  /** settings.json에 등록한 carve 훅 */
  hooks: ManifestHook[];
  /** settings.json에 등록한 carve MCP 서버 이름 (uninstall용) */
  mcps?: string[];
}

export function manifestPath(root: string): string {
  return join(root, MANIFEST_NAME);
}

export function readManifest(root: string): Manifest | null {
  const p = manifestPath(root);
  if (!existsSync(p)) return null;
  try {
    return JSON.parse(readFileSync(p, 'utf8')) as Manifest;
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
