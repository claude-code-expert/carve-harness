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

// 프로젝트 타입 오버레이 — 언어가 아니라 p.type(웹/cli/모바일…)로 고르는 타입별 아키텍처 관심사.
// assets/claude-base/types/<type>.md → .claude/rules/project-type.md (언어 축과 직교).
const TYPE_OVERLAY = 'project-type';
const TYPE_OVERLAYS = ['cli', 'web', 'mobile', 'desktop', 'batch', 'library'] as const;

// 다중 언어일 때 대표 스택 우선순위 (js는 typescript 번들로 매핑)
const STACK_PRIORITY = ['typescript', 'python', 'go', 'rust', 'java', 'dart'] as const;

/** 프로필의 언어로 rules 번들을 고른다. 미탐지/기타는 _default. */
export function selectStack(p: ProjectProfile): string {
  for (const s of STACK_PRIORITY) if (p.languages.includes(s)) return s;
  if (p.languages.includes('javascript')) return 'typescript';
  return '_default';
}

/** 프로필 타입으로 오버레이 파일을 고른다. 미매핑/unknown은 _default. */
export function selectTypeOverlay(p: ProjectProfile): string {
  return (TYPE_OVERLAYS as readonly string[]).includes(p.type) ? p.type : '_default';
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

/** 응답 언어 정책 프리셋 — 베이스라인 {{RESPONSE_POLICY}} 치환. 기본 en-ko(기존 동작 유지). */
export type ResponseLang = 'en-ko' | 'en' | 'ko';
export const RESPONSE_LANGS: readonly ResponseLang[] = ['en-ko', 'en', 'ko'];
const POLICY_TABLE_HEAD = `| Target | Language |
|--------|----------|
| Internal reasoning & planning | English |
| Code, variable names, comments, logs, error messages | English |
| Git commit messages | English (Conventional Commits) |`;
const POLICY_PRESETS: Record<ResponseLang, string> = {
  'en-ko': `${POLICY_TABLE_HEAD}
| User-facing response (explanation · summary · question) | English summary → Korean conclusion |

**Response format (always):**
- Write the working summary / explanation in **English first**.
- Then state the **final conclusion in Korean** (한글로 최종 결론).
- Order is fixed: **English summary → Korean conclusion**, each exactly once (see R2).

**On task completion**, the Korean conclusion covers, in one block, once: what changed / why / caveats.`,
  en: `${POLICY_TABLE_HEAD}
| User-facing response | English |

**On task completion**, the summary covers, in one block, once: what changed / why / caveats.`,
  ko: `${POLICY_TABLE_HEAD}
| User-facing response (설명 · 요약 · 질문) | 한국어 |

**작업 완료 시** 응답은 한 블록에 한 번만: 무엇을 변경했는지 / 왜 그렇게 했는지 / 주의할 점.`,
};

/** 베이스라인 CLAUDE.md(.claude/) + 스택별 rules 산출물. installer가 쓴다. */
export function generateClaudeBase(p: ProjectProfile, opts: { lang?: ResponseLang } = {}): Artifact[] {
  const stack = selectStack(p);
  const vars = varsFor(p, stack);
  const arts: Artifact[] = [
    // 베이스라인도 render — {{RESPONSE_POLICY}} 치환 (그 외 변수 없음, 미정의 키는 무해)
    { path: '.claude/CLAUDE.md', content: render(read('CLAUDE.md'), { ...vars, RESPONSE_POLICY: POLICY_PRESETS[opts.lang ?? 'en-ko'] }), executable: false },
  ];
  for (const f of RULE_FILES) {
    arts.push({ path: `.claude/rules/${f}.md`, content: render(read(`rules/${stack}/${f}.md`), vars), executable: false });
  }
  // 프로젝트 타입 오버레이 — 언어 축과 직교(p.type로 선택). render는 변수 없으면 무해.
  const overlay = selectTypeOverlay(p);
  arts.push({ path: `.claude/rules/${TYPE_OVERLAY}.md`, content: render(read(`types/${overlay}.md`), vars), executable: false });
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
${[...RULE_FILES, TYPE_OVERLAY, ...SHARED_RULES].map((f) => `@.claude/rules/${f}.md`).join('\n')}
`;
