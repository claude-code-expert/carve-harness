# Squad Router Hook - Feature Plan

> UserPromptSubmit hook that auto-detects keywords and injects subagent routing context.

---

## Feature Summary

Squad Router Hook은 사용자가 Claude Code에 프롬프트를 입력할 때 `UserPromptSubmit` 훅을 통해 키워드를 자동 감지하고, 매칭된 squad 서브에이전트를 호출하도록 stdout 컨텍스트를 주입하는 시스템이다. 기존에는 `/squad-review` 같은 슬래시 커맨드를 수동으로 입력해야 했지만, 이 훅이 설치되면 "코드 리뷰해줘"처럼 자연어로 입력해도 적절한 에이전트가 자동으로 위임된다. 모든 프롬프트마다 실행되므로 latency를 최소화하는 것이 핵심이다.

---

## User Stories

### US-001: 자연어 키워드 기반 자동 라우팅

**As a** Claude Code 사용자,
**I want to** "코드 리뷰해줘" 같은 자연어 프롬프트를 입력했을 때 자동으로 squad-review 서브에이전트가 호출되도록 하고 싶다,
**So that** `/squad-review`를 직접 타이핑하지 않아도 자연스러운 대화 흐름으로 전문 에이전트를 활용할 수 있다.

**Acceptance Criteria:**
- [ ] Given 사용자가 "이 코드 리뷰해줘"를 입력했을 때, when UserPromptSubmit 훅이 실행되면, then stdout에 squad-review 서브에이전트 호출 지시 메시지가 출력된다
- [ ] Given 사용자가 "이 에러 좀 봐줘"를 입력했을 때, when 키워드 매칭이 수행되면, then "에러"가 감지되어 squad-debug로 라우팅된다
- [ ] Given 어떤 키워드에도 매칭되지 않는 프롬프트일 때, when 훅이 실행되면, then 아무런 stdout 출력 없이 exit 0으로 조용히 종료된다
- [ ] Given jq가 설치되어 있지 않은 환경일 때, when 훅이 실행되면, then 에러 없이 exit 0으로 종료된다

**Technical Notes:**
- stdin으로 JSON (`{"prompt":"..."}`)이 전달됨
- case 문의 순서가 우선순위를 결정하므로, 충돌 키워드(예: "보안 리뷰")를 먼저 처리해야 함
- tr '[:upper:]' '[:lower:]'로 대소문자 정규화 필수

**Complexity:** M

---

### US-002: 충돌 키워드 우선순위 해결

**As a** Claude Code 사용자,
**I want to** "PR 리뷰해줘"라고 하면 squad-review로, "PR 만들어줘"라고 하면 squad-gitops로 정확히 분류되길 원한다,
**So that** 여러 에이전트에 걸치는 키워드를 사용해도 의도에 맞는 에이전트가 호출된다.

**Acceptance Criteria:**
- [ ] Given "PR 리뷰" 또는 "PR review"를 입력했을 때, when 키워드 매칭 시, then squad-review로 라우팅된다 (squad-gitops가 아님)
- [ ] Given "PR 만들어" 또는 "PR 작성"을 입력했을 때, when 키워드 매칭 시, then squad-gitops로 라우팅된다
- [ ] Given "보안 리뷰"를 입력했을 때, when 키워드 매칭 시, then squad-audit로 라우팅된다 (squad-review가 아님)
- [ ] Given "빌드 에러"를 입력했을 때, when 키워드 매칭 시, then squad-debug로 라우팅된다
- [ ] Given "빌드 확인"을 입력했을 때, when 키워드 매칭 시, then squad-qa로 라우팅된다
- [ ] Given "코드 정리해줘"를 입력했을 때, when 키워드 매칭 시, then squad-refactor로 라우팅된다

**Technical Notes:**
- case 문에서 복합 키워드(2-word) 패턴을 단순 키워드(1-word) 패턴보다 먼저 배치
- "CONFLICT ZONE" 블록을 case 문 최상단에 배치하여 우선 매칭

**Complexity:** M

---

### US-003: 슬래시 커맨드와의 중복 방지

