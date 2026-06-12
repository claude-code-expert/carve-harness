// src/wizard.ts — 대화형 구성요소 선택 (레이어 A). 추천을 기본 체크로 제시하되 사용자가 고른다.
// 선택 로직(buildChoices)은 순수·테스트 가능. selectInteractive는 @clack TTY 래퍼(얇음).
import type { HarnessDesign } from './designer.ts';
import { byId, statusOf } from './catalog.ts';
import { readPrefs, writePrefs, applyPrefs, type CarvePrefs } from './prefs.ts';

export interface WizardChoice {
  value: string;
  label: string;
  hint?: string;
  /** 추천(기본 체크) 여부 */
  selected: boolean;
}

/**
 * 설계 → 선택지 목록. 기본 체크는 applyPrefs(design, prefs)가 정한다. (순수)
 * prefs 없으면(undefined/null) 추천(design.recommended)이 그대로 기본 체크 — 기존 동작과 동일.
 */
export function buildChoices(design: HarnessDesign, prefs?: CarvePrefs | null): WizardChoice[] {
  const checked = new Set(applyPrefs(design, prefs ?? null));
  return design.available.map((id) => {
    const c = byId(id);
    // deprecated는 [비추천→대체id] 힌트 — designer가 추천에서 빼므로 기본 미체크(사용자 prefs로 켠 건 유지)
    const dep = c && statusOf(c) === 'deprecated';
    return {
      value: id,
      label: c?.title ?? id,
      hint: c ? `${c.kind} · ${dep ? `[비추천${c.replacedBy ? `→ ${c.replacedBy}` : ''}] ` : ''}${c.description}` : undefined,
      selected: checked.has(id),
    };
  });
}

/**
 * @clack 멀티셀렉트로 사용자 선택을 받는다(TTY). 취소 시 빈 배열(쓰기 없음).
 * 시작 시 <root>/.claude/.carve-prefs.json을 읽어 기본 체크에 반영하고,
 * 확정 후 새 선호(추천 대비 끈 것/켠 것)를 같은 위치에 쓴다.
 */
export async function selectInteractive(design: HarnessDesign, root: string): Promise<string[]> {
  const p = await import('@clack/prompts');
  const prefs = readPrefs(root);
  const choices = buildChoices(design, prefs);
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
  // 추천 대비 차이를 선호로 저장 (deselected=끈 추천, selected=켠 비추천).
  const deselected = design.recommended.filter((id) => !selected.includes(id));
  const added = selected.filter((id) => !design.recommended.includes(id));
  writePrefs(root, { deselected, selected: added, updatedAt: new Date().toISOString() });
  p.outro(`${selected.length}개 선택됨`);
  return selected;
}
