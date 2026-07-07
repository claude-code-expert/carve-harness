# Next.js 개발 스택 가이드 (Next.js 16 · App Router)

> **용도**: Claude Code 프로젝트의 `CLAUDE.md` · `.claude/rules/` · `.claude/skills/` 참조용 코딩 표준
> **대상**: 개발을 시작하는 비전공·직장인 → 실무 진입 단계
> **최종 검증일**: 2026-07-06 (KST) · 기준 버전 **Next.js 16.2.x**

---

## 0. 결론 먼저 — 핵심 규칙 Top 10

| # | 규칙 | 수준 |
|---|------|------|
| 1 | 신규 프로젝트는 **App Router**(`app/`)만 사용, Pages Router 혼용 금지 | MUST |
| 2 | 기본은 **Server Component**, 상호작용 필요한 잎(leaf)에만 `'use client'` | MUST |
| 3 | `params`·`searchParams`·`cookies()`·`headers()`는 **비동기 → await** | MUST |
| 4 | 미들웨어 파일명은 **`proxy.ts`** (구 `middleware.ts` 대체) | MUST |
| 5 | 폼 변경(mutation)은 **Server Actions**, 외부 호출/웹훅은 **Route Handler** | SHOULD |
| 6 | 데이터 fetch는 서버에서, 클라 `useEffect` fetch 지양 | SHOULD |
| 7 | 동적 라우트는 `generateStaticParams`, 메타데이터는 `generateMetadata` | SHOULD |
| 8 | `loading.tsx`/`error.tsx`로 로딩·에러 경계 구성 | SHOULD |
| 9 | 서버 전용 모듈은 클라 컴포넌트에서 import 금지(`server-only`) | MUST |
| 10 | 환경변수 클라 노출은 `NEXT_PUBLIC_` 접두만, 비밀키는 서버만 | MUST |

---

## 1. 스택 & 버전 (2026 기준)

| 항목 | 값 | 근거 |
|------|-----|------|
| Next.js | 16.2.x (공식 문서 표기 16.2.10, 2026-06 기준) | nextjs.org 문서 |
| React | 19.2 | Next 16 번들 |
| 번들러 | Turbopack (dev 기본) | Next 16 |
| 라우팅 | App Router (RSC 기반) | 기본값 |
| 미들웨어 | `proxy.ts` | Next 16 rename |

> 프로덕션 빌드 번들러/캐시(Cache Components·PPR) 세부는 릴리스마다 변동 → 배포 전 공식 릴리스 노트 재확인 권장.

---

## 2. 프로젝트 구조 (App Router 규약)

```
app/
├── layout.tsx        # 루트 레이아웃(필수, <html><body> 포함)
├── page.tsx          # '/' 페이지
├── loading.tsx       # 로딩 UI(Suspense 자동 래핑)
├── error.tsx         # 에러 경계('use client' 필수)
├── (marketing)/      # 라우트 그룹: URL에 미포함
├── blog/
│   └── [slug]/page.tsx   # 동적 세그먼트
└── api/
    └── users/route.ts    # Route Handler(GET/POST 등)
proxy.ts              # 미들웨어(구 middleware.ts)
```

- `[seg]` 단일 · `[...seg]` catch-all · `[[...seg]]` 옵셔널 catch-all
- `(group)` 라우트 그룹, `_folder` private 폴더(URL 미포함)

출처: Next.js 공식 Project Structure 문서.

---

## 3. 서버/클라이언트 경계 (가장 중요)

| 상황 | 선택 |
|------|------|
| 데이터 조회·렌더 | Server Component(기본) |
| 상태·이벤트·브라우저 API | Client Component(`'use client'`) |
| 폼 생성/수정/삭제 | Server Action |
| 외부 서비스가 호출하는 엔드포인트·웹훅·파일 업로드 | Route Handler |

`'use client'`는 **가능한 한 잎 컴포넌트에만**. 상위에 붙이면 하위 전체가 클라 번들에 포함.

---

## 4. 베스트 프랙티스 (검증된 코드 샘플)

### 4.1 async params (Next 16 — await 필수)

```tsx
// app/blog/[slug]/page.tsx
export default async function BlogPost({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params; // Next 16: params는 Promise
  const post = await getPost(slug);
  return <article>{post.title}</article>;
}
```

### 4.2 서버 컴포넌트에서 직접 데이터 fetch

```tsx
// 서버에서 실행 — 클라 번들 0, useEffect 불필요
export default async function Page() {
  const users = await db.query.users.findMany();
  return <UserList users={users} />;
}
```

### 4.3 Route Handler (JSON API)

```tsx
// app/api/users/route.ts
import { NextResponse } from 'next/server';

export async function GET() {
  const users = await getUsers();
  return NextResponse.json({ data: users });
}
```

### 4.4 generateMetadata (SEO)

```tsx
import type { Metadata } from 'next';

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const post = await getPost(slug);
  return { title: post.title, description: post.excerpt };
}
```

### 4.5 서버 전용 코드 보호

```tsx
import 'server-only'; // 클라에서 import 시 빌드 에러
export const dbSecret = process.env.DB_SECRET;
```

---

## 5. 안티패턴 (금지)

| 안티패턴 | 문제 | 대안 |
|---------|------|------|
| 최상위 `'use client'` | 전체 클라 번들화 | 잎에만 |
| App/Pages Router 혼용 | 규약·캐시 충돌 | 하나로 통일 |
| `params`를 await 없이 사용 | Next 16에서 런타임 오류 | `await params` |
| 클라에서 `useEffect` fetch 방치 | 워터폴·경쟁상태 | 서버 fetch/Query |
| Server Action에서 인증·권한 검증 생략 | 보안 취약 | 액션마다 인가 검사 |
| 비밀키를 `NEXT_PUBLIC_`로 노출 | 클라 유출 | 서버 전용 env |

---

## 6. 엄격한 규칙 (강제 설정)

- **MUST**: 모든 Server Action / Route Handler 입력은 Zod로 검증 후 처리
- **MUST**: 인증/인가는 서버 경계(Action·Handler·Middleware=`proxy.ts`)에서 강제
- **MUST NOT**: 클라 컴포넌트에서 DB/서버 시크릿 모듈 직접 import
- **SHOULD**: 정적 가능 페이지는 `generateStaticParams`로 사전 렌더

---
