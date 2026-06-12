// src/lifecycle.ts — 설치본 ↔ 카탈로그 라이프사이클 매핑 (레이어 A). 순수 함수만(IO·fs 없음).
// doctor/update가 deprecated·hidden 설치분을 안내할 때 쓴다. uninstall은 manifest만 보므로 영향 없음.
import type { Manifest } from './manifest.ts';
import { byId, statusOf, type ComponentStatus } from './catalog.ts';

/**
 * manifest 파일 경로 → 컴포넌트 id 역매핑.
 * 매핑 규칙(installer 산출 컨벤션의 역): .claude/skills/<id>/SKILL.md · .claude/hooks/carve-<id>.sh · .claude/agents/<id>.md
 * 비매핑 파일(문서·팩 자산 등)은 무시한다.
 */
export function installedComponentIds(m: Manifest): Set<string> {
  const ids = new Set<string>();
  for (const { path } of m.files) {
    const skill = /^\.claude\/skills\/([^/]+)\/SKILL\.md$/.exec(path);
    if (skill?.[1] !== undefined) {
      ids.add(skill[1]);
      continue;
    }
    const hook = /^\.claude\/hooks\/carve-(.+)\.sh$/.exec(path);
    if (hook?.[1] !== undefined) {
      ids.add(hook[1]);
      continue;
    }
    const agent = /^\.claude\/agents\/([^/]+)\.md$/.exec(path);
    if (agent?.[1] !== undefined) ids.add(agent[1]);
  }
  return ids;
}

export interface LifecycleNotice {
  id: string;
  status: ComponentStatus;
  title: string;
  replacedBy?: string;
}

/** 설치된 컴포넌트 중 라이프사이클 상태가 active가 아닌 것의 안내 목록. 카탈로그 미등재 id는 무시. */
export function deprecationNotices(m: Manifest): LifecycleNotice[] {
  const out: LifecycleNotice[] = [];
  for (const id of installedComponentIds(m)) {
    const c = byId(id);
    if (!c) continue;
    const status = statusOf(c);
    if (status === 'active') continue;
    out.push({ id, status, title: c.title, replacedBy: c.replacedBy });
  }
  return out;
}
