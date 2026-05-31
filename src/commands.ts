// src/commands.ts — CLI 명령 핸들러 (레이어 A). 파이프라인 와이어링.
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { analyze } from './analyzer.ts';
import { design } from './designer.ts';
import { generate, hookRegsFor } from './generator.ts';
import { audit, auditShellSyntax, errorsOf } from './auditor.ts';
import { install, uninstall } from './installer.ts';
import { readManifest } from './manifest.ts';
import { CATALOG } from './catalog.ts';
import type { IO } from './cli.ts';

/** 설치 가능 구성요소 목록 */
export function cmdList(io: IO): number {
  io.log('설치 가능 구성요소 (점수 ≥75):');
  for (const c of CATALOG) {
    const tags = [c.core ? '코어' : null, c.optional ? '선택' : null].filter(Boolean).join('·');
    io.log(`  [${c.kind}] ${c.id} (${c.score})${tags ? ` {${tags}}` : ''} — ${c.description}`);
  }
  return 0;
}

/** 분석 → 설계 → 생성 → 설치. selected가 주어지면 그 부분집합만 설치(대화형 선택 결과). */
export function cmdInstall(root: string, io: IO, selected?: string[]): number {
  const profile = analyze(root);
  let d = design(profile);
  if (selected) {
    const avail = new Set(d.available);
    d = { ...d, recommended: selected.filter((id) => avail.has(id)) };
  }
  const artifacts = generate(profile, d);

  // 설치 전 자기 검증 (PoC: secret·과도권한·훅 주입 0건 + 셸 문법)
  const errs = errorsOf([...audit(artifacts), ...auditShellSyntax(artifacts)]);
  if (errs.length > 0) {
    io.error(`auditor 차단: ERROR ${errs.length}건 — 설치 중단`);
    for (const f of errs) io.error(`  ${f.path}:${f.line} [${f.rule}] ${f.message}`);
    return 1;
  }

  const hooks = hookRegsFor(d);
  const r = install(root, artifacts, hooks);
  io.log(`설치 완료 [${profile.type}/${d.level}]: 파일 ${r.written.length} · 훅 ${r.hooks} · 백업 ${r.backedUp.length}`);
  return 0;
}

/** 대화형 설치: 추천을 기본 체크로 제시 → 사용자 선택 → 설치 (TTY). */
export async function interactiveInstall(root: string, io: IO): Promise<number> {
  const profile = analyze(root);
  const d = design(profile);
  const { selectInteractive } = await import('./wizard.ts');
  const selected = await selectInteractive(d);
  if (selected.length === 0) {
    io.log('선택된 구성요소가 없어 설치를 건너뜁니다.');
    return 0;
  }
  return cmdInstall(root, io, selected);
}

/** 설치된 하네스 점검 */
export function cmdDoctor(root: string, io: IO): number {
  const m = readManifest(root);
  if (!m) {
    io.log('carve 설치 없음. `carve install`로 설치하세요.');
    return 0;
  }
  io.log(`carve 설치됨 (v${m.version}): 파일 ${m.files.length} · 훅 ${m.hooks.length} · 백업 ${m.backups.length}`);
  for (const f of m.files) io.log(`  · ${f}`);
  // 설치된 셸 훅 문법 점검 (harness-audit)
  const hookArts = m.files
    .filter((f) => f.endsWith('.sh') && existsSync(join(root, f)))
    .map((f) => ({ path: f, content: readFileSync(join(root, f), 'utf8'), executable: true }));
  const shellErrs = errorsOf(auditShellSyntax(hookArts));
  io.log(shellErrs.length ? `⚠ 훅 문법 이슈 ${shellErrs.length}건` : `훅 문법 OK (${hookArts.length}개)`);
  return shellErrs.length > 0 ? 1 : 0;
}

/** 클린 제거 */
export function cmdUninstall(root: string, io: IO): number {
  const r = uninstall(root);
  io.log(`제거 완료: 파일 ${r.removed.length} · 복원 ${r.restored.length}`);
  return 0;
}
