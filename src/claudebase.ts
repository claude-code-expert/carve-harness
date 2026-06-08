// src/claudebase.ts — CLAUDE.md 베이스라인 + .claude/rules/* 스택별 생성 (레이어 A).
// `carve init-claude` / harness-architect 스킬의 셋업 단계가 쓴다.
// 스택 무관 베이스라인(.claude/CLAUDE.md) + 탐지 언어의 rules 번들을 깎아낸다.
import type { ProjectProfile } from './types.ts';
import { render, readAsset, type Artifact } from './generator.ts';

// assets/claude-base/ 기준 자산을 generator의 readAsset(assets/ 기준)으로 읽는다.
const read = (rel: string): string => readAsset(`claude-base/${rel}`);

// .claude/rules/ 를 채우는 스택별(언어 의존) 규칙 6개
const RULE_FILES = ['techstack', 'project-structure', 'commands', 'code-style', 'safety', 'gotchas'] as const;

// 스택 무관 공용 규칙 — 모든 언어 동일(단일 소스 assets/claude-base/rules/<name>.md). 시각·문서 산출물 anti-slop.
const SHARED_RULES = ['anti-ai-slop'] as const;

// 다중 언어일 때 대표 스택 우선순위 (js는 typescript 번들로 매핑)
const STACK_PRIORITY = ['typescript', 'python', 'go', 'rust', 'java', 'dart'] as const;

/** 프로필의 언어로 rules 번들을 고른다. 미탐지/기타는 _default. */
export function selectStack(p: ProjectProfile): string {
  for (const s of STACK_PRIORITY) if (p.languages.includes(s)) return s;
  if (p.languages.includes('javascript')) return 'typescript';
  return '_default';
}

// 스택별 명령/패키지매니저 기본값 (profile에 명령이 없을 때 fallback)
interface StackDefault { pkg: string; test: string; lint: string; format: string }
const DEFAULT_CMDS: StackDefault = { pkg: '<package-manager>', test: '<test command>', lint: '<lint command>', format: '<format command>' };
const STACK_DEFAULTS: Record<string, StackDefault> = {
  typescript: { pkg: 'npm', test: 'npm test', lint: 'npm run lint', format: 'npm run format' },
  python: { pkg: 'pip', test: 'pytest', lint: 'ruff check', format: 'ruff format' },
  go: { pkg: 'go', test: 'go test ./...', lint: 'golangci-lint run', format: 'gofmt -w .' },
  rust: { pkg: 'cargo', test: 'cargo test', lint: 'cargo clippy --all-targets -- -D warnings', format: 'cargo fmt' },
  java: { pkg: './gradlew', test: './gradlew test', lint: './gradlew check', format: './gradlew spotlessApply' },
  dart: { pkg: 'flutter', test: 'flutter test', lint: 'flutter analyze', format: 'dart format .' },
};

function varsFor(p: ProjectProfile, stack: string): Record<string, string> {
  const d = STACK_DEFAULTS[stack] ?? DEFAULT_CMDS;
  return {
    PROJECT_TYPE: p.type,
    PKG_MANAGER: p.packageManager ?? d.pkg,
    TEST_CMD: p.testCmd ?? d.test,
    LINT_CMD: p.lintCmd ?? d.lint,
    FORMAT_CMD: p.formatCmd ?? d.format,
  };
}

/** 베이스라인 CLAUDE.md(.claude/) + 스택별 rules 산출물. installer가 쓴다. */
export function generateClaudeBase(p: ProjectProfile): Artifact[] {
  const stack = selectStack(p);
  const vars = varsFor(p, stack);
  const arts: Artifact[] = [
    { path: '.claude/CLAUDE.md', content: read('CLAUDE.md'), executable: false },
  ];
  for (const f of RULE_FILES) {
    arts.push({ path: `.claude/rules/${f}.md`, content: render(read(`rules/${stack}/${f}.md`), vars), executable: false });
  }
  // 스택 무관 공용 규칙 — stack 디렉토리 없이 단일 소스에서 읽는다(변수 없음).
  for (const f of SHARED_RULES) {
    arts.push({ path: `.claude/rules/${f}.md`, content: read(`rules/${f}.md`), executable: false });
  }
  return arts;
}

// 루트 CLAUDE.md가 베이스라인+rules를 @import하도록 붙이는 블록 (멱등 마커)
export const ROOT_IMPORT_MARKER = '<!-- carve:claude-base -->';
export const ROOT_IMPORT_BLOCK = `
${ROOT_IMPORT_MARKER}
## 작업 지침 (베이스라인 + 스택 규칙)
> carve가 연결. 베이스라인·스택 규칙은 \`.claude/\` 아래 파일을 수정해 조정한다.
@.claude/CLAUDE.md
${[...RULE_FILES, ...SHARED_RULES].map((f) => `@.claude/rules/${f}.md`).join('\n')}
`;