**As a** Claude Code 사용자,
**I want to** `/squad-review`를 직접 입력했을 때 라우터가 중복으로 동작하지 않길 원한다,
**So that** 명시적 커맨드 사용 시 불필요한 컨텍스트 주입이 발생하지 않는다.

**Acceptance Criteria:**
- [ ] Given 프롬프트가 "/squad-"로 시작할 때, when 훅이 실행되면, then 키워드 매칭을 건너뛰고 즉시 exit 0한다
- [ ] Given 프롬프트가 "/squad review"로 시작할 때, when 훅이 실행되면, then 동일하게 건너뛴다

**Technical Notes:**
- 프롬프트의 첫 문자가 `/`이고 `squad`가 포함되면 early return
- `/squad` 뿐 아니라 `/` 로 시작하는 모든 커맨드를 건너뛰는 것도 고려 가능 (보수적 접근)

**Complexity:** S

---

### US-004: Opt-out (라우팅 비활성화)

**As a** Claude Code 사용자,
**I want to** 특정 프롬프트에서 키워드가 매칭되더라도 서브에이전트 호출을 원하지 않을 때 이를 무시할 수 있길 원한다,
**So that** 라우터의 자동 분류가 의도와 다를 때 제어권을 가질 수 있다.

**Acceptance Criteria:**
- [ ] Given 프롬프트에 "--no-route" 또는 "#direct"가 포함되어 있을 때, when 훅이 실행되면, then 키워드 매칭을 건너뛴다
- [ ] Given 환경변수 `SQUAD_ROUTER=off`가 설정되어 있을 때, when 훅이 실행되면, then 전체 라우팅을 비활성화한다

**Technical Notes:**
- 프롬프트 내 escape 키워드: `--no-route`, `#direct` (사용 후 Claude에게 그대로 전달됨 - 큰 부작용 없음)
- 환경변수 기반 전역 비활성화: `SQUAD_ROUTER=off`

**Complexity:** S

---

### US-005: install.sh 통합

**As a** Squad Agent 설치 사용자,
**I want to** `bash install.sh`를 실행하면 squad-router.sh 훅이 자동으로 설치되고 settings.json에 등록되길 원한다,
**So that** 별도의 수동 설정 없이 라우터를 사용할 수 있다.

**Acceptance Criteria:**
- [ ] Given `bash install.sh`를 실행했을 때, when 설치가 완료되면, then `~/.claude/hooks/squad-router.sh`가 복사되고 실행 권한이 부여된다
- [ ] Given settings.json에 UserPromptSubmit 훅이 없을 때, when 설치 스크립트가 실행되면, then UserPromptSubmit 훅이 자동 등록된다
- [ ] Given settings.json에 이미 UserPromptSubmit 훅이 존재할 때, when 설치 스크립트가 실행되면, then 중복 등록하지 않는다
- [ ] Given `bash install.sh --uninstall`을 실행했을 때, when 제거가 완료되면, then squad-router.sh가 삭제된다

**Technical Notes:**
- `SQUAD_HOOKS` 배열에 `squad-router.sh` 추가
- `register_hook()` 함수에 `UserPromptSubmit` 등록 로직 추가
- 기존 `subagent-chain.sh`와 동일한 패턴으로 `do_install()` 에서 처리됨

**Complexity:** S

---

### US-006: 라우팅 결과 컨텍스트 주입

**As a** Claude Code의 메인 에이전트,
**I want to** UserPromptSubmit 훅의 stdout 출력을 통해 어떤 서브에이전트를 호출해야 하는지 명확한 지시를 받고 싶다,
**So that** 사용자의 프롬프트를 적절한 전문 에이전트에게 확실히 위임할 수 있다.

**Acceptance Criteria:**
- [ ] Given squad-review로 라우팅이 결정되었을 때, when stdout이 출력되면, then Claude가 squad-review 서브에이전트를 호출하는 데 충분한 지시가 포함된다
- [ ] Given 출력 메시지가 Claude에게 전달되었을 때, when Claude가 이를 해석하면, then Agent 도구의 subagent_type 파라미터로 정확한 에이전트명을 사용한다

