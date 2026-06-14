// src/commands.ts — CLI 명령 핸들러 (레이어 A). 파이프라인 와이어링.
import {
  readFileSync, writeFileSync, existsSync, mkdirSync, chmodSync,
} from 'node:fs';
import { join, dirname } from 'node:path';
import { spawnSync } from 'node:child_process';
import { analyze } from './analyzer.ts';
import type { ProjectProfile } from './types.ts';
import { design, applyMetricsWeights, type HarnessLevel, type MetricsSuggestion } from './designer.ts';
import { aggregateMetrics, METRICS_REL } from './metrics.ts';
import { generate, hookRegsFor, mcpRegsFor, type Artifact } from './generator.ts';
import { audit, auditShellSyntax, errorsOf, type AuditFinding } from './auditor.ts';
import { install, uninstall, installClaudeBase, migrateHookPaths, removeOrphanedComponents, backupOnce, ROOT_CLAUDE } from './installer.ts';
import { generateClaudeBase, selectStack, ROOT_IMPORT_BLOCK, ROOT_IMPORT_MARKER, type ResponseLang } from './claudebase.ts';
import {
  readManifest, writeManifest, migrateManifest, hashContent, CARVE_VERSION,
  type Manifest, type ManifestFile,
} from './manifest.ts';
import { CATALOG, statusOf } from './catalog.ts';
import { deprecationNotices, type LifecycleNotice } from './lifecycle.ts';
import type { IO } from './cli.ts';

/** 설치 가능 구성요소 목록 (hidden 제외, deprecated는 태그 표시) */
export function cmdList(io: IO): number {
  io.log('설치 가능 구성요소 (점수 ≥75):');
  for (const c of CATALOG) {
    if (statusOf(c) === 'hidden') continue;
    const dep = statusOf(c) === 'deprecated' ? `비추천${c.replacedBy ? `→${c.replacedBy}` : ''}` : null;
    const tags = [c.core ? '코어' : null, c.optional ? '선택' : null, dep].filter(Boolean).join('·');
    io.log(`  [${c.kind}] ${c.id} (${c.score})${tags ? ` {${tags}}` : ''} — ${c.description}`);
  }
  return 0;
}

/** 텔레메트리 제안 표면화 (report·update 공용). 제안만 — 추천·자산을 강제로 바꾸지 않는다. */
function printSuggestions(suggestions: MetricsSuggestion[], io: IO): void {
  for (const s of suggestions) io.log(`텔레메트리 제안(${s.kind}): ${s.id} — ${s.reason}`);
}

