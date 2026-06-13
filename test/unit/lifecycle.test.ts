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

test('deprecationNotices: deprecated 설치분만 보고 + replacedBy 전달 (wave-1: changelog→squad-gitops)', () => {
  const m = manifestOf([
    '.claude/skills/commit/SKILL.md', // active — 보고 안 함
    '.claude/skills/changelog/SKILL.md', // wave-1 deprecated
    '.claude/skills/security-scan/SKILL.md', // wave-1 deprecated
    '.claude/skills/unknown-thing/SKILL.md', // 카탈로그 미등재 — 무시
  ]);
  const notices = deprecationNotices(m).sort((a, b) => a.id.localeCompare(b.id));
  assert.deepEqual(notices.map((n) => n.id), ['changelog', 'security-scan']);
  assert.ok(notices.every((n) => n.status === 'deprecated'));
  assert.equal(notices.find((n) => n.id === 'changelog')?.replacedBy, 'squad-gitops');
  assert.equal(notices.find((n) => n.id === 'security-scan')?.replacedBy, 'squad-audit');
});

test('deprecationNotices: hidden 설치분도 보고 (status hidden — 내장 슬래시 충돌로 fade-out된 memory·review)', () => {
  const m = manifestOf([
    '.claude/skills/commit/SKILL.md', // active — 보고 안 함
    '.claude/skills/memory/SKILL.md', // hidden (내장 /memory 충돌)
    '.claude/skills/review/SKILL.md', // hidden (내장 /review 충돌)
  ]);
  const notices = deprecationNotices(m).sort((a, b) => a.id.localeCompare(b.id));
  assert.deepEqual(notices.map((n) => n.id), ['memory', 'review']);
  assert.ok(notices.every((n) => n.status === 'hidden'));
});
