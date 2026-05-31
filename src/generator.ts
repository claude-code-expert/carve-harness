// src/generator.ts — 설계(HarnessDesign) + 프로필 → 깎인 자산 생성 (레이어 A, M3·M4·M5).
// assets/ 원목 템플릿을 읽어 변수 치환. 파일은 쓰지 않는다(installer가 쓴다).
import { readFileSync, existsSync } from 'node:fs';
import type { ProjectProfile } from './types.ts';
import type { HarnessDesign } from './designer.ts';
import { byId } from './catalog.ts';

export interface Artifact {
  /** 대상 프로젝트 기준 상대 경로 */
  path: string;
  content: string;
  /** 실행 권한 필요 여부 (훅 스크립트) */
  executable: boolean;
}

const ASSETS = new URL('../assets/', import.meta.url);
function readAsset(rel: string): string {
  return readFileSync(new URL(rel, ASSETS), 'utf8');
}
function assetExists(rel: string): boolean {
  return existsSync(new URL(rel, ASSETS));
}

// 훅 id → matcher (Stop/PreCompact는 matcher 불필요)
const HOOK_MATCHER: Record<string, string> = {
  'block-destructive': 'Bash',
  'protect-secrets': 'Read|Edit|Write',
  'pre-commit-lint': 'Bash',
  'pre-push-test': 'Bash',
  'auto-format': 'Edit|Write',
};

// anti-slop 팩: assets/antislop → 대상 .claude/skills (대상 레이아웃 그대로)
const ANTI_SLOP_PACK: [string, string][] = [
  ['antislop/SKILL.md', '.claude/skills/SKILL.md'],
  ['antislop/svg-image.md', '.claude/skills/svg-image.md'],
  ['antislop/card-news.md', '.claude/skills/card-news.md'],
  ['antislop/html-report.md', '.claude/skills/html-report.md'],
  ['antislop/html-presentation.md', '.claude/skills/html-presentation.md'],
  ['antislop/clean-html/SKILL.md', '.claude/skills/clean-html/SKILL.md'],
  ['antislop/clean-html/scripts/check-slop.mjs', '.claude/skills/clean-html/scripts/check-slop.mjs'],
];

/** 추천 설계에 대응하는 settings.json 훅 등록 목록 */
export function hookRegsFor(design: HarnessDesign): { event: string; command: string; matcher?: string }[] {
  const regs: { event: string; command: string; matcher?: string }[] = [];
  for (const id of design.recommended) {
    const c = byId(id);
    if (c?.kind === 'hook' && HOOK_ASSETS[id]) {
      regs.push({ event: c.event ?? 'PreToolUse', command: `bash .claude/hooks/carve-${id}.sh`, matcher: HOOK_MATCHER[id] ?? '' });
    }
  }
  if (design.recommended.includes('anti-ai-slop')) {
    regs.push({ event: 'PostToolUse', command: 'bash .claude/hooks/carve-anti-slop.sh', matcher: 'Write|Edit' });
  }
  // Squad 라우터(키워드 위임) + 체이닝(알림): 에이전트 추천 시
  if (design.recommended.some((id) => byId(id)?.kind === 'agent')) {
    regs.push({ event: 'UserPromptSubmit', command: 'bash .claude/hooks/squad-router.sh' });
    regs.push({ event: 'SubagentStart', command: 'bash .claude/hooks/subagent-chain.sh' });
    regs.push({ event: 'SubagentStop', command: 'bash .claude/hooks/subagent-chain.sh' });
  }
  return regs;
}

/** {{KEY}} → vars[KEY] 치환. 미정의 키는 빈 문자열. */
export function render(tmpl: string, vars: Record<string, string>): string {
  return tmpl.replace(/\{\{(\w+)\}\}/g, (_, k: string) => vars[k] ?? '');
}

// 훅 id → assets 스크립트 경로 (결정적 차단/경고 훅)
const HOOK_ASSETS: Record<string, string> = {
  'block-destructive': 'hooks/block-destructive.sh',
  'protect-secrets': 'hooks/protect-secrets.sh',
  'pre-commit-lint': 'hooks/pre-commit-lint.sh',
  'pre-push-test': 'hooks/pre-push-test.sh',
  'auto-format': 'hooks/auto-format.sh',
  'slack-notify': 'hooks/slack-notify.sh',
  'precompact-handoff': 'hooks/precompact-handoff.sh',
};

