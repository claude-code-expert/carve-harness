# carve-harness 요구사항

> 본 문서는 carve-harness CLI(레이어 A)가 충족해야 할 요구사항을 정의한다.
> 상세 설계는 [ARCHITECTURE.md](./ARCHITECTURE.md), 개발 지침은 [CLAUDE.md](./CLAUDE.md) 참고.

## 1. 목적

임의의 코드베이스를 분석해 **그 프로젝트에 맞는 하네스**(스킬·훅·커맨드·서브에이전트)를
대화형으로 선택·설치하는 CLI. carve = "범용 자산을 프로젝트에 맞게 깎아냄".

## 2. 핵심 요구사항

### 2.1 설치 흐름 (R-INSTALL)
- 결정적 휴리스틱으로 프로젝트 타입·언어·도구를 탐지하고, 적합한 구성요소를 **추천**한다.
- **대화형 선택 설치**: 사용자가 고른 구성요소만 설치한다. 일괄 설치 모드는 **지원하지 않는다**.
- 설치는 **멱등**하다. 재실행 시 사용자가 수정한 자산을 덮어쓰지 않고, 충돌은 diff 제시 후 확인한다.
- 설치 내역을 manifest에 기록해 **클린 언인스톨**을 보장한다.

### 2.2 필수 구성요소 (R-CORE)
6개 핵심(Skill + 얇은 커맨드 shim): `handoff` · `memory` · `commit` · `changelog` · `review` · `pr`

7개 필수 Hook:
1. 파괴적 명령 차단 (PreToolUse)
2. 비밀파일 보호 (PreToolUse)
3. 커밋 전 린트 (PreToolUse)
4. 푸시 전 테스트 (PreToolUse)
5. 자동 포맷 (PostToolUse)
6. Slack 알림 (Stop/Notification)
7. PreCompact handoff (PreCompact)

1개 선택 Hook: 자동 커밋 (기본 OFF)

### 2.3 서브에이전트 (R-SQUAD)
Squad 8종(review·plan·refactor·qa·debug·docs·gitops·audit) + post-PoC squad-evaluator = 9종 설치 + 키워드 라우터 훅 + 체이닝/알림 훅을
**100% 보존**하여 설치한다. (vendor/subagents가 원본)

### 2.4 추가 구성요소 (R-EXTRA)
나열된 필수 요소 외, 활용도·완성도 **75점 이상**인 스킬을 점수표로 선별해 카탈로그에 포함한다.

### 2.5 문서화 (R-DOC)
설치 시 대상 프로젝트 루트에 **사용법 가이드 MD**와 **CLAUDE.md**를 생성해
하네스의 역할·구조·사용법을 안내한다.

### 2.6 라이프사이클 (R-LIFECYCLE)
`install` / `uninstall` / `list` / `doctor` 명령을 제공한다. 설치도 제거도 쉽고 직관적이어야 한다.
v1.2.0(M8): `diff` / `update` / `migrate`로 설치된 하네스를 사용자 수정 보존하며 안전 갱신한다(자산 hash + manifest 스키마 v2, 멱등·`.bak` 1회·audit 게이트·manifest-last 원자성). `report`(M10)는 opt-in 로컬 텔레메트리를 집계한다(네트워크 없음).

### 2.7 배포 (R-DIST)
npx(`npx carve-harness`) + bash(`install.sh`) 두 경로를 모두 제공한다.

## 3. 지원 범위

- ✅ CLI · 웹 · 모바일 · 반응형 · PC 데스크탑 앱 · 배치 등 일반 개발 시스템
- ❌ 업무 자동화 · 대량 문서 처리 (서브에이전트 외 활용도 낮음)

## 4. 품질 기준

- 각 하네스 구성요소마다 동작하는 **기능 테스트 1개**(프롬프트 또는 명령) 구성.
- **커버리지·E2E 기준 80점 이상**.
- 생성/수정 코드는 커밋 전 검증(TS `tsc --noEmit` / Shell `bash -n` / `JSON.parse`).
- 생성물은 auditor 통과(secret 노출·과다권한·hook injection 없음).

## 5. 비목표

- 너무 복잡하거나 방대한 기능. 컴팩트하고 필수적인 기능 위주.
- LLM 호출 기반 분석(carve CLI 자체는 결정적). 미세조정은 하네스 내부 스킬이 담당.
