// src/catalog.ts — 설치 가능한 하네스 구성요소 레지스트리 (레이어 A, M2).
// designer가 ProjectProfile에 맞춰 추천할 때 참조한다. 점수 ≥75만 등재한다.
import type { ProjectType } from './types.ts';

export type ComponentKind = 'skill' | 'hook' | 'agent' | 'pack';

/**
 * 라이프사이클 상태 (단계적 fade-out):
 * - active(생략): 정상 — 추천·목록·설치 모두 가능
 * - deprecated: 추천 제외·목록에 [비추천] 표시·명시 선택 시 설치 가능·update는 갱신 동결
 * - hidden: 목록·wizard에서 제외 — 기존 설치의 manifest 기반 uninstall만 동작
 * 케이던스: active → deprecated(≥1 minor) → hidden(≥1 minor) → 카탈로그·자산 삭제
 */
export type ComponentStatus = 'active' | 'deprecated' | 'hidden';

export interface CatalogComponent {
  /** 고유 id (설치 경로/매니페스트 키) */
  id: string;
  kind: ComponentKind;
  title: string;
  description: string;
  /** 활용도·완성도 점수 (등재 기준 ≥75) */
  score: number;
  /** 필수 구성요소 여부 */
  core: boolean;
  /** 선택 구성요소 여부 (기본 미추천, 예: 자동 커밋) */
  optional: boolean;
  /** 추천 대상 프로젝트 타입. 'all' = 타입 무관 */
  applicable: ProjectType[] | 'all';
  /** 훅 이벤트 (kind==='hook') */
  event?: string;
  /** settings.json 훅 matcher (kind==='hook', Stop/PreCompact는 불필요) — generator의 단일 출처 */
  matcher?: string;
  /** 라이프사이클 상태. 생략 = 'active' */
  status?: ComponentStatus;
  /** deprecated/hidden일 때 안내할 대체 컴포넌트 id */
  replacedBy?: string;
  /** monorepo/CI 시그널 가중 대상 — designer의 단일 출처 */
  coordination?: boolean;
}

/** 라이프사이클 상태 (생략 = active). */
export function statusOf(c: CatalogComponent): ComponentStatus {
  return c.status ?? 'active';
}

