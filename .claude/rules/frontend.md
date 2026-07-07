---
paths:
  - "src/components/**/*.tsx"
  - "src/pages/**/*.tsx"
---

# 프론트엔드 개발 규칙

## 컴포넌트 구조
- 함수형 컴포넌트만 사용
- Props 타입은 컴포넌트명 + Props로 명명 (예: ButtonProps)
- 컴포넌트 파일 하나에 하나의 export default

## 스타일링
- Tailwind CSS 클래스 사용
- 복잡한 스타일은 cn() 유틸리티로 조합
- 인라인 스타일 사용 금지

## 상태 관리
- 로컬 상태: useState
- 서버 상태: React Query (useQuery, useMutation)
- 전역 상태: Zustand

## 접근성
- 모든 이미지에 alt 속성 필수
- 버튼에 aria-label 포함
- 키보드 네비게이션 지원
