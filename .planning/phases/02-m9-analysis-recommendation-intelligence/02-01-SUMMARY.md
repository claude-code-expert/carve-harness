---
phase: 02-m9-analysis-recommendation-intelligence
plan: 01
subsystem: analyzer
tags: [analyzer, types, monorepo, container, detection, INTEL-01, INTEL-02]
requires: []
provides:
  - "ProjectProfile.workspaces: string[]"
  - "ProjectProfile.container: { dockerfile, compose, makefile }"
  - "analyzer.detectWorkspaces(root, pkg)"
  - "analyzer.detectContainer(root)"
affects:
  - "designer (Plan 02 weights on these signals)"
tech-stack:
  added: []
  patterns:
    - "read-only existsSync/readIf detection (no writes)"
    - "deterministic, order-stable tag collection"
key-files:
  created:
    - test/fixtures/monorepo/pnpm-workspace.yaml
    - test/fixtures/monorepo/package.json
    - test/fixtures/docker/Dockerfile
    - test/fixtures/docker/docker-compose.yml
    - test/fixtures/docker/Makefile
    - test/fixtures/docker/package.json
  modified:
    - src/types.ts
    - src/analyzer.ts
    - test/unit/analyzer.test.ts
    - test/unit/designer.test.ts
    - test/unit/wizard.test.ts
    - test/unit/auditor.test.ts
    - test/unit/generator.test.ts
    - test/unit/claudebase.test.ts
decisions:
  - "container shape defined inline in interface (no separate exported type) — code-style 단순함이 먼저다"
  - "npm-workspaces tag uses truthy non-null check (array OR object form both count)"
metrics:
  duration: ~10m
  completed: 2026-06-05
---

# Phase 02 Plan 01: ProjectProfile workspace/container signals + analyzer detection Summary

monorepo 워크스페이스(INTEL-01)·컨테이너 빌드 시그널(INTEL-02)을 ProjectProfile에 추가하고, analyzer가 읽기 전용 결정적 탐지로 항상 두 필드를 채운다.

## What Changed

- **src/types.ts**: ProjectProfile에 REQUIRED 필드 `workspaces: string[]`, `container: { dockerfile; compose; makefile }` 추가 (한글 doc comment, container shape는 인라인).
- **src/analyzer.ts**: `detectWorkspaces(root, pkg)` (pnpm-workspace/turbo/nx/lerna/npm-workspaces/cargo-workspace 태그) + `detectContainer(root)` (Dockerfile / docker-compose.yml·yaml·compose.yaml / Makefile). PackageJson 인터페이스에 `workspaces?` 추가. analyze()가 두 필드를 채우고 사람이 읽을 signals[] 항목을 push. 읽기 전용 유지 (existsSync/readIf만).
- **fixtures**: test/fixtures/monorepo (pnpm-workspace.yaml + package.json workspaces) / test/fixtures/docker (Dockerfile + docker-compose.yml + Makefile[TAB] + package.json).
- **analyzer 테스트 5종 추가**: monorepo→pnpm-workspace+npm-workspaces, cli→workspaces=[], Cargo.toml [workspace]→cargo-workspace, docker→container all-true, cli→container all-false.

## Construction Sites Fixed

Adding two REQUIRED fields breaks every inline ProjectProfile literal. Found and fixed exactly 6:
1. `src/analyzer.ts` — analyze() return literal (workspaces + container).
2. `test/unit/designer.test.ts` — `profile()` helper.
3. `test/unit/wizard.test.ts` — `profile()` helper.
4. `test/unit/auditor.test.ts` — top-level `profile` const.
5. `test/unit/generator.test.ts` — `profile()` helper.
6. `test/unit/claudebase.test.ts` — `profile()` helper.

(commands.ts/cli.ts only consume the type; no literal. e2e tests build no ProjectProfile literals — verified by grep on `signals:`/`hasGit:`/`ProjectProfile`.)

## Deviations from Plan

None — plan executed exactly as written. (Added a minimal test/fixtures/docker/package.json, which the plan's action text explicitly called for so analyze() yields a profile.)

## Verification

- `npm run check` (tsc --noEmit, strict): clean.
- `npm test`: 157 pass / 0 fail (was 152 baseline; +5 new analyzer tests).
- analyzer remains read-only (no writeFileSync/mkdirSync/rmSync added).

## Commits

- `521ebf8` feat(types): ProjectProfile에 workspaces·container 필드 추가
- `2b919cf` feat(analyzer): 모노레포·컨테이너 시그널 탐지 + ProjectProfile 확장

## Self-Check: PASSED

All 9 declared files exist on disk; both commits (521ebf8, 2b919cf) present in git log.