export const CATALOG: CatalogComponent[] = [
  // ── 진입 스킬 (자연어 트리거, M7) ──
  { id: 'harness-architect', kind: 'skill', title: '하네스 아키텍트', description: '자연어 "하네스 구성해줘" 트리거 — 분석·추천·선택 설치 안내', score: 90, core: true, optional: false, applicable: 'all' },

  // ── 토큰 효율 기본 탑재 (codesight + LSP, core) ──
  { id: 'codesight', kind: 'skill', title: 'codesight 컨텍스트', description: '프로젝트 구조 맵 MCP — 탐색 토큰 ~11배 절약(grep 대체)', score: 92, core: true, optional: false, applicable: 'all' },
  { id: 'lsp', kind: 'skill', title: 'LSP 인텔리전스', description: '정확한 코드 네비게이션 MCP — findReferences/getDiagnostics(grep 대체)', score: 90, core: true, optional: false, applicable: 'all' },

  // ── 핵심 스킬 (Skill + 커맨드 shim) ──
  { id: 'handoff', kind: 'skill', title: '핸드오프', description: '세션 인계 컨텍스트(PreCompact 훅 연동)', score: 90, core: true, optional: false, applicable: 'all' },
  { id: 'commit', kind: 'skill', title: '커밋', description: 'Conventional Commit 메시지 생성(빠른 인라인) — 깊은 git 작업은 squad-gitops', score: 90, core: true, optional: false, applicable: 'all' },

  // ── 7 필수 훅 (matcher는 settings.json 등록의 단일 출처 — generator가 참조) ──
  { id: 'block-destructive', kind: 'hook', event: 'PreToolUse', matcher: 'Bash', title: '파괴적 명령 차단', description: 'rm -rf 등 위험 명령 exit 2 차단', score: 95, core: true, optional: false, applicable: 'all' },
  { id: 'protect-secrets', kind: 'hook', event: 'PreToolUse', matcher: 'Read|Edit|Write', title: '비밀파일 보호', description: '.env·키 파일 읽기·수정 차단', score: 95, core: true, optional: false, applicable: 'all' },
  { id: 'pre-commit-lint', kind: 'hook', event: 'PreToolUse', matcher: 'Bash', title: '커밋 전 린트', description: 'git commit 전 린터 실행', score: 85, core: true, optional: false, applicable: 'all' },
  { id: 'pre-push-test', kind: 'hook', event: 'PreToolUse', matcher: 'Bash', title: '푸시 전 테스트', description: 'git push 전 테스트 실행', score: 85, core: true, optional: false, applicable: 'all' },
  { id: 'auto-format', kind: 'hook', event: 'PostToolUse', matcher: 'Edit|Write', title: '자동 포맷', description: 'Edit/Write 후 포매터 실행', score: 80, core: true, optional: false, applicable: 'all' },
  { id: 'slack-notify', kind: 'hook', event: 'Stop', title: 'Slack 알림', description: '세션 종료 시 Slack 웹훅 알림', score: 75, core: true, optional: false, applicable: 'all' },
  { id: 'precompact-handoff', kind: 'hook', event: 'PreCompact', title: 'PreCompact 핸드오프', description: '압축 직전 상태 영속화', score: 85, core: true, optional: false, applicable: 'all' },

  // ── 1 선택 훅 ──
  { id: 'auto-commit', kind: 'hook', event: 'Stop', title: '자동 커밋', description: '세션 종료 시 자동 커밋(기본 OFF)', score: 75, core: false, optional: true, applicable: 'all' },

  // ── Squad 서브에이전트 8종 (100% 보존) ──
  { id: 'squad-review', kind: 'agent', title: 'Squad 리뷰', description: '보안·성능·스타일 코드 리뷰', score: 90, core: true, optional: false, applicable: 'all' },
  { id: 'squad-plan', kind: 'agent', title: 'Squad 플랜', description: '기능 기획·유저스토리·와이어프레임', score: 85, core: true, optional: false, applicable: 'all' },
  { id: 'squad-refactor', kind: 'agent', title: 'Squad 리팩터', description: '추출·단순화·이름변경·제거', score: 85, core: true, optional: false, applicable: 'all' },
  { id: 'squad-qa', kind: 'agent', title: 'Squad QA', description: '테스트 실행·QA 리포트', score: 85, core: true, optional: false, applicable: 'all' },
  { id: 'squad-debug', kind: 'agent', title: 'Squad 디버그', description: '에러 분석·근본 원인', score: 85, core: true, optional: false, applicable: 'all' },
  { id: 'squad-docs', kind: 'agent', title: 'Squad 문서', description: '문서 생성·갱신', score: 80, core: true, optional: false, applicable: 'all' },
  { id: 'squad-gitops', kind: 'agent', title: 'Squad GitOps', description: '커밋 메시지·PR·체인지로그', score: 80, core: true, optional: false, applicable: 'all' },
  { id: 'squad-audit', kind: 'agent', title: 'Squad 감사', description: '보안 감사·취약점 스캔', score: 85, core: true, optional: false, applicable: 'all' },
  { id: 'squad-evaluator', kind: 'agent', title: 'Squad 평가자', description: '완료 기준·Sprint Contract 대비 독립 평가 (Self-Eval Blindspot 대응)', score: 88, core: true, optional: false, applicable: 'all' },

  // ── 추가 컴포넌트 (≥75) ──
  { id: 'anti-ai-slop', kind: 'pack', title: 'Anti-AI-Slop 팩', description: 'HTML·SVG·문서 슬롭 제거 스킬 + check-slop 검증 훅', score: 85, core: false, optional: false, applicable: 'all' },
  { id: 'iterate', kind: 'skill', title: '자율 수렴 루프', description: 'green까지 진단→수정→재실행, 최종만 보고(최대 N회)', score: 85, core: false, optional: false, applicable: 'all' },
  { id: 'test-gen', kind: 'skill', title: '테스트 생성', description: 'UAT 기준 테스트 생성', score: 76, core: false, optional: false, applicable: 'all' },

  // ── 외부 큐레이션 도입 (mattpocock/skills, MIT — 출처 표기) ──
  { id: 'tdd', kind: 'skill', title: 'TDD', description: 'red-green-refactor 테스트 우선 개발 (mattpocock/skills MIT)', score: 88, core: false, optional: false, applicable: 'all' },
  { id: 'caveman', kind: 'skill', title: '초압축 모드', description: '토큰 ~75% 절감 압축 커뮤니케이션 (mattpocock/skills MIT)', score: 80, core: false, optional: false, applicable: 'all' },
  { id: 'write-a-skill', kind: 'skill', title: '스킬 작성', description: '재사용 스킬 SKILL.md 스캐폴딩 (mattpocock/skills MIT)', score: 78, core: false, optional: false, applicable: 'all' },
  { id: 'zoom-out', kind: 'skill', title: '시스템 조망', description: '시스템 수준 시야로 모듈·호출 매핑 (mattpocock/skills MIT)', score: 76, core: false, optional: false, applicable: 'all' },

  // ── post-PoC (멀티에이전트·튜닝·라우팅) ──
  { id: 'model-route', kind: 'skill', title: '모델 라우팅', description: '작업→Haiku/Sonnet/Opus 3-Tier 라우팅(비용 최적화)', score: 85, core: false, optional: false, applicable: 'all' },
  { id: 'parallel-agents', kind: 'skill', title: '멀티에이전트 병렬', description: '최소 병렬화 3~4 에이전트 + git worktree 격리', score: 80, core: false, optional: false, applicable: 'all', coordination: true },
  { id: 'workflow', kind: 'skill', title: '절차적 완수 워크플로', description: 'Fablize식 장기 실행 작업 규율 — 목표→분해→완료기준→가정→실행→자체검증→리스크 7단계 + 최소 출력형식·완료 게이트·에스컬레이션. iterate/sprint-contract/evaluation-criteria를 지휘.', score: 85, core: false, optional: false, applicable: 'all' },
  { id: 'evaluator-tuning', kind: 'skill', title: 'Evaluator 튜닝', description: '평가자 오판 수집→few-shot 보정 루프 (squad-evaluator 운영자용 — 필요 시 직접 선택)', score: 76, core: false, optional: true, applicable: 'all' },

  // ── post-PoC (고도화) ──
  { id: 'harness-audit', kind: 'skill', title: '하네스 감사', description: '설치된 하네스 자기 점검(doctor+훅 등록·문법·자산 정합)', score: 78, core: false, optional: false, applicable: 'all' },
];

/** 컴포넌트가 주어진 프로젝트 타입에 적합한지 */
export function applicableTo(c: CatalogComponent, type: ProjectType): boolean {
  return c.applicable === 'all' || c.applicable.includes(type);
}

/** 주어진 타입에 적합한 컴포넌트 목록 */
export function forType(type: ProjectType): CatalogComponent[] {
  return CATALOG.filter((c) => applicableTo(c, type));
}

/** id로 조회 */
export function byId(id: string): CatalogComponent | undefined {
  return CATALOG.find((c) => c.id === id);
}