/** deprecated/hidden 설치분 안내 출력 (doctor·update 공용). 에러 아님 — 안내만. */
function printLifecycleNotices(notices: LifecycleNotice[], io: IO, frozen: boolean): void {
  for (const n of notices) {
    if (n.status === 'deprecated') {
      const repl = n.replacedBy ? ` — ${n.replacedBy} 권장` : '';
      io.log(frozen
        ? `갱신 동결(비추천): ${n.id}${repl} (현재 설치 상태로 유지·uninstall 가능)`
        : `비추천 컴포넌트 설치됨: ${n.id}${repl} (계속 동작·uninstall 가능)`);
    } else {
      io.log(`제공 종료 컴포넌트 설치됨: ${n.id} — 갱신되지 않으며 uninstall 시 제거됩니다`);
    }
  }
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

/**
 * 진짜 미마이그레이션 v1 매니페스트 판정.
 * hash:''는 두 가지를 뜻한다 — (a) v1에서 승급된 미상 해시(전 파일), (b) 루트 CLAUDE.md의 append-merge 센티넬.
 * (b)는 init-claude가 정상 v2에 남기는 합법 항목이므로 v1 신호에서 제외한다. (schemaVersion은 normalize 후 항상 2라 검사 안 함.)
 */
function isUnmigrated(m: Manifest): boolean {
  return m.files.some((f) => f.hash === '' && f.path !== ROOT_CLAUDE);
}

/**
 * 사용자에게 보여줄 carve 서브커맨드 실행법.
 * carve는 보통 npx 일회성으로 실행돼 PATH에 `carve`가 없다 → npx 형태를 우선 안내한다.
 * `@latest`를 붙여 캐시된 옛 버전(예: 1.1.x엔 migrate/update 없음)으로 해석되는 것을 막는다.
 */
function cmdHint(sub: string): string {
  return `\`npx carve-harness@latest ${sub}\`(글로벌 설치 시 \`carve ${sub}\`)`;
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
    // 미등재(오타)·hidden(제공 종료) id는 조용히 버리지 않고 안내한다
    const ignored = selected.filter((id) => !avail.has(id));
    if (ignored.length > 0) io.log(`무시된 id(미등재/제공종료): ${ignored.join(', ')}`);
    d = { ...d, recommended: selected.filter((id) => avail.has(id)) };
  }
  const artifacts = generate(profile, d);

  // 설치 전 자기 검증 (PoC: secret·과도권한·훅 주입 0건 + 셸 문법)
  if (auditGate([...audit(artifacts), ...auditShellSyntax(artifacts)], io, '설치')) return 1;

  const hooks = hookRegsFor(d);
  const mcps = mcpRegsFor(d);
  const r = install(root, artifacts, hooks, mcps, d.level); // d.level 영속 → update/diff가 동일 레벨로 재현
  io.log(`설치 완료 [${profile.type}/${d.level}]: 파일 ${r.written.length} · 훅 ${r.hooks} · MCP ${mcps.length} · 백업 ${r.backedUp.length}`);

  // 토큰 효율: LSP 언어서버 자동설치(대화형/명시 요청 시)
  if (lspServers && d.recommended.includes('lsp')) installLspServers(profile, io);
  return 0;
}

/**
 * CLAUDE.md 베이스라인 + .claude/rules/* 생성 (carve init-claude).
 * 탐지된 언어 스택으로 깎고, 루트 CLAUDE.md가 @import하도록 연결한다. 멱등.
 */
export function cmdInitClaude(root: string, io: IO, lang?: ResponseLang): number {
  const profile = analyze(root);
  const artifacts = generateClaudeBase(profile, { lang });

  if (auditGate(audit(artifacts), io, '생성')) return 1;

  const stack = selectStack(profile);
  const r = installClaudeBase(root, artifacts, ROOT_IMPORT_BLOCK, ROOT_IMPORT_MARKER);
  io.log(`CLAUDE.md 베이스라인 생성 [stack=${stack}]: .claude/CLAUDE.md + rules ${artifacts.length - 1}개 · 루트 CLAUDE.md @import 연결 (파일 ${r.written.length})`);
  return 0;
}

/** 대화형 설치: 추천을 기본 체크로 제시 → 사용자 선택 → 설치 (TTY). level=--level 강제. */
export async function interactiveInstall(root: string, io: IO, level?: HarnessLevel): Promise<number> {
  const profile = analyze(root);
  const d = design(profile, level); // --level을 wizard 추천 베이스라인에 반영
  const { selectInteractive } = await import('./wizard.ts');
  // root를 넘겨 선호(.claude/.carve-prefs.json)를 라운드트립한다.
  // 주의: .carve-prefs.json은 사용자 데이터이므로 install manifest에 추가하지 않는다
  // (uninstall이 사용자 선호를 지우거나 update가 자산처럼 diff하면 안 됨).
  const selected = await selectInteractive(d, root);
  if (selected.length === 0) {
    io.log('선택된 구성요소가 없어 설치를 건너뜁니다.');
    return 0;
  }
  // 에러 경계: wizard 경로는 run()의 try/catch를 거치지 않으므로 여기서 직접 감싼다.
  try {
    return cmdInstall(root, io, selected, true, level); // 대화형 설치 → LSP 자동설치 + --level 전달
  } catch (e) {
    io.error(`오류: ${(e as Error).message}`);
    return 1;
  }
}

