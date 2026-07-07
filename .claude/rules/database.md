---
paths:
  - "src/models/**/*.ts"
  - "src/repositories/**/*.ts"
  - "prisma/**/*"
---

# 데이터베이스 규칙

## 모델 정의
- 모든 테이블에 id, createdAt, updatedAt 필드 필수
- soft delete 사용: deletedAt 필드로 관리
- 외래키는 관계 테이블명 + Id 형식 (예: userId)

## 쿼리 작성
- N+1 문제 방지: include 또는 join 적극 활용
- 대량 조회 시 반드시 페이지네이션 적용
- 트랜잭션 필요 시 prisma.$transaction 사용

## 마이그레이션
- 마이그레이션 파일명에 변경 내용 명시
- 프로덕션 배포 전 마이그레이션 테스트 필수
- 롤백 가능한 마이그레이션 작성

## 인덱스
- 자주 검색되는 컬럼에 인덱스 추가
- 복합 인덱스는 검색 순서 고려