**Technical Notes:**
- UserPromptSubmit 훅의 stdout은 Claude에게 "추가 컨텍스트"로 주입됨
- 단순 안내보다 구체적 지시가 효과적:
  ```
  [Squad Router] Use the squad-review subagent (via Agent tool with subagent_type="squad-review") to handle this request. The user's prompt matches code review keywords.
  ```
- 지시문은 영어로 작성 (Claude의 시스템 프롬프트 해석 일관성)

**Complexity:** S

---

## Conflict Resolution Strategy / 충돌 해결 전략

### 설계 원칙

case 문은 **first-match-wins** 방식으로 동작한다. 따라서 충돌 키워드는 반드시 일반 키워드보다 먼저 배치해야 한다.

### case 문 구조 (3단계)

```
Phase 1: SKIP 조건 (슬래시 커맨드, opt-out)
Phase 2: CONFLICT 패턴 (복합 키워드 - 2~3 word 조합)
Phase 3: GENERAL 패턴 (단일 키워드)
```

### Phase 2: 충돌 패턴 정의

```bash
# --- Phase 2: Conflict resolution (복합 키워드 우선 매칭) ---
*"pr 리뷰"*|*"pr review"*|*"테스트 코드 리뷰"*)
  AGENT="squad-review" ;;
*"pr 작성"*|*"pr 만들"*|*"pr 써"*)
  AGENT="squad-gitops" ;;
*"보안 리뷰"*|*"보안 검토"*|*"security review"*)
  AGENT="squad-audit" ;;
*"에러 테스트"*|*"빌드 에러"*)
  AGENT="squad-debug" ;;
*"빌드 확인"*|*"빌드 돌"*)
  AGENT="squad-qa" ;;
*"코드 정리"*)
  AGENT="squad-refactor" ;;
```

### Phase 3: 일반 패턴의 에이전트 순서

충돌 가능성이 높은 에이전트를 먼저 배치:

```
1. squad-audit    (보안 키워드는 오탐 시 리스크가 가장 큼)
2. squad-debug    (에러/버그는 즉각 대응 필요)
3. squad-plan     (기획 키워드는 비교적 고유)
4. squad-refactor (리팩토링 키워드는 비교적 고유)
5. squad-docs     (문서 키워드는 비교적 고유)
6. squad-gitops   (커밋/PR 키워드)
7. squad-qa       (테스트/검증 - 범용적 단어가 많아 마지막)
8. squad-review   (리뷰 - 가장 범용적이므로 최후순위)
```

**이유**: "리뷰"나 "테스트" 같은 단어는 다양한 맥락에서 사용되므로 뒤로 배치하고, "보안"이나 "에러"처럼 의도가 명확한 키워드를 앞에 배치한다.

---

## Essential Keyword Selection / 필수 키워드 선별

SQUAD-KEYWORD-MAP.md에서 **오탐이 낮고 의도가 명확한 핵심 키워드**만 선별한다. 선별 기준:

1. **의도 명확성**: 단어만으로 에이전트를 특정할 수 있는가?
2. **오탐 확률**: 일상 대화에서 해당 단어가 다른 의미로 쓰일 확률은?
3. **사용 빈도**: 실제 개발자가 자주 쓰는 표현인가?

### 선별 결과

