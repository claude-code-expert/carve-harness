// src/commands.ts — CLI 명령 핸들러 (레이어 A). 파이프라인 와이어링.
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { analyze } from './analyzer.ts';
import type { ProjectProfile } from './types.ts';
import { design, type HarnessLevel } from './designer.ts';
import { generate, hookRegsFor, mcpRegsFor } from './generator.ts';
import { audit, auditShellSyntax, errorsOf, type AuditFinding } from './auditor.ts';
import { install, uninstall, installClaudeBase } from './installer.ts';
import { generateClaudeBase, selectStack, ROOT_IMPORT_BLOCK, ROOT_IMPORT_MARKER } from './claudebase.ts';
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

// npm 설치 가능한 언어서버 (그 외 언어는 lsp 스킬이 수동 안내)
const NPM_LANG_SERVERS: Record<string, string[]> = {
  typescript: ['@vtsls/language-server', 'typescript'],
  javascript: ['@vtsls/language-server', 'typescript'],
  python: ['pyright'],
};

/** 탐지 언어의 LSP 언어서버를 전역 설치한다(best-effort, 비차단). */
function installLspServers(profile: ProjectProfile, io: IO): void {
  const pkgs = new Set<string>();
  for (const lang of profile.languages) for (const p of NPM_LANG_SERVERS[lang] ?? []) pkgs.add(p);
  if (pkgs.size === 0) {
    io.log('LSP: npm 설치 대상 언어서버 없음(go/rust 등은 lsp 스킬의 수동 안내 참조).');
    return;
  }
  io.log(`LSP 언어서버 설치: npm i -g ${[...pkgs].join(' ')} ...`);
  const r = spawnSync('npm', ['i', '-g', ...pkgs], { stdio: 'ignore' });
  io.log(r.status === 0 ? 'LSP 언어서버 설치 완료.' : 'LSP 언어서버 설치 실패 — 수동: npm i -g ' + [...pkgs].join(' '));
}

/** 생성물 감사 — ERROR가 있으면 출력하고 true(차단)를 반환한다. */
function auditGate(findings: AuditFinding[], io: IO, verb: string): boolean {
  const errs = errorsOf(findings);
  if (errs.length === 0) return false;
  io.error(`auditor 차단: ERROR ${errs.length}건 — ${verb} 중단`);
  for (const f of errs) io.error(`  ${f.path}:${f.line} [${f.rule}] ${f.message}`);
  return true;
}

/** 분석 → 설계 → 생성 → 설치. selected=부분집합, lspServers=언어서버 자동설치, level=레벨 강제(--level). */
export function cmdInstall(root: string, io: IO, selected?: string[], lspServers = false, level?: HarnessLevel): number {
  const profile = analyze(root);
  let d = design(profile, level);
  if (selected) {
    const avail = new Set(d.available);
    d = { ...d, recommended: selected.filter((id) => avail.has(id)) };
  }
  const artifacts = generate(profile, d);

  // 설치 전 자기 검증 (PoC: secret·과도권한·훅 주입 0건 + 셸 문법)
  if (auditGate([...audit(artifacts), ...auditShellSyntax(artifacts)], io, '설치')) return 1;

  const hooks = hookRegsFor(d);
  const mcps = mcpRegsFor(d);
  const r = install(root, artifacts, hooks, mcps);
  io.log(`설치 완료 [${profile.type}/${d.level}]: 파일 ${r.written.length} · 훅 ${r.hooks} · MCP ${mcps.length} · 백업 ${r.backedUp.length}`);

  // 토큰 효율: LSP 언어서버 자동설치(대화형/명시 요청 시)
  if (lspServers && d.recommended.includes('lsp')) installLspServers(profile, io);
  return 0;
}

/**
 * CLAUDE.md 베이스라인 + .claude/rules/* 생성 (carve init-claude).
 * 탐지된 언어 스택으로 깎고, 루트 CLAUDE.md가 @import하도록 연결한다. 멱등.
 */
export function cmdInitClaude(root: string, io: IO): number {
  const profile = analyze(root);
  const artifacts = generateClaudeBase(profile);

  if (auditGate(audit(artifacts), io, '생성')) return 1;

  const stack = selectStack(profile);
  const r = installClaudeBase(root, artifacts, ROOT_IMPORT_BLOCK, ROOT_IMPORT_MARKER);
  io.log(`CLAUDE.md 베이스라인 생성 [stack=${stack}]: .claude/CLAUDE.md + rules ${artifacts.length - 1}개 · 루트 CLAUDE.md @import 연결 (파일 ${r.written.length})`);
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
  return cmdInstall(root, io, selected, true); // 대화형 설치 → LSP 언어서버 자동설치
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
