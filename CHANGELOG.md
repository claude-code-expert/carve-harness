# Changelog

이 프로젝트의 모든 주요 변경사항을 기록한다.
포맷은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/)를 따르며,
[유의적 버전(SemVer)](https://semver.org/lang/ko/)을 준수한다.

## [Unreleased]

### 잔여 (코드 외)
- 정량 평가 축 1·3·4 라이브 비교 벤치(`bench/run.sh`) 구축 — 타 하네스 대비 실측.

---

## [1.1.0] — 2026-05-31

MVP 구현 완료. TypeScript(ESM, 빌드 0) CLI로 분석→설계→생성→자기검증→멱등설치 파이프라인 동작.

### Added
- **CLI**: `carve install`(대화형 @clack 선택 + `--only` 명시 선택, 일괄 설치 없음)·`list`·`doctor`·`uninstall`.
- **파이프라인 모듈**: `analyzer`(프로젝트 타입·언어·도구 탐지)·`catalog`(점수≥75 레지스트리)·`designer`(슬롯 설계+하네스 레벨)·`generator`(자산 깎기+템플릿 치환)·`auditor`(생성물 보안 자기검증)·`installer`/`manifest`(멱등·`.bak` 보존·클린 uninstall).
- **핵심 스킬 6 + 진입 스킬**: handoff·memory·commit·changelog·review·pr + harness-architect(자연어 트리거) + `carve-*` 커맨드 shim.
- **필수 훅 7 + 선택 1**: 파괴적 명령 차단·비밀파일 보호(exit 2 결정적 차단)·커밋 전 린트·푸시 전 테스트·자동 포맷·Slack 알림·PreCompact 핸드오프(+자동 커밋 선택).
- **Squad 서브에이전트 8종 100% 보존**: 에이전트·커맨드·키워드 라우터(`squad-router.sh`)·체이닝/알림(`subagent-chain.sh`) 훅 vendoring + 등록.
- **anti-ai-slop 팩**: 마스터 스킬 + 포맷별(svg-image·card-news·html-report·html-presentation) + `clean-html` + `check-slop.mjs` 린터(HTML/CSS·SVG·Markdown 디스패치). PostToolUse 경고 훅(예외경로).
- **생성 문서**: `flight-rules.md`·`evaluation-criteria.md`·대상 `CLAUDE.md`·`HARNESS-GUIDE.md`.
- **배포**: npx(`carve-harness`) + `install.sh` bash 래퍼.
- **테스트**: 96개(단위+E2E), 커버리지 ~95%. PoC 합격 시나리오 E2E.
- **정량 평가표**: `docs/guide/carve-harness-benchmark-results.md`(6축 28지표, 한 줄 단위).

### Changed
- 언어 JS → TypeScript(빌드 0, Node ≥22.18 타입 스트리핑). `node --check` → `tsc --noEmit`.
- `vendor/`로 OpenHarness·subagents 이동(읽기 전용 원본 보존).

### Notes
- 정량 평가: 자기측정 축(제어·안전 / 기능 E2E / 구성 품질) 목표 달성. 비교 축(효율·트리거·컨텍스트)은 라이브 벤치 보류.

[Unreleased]: https://github.com/claude-code-expert/carve-harness/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/claude-code-expert/carve-harness/releases/tag/v1.1.0
