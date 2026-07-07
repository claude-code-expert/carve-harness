# JavaScript 개발 스택 가이드

> **용도**: Claude Code 프로젝트의 `CLAUDE.md` · `.claude/rules/` · `.claude/skills/` 참조용 코딩 표준
> **대상**: 개발을 시작하는 비전공·직장인 → 실무 진입 단계
> **최종 검증일**: 2026-07-06 (KST)
> **표기 규칙**: 규칙은 **MUST / MUST NOT / SHOULD** 로 강제 수준 구분

---

## 0. 결론 먼저 — 핵심 규칙 Top 10

| # | 규칙 | 수준 |
|---|------|------|
| 1 | `var` 금지, `const` 우선 → 재할당 필요 시만 `let` | MUST |
| 2 | `==` / `!=` 금지, `===` / `!==` 만 사용 | MUST |
| 3 | 동등성/타입 비교 전 `typeof`·`Array.isArray` 등 명시 검사 | SHOULD |
| 4 | 함수는 화살표 함수 + 순수 함수 지향, 부수효과 격리 | SHOULD |
| 5 | 비동기는 `async/await` (콜백 중첩·`.then` 체인 지양) | MUST |
| 6 | `try/catch`로 Promise 거부 처리, 삼켜서 무시 금지 | MUST |
| 7 | 모듈은 ESM(`import`/`export`), 명시적 named export 우선 | SHOULD |
| 8 | 매직 넘버·문자열 상수화(대문자 `SCREAMING_SNAKE`) | SHOULD |
| 9 | 린터/포매터 강제: ESLint(flat config) + Prettier 또는 Biome | MUST |
| 10 | 순환 참조·배럴 파일 남용 금지(트리셰이킹 저해) | SHOULD |

---

## 1. 스택 & 버전 (2026 기준)

| 항목 | 권장 | 비고 |
|------|------|------|
| 런타임 | Node.js 22 LTS (또는 24) | LTS 라인 고정 |
| 언어 표준 | ES2023+ / ESM | `"type": "module"` |
| 린터 | ESLint 9 (flat config `eslint.config.js`) | 신규 형식 |
| 포매터 | Prettier 3 **또는** Biome | Biome = 린트+포맷 통합 |
| 패키지 매니저 | pnpm (또는 npm) | 모노레포는 pnpm workspace |

---

## 2. 프로젝트 구조 (기능 기반 · feature-based)

```
src/
├── config/          # 환경변수·전역 설정 (env는 여기서만 접근)
├── lib/             # 외부 라이브러리 래퍼(사전 설정된 클라이언트)
├── features/        # 기능별 모듈 (핵심)
│   └── <feature>/
│       ├── api/     # 해당 기능의 API 호출
│       ├── model/   # 도메인 로직
│       └── utils/
├── shared/          # 여러 기능이 공유하는 순수 유틸/상수
└── main.js          # 진입점
```

**의존성 방향(단방향)**: `shared → features → app`. 상위가 하위를 import 하지 않는다.
출처: bulletproof-react project-structure(구조 원칙 공통 적용).

---

## 3. 네이밍 & 코드 컨벤션

| 대상 | 규칙 | 예 |
|------|------|-----|
| 변수·함수 | camelCase | `getUserById` |
| 클래스·생성자 | PascalCase | `UserRepository` |
| 상수(불변) | SCREAMING_SNAKE_CASE | `MAX_RETRY` |
| 파일 | kebab-case 또는 도메인 규칙 통일 | `user-service.js` |
| 불리언 | is/has/should 접두 | `isActive`, `hasToken` |
| 비공개 | `#` private field | `#secret` |

- 문자열: 작은따옴표 `'...'`, 보간은 템플릿 리터럴 `` `${x}` ``.
- 들여쓰기 2 spaces, 세미콜론 사용, 한 줄 최대 100자(포매터 위임).

---

## 4. 베스트 프랙티스 (검증된 코드 샘플)

### 4.1 변수 선언 · 동등성

```javascript
const MAX_RETRY = 3;          // 상수: const + 대문자
let attempt = 0;              // 재할당 필요할 때만 let

if (attempt === MAX_RETRY) {  // 항상 === / !==
  throw new Error('재시도 초과');
}
```

### 4.2 비동기 — async/await + 에러 처리

```javascript
async function fetchUser(id) {
  try {
    const res = await fetch(`/api/users/${id}`);
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
    return await res.json();
  } catch (err) {
    // 로깅 후 재던지기 — 절대 조용히 삼키지 않는다
    console.error('fetchUser 실패:', err);
    throw err;
  }
}
```

### 4.3 병렬 처리 — 독립 작업은 Promise.all

```javascript
// 서로 의존하지 않는 요청은 병렬로 (순차 await 금지)
const [user, posts] = await Promise.all([
  fetchUser(id),
  fetchPosts(id),
]);
```

### 4.4 불변 데이터 · 구조 분해

```javascript
const updateUser = (user, patch) => ({ ...user, ...patch }); // 원본 불변
const { name, email = 'unknown@example.com' } = user;        // 기본값
```

### 4.5 옵셔널 체이닝 · nullish 병합

```javascript
const city = user?.address?.city ?? '미지정'; // undefined/null만 대체 (0/'' 보존)
```

---

## 5. 안티패턴 (금지)

| 안티패턴 | 문제 | 대안 |
|---------|------|------|
| `var` 사용 | 함수 스코프·호이스팅 혼란 | `const`/`let` |
| `==` 비교 | 암묵 형변환 버그 | `===` |
| `catch (e) {}` 빈 처리 | 에러 은폐 | 로깅+재던지기 |
| 순차 `await` 남발 | 불필요한 대기 | `Promise.all` |
| 전역 변수 오염 | 예측 불가 부수효과 | 모듈 스코프 |
| `for...in`으로 배열 순회 | 프로토타입 키 포함 | `for...of`/`map` |
| 배럴(`index.js`) 남용 | 트리셰이킹 저해 | 직접 import |
| `arguments` 객체 의존 | 화살표함수 미지원 | rest 파라미터 `...args` |

---

## 6. 엄격한 규칙 (강제 설정)

### 6.1 ESLint 9 flat config (예시)

```javascript
// eslint.config.js
import js from '@eslint/js';

export default [
  js.configs.recommended,
  {
    languageOptions: { ecmaVersion: 2023, sourceType: 'module' },
    rules: {
      'no-var': 'error',
      'prefer-const': 'error',
      eqeqeq: ['error', 'always'],
      'no-console': ['warn', { allow: ['warn', 'error'] }],
      'no-unused-vars': 'error',
      'no-await-in-loop': 'warn',
    },
  },
];
```

### 6.2 MUST NOT (안전 가드)

- `eval()` · `new Function(userInput)` **금지** (코드 인젝션)
- `innerHTML`에 미검증 문자열 대입 **금지** (XSS)
- 민감정보를 로그/에러 메시지에 노출 **금지**
- 프로덕션에 `console.log` 잔존 **금지**

---
