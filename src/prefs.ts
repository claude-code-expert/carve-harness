// src/prefs.ts — 사용자 구성요소 선택 영속화 (레이어 A, M9/INTEL-04).
// 순수 데이터 모듈: 로깅은 호출자 책임(console.* 없음). 새 의존성 없음(node:fs + JSON).
// 이 파일은 사용자 데이터이며 install manifest에 포함하지 않는다 — uninstall이 사용자 선호를 지우면 안 된다.
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import type { HarnessDesign } from './designer.ts';

/** 사용자 선호: 추천 대비 끈 것(deselected)·켠 것(selected) + 갱신 시각. */
export interface CarvePrefs {
  /** 추천이었으나 사용자가 끈 컴포넌트 id */
  deselected: string[];
  /** 추천이 아니었으나 사용자가 켠 컴포넌트 id */
  selected: string[];
  /** ISO 갱신 시각 */
  updatedAt: string;
}

/** 대상 루트 기준 prefs 파일 상대경로 (D5: .claude/ 안에 한정). */
export const PREFS_REL = '.claude/.carve-prefs.json';

function prefsPath(root: string): string {
  return join(root, PREFS_REL);
}

/** unknown JSON이 CarvePrefs 형태인지 좁힌다(deselected/selected가 string[]). */
function isCarvePrefs(v: unknown): v is CarvePrefs {
  if (typeof v !== 'object' || v === null) return false;
  const o = v as Record<string, unknown>;
  const isStrArr = (x: unknown): x is string[] =>
    Array.isArray(x) && x.every((e) => typeof e === 'string');
  return isStrArr(o.deselected) && isStrArr(o.selected);
}

/**
 * <root>/.claude/.carve-prefs.json을 읽는다.
 * 파일이 없으면 null. 손상/형태불일치도 throw 없이 null (손상된 prefs가 설치를 깨면 안 됨).
 */
export function readPrefs(root: string): CarvePrefs | null {
  const p = prefsPath(root);
  if (!existsSync(p)) return null;
  try {
    const parsed: unknown = JSON.parse(readFileSync(p, 'utf8'));
    if (!isCarvePrefs(parsed)) return null;
    return { deselected: parsed.deselected, selected: parsed.selected, updatedAt: parsed.updatedAt };
  } catch {
    return null;
  }
}

/** prefs를 <root>/.claude/.carve-prefs.json에 쓴다(.claude 없으면 생성). pretty JSON + 끝 개행. */
export function writePrefs(root: string, prefs: CarvePrefs): void {
  const p = prefsPath(root);
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, JSON.stringify(prefs, null, 2) + '\n');
}

/**
 * 기본 체크될 id 목록을 계산한다(순수·결정적, I/O 없음).
 * prefs 없으면 recommended 그대로. 있으면 (recommended − deselected + selected),
 * 단 design.available에 있는 id만 (없는 건 절대 체크 안 함).
 */
export function applyPrefs(design: HarnessDesign, prefs: CarvePrefs | null): string[] {
  if (prefs === null) return [...design.recommended];
  const avail = new Set(design.available);
  const checked = new Set(design.recommended);
  for (const id of prefs.deselected) checked.delete(id);
  for (const id of prefs.selected) checked.add(id);
  return [...checked].filter((id) => avail.has(id));
}
