# React 개발 스택 가이드 (React 19)

> **용도**: Claude Code 프로젝트의 `CLAUDE.md` · `.claude/rules/` · `.claude/skills/` 참조용 코딩 표준
> **대상**: 개발을 시작하는 비전공·직장인 → 실무 진입 단계
> **최종 검증일**: 2026-07-06 (KST)

---

## 0. 결론 먼저 — 핵심 규칙 Top 10

| # | 규칙 | 수준 |
|---|------|------|
| 1 | 함수형 컴포넌트 + Hooks만 사용(클래스형 지양) | MUST |
| 2 | Hooks 규칙: 최상위에서만, 조건/반복문 안 금지 | MUST |
| 3 | `key`는 인덱스가 아니라 안정적 고유 ID 사용 | MUST |
| 4 | 상태 최소화·정규화, 파생값은 렌더 중 계산 | SHOULD |
| 5 | `useEffect`는 "외부 시스템 동기화"에만(데이터 변환에 금지) | MUST |
| 6 | props/상태 불변 유지(직접 변이 금지) | MUST |
| 7 | 컴포넌트는 feature 폴더로, cross-feature import 금지 | SHOULD |
| 8 | 서버 상태는 TanStack Query, 클라 상태는 Zustand 등 분리 | SHOULD |
| 9 | 접근성(a11y): 시맨틱 태그·label·alt·키보드 지원 | MUST |
| 10 | React 19: `ref` prop 직접 전달, `use()`·Actions 활용 | SHOULD |

---

## 1. 스택 & 버전 (2026 기준, markflow 정렬)

| 항목 | 권장 | 비고 |
|------|------|------|
| React | 19.x | `forwardRef` 불필요(ref=prop), Actions, `use()` |
| 언어 | TypeScript 5.x | `.tsx` |
| 서버 상태 | TanStack Query 5 | 캐시·재검증 |
| 클라 상태 | Zustand 5 | 전역 UI 상태 |
| 스타일 | Tailwind CSS 4 | 유틸리티 |
| 테스트 | Vitest + Testing Library | 사용자 관점 |

> React 19: `forwardRef` 없이 `ref`를 일반 prop으로 받을 수 있고, `useFormStatus`·`useActionState`·`use()` 등 신규 API 제공. (출처: React 공식 블로그 React 19)

---

## 2. 프로젝트 구조 (feature-based · 단방향)

```
src/
├── app/            # 진입·프로바이더·라우팅
├── components/     # 전역 공유 컴포넌트(ui/)
├── features/<name>/
│   ├── api/        # 이 기능의 서버 통신(useQuery/useMutation)
│   ├── components/ # 이 기능 전용 컴포넌트
│   ├── hooks/
│   └── stores/     # 이 기능 전용 상태
├── hooks/          # 전역 공유 훅
├── lib/            # 사전 설정 라이브러리
└── types/
```

**cross-feature import 금지**를 ESLint로 강제(출처: bulletproof-react):

```javascript
'import/no-restricted-paths': ['error', { zones: [
  { target: './src/features/auth', from: './src/features', except: ['./auth'] },
]}]
```

**단방향 아키텍처**: `shared → features → app`.

---

## 3. 네이밍 & 컨벤션

| 대상 | 규칙 | 예 |
|------|------|-----|
| 컴포넌트 | PascalCase | `UserCard.tsx` |
| 훅 | `use` 접두 camelCase | `useUser` |
| 이벤트 핸들러 | `handle` 접두 | `handleSubmit` |
| props 콜백 | `on` 접두 | `onChange` |
| 불리언 props | is/has | `isLoading` |

---

## 4. 베스트 프랙티스 (검증된 코드 샘플)

### 4.1 컴포넌트 기본형 + 타입 props

```tsx
type UserCardProps = {
  name: string;
  email: string;
  onSelect?: (email: string) => void;
};

export function UserCard({ name, email, onSelect }: UserCardProps) {
  return (
    <button type="button" onClick={() => onSelect?.(email)}>
      {name} ({email})
    </button>
  );
}
```

### 4.2 파생 상태는 계산(불필요한 useEffect 금지)

```tsx
// 나쁨: useEffect + 별도 state로 파생값 관리
// 좋음: 렌더 중 직접 계산
function Cart({ items }: { items: Item[] }) {
  const total = items.reduce((sum, i) => sum + i.price, 0); // 파생값
  return <p>합계: {total}</p>;
}
```

### 4.3 서버 상태(TanStack Query) vs 클라 상태 분리

```tsx
import { useQuery } from '@tanstack/react-query';

function useUser(id: string) {
  return useQuery({
    queryKey: ['user', id],
    queryFn: () => fetchUser(id),
    staleTime: 60_000,
  });
}
```

### 4.4 React 19 — ref를 일반 prop으로

```tsx
// React 19: forwardRef 불필요
function TextInput({ ref, ...props }: React.ComponentProps<'input'>) {
  return <input ref={ref} {...props} />;
}
```

### 4.5 리스트 key — 안정적 ID

```tsx
{users.map((u) => (
  <UserCard key={u.id} name={u.name} email={u.email} /> // index 금지
))}
```

### 4.6 useEffect는 외부 시스템 동기화에만

```tsx
useEffect(() => {
  const sub = socket.subscribe(onMessage);
  return () => sub.unsubscribe(); // 정리 함수 필수
}, [socket]);
```

---

## 5. 안티패턴 (금지)

| 안티패턴 | 문제 | 대안 |
|---------|------|------|
| `key={index}` | 재정렬 시 상태 꼬임 | 고유 ID |
| 파생값을 useEffect+state로 | 불필요 렌더·버그 | 렌더 중 계산 |
| props/state 직접 변이 | 렌더 미갱신 | 새 객체/배열 |
| 거대 단일 컴포넌트 | 재사용·테스트 불가 | 분리·합성 |
| useEffect로 데이터 fetch 방치 | 워터폴·경쟁상태 | Query 라이브러리 |
| 과도한 useMemo/useCallback | 복잡도만 증가 | 측정 후 최적화 |
| 전역 상태에 서버 데이터 저장 | 캐시 무효화 지옥 | 서버상태 라이브러리 |

---

## 6. 엄격한 규칙 (강제 설정)

- ESLint: `eslint-plugin-react-hooks`(`rules-of-hooks`, `exhaustive-deps`) **error**
- ESLint: `eslint-plugin-jsx-a11y` 활성화
- `dangerouslySetInnerHTML` 사용 시 반드시 sanitize(예: `rehype-sanitize`) 선행 — **미검증 HTML 렌더 금지**
- 컴포넌트 파일당 export 컴포넌트 1개 원칙(테스트/추적 용이)

---