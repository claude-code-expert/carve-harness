---
paths: ["**/*.ts", "**/*.tsx"]
---
# React / Next.js / TypeScript 규칙 (자동 로드)

> 자동 로드되는 **규칙 목록**. 코드 샘플·근거·프로젝트 구조는 상세본 참조:
> `.claude/rules/code-convention/dev-stack-{react,nextjs,typescript,orm}.md`
> 최종 정합: 2026-07-07 (React 19 · Next 16 · TS 5 — Context7 검증)

## TypeScript
- [MUST] `tsconfig`에 `"strict": true`. `any` 금지 → `unknown` + 타입 좁히기(narrowing).
- [MUST] 외부 입력은 Zod 등 런타임 검증 후에만 타입 신뢰 (`JSON.parse` 결과 단언 금지).
- [MUST] `@ts-ignore` 금지 → 불가피하면 `@ts-expect-error` + 사유. floating promise 금지(`await`/`void` 명시).
- [SHOULD] `enum` 대신 `as const` 유니온. 타입 전용은 `import type`. 객체=`interface`, 유니온/유틸=`type`. 인터페이스 접두 `I` 금지.

## React (19)
- [MUST] 함수형 컴포넌트 + Hooks만(클래스형 지양). Hooks는 최상위에서만 — 조건·반복문 안 금지.
- [MUST] 리스트 `key`는 안정적 고유 ID (`index` 금지).
- [MUST] props/state 불변 — 직접 변이 금지(새 객체/배열).
- [MUST] `useEffect`는 **외부 시스템 동기화 전용**. 파생값은 렌더 중 계산, **유저 이벤트는 이벤트 핸들러에서**(데이터 변환·이벤트 처리에 Effect 금지). Effect엔 정리(cleanup) 함수.
- [MUST] `dangerouslySetInnerHTML`은 sanitize 후에만 — 미검증 HTML 렌더 금지.
- [SHOULD] 서버 상태 = TanStack Query, 클라 상태 = Zustand — 전역 상태에 서버 데이터 저장 금지.
- [SHOULD] feature 폴더 단방향(`shared → features → app`), cross-feature import 금지(ESLint 강제). 파일당 export 컴포넌트 1개.
- [SHOULD] a11y: 시맨틱 태그·label·alt·키보드 지원. React 19: `ref`=일반 prop(`forwardRef` 불필요), `use()`·Actions 활용.

## Next.js (16 · App Router)
- [MUST] App Router만(Pages Router 혼용 금지). 기본 Server Component, 상호작용 잎(leaf)에만 `'use client'`.
- [MUST] `params`·`searchParams`·`cookies()`·`headers()`는 비동기 → `await`.
- [MUST] 미들웨어 파일명 `proxy.ts`(구 `middleware.ts`).
- [MUST] Server Action·Route Handler 입력은 Zod 검증 + 인증/인가를 서버 경계에서 강제.
- [MUST] 클라 컴포넌트에서 DB·시크릿 모듈 import 금지(`server-only`). 비밀키 `NEXT_PUBLIC_` 노출 금지.
- [SHOULD] mutation = Server Action, 웹훅·외부 호출 = Route Handler. 데이터 fetch는 서버에서 — 클라 `useEffect` 직접 fetch 지양(api client/Query 경유).
- [SHOULD] `loading.tsx`/`error.tsx` 경계, `generateStaticParams`/`generateMetadata` 활용.

## 데이터 / ORM (Drizzle)
- [MUST] N+1 금지 — relational query 또는 명시 join. raw SQL 문자열 보간 금지 → 파라미터 바인딩.
- [MUST] 스키마 변경은 마이그레이션 도구(drizzle-kit)로만, 기존 마이그레이션 파일 수정 금지(새 버전 추가).
- [SHOULD] 대용량 페이지네이션은 offset 대신 cursor(keyset). 공통 컬럼(`id`·`created_at`·`updated_at`·`deleted_at`) 표준화, 타입 추론(`$inferSelect`) 활용.

> 프로젝트별 규칙은 이 아래에 추가한다 (데이터 패칭 경계, 폼 검증 규약, 라우팅 컨벤션 등).
