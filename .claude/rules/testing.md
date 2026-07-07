---
paths:
  - "**/*.test.ts"
  - "**/*.spec.ts"
  - "tests/**/*"
---

# 테스트 작성 규칙

## 테스트 구조
- describe: 테스트 대상 (클래스명 또는 함수명)
- it: 구체적인 동작 설명 (should로 시작)

## 네이밍 컨벤션

```typescript
describe('UserService', () => {
  it('should create a new user with valid data', () => {});
  it('should throw error when email is duplicated', () => {});
});
```

## AAA 패턴
모든 테스트는 Arrange-Act-Assert 패턴을 따른다:

```typescript
it('should return sum of two numbers', () => {
  // Arrange
  const a = 5, b = 3;
  
  // Act
  const result = add(a, b);
  
  // Assert
  expect(result).toBe(8);
});
```

## Mock 사용
- 외부 의존성은 반드시 Mock 처리
- Mock 파일은 __mocks__ 디렉토리에 위치
- jest.mock() 사용 시 파일 상단에 배치