/** 설치된 하네스 점검 */
export function cmdDoctor(root: string, io: IO): number {
  const m = readManifest(root);
  if (!m) {
    io.log(`carve 설치 없음 — ${cmdHint('install')}로 설치하세요.`);
    return 0;
  }
  io.log(`carve 설치됨 (v${m.version}): 파일 ${m.files.length} · 훅 ${m.hooks.length} · 백업 ${m.backups.length}`);
  io.log(`스키마 v${m.schemaVersion}`);
  for (const { path } of m.files) io.log(`  · ${path}`);
  // v1/미마이그레이션(해시 빈 문자열) 매니페스트 안내 (CLAUDE.md append-merge 센티넬은 제외)
  if (isUnmigrated(m)) {
    io.log(`미마이그레이션 매니페스트 — ${cmdHint('migrate')} 권장`);
  }
  // 라이프사이클 안내: deprecated/hidden 설치분 (안내만 — exit code 영향 없음)
  printLifecycleNotices(deprecationNotices(m), io, false);
  // 설치된 셸 훅 문법 점검 (harness-audit) — v2 파일 객체에서 .path 사용
  const hookArts = m.files
    .filter((f) => f.path.endsWith('.sh') && existsSync(join(root, f.path)))
    .map((f) => ({ path: f.path, content: readFileSync(join(root, f.path), 'utf8'), executable: true }));
  const shellErrs = errorsOf(auditShellSyntax(hookArts));
  io.log(shellErrs.length ? `⚠ 훅 문법 이슈 ${shellErrs.length}건` : `훅 문법 OK (${hookArts.length}개)`);
  return shellErrs.length > 0 ? 1 : 0;
}

/** 3-way diff의 한 자산 분류 결과. */
export interface DiffEntry {
  path: string;
  status: 'unchanged' | 'carve-updated' | 'user-modified' | 'new-recommended';
  /** orig 해시가 빈 문자열(v1 미마이그레이션)이라 보수적으로 user-modified 처리됨. */
  unmigrated?: boolean;
}

/**
 * 자산별 3-way 분류 (순수 함수 — 디스크 읽기만, 쓰기 없음).
 * orig=매니페스트 해시, cur=디스크 콘텐츠 해시, next=현재 carve 자산 해시 를 비교한다.
 * 현재 추천 자산 집합(artifacts)만 분류한다 — diff/update에 충분.
 */
export function classify(root: string, m: Manifest | null, artifacts: Artifact[]): DiffEntry[] {
  // 매니페스트 항목을 경로→해시로 인덱싱 (orig)
  const origByPath = new Map<string, string>();
  if (m) for (const f of m.files) origByPath.set(f.path, f.hash);

  const entries: DiffEntry[] = [];
  for (const a of artifacts) {
    const orig = origByPath.get(a.path); // 매니페스트에 없으면 undefined
    const full = join(root, a.path);
    // 디스크에 파일이 없으면 cur=null (삭제됨) — 아래에서 carve-updated로 복원 처리
    const cur = existsSync(full) ? hashContent(readFileSync(full, 'utf8')) : null;
    const next = hashContent(a.content);

    // 규칙은 문서화된 순서대로 적용한다.
    if (orig === undefined) {
      // 매니페스트에 없는 신규 추천
      entries.push({ path: a.path, status: 'new-recommended' });
    } else if (orig === '') {
      if (a.path === ROOT_CLAUDE) {
        // append-merge 센티넬 — carve가 파일 전체를 소유하지 않음. 갱신/미마이그레이션 대상이 아니다.
        entries.push({ path: a.path, status: 'unchanged' });
      } else {
        // v1 미마이그레이션 — 설치 시점 해시 미상이므로 보수적으로 user-modified (자동 덮어쓰기 금지)
        entries.push({ path: a.path, status: 'user-modified', unmigrated: true });
      }
    } else if (cur === null) {
      // 디스크에서 삭제됨 — 갱신(복원)으로 분류한다(보수적 복원 선택)
      entries.push({ path: a.path, status: 'carve-updated' });
    } else if (cur === next) {
      entries.push({ path: a.path, status: 'unchanged' });
    } else if (cur === orig && next !== orig) {
      // 사용자는 안 건드렸고 carve 자산이 바뀜 — 안전하게 갱신 가능
      entries.push({ path: a.path, status: 'carve-updated' });
    } else {
      // cur !== orig — 사용자가 수정함 (보존)
      entries.push({ path: a.path, status: 'user-modified' });
    }
  }
  return entries;
}

