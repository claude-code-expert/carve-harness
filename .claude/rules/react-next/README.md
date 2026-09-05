# `.claude/rules/react-next/` — TS/React/Next 규칙 (typescript 팩)

`**/*.ts`·`**/*.tsx`를 열면 자동 로드. `typescript` 언어팩과 함께 설치.

| 파일 | glob | 내용 |
|---|---|---|
| `patterns.md` | `**/*.ts,tsx` | TS strict·Zod 검증 · React Hooks·key·서버상태 분리 · Next App Router · Drizzle N+1 |

## 사용방법
- 자동 로드. 상세본은 `docs/rules/code-convention/dev-stack-{typescript,react,nextjs,javascript,orm}.md`.
- 프로젝트 규칙(데이터 패칭 경계·폼 검증 등)은 파일 하단에 append.

> 최종 정합: React 19 · Next 16 · TS 5.
