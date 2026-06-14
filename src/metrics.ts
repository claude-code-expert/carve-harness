// src/metrics.ts — 로컬 텔레메트리 집계 (레이어 A, M12).
// 순수 read-only 모듈: 로깅은 호출자 책임(console.* 없음). 새 의존성 없음(node:fs + JSON).
// .claude/.carve-metrics.jsonl(M10, opt-in)을 읽어 report·update·designer가 공유하는 집계를 만든다.
// prefs.ts와 같은 결: 파일 없으면 null, 손상은 throw 없이 방어적으로 건너뛴다.
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import type { Manifest } from './manifest.ts';

/** 대상 루트 기준 텔레메트리 파일 상대경로 (M10이 emit, opt-in). */
export const METRICS_REL = '.claude/.carve-metrics.jsonl';

/**
 * carve_metric을 실제로 호출하는(계측된) 훅 id — 0-fire 판정 대상.
 * 비계측 훅(slack-notify·codesight-refresh)은 구조상 0회라 오탐 방지 위해 제외.
 */
export const INSTRUMENTED_HOOKS = new Set([
  'block-destructive', 'protect-secrets', 'pre-commit-lint',
  'pre-push-test', 'auto-format', 'precompact-handoff', 'anti-slop',
]);

/** 메트릭 한 줄의 신뢰 가능한 형태 — {ts, hook, event}만 본다. */
export interface MetricLine {
  ts: number;
  hook: string;
  event: string;
}

/** 훅별 발화·차단 + 0-fire 목록 집계 결과. */
export interface MetricsAggregate {
  /** 훅 id → {발화 총수, 차단 수}. 발화한 훅만 등장(파일 등장 순서 보존). */
  perHook: Map<string, { total: number; blocks: number }>;
  /** 계측 대상인데 한 번도 발화하지 않은 설치 훅 id (manifest 기준 노이즈 후보). manifest 없으면 빈 배열. */
  zeroFire: string[];
  /** 전체 발화 합계 (= 파싱 성공한 유효 줄 수 — 유효 줄 1개 = 훅 발화 1건) */
  totalFires: number;
  /** 전체 차단 합계 */
  totalBlocks: number;
}

/** 손편집·부분기록 가능한 jsonl 한 줄을 안전하게 파싱·검증. 무효면 null(throw 없음). */
export function parseMetricLine(line: string): MetricLine | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(line);
  } catch {
    return null;
  }
  if (typeof parsed !== 'object' || parsed === null) return null;
  const o = parsed as Record<string, unknown>;
  if (typeof o.hook !== 'string' || typeof o.event !== 'string') return null;
  const ts = typeof o.ts === 'number' ? o.ts : 0;
  return { ts, hook: o.hook, event: o.event };
}

/**
 * .claude/.carve-metrics.jsonl을 읽어 훅별 발화·차단 + 0-fire 목록으로 집계한다.
 * 파일이 없으면(opt-in 미사용) null — 호출자는 graceful degrade한다.
 * 손상·필드누락·빈 줄은 줄 단위로 건너뛴다(throw 없음).
 * 0-fire는 manifest의 carve-<id>.sh 중 계측 대상인데 발화 0회인 id (manifest 없으면 빈 배열).
 */
export function aggregateMetrics(root: string, manifest: Manifest | null): MetricsAggregate | null {
  const metricsPath = join(root, METRICS_REL);
  if (!existsSync(metricsPath)) return null;

  const perHook = new Map<string, { total: number; blocks: number }>();
  let totalFires = 0;
  let totalBlocks = 0;
  for (const line of readFileSync(metricsPath, 'utf8').split(/\r?\n/)) {
    if (line.trim() === '') continue;
    const m = parseMetricLine(line);
    if (!m) continue; // 손상·필드 누락 줄은 방어적으로 건너뜀
    const e = perHook.get(m.hook) ?? { total: 0, blocks: 0 };
    e.total += 1;
    totalFires += 1;
    if (m.event === 'block') {
      e.blocks += 1;
      totalBlocks += 1;
    }
    perHook.set(m.hook, e);
  }

  const zeroFire: string[] = [];
  if (manifest) {
    for (const f of manifest.files) {
      const match = /^\.claude\/hooks\/carve-(.+)\.sh$/.exec(f.path);
      const id = match?.[1];
      if (id !== undefined && INSTRUMENTED_HOOKS.has(id) && !perHook.has(id)) zeroFire.push(id);
    }
  }

  return { perHook, zeroFire, totalFires, totalBlocks };
}