/** 읽기 전용 diff 리포트 — analyze→design→generate 후 분류, 그룹 출력, 항상 exit 0. */
export function cmdDiff(root: string, io: IO): number {
  const m = readManifest(root);
  if (!m) {
    io.log(`carve 설치 없음 — ${cmdHint('install')}로 설치하세요.`);
    return 0;
  }
  const profile = analyze(root);
  const d = design(profile, m.level); // 설치 레벨 재현(미기록=auto, normalize에서 검증됨)
  const artifacts = generate(profile, d);
  const entries = classify(root, m, artifacts);

  const sections: { status: DiffEntry['status']; label: string }[] = [
    { status: 'unchanged', label: '변경 없음' },
    { status: 'carve-updated', label: 'carve 갱신 가능' },
    { status: 'user-modified', label: '사용자 수정 — 보존됨' },
    { status: 'new-recommended', label: '신규 추천' },
  ];
  for (const { status, label } of sections) {
    const group = entries.filter((e) => e.status === status);
    if (group.length === 0) continue;
    io.log(`${label} (${group.length}):`);
    for (const e of group) io.log(`  · ${e.path}`);
  }
  if (entries.some((e) => e.unmigrated)) {
    io.log(`미마이그레이션 항목 있음 — ${cmdHint('migrate')} 권장`);
  }
  io.log(`총 ${entries.length}개 자산 비교 완료.`);
  return 0;
}

/**
 * carve-updated 자산 1건을 디스크에 기록하고 갱신된 ManifestFile을 반환한다.
 * - 사용자 현재 콘텐츠를 .bak로 1회 보존(이미 .bak가 있으면 보존 안 함 — installer의 .bak-once 규칙 거울).
 * - 실행 자산이면 chmod 0o755. 해시는 기록 시점에 계산.
 * 주의: 호출 전 audit 게이트를 반드시 통과시킨다(디스크 변경은 audit 이후에만).
 */
function writeUpdatedArtifact(root: string, a: Artifact): ManifestFile {
  const full = join(root, a.path);
  mkdirSync(dirname(full), { recursive: true });
  if (existsSync(full)) backupOnce(full);
  writeFileSync(full, a.content);
  if (a.executable) chmodSync(full, 0o755);
  return { path: a.path, hash: hashContent(a.content), assetVersion: CARVE_VERSION };
}

/**
 * carve update — carve-updated 자산만 제자리 갱신, user-modified는 보존(기본), new-recommended는 제안만.
 * audit-gate-before-write + manifest-last(원자성: audit 실패 시 이전 설치·매니페스트가 그대로 유지된다).
 * opts: { yes?: 비대화형 확인, force?: user-modified 강제 덮어쓰기(.bak 1회 보존 후) }.
 */