| Agent | 채택 키워드 | 제외한 키워드 | 제외 사유 |
|-------|------------|-------------|----------|
| squad-review | `리뷰`, `review`, `코드 검토`, `검토해`, `diff 봐` | `코드 확인`, `코드 체크`, `pull request`, `코드 품질` | "확인/체크"는 범용적, "pull request"는 gitops와 충돌, "품질"은 모호 |
| squad-plan | `기획`, `plan `, `설계해`, `와이어프레임`, `wireframe`, `유저스토리`, `user story`, `브레인스토밍`, `brainstorm`, `스펙`, `spec`, `요구사항`, `구현 계획` | `플래닝`, `planning`, `화면 설계`, `화면 구성`, `화면 그려`, `ui 설계`, `뭐부터 해`, `어떻게 만들`, `구조 잡`, `태스크 분해`, `작업 분해` | `플래닝/planning`은 plan과 중복, 나머지는 너무 구어체이거나 오탐 우려 |
| squad-refactor | `리팩토링`, `리팩터`, `refactor`, `클린업`, `cleanup`, `clean up`, `추출`, `extract`, `중복 제거`, `코드 개선`, `함수 분리`, `컴포넌트 분리` | `정리해`, `분리해`, `중복 코드`, `deduplic`, `코드 스멜`, `code smell`, `구조 개선`, `깔끔하게`, `깨끗하게`, `simplify`, `dry` | "정리해"는 너무 범용, "dry"는 3글자로 오탐, "깔끔하게"는 모호 |
| squad-qa | `테스트`, `test`, `qa`, `검증`, `린트`, `lint`, `타입체크`, `type check`, `리그레션`, `regression` | `동작 확인`, `돌려`, `잘 되나`, `잘되나`, `빌드 돌`, `타입 검사`, `깨지는`, `통과`, `verify` | "돌려/확인/통과"는 범용적, "verify"는 다른 맥락 가능 |
| squad-debug | `디버그`, `debug`, `에러`, `error`, `버그`, `bug`, `오류`, `크래시`, `crash`, `stack trace`, `traceback`, `exception` | `왜 안`, `왜안`, `안돼`, `안되`, `안 돼`, `안 되`, `터졌`, `죽었`, `뻗었`, `실패`, `fail`, `not working`, `doesn't work`, `broken`, `원인 분석`, `원인 파악`, `이상해`, `문제가`, `문제 생` | "안돼/안되" 류는 일반 대화에서 매우 빈번, "실패/fail"은 테스트 실패와 혼동, "문제가/이상해"는 너무 범용 |
| squad-docs | `문서`, `document`, `readme`, `리드미`, `jsdoc`, `tsdoc`, `주석`, `comment`, `문서화` | `docs`, `api 문서`, `가이드 작성`, `가이드 만들`, `설명 달아` | "docs"는 3글자 오탐, "api 문서"는 "문서"로 커버, "설명 달아"는 모호 |
| squad-gitops | `커밋`, `commit`, `체인지로그`, `changelog`, `릴리즈 노트`, `release note`, `conventional` | `피알`, `풀리퀘`, `배포 노트` | "피알"은 PR의 구어체로 오탐 우려, "풀리퀘"도 축약어 |
| squad-audit | `보안`, `security`, `취약점`, `vulnerab`, `audit`, `owasp`, `시크릿`, `secret`, `인젝션`, `injection`, `xss`, `csrf` | `비밀키`, `토큰 노출`, `키 노출`, `npm audit`, `보안 스캔`, `security scan` | "npm audit"은 audit으로 커버, "키 노출"은 모호, "보안 스캔"은 "보안"으로 커버 |

### 주의: 오탐 고위험 키워드 (제외 또는 복합 조건)

| 키워드 | 오탐 시나리오 | 결정 |
|--------|-------------|------|
| `test` | "I want to test this" (일반 용도) | **채택** - 개발 맥락에서 대부분 QA 의도 |
| `docs` | 파일 경로 내 "docs/" | **제외** - "문서"로 대체 |
| `plan ` (공백 포함) | "I plan to..." | **채택** - 후행 공백으로 "plan" 단독 사용과 구분 |
| `dry` | "dry run", 일반 단어 | **제외** - 3글자, 오탐 확률 높음 |
| `fail` | "if it fails..." (코드 논의) | **제외** - squad-debug보다 일반 대화 |
| `comment` | "코드에 comment 달아" vs "그건 comment out 해" | **채택** - 대부분 문서화 의도 |

---

## Performance Considerations / 성능 고려사항

### 현재 설계의 성능 특성

| 단계 | 비용 | 예상 시간 |
|------|------|----------|
| stdin 읽기 (cat) | I/O | < 1ms |
| jq 파싱 | 프로세스 spawn | ~5-10ms |
| tr 소문자 변환 | 파이프라인 | < 1ms |
| case 매칭 | bash 내장 | < 1ms |
| stdout 출력 | I/O | < 1ms |
| **총합** | | **~10-15ms** |

### 최적화 포인트

