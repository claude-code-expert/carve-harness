// src/designer.ts — ProjectProfile + catalog → 추천 슬롯 설계 (레이어 A, M2).
// 추천만 한다. 실제 설치는 wizard 선택 + installer가 한다 (일괄 설치 없음).
import type { ProjectProfile, ProjectType } from './types.ts';
import { forType, type CatalogComponent } from './catalog.ts';

export type HarnessLevel = 'minimal' | 'standard' | 'full';

export interface HarnessDesign {
  /** 제안된 하네스 레벨 */
  level: HarnessLevel;
  /** 기본 체크될 추천 컴포넌트 id */
  recommended: string[];
  /** 선택 가능한 전체 컴포넌트 id (적합 타입) */
  available: string[];
  /** 추천 근거 */
  rationale: string[];
}

const SIMPLE_TYPES: ProjectType[] = ['cli', 'library', 'batch', 'unknown'];

// minimal 레벨에서 기본 추천하는 필수 훅 (가장 안전 결정적인 것만)
const ESSENTIAL_HOOKS = new Set(['block-destructive', 'protect-secrets', 'precompact-handoff']);

/** 프로젝트 복잡도로 하네스 레벨을 제안한다. */
export function harnessLevel(p: ProjectProfile): HarnessLevel {
  if (p.ci !== null && p.languages.length > 1) return 'full';
  if (SIMPLE_TYPES.includes(p.type)) return 'minimal';
  return 'standard';
}

// 모노레포/CI 시그널이 있을 때 가중하는 조정 컴포넌트 id (INTEL-03).
// 단 2개뿐이라 catalog 메타(boostOn) 대신 designer에 명시 유지 (over-design 회피).
const COORDINATION_IDS = ['parallel-agents', 'coordinator'];

/**
 * 시그널 가중 스코어링 (INTEL-03, 순수 함수).
 * 모노레포(workspaces 비어있지 않음) 또는 CI(ci !== null) 시그널이 있으면
 * 조정 컴포넌트를 추천 목록에 가중한다 — 단 `available`에 있는 id만, 중복 없이.
 * 입력을 변형하지 않고 새 배열을 반환한다.
 */
export function applySignalWeights(
  p: ProjectProfile,
  baseRecommended: string[],
  available: string[],
): string[] {
  const result = new Set(baseRecommended);
  const isMonorepo = p.workspaces.length > 0;
  const hasCi = p.ci !== null;
  if (isMonorepo || hasCi) {
    for (const id of COORDINATION_IDS) {
      if (available.includes(id)) result.add(id);
    }
  }
  return [...result];
}

/** ProjectProfile → 추천 슬롯 설계. levelOverride로 자동 레벨을 덮어쓸 수 있다(--level). */
export function design(p: ProjectProfile, levelOverride?: HarnessLevel): HarnessDesign {
  const level = levelOverride ?? harnessLevel(p);
  const available = forType(p.type);
  const rec = new Set<string>();
  const rationale: string[] = [];

  // 코어 스킬·에이전트는 항상 추천
  for (const c of available) {
    if (c.core && (c.kind === 'skill' || c.kind === 'agent')) rec.add(c.id);
  }
  rationale.push('코어 스킬·서브에이전트 기본 포함');

  // anti-slop 팩은 타입 무관 기본 추천 (모든 프로젝트가 문서·다이어그램을 만든다)
  if (available.some((c) => c.id === 'anti-ai-slop')) {
    rec.add('anti-ai-slop');
    rationale.push('anti-ai-slop: 문서·SVG·HTML 슬롭 제거 (타입 무관)');
  }

  // 훅: minimal은 필수 훅만, standard 이상은 모든 코어 훅
  for (const c of available) {
    if (c.kind !== 'hook' || !c.core) continue;
    if (level === 'minimal') {
      if (ESSENTIAL_HOOKS.has(c.id)) rec.add(c.id);
    } else {
      rec.add(c.id);
    }
  }
  rationale.push(
    level === 'minimal' ? '필수 훅(차단·보호·핸드오프)만 기본 추천' : '7개 필수 훅 기본 추천',
  );

  // full: 추가 스킬(verify/security-scan/test-gen)까지 추천
  if (level === 'full') {
    for (const c of available) {
      if (!c.core && !c.optional && c.id !== 'anti-ai-slop') rec.add(c.id);
    }
    rationale.push('full 레벨: 추가 스킬(verify·security-scan·test-gen) 포함');
  }

  // 시그널 가중 (INTEL-03): 모노레포/CI 시그널 → 조정 컴포넌트 가중 (ADDITIVE).
  const availableIds = available.map((c: CatalogComponent) => c.id);
  const recommended = applySignalWeights(p, [...rec], availableIds);
  if (recommended.length > rec.size) {
    if (p.workspaces.length > 0) rationale.push('monorepo 시그널 — 병렬·조율 에이전트 가중');
    if (p.ci !== null) rationale.push('CI 시그널 — 조율 컴포넌트 가중');
  }

  // 선택 컴포넌트(auto-commit 등)는 절대 자동 추천하지 않는다 — wizard에서 사용자가 켠다.
  return {
    level,
    recommended,
    available: availableIds,
    rationale,
  };
}