export function cmdUpdate(root: string, io: IO, opts: { yes?: boolean; force?: boolean } = {}): number {
  const m = readManifest(root);
  if (!m) {
    io.log(`carve 설치 없음 — ${cmdHint('install')}을 먼저 실행하세요.`);
    return 0;
  }
  // 미마이그레이션 v1(해시 빈 문자열) — 보수적으로 중단(모든 파일을 user-modified로 오분류해 강제 덮어쓸 위험 회피).
  // CLAUDE.md append-merge 센티넬은 정상 v2의 합법 항목이므로 제외(init-claude 후 update 차단 방지).
  if (isUnmigrated(m)) {
    io.error(`manifest v1(미마이그레이션) — 1회 마이그레이션이 필요합니다. 먼저 ${cmdHint('migrate')}를 실행하세요.`);
    return 1;
  }

  const profile = analyze(root);
  const d = design(profile, m.level); // 설치 레벨 재현(미기록=auto, normalize에서 검증됨)
  const artifacts = generate(profile, d);
  const entries = classify(root, m, artifacts);
  const artByPath = new Map(artifacts.map((a) => [a.path, a]));

  const carveUpdated = entries.filter((e) => e.status === 'carve-updated');
  const userModified = entries.filter((e) => e.status === 'user-modified');
  const newRecommended = entries.filter((e) => e.status === 'new-recommended');

  // 기록 대상 자산 수집: carve-updated + (force일 때) user-modified.
  const toWrite: Artifact[] = [];
  for (const e of carveUpdated) {
    const a = artByPath.get(e.path);
    if (a) toWrite.push(a);
  }
  if (opts.force) {
    for (const e of userModified) {
      const a = artByPath.get(e.path);
      if (a) toWrite.push(a);
    }
  }

  // AUDIT GATE FIRST — 디스크 변경(.bak·write) 전에 검사. 차단되면 아무것도 쓰지 않고 종료.
  if (auditGate([...audit(toWrite), ...auditShellSyntax(toWrite)], io, '업데이트')) return 1;

  // audit 통과 후에만 디스크를 만진다(원자성). 갱신 파일의 매니페스트 항목을 새 해시로 교체.
  const updatedByPath = new Map<string, ManifestFile>();
  for (const a of toWrite) {
    const mf = writeUpdatedArtifact(root, a);
    updatedByPath.set(mf.path, mf);
  }

  // 설정(settings.json) 훅/MCP 재병합은 하지 않는다(의도적):
  //   install()은 manifest.files를 toWrite로 통째 덮어 미변경 항목을 잃는다 → 매니페스트 손상.
  //   훅 .sh 파일 자체는 위에서 자산으로 갱신되며, settings.json의 훅 등록은 install 시점과 동일해
  //   재병합이 불필요하다(가장 단순·안전한 선택). 신규 훅 추가는 new-recommended → `carve install` 경로.

  // 매니페스트는 완전한 기록을 유지: 기존 files를 보존하되 갱신 항목만 새 해시로 교체(manifest-last).
  const updatedFiles: ManifestFile[] = m.files.map((f) => updatedByPath.get(f.path) ?? f);
  writeManifest(root, { ...m, schemaVersion: 2, files: updatedFiles });

  // 구버전 설치 교정: settings.json의 상대경로 _carve 훅을 $CLAUDE_PROJECT_DIR 절대경로로 1회 치환.
  // (재설치 없이 `carve update`만으로 "No such file" 훅 실패가 해소된다 — gotchas 참조.)
  const fixedHooks = migrateHookPaths(root);
  if (fixedHooks > 0) io.log(`훅 경로 교정: 상대→$CLAUDE_PROJECT_DIR 절대경로 ${fixedHooks}건 (settings.json·manifest 동기화).`);

  // 삭제된 컴포넌트(tombstone) 잔여 정리: 기존 설치에 남은 fade-out 스킬/shim을 1회 제거(해시 가드).
  const orphans = removeOrphanedComponents(root);
  if (orphans.removed.length > 0) io.log(`삭제된 컴포넌트 잔여 정리: ${orphans.removed.length}건 제거 (${orphans.removed.join(', ')}).`);
  for (const p of orphans.preserved) io.log(`삭제된 컴포넌트지만 사용자 수정분 보존: ${p} (수동 삭제 가능).`);

  // new-recommended: 절대 자동 설치하지 않고 제안만.
  for (const e of newRecommended) {
    io.log(`신규 추천: ${e.path} — ${cmdHint('install')}로 추가할 수 있습니다.`);
  }
  // user-modified: 기본 보존, 건너뜀 안내(+ --force 힌트). force면 위에서 덮어썼으므로 안내 문구를 달리한다.
  for (const e of userModified) {
    if (opts.force) io.log(`사용자 수정 강제 덮어씀(원본 .bak 보존): ${e.path}`);
    else io.log(`사용자 수정 보존(건너뜀): ${e.path} — 덮어쓰려면 --force`);
  }

  io.log(`업데이트 완료: 갱신 ${carveUpdated.length} · 보존(사용자수정) ${opts.force ? 0 : userModified.length} · 신규 제안 ${newRecommended.length}`);

  // M12 closed loop: 로컬 텔레메트리 기반 제안 표면화(제안만 — 위 write 경로는 metrics와 무관하게 불변).
  // metrics opt-out(기본)이면 aggregateMetrics가 null → 제안 없음 → 기존 동작과 100% 동일.
  printSuggestions(applyMetricsWeights(aggregateMetrics(root, m)), io);

  // deprecated 설치분은 generate()에서 자연 탈락해 갱신 대상이 아니다 — 암묵 동결을 사용자에게 명시한다.
  printLifecycleNotices(deprecationNotices(m), io, true);
  return 0;
}