1. **jq는 필수**: stdin JSON에서 `.prompt` 필드를 추출해야 하므로 대안이 없음. 단, jq 미설치 시 graceful exit.
2. **mktemp + cat 패턴**: 기존 `subagent-chain.sh`와 동일. stdin이 파이프이므로 여러 번 읽기 위해 임시 파일 필요. 라우터에서는 한 번만 읽으므로 파이프 직접 사용도 가능하나, 일관성과 디버깅 편의를 위해 기존 패턴 유지.
3. **case 문 효율성**: bash case 문은 O(n) 패턴 매칭이지만, n이 ~60 정도이므로 무시할 수 있는 수준.
4. **모든 프롬프트마다 실행**: UserPromptSubmit은 모든 입력에 대해 트리거됨. 15ms 이하이므로 UX에 영향 없음.

### 잠재적 이슈

- **jq 미설치**: exit 0으로 조용히 종료 (기존 패턴과 동일)
- **비정상 JSON**: jq empty 검증 실패 시 exit 0
- **빈 프롬프트**: PROMPT가 비어있으면 case 매칭 불가 -> AGENT=""으로 끝남 -> 출력 없음

---

## Implementation Plan / 구현 계획

### Task 1: squad-router.sh 스크립트 작성
- **파일**: `hooks/squad-router.sh` (신규)
- **복잡도**: M
- **의존성**: 없음
- **변경 내용**:
  - shebang: `#!/bin/bash` (zsh 의존성 불필요)
  - stdin JSON 읽기 + jq 파싱
  - Phase 1 (SKIP): 슬래시 커맨드 감지, opt-out 키워드 감지, 환경변수 체크
  - Phase 2 (CONFLICT): 복합 키워드 우선 매칭 (6개 패턴)
  - Phase 3 (GENERAL): 에이전트별 핵심 키워드 매칭 (8개 블록)
  - 매칭 시 stdout 컨텍스트 주입
  - 항상 exit 0

### Task 2: install.sh 수정
- **파일**: `install.sh` (기존)
- **복잡도**: S
- **의존성**: Task 1
- **변경 내용**:
  - `SQUAD_HOOKS` 배열에 `squad-router.sh` 추가
  - `register_hook()` 함수에 `UserPromptSubmit` 훅 등록 로직 추가
  - uninstall 시 `squad-router.sh`도 삭제 (기존 루프가 `SQUAD_HOOKS` 배열을 순회하므로 배열 추가만으로 자동 처리)

### Task 3: docs/ARCHITECTURE.md 업데이트
- **파일**: `docs/ARCHITECTURE.md` (기존)
- **복잡도**: S
- **의존성**: Task 1
- **변경 내용**:
  - "Installed Directory Structure"에 `squad-router.sh` 추가
  - "Squad Router Hook" 섹션 추가 (UserPromptSubmit 흐름 설명)
  - Pipeline 다이어그램에 라우터 진입점 표시

### Task 4: README 업데이트
- **파일**: `README.md`, `README.ko.md` (기존)
- **복잡도**: S
- **의존성**: Task 1
- **변경 내용**:
  - 자동 라우팅 기능 소개 추가
  - opt-out 방법 안내
  - 지원되는 키워드 예시 테이블

### Task 5: 버전 범프 및 CHANGELOG
- **파일**: `VERSION`, `CHANGELOG.md` (기존)
- **복잡도**: S
- **의존성**: Task 1-4
- **변경 내용**:
  - minor 버전 범프 (1.2.1 -> 1.3.0, 신규 feature이므로)
  - CHANGELOG에 squad-router-hook 항목 추가

### Task Dependency Graph

```
Task 1 (squad-router.sh) ─────┬──► Task 2 (install.sh)
                               ├──► Task 3 (ARCHITECTURE.md)
                               ├──► Task 4 (README)
                               └──► Task 5 (VERSION + CHANGELOG)
```

---

## Detailed File Changes / 파일별 상세 변경

### hooks/squad-router.sh (신규)

