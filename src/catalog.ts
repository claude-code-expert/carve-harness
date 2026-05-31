// src/catalog.ts — 설치 가능한 하네스 구성요소 레지스트리 (레이어 A, M2).
// designer가 ProjectProfile에 맞춰 추천할 때 참조한다. 점수 ≥75만 등재한다.
import type { ProjectType } from './types.ts';

export type ComponentKind = 'skill' | 'hook' | 'agent' | 'pack';

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
}

export const CATALOG: CatalogComponent[] = [
  // ── 진입 스킬 (자연어 트리거, M7) ──
  { id: 'harness-architect', kind: 'skill', title: '하네스 아키텍트', description: '자연어 "하네스 구성해줘" 트리거 — 분석·추천·선택 설치 안내', score: 90, core: true, optional: false, applicable: 'all' },

  // ── 6 핵심 스킬 (Skill + 커맨드 shim) ──
  { id: 'handoff', kind: 'skill', title: '핸드오프', description: '세션 인계 컨텍스트(PreCompact/SessionStart 연동)', score: 90, core: true, optional: false, applicable: 'all' },
  { id: 'memory', kind: 'skill', title: '메모리', description: '프로젝트 지속 메모리', score: 90, core: true, optional: false, applicable: 'all' },
  { id: 'commit', kind: 'skill', title: '커밋', description: 'Conventional Commit 메시지 생성', score: 90, core: true, optional: false, applicable: 'all' },
  { id: 'changelog', kind: 'skill', title: '체인지로그', description: 'CHANGELOG 생성·갱신', score: 85, core: true, optional: false, applicable: 'all' },
  { id: 'review', kind: 'skill', title: '리뷰', description: '코드 리뷰(squad-review 위임)', score: 90, core: true, optional: false, applicable: 'all' },
  { id: 'pr', kind: 'skill', title: 'PR', description: 'PR 본문 생성·생성', score: 85, core: true, optional: false, applicable: 'all' },

  // ── 7 필수 훅 ──
  { id: 'block-destructive', kind: 'hook', event: 'PreToolUse', title: '파괴적 명령 차단', description: 'rm -rf 등 위험 명령 exit 2 차단', score: 95, core: true, optional: false, applicable: 'all' },
  { id: 'protect-secrets', kind: 'hook', event: 'PreToolUse', title: '비밀파일 보호', description: '.env·키 파일 읽기·수정 차단', score: 95, core: true, optional: false, applicable: 'all' },
  { id: 'pre-commit-lint', kind: 'hook', event: 'PreToolUse', title: '커밋 전 린트', description: 'git commit 전 린터 실행', score: 85, core: true, optional: false, applicable: 'all' },
  { id: 'pre-push-test', kind: 'hook', event: 'PreToolUse', title: '푸시 전 테스트', description: 'git push 전 테스트 실행', score: 85, core: true, optional: false, applicable: 'all' },
  { id: 'auto-format', kind: 'hook', event: 'PostToolUse', title: '자동 포맷', description: 'Edit/Write 후 포매터 실행', score: 80, core: true, optional: false, applicable: 'all' },
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

  // ── 추가 컴포넌트 (≥75) ──
  { id: 'anti-ai-slop', kind: 'pack', title: 'Anti-AI-Slop 팩', description: 'HTML·SVG·문서 슬롭 제거 스킬 + check-slop 검증 훅', score: 85, core: false, optional: false, applicable: 'all' },
  { id: 'verify', kind: 'skill', title: '검증 루프', description: 'build→lint→test→typecheck 루프', score: 90, core: false, optional: false, applicable: 'all' },
  { id: 'security-scan', kind: 'skill', title: '보안 스캔', description: 'squad-audit 위임 보안 게이트', score: 80, core: false, optional: false, applicable: 'all' },
  { id: 'test-gen', kind: 'skill', title: '테스트 생성', description: 'UAT 기준 테스트 생성', score: 76, core: false, optional: false, applicable: 'all' },

  // ── 외부 큐레이션 도입 (mattpocock/skills, MIT — 출처 표기) ──
  { id: 'tdd', kind: 'skill', title: 'TDD', description: 'red-green-refactor 테스트 우선 개발 (mattpocock/skills MIT)', score: 88, core: false, optional: false, applicable: 'all' },
  { id: 'caveman', kind: 'skill', title: '초압축 모드', description: '토큰 ~75% 절감 압축 커뮤니케이션 (mattpocock/skills MIT)', score: 80, core: false, optional: false, applicable: 'all' },
  { id: 'write-a-skill', kind: 'skill', title: '스킬 작성', description: '재사용 스킬 SKILL.md 스캐폴딩 (mattpocock/skills MIT)', score: 78, core: false, optional: false, applicable: 'all' },
  { id: 'zoom-out', kind: 'skill', title: '시스템 조망', description: '시스템 수준 시야로 모듈·호출 매핑 (mattpocock/skills MIT)', score: 76, core: false, optional: false, applicable: 'all' },
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
