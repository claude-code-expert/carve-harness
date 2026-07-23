# TypeScript 개발 스택 가이드

> **용도**: Claude Code 프로젝트의 `CLAUDE.md` · `.claude/rules/` · `.claude/skills/` 참조용 코딩 표준
> **대상**: 개발을 시작하는 비전공·직장인 → 실무 진입 단계
> **최종 검증일**: 2026-07-06 (KST)

---

## 0. 결론 먼저 — 핵심 규칙 Top 10

| # | 규칙 | 수준 |
|---|------|------|
| 1 | `tsconfig`에 `"strict": true` 필수 | MUST |
| 2 | `any` 금지 → `unknown` + 타입 좁히기(narrowing) | MUST |
| 3 | 타입 단언 `as` 남용 금지(진짜 필요할 때만) | MUST |
| 4 | 객체 형태는 `interface`, 유니온/유틸은 `type` | SHOULD |
| 5 | 함수 반환 타입 명시(공개 API), 내부는 추론 허용 | SHOULD |
| 6 | `enum` 대신 `as const` 객체 또는 유니온 리터럴 | SHOULD |
| 7 | `null`/`undefined`는 옵셔널·nullish로 명시 처리 | MUST |
| 8 | 외부 입력은 런타임 검증(Zod 등) 후 타입 신뢰 | MUST |
| 9 | `@ts-ignore` 금지, 불가피하면 `@ts-expect-error`+사유 | MUST |
| 10 | 배럴/순환참조 지양, `import type`으로 타입 전용 임포트 | SHOULD |

---

## 1. 스택 & 버전 (2026 기준)

| 항목 | 권장 | 비고 |
|------|------|------|
| 컴파일러 | TypeScript 5.x | `strict` 기본 |
| 런타임 | Node.js 22 LTS | ESM |
| 린트 | typescript-eslint (flat config) | 타입 인식 규칙 |
| 검증 | Zod (스키마 → 타입 추론) | 외부 경계 |
| 포맷 | Prettier 3 또는 Biome | 택1 |

---

## 2. 프로젝트 구조

```
src/
├── types/            # 전역 공유 타입 (도메인 타입은 feature 안에)
├── lib/              # 사전 설정된 클라이언트/유틸
├── features/<name>/
│   ├── schemas.ts    # Zod 스키마 (타입의 단일 진실원)
│   ├── service.ts
│   └── types.ts
└── config/env.ts     # 환경변수 파싱+검증(Zod)
```

**원칙**: 타입은 가급적 사용처 근처에. 전역 `types/`는 여러 기능이 진짜 공유할 때만.

---

## 3. 네이밍 & 컨벤션

| 대상 | 규칙 | 예 |
|------|------|-----|
| 타입·인터페이스 | PascalCase (접두 `I` 금지) | `User`, `OrderStatus` |
| 제네릭 | 의미있는 이름 우선 | `<TItem>` (단순시 `T`) |
| 변수·함수 | camelCase | `parseUser` |
| 상수 | SCREAMING_SNAKE | `DEFAULT_PAGE_SIZE` |
| 파일 | kebab-case | `user-service.ts` |

Google TypeScript Style Guide: 인터페이스 접두사 `I` **비권장**.

---

## 4. 베스트 프랙티스 (검증된 코드 샘플)

### 4.1 strict tsconfig

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "verbatimModuleSyntax": true,
    "skipLibCheck": true
  }
}
```

### 4.2 any 대신 unknown + 좁히기

```typescript
function handle(input: unknown): string {
  if (typeof input === 'string') return input.toUpperCase(); // 좁히기
  if (typeof input === 'number') return String(input);
  throw new Error('지원하지 않는 타입');
}
```

### 4.3 유니온 리터럴 + as const (enum 대체)

```typescript
const ROLE = ['owner', 'admin', 'editor', 'viewer'] as const;
type Role = (typeof ROLE)[number]; // 'owner' | 'admin' | 'editor' | 'viewer'
```

### 4.4 Zod로 외부 경계 검증 → 타입 추론

```typescript
import { z } from 'zod';

const UserSchema = z.object({
  id: z.string(),
  email: z.string().email(),
  age: z.number().int().nonnegative().optional(),
});

type User = z.infer<typeof UserSchema>; // 스키마가 타입의 단일 진실원

function parseUser(raw: unknown): User {
  return UserSchema.parse(raw); // 런타임 검증 통과 후에만 타입 신뢰
}
```

### 4.5 판별 유니온(discriminated union)으로 안전한 상태 표현

```typescript
type Result<T> =
  | { ok: true; data: T }
  | { ok: false; error: string };

function unwrap<T>(r: Result<T>): T {
  if (r.ok) return r.data; // ok로 좁혀짐
  throw new Error(r.error);
}
```

### 4.6 타입 전용 임포트

```typescript
import type { User } from './types'; // 런타임 코드에 포함되지 않음
```

---

## 5. 안티패턴 (금지)

| 안티패턴 | 문제 | 대안 |
|---------|------|------|
| `any` 도배 | 타입 안전성 붕괴 | `unknown`+narrowing |
| `as X` 강제 단언 | 런타임 불일치 은폐 | 타입 가드/스키마 검증 |
| `@ts-ignore` | 오류 영구 은폐 | `@ts-expect-error`+사유 |
| 숫자 `enum` | 트리셰이킹·역매핑 문제 | `as const` 유니온 |
| 함수형 오버로드 남용 | 가독성 저하 | 유니온/제네릭 |
| 옵셔널+non-null(`!`) 혼용 | 런타임 크래시 | 명시적 분기 |
| `Object`/`Function`/`{}` 타입 | 사실상 any | 구체 타입 |

---

## 6. 엄격한 규칙 (강제 설정)

### 6.1 typescript-eslint 핵심 규칙

```javascript
// eslint.config.js (발췌)
export default [
  {
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-unsafe-assignment': 'error',
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/consistent-type-imports': 'error',
      '@typescript-eslint/no-non-null-assertion': 'warn',
    },
  },
];
```

### 6.2 MUST NOT

- 컴파일러 오류를 `@ts-ignore`로 덮기 **금지**
- 검증 없이 `JSON.parse` 결과를 특정 타입으로 단언 **금지**
- `Promise` 반환 함수 호출 후 `await`/`void` 누락(floating promise) **금지**

---
