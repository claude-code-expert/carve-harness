---
paths: ["**/*.java"]
---
# Java/Spring 규칙
- @Transactional 내 외부 API 호출 금지.
- Controller에서 Entity 직접 반환 금지 → DTO(record) 매핑.
- 연관관계 FetchType.LAZY 기본 (N+1 방지).
- domain 패키지는 infrastructure import 금지(단방향).
> [추가 규칙 — 내용없음]
