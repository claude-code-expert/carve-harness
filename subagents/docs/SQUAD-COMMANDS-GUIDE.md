# [Claude Code Expert](https://github.com/claude-code-expert) 서적의 예제 문서 모음

> 📘 [github.com/claude-code-expert](https://github.com/claude-code-expert) — 클로드 코드 마스터 (한빛미디어 서적 공식 리포지토리) <br>  
> ☕ [www.brewnet.dev](https://www.brewnet.dev) — 셀프 호스팅 홈서버 자동 구축 오픈소스
> 한빛미디어 | 2026.04.15 출간 예정

# Squad 서브에이전트 명령어 가이드

https://github.com/claude-code-expert/subagents

9개 슬래시 명령어의 전체 리스트와 실전 사용 예시를 정리한 문서입니다.

---

## 📋 명령어 요약표

| 명령어 | 역할 | 모델 | 파이프라인 위치 |
|--------|------|------|----------------|
| `/squad` | 라우터 (멤버 선택) | - | 진입점 |
| `/squad-plan` | 기획 / 유저스토리 / 와이어프레임 | opus | START |
| `/squad-review` | 코드 리뷰 | - | 구현 후 |
| `/squad-refactor` | 리팩토링 | - | review REQUEST_CHANGES 후 |
| `/squad-qa` | 테스트 / QA | - | review APPROVE 후 |
| `/squad-debug` | 디버깅 / 근본원인 분석 | - | 버그 발생 시 |
| `/squad-docs` | 문서 생성 | - | 어느 시점이나 |
| `/squad-gitops` | 커밋 / PR / 체인지로그 | haiku | qa PASS 후 |
| `/squad-audit` | 보안 감사 | - | 배포 전 |

---

## 🔧 명령어별 상세 사용법

### 1. `/squad` — 라우터

첫 단어를 키워드(`review`, `plan`, `refactor`, `qa`, `debug`, `docs`, `gitops`, `audit`)로 파싱하여 해당 서브에이전트를 호출합니다.

**문법**: `/squad <member> [task]`

```bash
/squad review
# → squad-review 호출 (범위: 최근 커밋)

/squad refactor src/utils/
# → squad-refactor에 src/utils/ 스코프 전달

/squad debug "TypeError: undefined"
# → squad-debug에 에러 메시지 전달

/squad plan 결제 화면
# → squad-plan에 기획 요청 전달
```

---

### 2. `/squad-plan <feature>` — 기획

**출력물**
- 유저 스토리 (US-001, US-002 …)
- 와이어프레임 (SVG/HTML, `docs/wireframes/` 저장)
- 구현 계획 (태스크 순서 + 복잡도 S/M/L/XL)

**금지 사항**: 소스 코드 수정, git 커밋

```bash
/squad-plan 사용자 로그인 (OAuth + 2FA)
# → docs/wireframes/login.svg 생성
# → 유저 스토리 5개 + 구현 순서 10단계

/squad-plan 장바구니 체크아웃 화면
# → 모바일 375x812 뷰포트 와이어프레임
# → "빈 장바구니" 엣지 케이스 포함

/squad-plan 관리자 대시보드 — 실시간 주문 현황
# → 권한 체크, WebSocket vs Polling 등 기술 고려사항 포함
```

---

### 3. `/squad-review [scope]` — 코드 리뷰

**검사 항목**: 보안, 성능, 유지보수성, 스타일
**결과**: `APPROVE` → `/squad-qa`, `REQUEST_CHANGES` → `/squad-refactor`

```bash
/squad-review
# 기본값: 최근 커밋 diff 리뷰

/squad-review src/auth/
# 특정 디렉터리 전체 리뷰

/squad-review HEAD~3..HEAD
# 최근 3개 커밋 묶어서 리뷰

/squad-review PR #42
# 특정 PR 스코프 리뷰
```

---

### 4. `/squad-refactor [scope]` — 리팩토링

**작업 범위**: 파일 / 디렉터리 / 모듈 단위까지
**주의**: 테스트 실행 안 함 → `/squad-qa`로 위임

```bash
/squad-refactor
# 기본값: 최근 커밋 diff 리팩토링

/squad-refactor src/utils/helpers.js
# 특정 파일 단위 리팩토링

/squad-refactor payments 모듈 중복 제거
# 자연어로 스코프 + 목표 명시

/squad-refactor src/api/ — 긴 함수 분리 위주로
# 리팩토링 방향 지정
```

---

### 5. `/squad-qa [scope]` — 테스트 실행

**결과**: `PASS` / `FAIL` 리포트
**PASS 후 다음**: `/squad-gitops`

```bash
/squad-qa
# 기본값: 최근 변경사항 전체 테스트

/squad-qa tests/auth/
# 인증 테스트 디렉터리만

/squad-qa "결제 플로우 E2E만 검증"
# 자연어로 검증 범위 지정

/squad-qa unit
# 유닛 테스트만 실행 (integration 제외)
```

---

### 6. `/squad-debug <error>` — 디버깅

**출력**: 근본 원인 분석 + 권장 수정안 (설명만, 코드 수정 X)

```bash
/squad-debug "TypeError: Cannot read property 'id' of undefined at UserService.js:42"
# → 스택 추적, 원인 분석, 수정안 제시

/squad-debug
Error: EADDRINUSE: address already in use :::3000
    at Server.setupListenHandle [as _listen2]
# → 포트 점유 프로세스 확인 절차 안내

/squad-debug "로그인 후 화이트스크린, 콘솔 에러 없음"
# → 디버깅 단서 질문 + 용의점 리스트

/squad-debug logs/app.log
# → 로그 파일 분석
```

---

### 7. `/squad-docs [type]` — 문서 생성

**타입**: `readme` / `api` / `architecture` / `jsdoc`

```bash
/squad-docs readme
# → README.md 생성 또는 갱신

/squad-docs api
# → API 레퍼런스 (엔드포인트, 파라미터, 응답)

/squad-docs architecture
# → 시스템 아키텍처 다이어그램 + 설명

/squad-docs jsdoc src/services/
# → services/ 아래 파일에 JSDoc 주석 추가
```

---

### 8. `/squad-gitops [type]` — Git 워크플로우

**타입**: `commit` / `pr` / `changelog` / `release-notes`
**중요**: 메시지만 생성, `git commit`/`push`는 사용자가 직접 실행

```bash
/squad-gitops commit
# → Conventional Commit 메시지 생성
# 예: "feat(auth): add OAuth2 login flow"

/squad-gitops pr
# → PR 제목 + 본문 (What / Changes / How to Test / Checklist)

/squad-gitops changelog
# → CHANGELOG.md 갱신 (Keep a Changelog 포맷)

/squad-gitops release-notes v1.3.2
# → 사용자 친화적 릴리즈 노트
```

**생성되는 커밋 메시지 포맷**
```
type(scope): subject (50자 이내)

body (72자 래핑)

footer (BREAKING CHANGE, Closes #issue)
```

---

### 9. `/squad-audit [scope]` — 보안 감사

**검사**: 시크릿 노출, OWASP Top 10, 의존성 CVE, 인증/권한

```bash
/squad-audit
# 기본값: 전체 프로젝트 스캔

/squad-audit src/api/
# 특정 경로 집중 감사

/squad-audit "OWASP Top 10에 집중해서"
# 포커스 영역 지정

/squad-audit .env, config/
# 시크릿 노출 검사 우선
```

---

## 🔄 권장 파이프라인

### 표준 기능 개발 플로우

```
/squad-plan 새기능
    ↓ (유저스토리 + 와이어프레임 + 계획)
[사용자 구현]
    ↓
/squad-review
    ├─ APPROVE      → /squad-qa
    │                  ├─ PASS → /squad-gitops commit → /squad-gitops pr
    │                  └─ FAIL → /squad-debug → 수정 → /squad-qa
    └─ REQUEST_CHANGES → /squad-refactor → /squad-review (재검증)
    ↓
[배포 전]
/squad-audit
```

### 버그 수정 플로우

```
버그 리포트
    ↓
/squad-debug "에러 메시지"
    ↓ (근본원인 + 수정안)
[사용자 수정]
    ↓
/squad-qa
    ↓ PASS
/squad-gitops commit
```

### 문서화 플로우

```
언제든지:
/squad-docs readme
/squad-docs api
/squad-docs architecture
```

---

## 💡 실전 시나리오 예시

### 시나리오 A: 새 기능 "비밀번호 재설정" 개발

```bash
# 1단계: 기획
/squad-plan 비밀번호 재설정 (이메일 토큰 방식)
# → docs/wireframes/password-reset.svg
# → US-001 ~ US-004, 구현 8단계

# 2단계: 구현 (사용자 직접)

# 3단계: 리뷰
/squad-review
# → REQUEST_CHANGES: 토큰 만료 시간 하드코딩 발견

# 4단계: 리팩토링
/squad-refactor src/auth/password-reset.js — 토큰 설정 외부화

# 5단계: 재리뷰
/squad-review
# → APPROVE

# 6단계: 테스트
/squad-qa tests/auth/password-reset.test.js
# → PASS

# 7단계: 커밋 + PR
/squad-gitops commit
/squad-gitops pr

# 8단계: 배포 전 보안 감사
/squad-audit src/auth/
```

### 시나리오 B: 프로덕션 버그 긴급 대응

```bash
# 1단계: 증상 분석
/squad-debug "500 Internal Server Error on /api/orders after 5 min idle"
# → DB 커넥션 풀 타임아웃 의심 + 확인 방법 제시

# 2단계: 사용자가 로그 확인 후 재진단
/squad-debug logs/production-2026-04-17.log
# → 근본원인: keepalive 설정 누락, 수정안 제시

# 3단계: 수정 후 테스트
/squad-qa "DB 커넥션 재연결 시나리오"

# 4단계: hotfix 커밋
/squad-gitops commit
# → "fix(db): add connection keepalive to prevent idle timeout"
```

### 시나리오 C: 레거시 코드 정리 스프린트

```bash
# 1단계: 전체 감사
/squad-audit
# → 시크릿 3건, 구버전 의존성 5건 발견

# 2단계: 리팩토링 대상 식별
/squad-review src/legacy/
# → REQUEST_CHANGES: 긴 함수 7개, 중복 로직 3건

# 3단계: 모듈 단위 리팩토링
/squad-refactor src/legacy/order-processor.js
/squad-refactor src/legacy/inventory.js

# 4단계: 테스트
/squad-qa src/legacy/

# 5단계: 문서 갱신
/squad-docs architecture

# 6단계: 변경사항 기록
/squad-gitops changelog
```

### 시나리오 D: 라우터로 빠르게 호출

```bash
# 긴 명령어 대신 /squad 한 번으로
/squad plan 알림 센터
/squad review
/squad qa tests/
/squad debug "NullPointerException at line 42"
/squad gitops commit
```

---

## 🚫 각 에이전트의 경계 (공통 원칙)

모든 squad 에이전트는 다음을 **절대 하지 않습니다**:

- `git commit`, `git push` 직접 실행 (사용자 결정)
- `rm`, `mv` 등 파괴적 명령 실행
- 자기 역할을 벗어난 작업 수행

역할 간 위임은 명확합니다:

| 할 일 | 담당 |
|-------|------|
| 코드 수정 | `/squad-refactor` |
| 테스트 실행 | `/squad-qa` |
| 커밋/PR 메시지 | `/squad-gitops` |
| 문서 작성 | `/squad-docs` |
| 기획/와이어프레임 | `/squad-plan` |
| 보안 스캔 | `/squad-audit` |
| 근본원인 분석 | `/squad-debug` |
| 품질 검증 | `/squad-review` |

---

## 📚 관련 문서

- [ARCHITECTURE.md](./ARCHITECTURE.md) — 전체 시스템 구조
- [SQUAD-KEYWORD-MAP.md](./SQUAD-KEYWORD-MAP.md) — 한/영 트리거 키워드 매핑
- [SQUAD-ROUTER-KEYWORDS.md](./SQUAD-ROUTER-KEYWORDS.md) — 라우터 키워드 규칙
- [pipeline-diagram.svg](./pipeline-diagram.svg) — 파이프라인 시각화
