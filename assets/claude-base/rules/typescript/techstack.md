# Tech Stack — TypeScript

> Detected stack. Trim/extend to match reality.

## Core
- **Language**: TypeScript 5.x (`strict: true`)
- **Runtime**: Node.js 20+ (LTS)
- **Package manager**: {{PKG_MANAGER}} (lockfile committed)
- **Module system**: ESM (`"type": "module"`)

## Quality Tooling
- **Lint/format**: ESLint + Prettier (or Biome)
- **Type check**: `tsc --noEmit` in CI
- **Test**: Vitest / Jest (unit) + Playwright (e2e, if UI)
- **Validation**: Zod for runtime schema validation at boundaries

## Frontend (if applicable)
- Framework: React / Next.js (App Router) or Vite SPA
- Styling: Tailwind CSS + a headless component lib
- State/data: a store (Zustand/Redux) + TanStack Query
- Forms: React Hook Form + Zod

## Backend (if applicable)
- HTTP: Express / Fastify / Hono — pick one, keep it consistent
- DB access: a typed query builder or ORM (e.g. Drizzle/Prisma) — no raw string SQL in app code
- Auth: JWT (stateless) or session — document the choice

## Rules
- No library outside this stack without a stated rationale and user approval.
- Pin major versions; document any upgrade in the changelog.