/** 설계+프로필로부터 생성 산출물 목록을 만든다. */
export function generate(profile: ProjectProfile, design: HarnessDesign): Artifact[] {
  const artifacts: Artifact[] = [];
  const antiSlop = design.recommended.includes('anti-ai-slop');

  const vars: Record<string, string> = {
    PROJECT_TYPE: profile.type,
    TEST_CMD: profile.testCmd ?? 'npm test',
    LINT_CMD: profile.lintCmd ?? '(린터 미탐지)',
    LANG_RULES: profile.languages.includes('typescript')
      ? '- `any` 타입 금지 — 명시적 타입을 쓴다.'
      : '',
    ANTI_SLOP_SECTION: antiSlop ? readAsset('templates/_flight-rules-antislop.md') : '',
    ANTI_SLOP_EVAL: antiSlop ? '- [ ] 생성 HTML/SVG/문서 `check-slop` 0 ERROR' : '',
    // 훅 템플릿용 (미탐지 시 빈 문자열 → 훅이 스킵)
    HOOK_LINT_CMD: profile.lintCmd ?? '',
    HOOK_TEST_CMD: profile.testCmd ?? 'npm test',
    HOOK_FORMAT_CMD: profile.formatCmd ?? '',
    COMPONENT_LIST: design.recommended
      .map((id) => { const c = byId(id); return `- ${c?.title ?? id} (\`${id}\`)`; })
      .join('\n'),
  };

  // M4/M5 문서
  artifacts.push({
    path: 'flight-rules.md',
    content: render(readAsset('templates/flight-rules.md'), vars),
    executable: false,
  });
  artifacts.push({
    path: 'evaluation-criteria.md',
    content: render(readAsset('templates/evaluation-criteria.md'), vars),
    executable: false,
  });
  artifacts.push({
    path: 'sprint-contract.md',
    content: render(readAsset('templates/sprint-contract.md'), vars),
    executable: false,
  });
  artifacts.push({
    path: 'CLAUDE.md',
    content: render(readAsset('templates/target-CLAUDE.md'), vars),
    executable: false,
  });
  artifacts.push({
    path: 'HARNESS-GUIDE.md',
    content: render(readAsset('templates/HARNESS-GUIDE.md'), vars),
    executable: false,
  });

  // 추천된 훅 중 자산이 있는 것 → 훅 스크립트 생성 (템플릿 변수 치환)
  for (const id of design.recommended) {
    const asset = HOOK_ASSETS[id];
    if (asset) {
      artifacts.push({
        path: `.claude/hooks/carve-${id}.sh`,
        content: render(readAsset(asset), vars),
        executable: true,
      });
    }
  }

  // anti-slop: 경고 훅 + 스킬 패밀리 vendoring (check-slop.mjs 포함)
  if (antiSlop) {
    artifacts.push({
      path: '.claude/hooks/carve-anti-slop.sh',
      content: readAsset('hooks/anti-slop.sh'),
      executable: true,
    });
    for (const [src, dst] of ANTI_SLOP_PACK) {
      artifacts.push({ path: dst, content: readAsset(src), executable: src.endsWith('.mjs') });
    }
  }

  // 스킬 자산(+커맨드 shim) + Squad 에이전트(+커맨드) — 추천된 것만
  for (const id of design.recommended) {
    const c = byId(id);
    if (c?.kind === 'skill' && assetExists(`skills/${id}/SKILL.md`)) {
      artifacts.push({ path: `.claude/skills/${id}/SKILL.md`, content: readAsset(`skills/${id}/SKILL.md`), executable: false });
      if (assetExists(`commands/carve-${id}.md`)) {
        artifacts.push({ path: `.claude/commands/carve-${id}.md`, content: readAsset(`commands/carve-${id}.md`), executable: false });
      }
    } else if (c?.kind === 'agent' && assetExists(`squad/agents/${id}.md`)) {
      artifacts.push({ path: `.claude/agents/${id}.md`, content: readAsset(`squad/agents/${id}.md`), executable: false });
      if (assetExists(`squad/commands/${id}.md`)) {
        artifacts.push({ path: `.claude/commands/${id}.md`, content: readAsset(`squad/commands/${id}.md`), executable: false });
      }
    }
  }

  // Squad 보존: 에이전트가 하나라도 추천되면 라우터/체이닝 훅 + 디스패처 커맨드 (assets/squad에 녹여둠)
  if (design.recommended.some((id) => byId(id)?.kind === 'agent')) {
    if (assetExists('squad/commands/squad.md')) {
      artifacts.push({ path: '.claude/commands/squad.md', content: readAsset('squad/commands/squad.md'), executable: false });
    }
    for (const h of ['squad-router.sh', 'subagent-chain.sh']) {
      if (assetExists(`squad/hooks/${h}`)) {
        artifacts.push({ path: `.claude/hooks/${h}`, content: readAsset(`squad/hooks/${h}`), executable: true });
      }
    }
  }

  return artifacts;
}
