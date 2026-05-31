# codesight 완전 가이드

> AI 어시스턴트가 프로젝트를 탐색하느라 낭비하는 수만 토큰을 단 하나의 명령어로 해결하는  
> **범용 AI 컨텍스트 생성기**

- **GitHub:** https://github.com/Houseofmvps/codesight
- **npm:** `npx codesight` (설치 불필요, 즉시 실행)
- **라이선스:** MIT
- **요구 사항:** Node.js >= 18 / 의존성 0개

---

## 목차

1. [codesight란?](#1-codesight란)
2. [⚡ 핵심 질문: Claude Code 실행하면 자동 적용되나?](#2--핵심-질문-claude-code-실행하면-자동-적용되나)
3. [설치 및 기본 실행](#3-설치-및-기본-실행)
4. [전체 명령어 레퍼런스](#4-전체-명령어-레퍼런스)
5. [생성 파일 구조 및 내용](#5-생성-파일-구조-및-내용)
6. [Claude Code 연동 3가지 방법](#6-claude-code-연동-3가지-방법)
7. [MCP 서버 설정 (가장 강력)](#7-mcp-서버-설정-가장-강력)
8. [자동화 방법 (Watch / Git Hook / CI)](#8-자동화-방법-watch--git-hook--ci)
9. [Blast Radius 분석](#9-blast-radius-분석)
10. [지원 스택 전체 목록](#10-지원-스택-전체-목록)
11. [실전 활용 시나리오](#11-실전-활용-시나리오)
12. [토큰 절약 벤치마크](#12-토큰-절약-벤치마크)

---

## 1. codesight란?

AI 코딩 어시스턴트(Claude Code, Cursor, Copilot 등)는 새 대화를 시작할 때마다 프로젝트 구조를 파악하기 위해 수만 토큰을 소비한다. codesight는 이 탐색 비용을 없애기 위해 **프로젝트 전체를 한 번에 분석해 구조화된 마크다운 컨텍스트 맵**을 생성한다.

### 핵심 수치 (실제 프로젝트 측정값)

| 프로젝트 | 스택 | AI 탐색 비용 | codesight 출력 | 절약 |
|---|---|---|---|---|
| SaveMRR | Hono + Drizzle | 66,040 토큰 | 5,129 토큰 | **12.9배** |
| BuildRadar | HTTP + Drizzle | 46,020 토큰 | 3,945 토큰 | **11.7배** |
| RankRev | Hono + Drizzle | 26,130 토큰 | 2,865 토큰 | **9.1배** |

**평균 11.2배 토큰 절약 / 스캔 시간 185~290ms**

### 무엇을 감지하는가?

8개의 병렬 분석기가 동시에 실행된다:

| 분석기 | 감지 내용 |
|---|---|
| Routes | 25개 이상 프레임워크의 API 라우트 (메서드, 경로, 파라미터, 관련 서비스) |
| Schema | 8개 ORM의 DB 모델 (필드, 타입, PK/FK, 관계) |
| Components | React/Vue/Svelte 컴포넌트 및 Props |
| Dep Graph | 임포트 그래프 및 변경 위험도 높은 파일 |
| Middleware | Auth, Rate limiting, CORS, Validation 등 |
| Config | 환경변수 (required vs default, 참조 파일) |
| Libraries | 함수 시그니처 포함 라이브러리 내보내기 |
| Contracts | URL 파라미터, 요청/응답 타입 |

---

## 2. ⚡ 핵심 질문: Claude Code 실행하면 자동 적용되나?

> **결론: 자동 적용되지 않는다. 단, 3가지 방법으로 자동화할 수 있다.**

### 작동 원리 이해

```
[codesight 실행]
      │
      ▼
  프로젝트 분석 (AST + Regex)
      │
      ▼
.codesight/ 폴더 생성
├── CODESIGHT.md  ← 전체 컨텍스트 맵
├── routes.md
├── schema.md
└── ...

     +  --init 옵션 시:
      ▼
CLAUDE.md         ← Claude Code가 시작 시 자동 로딩
.cursorrules      ← Cursor가 자동 로딩
codex.md          ← Codex가 자동 로딩
AGENTS.md         ← OpenAI 에이전트가 자동 로딩
```

### 시나리오별 동작 정리

| 시나리오 | 동작 |
|---|---|
| `claude` 그냥 실행 (codesight 미설치) | ❌ codesight 전혀 적용 안 됨 |
| `npx codesight` 실행 후 `claude` 실행 | ⚠️ `.codesight/` 파일만 생성됨. Claude가 자동으로 읽지는 않음 |
| `npx codesight --init` 후 `claude` 실행 | ✅ `CLAUDE.md` 생성 → Claude Code 시작 시 자동 로딩 |
| `npx codesight --mcp` 으로 MCP 서버 실행 | ✅ Claude Code가 필요할 때 직접 API로 쿼리 (가장 강력) |
| `npx codesight --hook` 설치 후 | ✅ git commit마다 자동 재생성 |
| `npx codesight --watch` 실행 중 | ✅ 파일 변경 감지 → 자동 재스캔 |

### 가장 빠른 적용 방법 (2단계)

```bash
# 프로젝트 루트에서:
npx codesight --init    # CLAUDE.md, .cursorrules, AGENTS.md 생성
claude                  # Claude Code 시작 → CLAUDE.md 자동 로딩
```

---

## 3. 설치 및 기본 실행

### 설치 불필요 — npx 즉시 실행

```bash
# 프로젝트 루트로 이동 후 실행
cd /your/project
npx codesight
```

처음 실행 시 `.codesight/` 폴더가 생성되고 분석 결과가 저장된다.

```
Analyzing... done (AST: 60 routes, 18 models, 16 components)
Output: .codesight/CODESIGHT.md
```

### 글로벌 설치 (선택)

자주 쓴다면 전역 설치가 편하다:

```bash
npm install -g codesight

# 이후 어디서든:
codesight
codesight --init
codesight --mcp
```

### 특정 디렉토리 스캔

```bash
npx codesight ./my-project
npx codesight /absolute/path/to/project
```

---

## 4. 전체 명령어 레퍼런스

### 기본 스캔

```bash
npx codesight                          # 현재 디렉토리 스캔 → .codesight/ 생성
npx codesight ./my-project             # 특정 디렉토리 스캔
npx codesight -o .ai-context           # 출력 폴더 이름 변경 (기본: .codesight)
npx codesight -d 5                     # 디렉토리 탐색 깊이 제한
npx codesight --json                   # JSON 포맷으로 출력
```

### AI 설정 파일 생성

```bash
npx codesight --init                   # 모든 AI 도구용 설정 파일 생성
                                       # → CLAUDE.md, .cursorrules,
                                       #   .github/copilot-instructions.md,
                                       #   codex.md, AGENTS.md

npx codesight --profile claude-code    # Claude Code 전용 최적화 파일만 생성
npx codesight --profile cursor         # Cursor 전용
npx codesight --profile codex          # OpenAI Codex 전용
npx codesight --profile copilot        # GitHub Copilot 전용
npx codesight --profile windsurf       # Windsurf 전용
```

### 분석 및 시각화

```bash
npx codesight --blast src/lib/db.ts    # 특정 파일 변경 시 영향 범위 분석
npx codesight --benchmark              # 토큰 절약 상세 분석 출력
npx codesight --open                   # 브라우저로 인터랙티브 HTML 대시보드 열기
npx codesight --html                   # HTML 리포트 생성 (열지 않음)
```

### 자동화

```bash
npx codesight --mcp                    # MCP 서버 실행 (8개 도구)
npx codesight --watch                  # Watch 모드 (파일 변경 시 자동 재스캔)
npx codesight --hook                   # git pre-commit hook 설치
```

---

## 5. 생성 파일 구조 및 내용

```
.codesight/
├── CODESIGHT.md      # 전체 프로젝트 컨텍스트 맵 (메인 파일)
├── routes.md         # 모든 API 라우트 (메서드, 경로, 파라미터, 관련 서비스)
├── schema.md         # 모든 DB 모델 (필드, 타입, 키, 관계)
├── components.md     # UI 컴포넌트 및 Props
├── libs.md           # 라이브러리 내보내기 및 함수 시그니처
├── config.md         # 환경변수 및 설정 파일
├── middleware.md     # 미들웨어 목록 (인증, CORS, 검증 등)
├── graph.md          # 임포트 그래프 및 고위험 파일
└── report.html       # 인터랙티브 시각화 대시보드
```

### CODESIGHT.md 실제 출력 예시 (routes.md)

```markdown
## API Routes (60 total)

- `GET` `/dashboard/me` [auth, db, cache, payment, ai]
- `PUT` `/dashboard/me` [auth, db, cache, payment, ai]
- `POST` `/dashboard/generate-reply` [auth, db, cache, payment, ai]
- `POST` `/webhooks/polar` [db, payment]
- `GET` `/health` [auth, db, cache, payment, ai]
```

### schema.md 실제 출력 예시

```markdown
### user
- id: text (pk)
- name: text (required)
- email: text (unique, required)
- tier: text (default, required)
- polarCustomerId: text (fk)

### monitor
- id: text (default, pk)
- userId: text (fk, required)
- keywords: jsonb (required)
- _relations_: userId -> user.id
```

### graph.md 실제 출력 예시

```markdown
## Most Imported Files (change these carefully)
- `src/types/index.ts` — imported by **20** files
- `src/core/composio-auth.ts` — imported by **6** files
- `src/db/index.ts` — imported by **5** files
- `src/intelligence/patterns.ts` — imported by **5** files
```

---

## 6. Claude Code 연동 3가지 방법

### 방법 1: CLAUDE.md 자동 생성 (가장 간단)

```bash
npx codesight --init
```

생성된 `CLAUDE.md`에는 프로젝트 스택, 아키텍처, 고위험 파일, 필수 환경변수가 포함된다.
Claude Code는 시작 시 `CLAUDE.md`를 자동으로 로딩한다.

**업데이트 방법:** 코드가 크게 바뀌면 다시 실행:
```bash
npx codesight --init
```

**Claude Code 시작 후 컨텍스트 확인:**
```
> 이 프로젝트의 주요 API 라우트는 뭐야?
# → CLAUDE.md를 이미 읽었으므로 바로 답변 가능
```

---

### 방법 2: MCP 서버 (가장 강력, 실시간)

Claude Code가 직접 codesight MCP 서버에 쿼리를 날린다. 필요한 정보만 요청하므로 토큰 효율이 가장 높다.

→ [다음 섹션: MCP 서버 설정](#7-mcp-서버-설정-가장-강력) 참조

---

### 방법 3: `.codesight/` 파일 수동 참조

`--init` 없이 기본 스캔만 했을 때 Claude Code에 직접 지시:

```
# Claude Code 채팅에서:
> .codesight/CODESIGHT.md 파일을 읽고 프로젝트 구조를 파악해줘
> .codesight/routes.md를 바탕으로 인증 관련 라우트만 정리해줘
> .codesight/schema.md 보고 user 모델에 필드 추가해줘
```

---

## 7. MCP 서버 설정 (가장 강력)

### Claude Code MCP 설정

`~/.claude/settings.json` 또는 프로젝트 `.claude/settings.json`에 추가:

```json
{
  "mcpServers": {
    "codesight": {
      "command": "npx",
      "args": ["codesight", "--mcp"]
    }
  }
}
```

설정 후 Claude Code 재시작 → 자동으로 MCP 서버 연결.

### 사용 가능한 8개 MCP 도구

| 도구 | 설명 | 토큰 |
|---|---|---|
| `codesight_scan` | 프로젝트 전체 스캔 | ~3K-5K |
| `codesight_get_summary` | 압축 요약 | ~500 |
| `codesight_get_routes` | prefix/tag/method 필터링된 라우트 | 필요한 것만 |
| `codesight_get_schema` | 모델명 필터링된 스키마 | 필요한 것만 |
| `codesight_get_blast_radius` | 파일 변경 전 영향 범위 분석 | ~300 |
| `codesight_get_env` | 환경변수 목록 (required 필터 가능) | ~100 |
| `codesight_get_hot_files` | 고위험 파일 목록 | ~200 |
| `codesight_refresh` | 강제 재스캔 (세션 캐시 갱신) | - |

> **세션 캐싱:** 첫 호출 시 스캔, 이후 호출은 캐시에서 즉시 반환

### Claude Code에서 MCP 도구 직접 호출 예시

```
# 변경 전 영향도 확인
> src/db/index.ts를 수정하기 전에 blast radius 확인해줘
# → codesight_get_blast_radius 자동 호출

# 특정 도메인 라우트만 조회
> 인증 관련 라우트만 보여줘
# → codesight_get_routes(tag: "auth") 호출

# 스키마 조회
> user 모델 구조 알려줘
# → codesight_get_schema(model: "user") 호출
```

---

## 8. 자동화 방법 (Watch / Git Hook / CI)

### Watch 모드 — 파일 변경 시 자동 재스캔

```bash
npx codesight --watch
```

파일을 저장할 때마다 자동으로 `.codesight/` 파일이 업데이트된다.
개발 중 별도 터미널에 띄워두면 항상 최신 상태 유지.

```bash
# 터미널 A: 개발 서버
npm run dev

# 터미널 B: codesight watch
npx codesight --watch
```

---

### Git Hook — 커밋마다 자동 재생성

```bash
npx codesight --hook
```

`.git/hooks/pre-commit`에 자동 설치된다. 이후 `git commit` 실행 시마다:
1. codesight 자동 실행
2. `.codesight/` 파일 재생성
3. 업데이트된 파일 커밋에 포함

**팀 전체가 항상 최신 컨텍스트를 공유할 수 있다.**

---

### GitHub Actions — CI/CD에서 자동 생성

```yaml
# .github/workflows/codesight.yml
name: codesight
on: [push]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm install -g codesight && codesight
      - uses: actions/upload-artifact@v4
        with:
          name: codesight
          path: .codesight/
```

푸시마다 `.codesight/` 파일이 자동 생성되어 아티팩트로 저장된다.

---

### 자동화 방법 비교 요약

| 방법 | 언제 실행 | 적합한 상황 |
|---|---|---|
| `--init` 수동 실행 | 수동 | 큰 구조 변경 후 1회 |
| `--watch` | 파일 저장마다 | 개발 중 실시간 |
| `--hook` | git commit마다 | 팀 협업, 항상 최신 보장 |
| `--mcp` | AI 요청마다 | 토큰 최적화 최우선 |
| GitHub Action | push마다 | CI/CD 파이프라인 |

---

## 9. Blast Radius 분석

파일 변경 전에 영향 범위를 미리 파악하는 기능.

```bash
npx codesight --blast src/db/index.ts
```

실제 출력 예시 (BuildRadar 프로젝트):

```
Blast Radius: src/db/index.ts
Depth: 3 hops

Affected files (10):
  src/api/dashboard.ts
  src/api/webhooks.ts
  src/auth/session.ts
  src/monitor/daily-digest.ts
  src/monitor/scanner.ts
  src/server.ts
  ...

Affected routes (33):
  GET /dashboard/me — src/api/dashboard.ts
  PUT /dashboard/me — src/api/dashboard.ts
  POST /webhooks/polar — src/api/webhooks.ts
  ...

Affected models: user, session, account, reddit_credentials,
  monitor, scan_result, lead, ...
```

**BFS(너비 우선 탐색)로 임포트 그래프를 3단계까지 추적.**

Claude Code + MCP 연동 시:
```
> src/db/index.ts 수정하기 전에 blast radius 먼저 보여줘
# → AI가 자동으로 codesight_get_blast_radius 호출
```

---

## 10. 지원 스택 전체 목록

### 라우트 감지 (25개 이상 프레임워크)

**JavaScript/TypeScript:**  
Hono, Express, Fastify, Next.js (App Router + Pages Router), Koa, NestJS, tRPC, Elysia, AdonisJS, SvelteKit, Remix, Nuxt, raw `http.createServer`

**Python:** FastAPI, Flask, Django

**Go:** net/http, Gin, Fiber, Echo, Chi

**기타:** Rails (Ruby), Phoenix (Elixir), Spring Boot (Java), Actix/Axum (Rust)

### ORM / Schema 감지 (8개)

Drizzle, Prisma, TypeORM, Mongoose, Sequelize, SQLAlchemy, ActiveRecord, Ecto

### 컴포넌트 감지

React (shadcn/ui, Radix 자동 필터링), Vue, Svelte

### 지원 언어

TypeScript, JavaScript, Python, Go, Ruby, Elixir, Java, Kotlin, Rust, PHP

### 모노레포 지원

pnpm / npm / yarn workspaces (크로스 워크스페이스 감지 포함)

---

## 11. 실전 활용 시나리오

### 시나리오 1 — 신규 팀원 온보딩

```bash
# 프로젝트 클론 후
npx codesight --open        # 브라우저로 전체 구조 시각화
npx codesight --benchmark   # 이 프로젝트의 복잡도 파악
```

HTML 대시보드로 라우트, 스키마, 의존성 그래프를 시각적으로 탐색.

---

### 시나리오 2 — Claude Code와 일상 개발 (권장 설정)

```bash
# 1. 최초 1회 설정
npx codesight --init        # CLAUDE.md 생성

# 2. MCP 서버 등록 (claude settings.json)
# → .claude/settings.json에 codesight MCP 추가

# 3. Git hook 설치
npx codesight --hook        # 커밋마다 자동 업데이트

# 4. 이후 claude 실행
claude
# → CLAUDE.md 자동 로딩 + MCP 실시간 쿼리 가능
```

---

### 시나리오 3 — Spring Boot 프로젝트 (코드빌런님 백엔드)

```bash
cd my-spring-project
npx codesight                    # Java/Spring Boot 라우트 + 스키마 감지
npx codesight --profile claude-code  # CLAUDE.md 생성
npx codesight --blast src/main/java/com/example/db/DatabaseConfig.java
# → DB 설정 변경 시 영향 받는 모든 서비스, 컨트롤러 파악
```

---

### 시나리오 4 — 책 집필: Claude Code 챕터 실습 자료

```bash
# 독자들이 실습할 수 있는 예제 프로젝트에 적용
npx codesight --benchmark        # 토큰 절약 수치 → 책 예제로 활용
npx codesight --open             # HTML 대시보드 스크린샷 → 책 삽입용
npx codesight --json > codesight-output.json  # JSON으로 추가 가공
```

---

### 시나리오 5 — 멀티 프로젝트 관리

```bash
# 각 프로젝트마다 독립적으로 실행
cd ~/projects/project-a && npx codesight --init
cd ~/projects/project-b && npx codesight --init
cd ~/projects/project-c && npx codesight --init

# 각 프로젝트 루트에 CLAUDE.md 존재
# → Claude Code가 어떤 프로젝트에서 열리든 자동 컨텍스트 로딩
```

---

### 시나리오 6 — 환경변수 감사

```bash
npx codesight --blast .env
# 또는 MCP 서버에서:
# codesight_get_env(required_only: true)
```

실제 출력 예시:
```
- `DATABASE_URL` **required** — .env.example
- `ANTHROPIC_API_KEY` **required** — src/api/ai.ts
- `JWT_SECRET` **required** — src/auth/session.ts
- `REDIS_URL` (has default) — src/core/cache.ts
```

---

## 12. 토큰 절약 벤치마크

```bash
npx codesight --benchmark
```

항목별 절약 근거:

| 감지 항목 | 항목당 절약 토큰 | 이유 |
|---|---|---|
| 라우트 1개 | ~400 토큰 | AI가 핸들러 파일 읽기 + 경로 grep + 미들웨어 확인 |
| 스키마 모델 1개 | ~300 토큰 | ORM 파일 열기 + 필드 수동 파싱 |
| 컴포넌트 1개 | ~250 토큰 | 컴포넌트 파일 열기 + Props 타입 읽기 |
| 라이브러리 내보내기 1개 | ~200 토큰 | export grep + 시그니처 읽기 |
| 환경변수 1개 | ~100 토큰 | process.env grep + .env 파일 읽기 |
| 파일 스캔 1개 | ~80 토큰 | glob/grep 작업 |

**1.3배 보정:** AI가 멀티턴 대화에서 같은 파일을 재방문하는 비용.

---

## 빠른 시작 체크리스트

```bash
# 1단계: 프로젝트 루트에서 스캔
npx codesight

# 2단계: Claude Code용 설정 파일 생성
npx codesight --init

# 3단계: MCP 서버 등록 (.claude/settings.json)
# { "mcpServers": { "codesight": { "command": "npx", "args": ["codesight", "--mcp"] } } }

# 4단계: git hook 설치 (자동 업데이트)
npx codesight --hook

# 5단계: Claude Code 실행
claude
```

이후 코드를 수정하고 커밋할 때마다 `.codesight/`와 `CLAUDE.md`가 자동 갱신된다.

---

## 관련 링크

- **GitHub:** https://github.com/Houseofmvps/codesight
- **npm:** https://www.npmjs.com/package/codesight
- **같은 개발자의 다른 도구:**
  - ultraship — Claude Code 전용 39개 전문 스킬
  - claude-rank — Claude Code SEO/GEO/AEO 플러그인

---

*MIT License — Kailesk Khumar / houseofmvps.com*