```bash
#!/bin/bash
# squad-router.sh — Keyword-based subagent routing hook
# Triggered by UserPromptSubmit: detects keywords and injects
# subagent delegation context via stdout.
#
# Registered automatically by install.sh
set -euo pipefail

# --- Env-level opt-out ---
if [ "${SQUAD_ROUTER:-}" = "off" ]; then
  exit 0
fi

# --- Read stdin (JSON from Claude Code) ---
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
cat > "$TMPFILE"

# --- jq guard ---
if ! command -v jq &>/dev/null; then exit 0; fi
if ! jq empty < "$TMPFILE" 2>/dev/null; then exit 0; fi

PROMPT=$(jq -r '.prompt // ""' < "$TMPFILE")
if [ -z "$PROMPT" ]; then exit 0; fi

# --- Normalize to lowercase ---
LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# === Phase 1: SKIP conditions ===

# Skip slash commands (user already chose explicitly)
case "$LOWER" in
  "/"*) exit 0 ;;
esac

# Skip opt-out markers
case "$LOWER" in
  *"--no-route"*|*"#direct"*) exit 0 ;;
esac

# === Phase 2: CONFLICT resolution (multi-word patterns first) ===
AGENT=""
case "$LOWER" in
  *"pr 리뷰"*|*"pr review"*|*"테스트 코드 리뷰"*)
    AGENT="squad-review" ;;
  *"pr 작성"*|*"pr 만들"*|*"pr 써"*)
    AGENT="squad-gitops" ;;
  *"보안 리뷰"*|*"보안 검토"*|*"security review"*)
    AGENT="squad-audit" ;;
  *"에러 테스트"*|*"빌드 에러"*)
    AGENT="squad-debug" ;;
  *"빌드 확인"*|*"빌드 돌"*)
    AGENT="squad-qa" ;;
  *"코드 정리"*)
    AGENT="squad-refactor" ;;
esac

# === Phase 3: GENERAL keyword matching (if no conflict match) ===
if [ -z "$AGENT" ]; then
  case "$LOWER" in
    # squad-audit (security keywords - high priority)
    *"보안"*|*"security"*|*"취약점"*|*"vulnerab"*|*"audit"*|*"owasp"*|\
    *"시크릿"*|*"secret"*|*"인젝션"*|*"injection"*|*"xss"*|*"csrf"*)
      AGENT="squad-audit" ;;

    # squad-debug (error/bug keywords)
    *"디버그"*|*"debug"*|*"에러"*|*"error"*|*"버그"*|*"bug"*|\
    *"오류"*|*"크래시"*|*"crash"*|*"stack trace"*|*"traceback"*|*"exception"*)
      AGENT="squad-debug" ;;

    # squad-plan (planning keywords)
    *"기획"*|*"plan "*|*"설계해"*|*"와이어프레임"*|*"wireframe"*|\
    *"유저스토리"*|*"user story"*|*"브레인스토밍"*|*"brainstorm"*|\
    *"스펙"*|*"spec"*|*"요구사항"*|*"구현 계획"*)
      AGENT="squad-plan" ;;

    # squad-refactor (refactoring keywords)
    *"리팩토링"*|*"리팩터"*|*"refactor"*|*"클린업"*|*"cleanup"*|*"clean up"*|\
    *"추출"*|*"extract"*|*"중복 제거"*|*"코드 개선"*|*"함수 분리"*|*"컴포넌트 분리"*)
      AGENT="squad-refactor" ;;

    # squad-docs (documentation keywords)
    *"문서"*|*"document"*|*"readme"*|*"리드미"*|\
    *"jsdoc"*|*"tsdoc"*|*"주석"*|*"comment"*|*"문서화"*)
      AGENT="squad-docs" ;;

    # squad-gitops (git operation keywords)
    *"커밋"*|*"commit"*|*"체인지로그"*|*"changelog"*|\
    *"릴리즈 노트"*|*"release note"*|*"conventional"*)
      AGENT="squad-gitops" ;;

    # squad-qa (test/verification keywords)
    *"테스트"*|*"test"*|*"qa"*|*"검증"*|\
    *"린트"*|*"lint"*|*"타입체크"*|*"type check"*|*"리그레션"*|*"regression"*)
      AGENT="squad-qa" ;;

    # squad-review (review keywords - broadest, last)
    *"리뷰"*|*"review"*|*"코드 검토"*|*"검토해"*|*"diff 봐"*)
      AGENT="squad-review" ;;
  esac
fi

# === Output: inject context for Claude ===
if [ -n "$AGENT" ]; then
  echo "[Squad Router] Use the ${AGENT} subagent (via the Agent tool with subagent_type=\"${AGENT}\") to handle this request. The user's prompt matched ${AGENT} keywords. Delegate the full user prompt to this specialized agent."
fi

exit 0
```

