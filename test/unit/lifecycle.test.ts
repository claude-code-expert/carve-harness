// test/unit/lifecycle.test.ts — 설치본 ↔ 카탈로그 라이프사이클 매핑 (순수 함수) 검증.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { installedComponentIds, deprecationNotices } from '../../src/lifecycle.ts';
import { statusOf, type CatalogComponent } from '../../src/catalog.ts';
import type { Manifest } from '../../src/manifest.ts';

function manifestOf(paths: string[]): Manifest {
  return {
    schemaVersion: 2,
    version: '1.0.0',
    files: paths.map((path) => ({ path, hash: 'h', assetVersion: '1.0.0' })),
    backups: [],
    hooks: [],
  };
}

test('statusOf: 생략 시 active, 명시 시 그대로', () => {
  assert.equal(statusOf({ id: 'x' } as CatalogComponent), 'active');
  assert.equal(statusOf({ id: 'x', status: 'deprecated' } as CatalogComponent), 'deprecated');
  assert.equal(statusOf({ id: 'x', status: 'hidden' } as CatalogComponent), 'hidden');
});

test('installedComponentIds: 파일 경로 → 컴포넌트 id 역매핑 (skills/hooks/agents, 비매핑 무시)', () => {
  const m = manifestOf([
    '.claude/skills/commit/SKILL.md',
    '.claude/hooks/carve-block-destructive.sh',
    '.claude/agents/squad-review.md',
    'flight-rules.md', // 비매핑 문서
    '.claude/skills/SKILL.md', // anti-slop 팩 마스터 — 하위 디렉토리 아님 → 비매핑
    '.claude/hooks/_metrics.sh', // carve- 프리픽스 아님 → 비매핑
  ]);
  const ids = installedComponentIds(m);
  assert.deepEqual([...ids].sort(), ['block-destructive', 'commit', 'squad-review']);
});

test('deprecationNotices: active만 설치된 경우 빈 배열', () => {
  const m = manifestOf(['.claude/skills/commit/SKILL.md', '.claude/agents/squad-review.md']);
  assert.deepEqual(deprecationNotices(m), []);
});

test('deprecationNotices: 카탈로그 미등재(삭제됨) 설치분은 무시 — 잔여 fade-out 안내 없음', () => {
  // v1.5.0에서 삭제한 컴포넌트(memory·changelog 등)가 구설치에 남아도 byId 미등재라 안내하지 않는다.
  // (잔여 정리는 carve update의 removeOrphanedComponents가 담당 — orphan-cleanup.test가 별도 검증.)
  const m = manifestOf([
    '.claude/skills/commit/SKILL.md', // active
    '.claude/skills/memory/SKILL.md', // 삭제됨(미등재)
    '.claude/skills/changelog/SKILL.md', // 삭제됨(미등재)
  ]);
  assert.deepEqual(deprecationNotices(m), []);
});
