// src/wizard.ts — 대화형 구성요소 선택 (레이어 A). 추천을 기본 체크로 제시하되 사용자가 고른다.
// 선택 로직(buildChoices)은 순수·테스트 가능. selectInteractive는 @clack TTY 래퍼(얇음).
import type { HarnessDesign } from './designer.ts';
import { byId } from './catalog.ts';

export interface WizardChoice {
  value: string;
  label: string;
  hint?: string;
  /** 추천(기본 체크) 여부 */
  selected: boolean;
}

/** 설계 → 선택지 목록. 추천 항목은 selected=true. (순수) */
export function buildChoices(design: HarnessDesign): WizardChoice[] {
  const recommended = new Set(design.recommended);
  return design.available.map((id) => {
    const c = byId(id);
    return {
      value: id,
      label: c?.title ?? id,
      hint: c ? `${c.kind} · ${c.description}` : undefined,
      selected: recommended.has(id),
    };
  });
}

/** @clack 멀티셀렉트로 사용자 선택을 받는다(TTY). 취소 시 빈 배열. */
export async function selectInteractive(design: HarnessDesign): Promise<string[]> {
  const p = await import('@clack/prompts');
  const choices = buildChoices(design);
  p.intro('carve — 설치할 구성요소 선택');
  const res = await p.multiselect({
    message: '이 프로젝트에 설치할 구성요소를 고르세요 (스페이스=토글, 엔터=확정).',
    options: choices.map((c) => ({ value: c.value, label: c.label, hint: c.hint })),
    initialValues: choices.filter((c) => c.selected).map((c) => c.value),
    required: false,
  });
  if (p.isCancel(res)) {
    p.cancel('설치 취소됨');
    return [];
  }
  const selected = res as string[];
  p.outro(`${selected.length}개 선택됨`);
  return selected;
}