/**
 * carve migrate — v1 매니페스트를 v2로 승급(파일별 해시 back-fill). migrateManifest에 위임.
 * 한계: 설치 시점 원본 해시는 복구 불가 → 현재 디스크 콘텐츠 기준으로 채운다.
 * 멱등: 이미 v2면 재기록 없이 no-op.
 */
export function cmdMigrate(root: string, io: IO): number {
  const r = migrateManifest(root);
  if (r.from === 0) {
    io.log(`carve 설치 없음 — ${cmdHint('install')}을 먼저 실행하세요.`);
    return 0;
  }
  if (!r.migrated) {
    io.log('이미 최신 스키마 (v2) — 변경 없음.');
    return 0;
  }
  io.log(`마이그레이션 완료: v${r.from} → v2, 파일 ${r.filled}개 해시 채움.`);
  io.log('한계: 설치 시점 원본 해시는 복구 불가 — 현재 디스크 콘텐츠 기준으로 채웠습니다.');
  io.log('따라서 migrate 직후 첫 diff는 carve 갱신분만 반영됩니다(이미 수정된 파일은 그 상태가 기준선).');
  return 0;
}

/**
 * carve report — 설치 훅의 로컬 효과 텔레메트리(.claude/.carve-metrics.jsonl)를 집계한다.
 * 집계는 metrics.aggregateMetrics에 위임(designer·update와 단일 출처 공유).
 * 훅별 발화(total)·차단(event==='block') 수와, 매니페스트 기준 0회 발화 훅(노이즈 후보)을 보고하고,
 * M12: 0-fire 훅을 "제외 고려" 제안으로 표면화한다(제안만 — 추천/자산을 강제로 바꾸지 않음).
 * opt-in 기록이 없으면 graceful degrade(메시지 + return 0).
 */
export function cmdReport(root: string, io: IO): number {
  // 메트릭 파일이 없으면 매니페스트를 읽지 않는다(손상 manifest로 인한 throw 회피 — 기존 동작 보존).
  const manifest = existsSync(join(root, METRICS_REL)) ? readManifest(root) : null;
  const agg = aggregateMetrics(root, manifest);
  if (agg === null) {
    io.log('텔레메트리 기록 없음 (opt-in: CARVE_METRICS=on 또는 .claude/.carve-metrics.enabled 파일).');
    return 0;
  }

  io.log('carve 로컬 효과 텔레메트리 (opt-in):');
  for (const [hook, { total, blocks }] of agg.perHook) {
    io.log(`  · ${hook}: 발화 ${total} · 차단 ${blocks}`);
  }

  // 0회 발화 훅: 계측된(carve_metric 호출) 훅 중 메트릭에 한 번도 안 나온 id만 노이즈 후보로 본다.
  // slack-notify·codesight-refresh는 의도적으로 비계측이라 구조상 0회 → aggregateMetrics가 제외함.
  if (manifest) {
    io.log(`발화 0회 훅(노이즈 후보): ${agg.zeroFire.length ? agg.zeroFire.join(', ') : '없음'}`);
  } else {
    io.log('발화 0회 훅: 매니페스트 없음 — 0-fire 판정 생략.');
  }

  io.log(`합계: 발화 ${agg.totalFires} · 차단 ${agg.totalBlocks} (유효 ${agg.totalFires}줄, 훅 ${agg.perHook.size}종)`);

  // M12 closed loop: 측정 → 제안. 0-fire 훅을 "다음 설치에서 제외 고려" 제안으로 표면화(강제 변경 없음).
  printSuggestions(applyMetricsWeights(agg), io);
  return 0;
}

/** 클린 제거 */
export function cmdUninstall(root: string, io: IO): number {
  const r = uninstall(root);
  io.log(`제거 완료: 파일 ${r.removed.length} · 복원 ${r.restored.length}`);
  return 0;
}
