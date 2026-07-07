---
paths:
  - "src/api/**/*.ts"
---

# API 개발 규칙

## 응답 형식
모든 API는 다음 형식으로 응답한다:

```json
{
  "success": boolean,
  "data": any | null,
  "error": string | null
}
```

## 에러 처리
- 비즈니스 로직 에러: 400번대
- 서버 에러: 500번대
- 모든 에러는 AppError 클래스로 래핑

## 인증
- 인증 필요 라우트는 authMiddleware 적용 필수
- 권한 체크는 checkPermission 미들웨어 사용

## 유효성 검사
- 모든 입력은 zod 스키마로 검증
- 스키마 파일은 src/schemas/에 위치