### install.sh 변경점

```diff
- SQUAD_HOOKS=(subagent-chain.sh)
+ SQUAD_HOOKS=(subagent-chain.sh squad-router.sh)
```

`register_hook()` 함수에 UserPromptSubmit 등록 블록 추가:

```diff
+  # Register UserPromptSubmit hook (squad-router)
+  local router_cmd="bash ~/.claude/hooks/squad-router.sh"
+  local router_hook='[{"matcher":"","hooks":[{"type":"command","command":"'"$router_cmd"'"}]}]'
+
+  if jq -e '.hooks.UserPromptSubmit' "$settings" &>/dev/null; then
+    green "  UserPromptSubmit hook already registered."
+  else
+    local tmp
+    tmp=$(mktemp)
+    if jq --argjson hook "$router_hook" '.hooks.UserPromptSubmit = $hook' "$settings" > "$tmp" 2>/dev/null; then
+      mv "$tmp" "$settings"
+      green "  UserPromptSubmit hook registered (squad-router)"
+      ((registered++)) || true
+    else
+      rm -f "$tmp"
+    fi
+  fi
```

**주의**: squad-router.sh는 `bash`로 실행 (subagent-chain.sh는 `zsh`). 라우터는 zsh 전용 기능을 사용하지 않으므로 bash로 충분하며, 호환성이 더 넓다.

---

## Open Questions / 미결 사항

### 1. stdout 주입 메시지의 효과 검증 필요
UserPromptSubmit 훅의 stdout이 Claude에게 "추가 컨텍스트"로 정확히 전달되는지, 그리고 Claude가 이를 보고 실제로 Agent 도구를 호출하는지에 대한 실증 테스트가 필요하다. 현재 Claude Code 공식 문서에서 UserPromptSubmit stdout의 동작을 확인해야 한다.

**위험도**: HIGH - 이것이 동작하지 않으면 전체 기능이 무의미
**대안**: stdout이 효과가 없다면, 프롬프트 자체를 변환하는 방식을 고려해야 할 수 있음

### 2. "test" 키워드의 오탐 빈도
"test"는 가장 범용적인 영어 단어 중 하나이다. "I want to test this approach" (QA 의도 아님)에서도 squad-qa가 트리거될 수 있다.

**위험도**: MEDIUM
**대안**: "test" 단독이 아니라 "테스트 돌려", "run test" 같은 복합 패턴만 채택하는 보수적 접근

### 3. 에이전트 description의 PROACTIVELY 키워드와의 관계
현재 각 에이전트의 `description`에 이미 키워드가 포함되어 있어 Claude가 자체적으로 에이전트를 선택하는 경우가 있다. 라우터가 추가되면 이중 라우팅(훅 + Claude 자체 판단)이 발생할 수 있다.

**위험도**: LOW - 동일 에이전트로 라우팅되면 무해, 다른 에이전트로 판단되면 충돌
**대안**: 라우터의 stdout 메시지에 "이 판단을 우선하라"는 지시 포함

### 4. 한글 인코딩 이슈
bash의 case 문에서 한글 패턴 매칭이 모든 환경(macOS, Linux, WSL)에서 동일하게 동작하는지 검증 필요.

**위험도**: LOW - macOS/Linux에서는 UTF-8이 기본이므로 대부분 문제없음
**대안**: 문제 발견 시 grep -q 기반 매칭으로 전환

### 5. 다중 에이전트 매칭 시 사용자 선택권
현재 설계는 first-match-wins로 하나의 에이전트만 선택한다. "리뷰하고 테스트도 돌려줘"처럼 복수 에이전트가 필요한 경우를 처리하지 않는다.

**위험도**: LOW - v1에서는 단일 매칭으로 충분. 복수 매칭은 향후 enhancement
**대안**: 향후 여러 매칭 결과를 나열하고 Claude가 파이프라인을 구성하도록 위임

---

## Wireframe

파일 경로: `docs/wireframes/squad-router-flow.svg`

라우터의 실행 흐름을 시각화한 다이어그램.
