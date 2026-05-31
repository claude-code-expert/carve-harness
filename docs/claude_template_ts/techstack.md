# Tech Stack

> Fill in / trim per project. Defaults assume a TypeScript codebase.

## Core
- **Language**: TypeScript 5.x (`strict: true`)
- **Runtime**: Node.js 20+ (LTS)
- **Package manager**: pnpm (lockfile committed)
- **Module system**: ESM (`"type": "module"`)

## Quality Tooling
- **Lint/format**: ESLint + Prettier (or Biome)
- **Type check**: `tsc --noEmit` in CI
- **Test**: Vitest (unit) + Playwright (e2e, if UI)
- **Validation**: Zod for runtime schema validation at boundaries

## Frontend (if applicable)
- Framework: React 19 / Next.js (App Router) or Vite SPA
- Styling: Tailwind CSS + shadcn/ui
- State/data: Zustand + TanStack Query
- Forms: React Hook Form + Zod

## Backend (if applicable)
- HTTP: Express / Fastify / Hono — pick one, keep it consistent
- DB access: typed query builder or ORM (e.g. Drizzle) — no raw string SQL in app code
- Auth: JWT (stateless) or session — document the choice

## Rules
- No library outside this stack without a stated rationale and user approval.
- Pin major versions; document any upgrade in the changelog.
