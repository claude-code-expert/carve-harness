---
paths: ["**/*.java"]
---
# Java / Spring Boot 규칙 (자동 로드)

> 자동 로드되는 **규칙 목록**. 코드 샘플·근거·프로젝트 구조는 상세본 참조:
> `.claude/rules/code-convention/dev-stack-{java-spring,orm}.md`
> 최종 정합: 2026-07-07 (Java 21+ · Spring Boot 4 — Context7 검증)

## 계층 · 의존성
- [MUST] 계층 분리: Controller → Service → Repository. 역방향 의존 금지. domain 패키지는 infrastructure import 금지(단방향).
- [MUST] 생성자 주입(`@RequiredArgsConstructor`). 필드 주입(`@Autowired`) 금지.
- [MUST] 비즈니스 로직은 Service에(Controller에 두지 않음). 도메인형(package-by-feature) 구조 권장.

## API · DTO · 검증
- [MUST] Controller에서 Entity 직접 반환 금지 → DTO(record) 매핑.
- [MUST] 모든 외부 입력 `@Valid` + Bean Validation. 전역 예외 처리 `@RestControllerAdvice` + 표준 `ErrorResponse`.
- [SHOULD] 응답은 표준 래퍼(`ApiResponse<T>`)로 통일. `RuntimeException` 남발 금지 → 도메인 예외 + 핸들러.

## 영속성 (JPA / Hibernate)
- [MUST] 연관관계 `FetchType.LAZY` 고정(EAGER 금지). N+1은 `JOIN FETCH`/`@EntityGraph`로 해결.
- [MUST] `@Transactional(readOnly=true)` 클래스 기본 + 쓰기 메서드만 `@Transactional`. `@Transactional` 내 외부 API 호출 금지.
- [MUST] SQL 문자열 직접 결합 금지(인젝션) → JPQL 파라미터/Query 메서드.
- [SHOULD] Entity는 정적 팩토리 생성, public 생성자 지양. 대용량 페이지네이션은 offset 대신 cursor(keyset).

## 마이그레이션 · 보안
- [MUST] Flyway `V<n>__snake_case.sql`, 버전 단조 증가, 기존 파일 **불변**(수동 DDL 금지).
- [MUST] 비밀정보 `application.yml` 하드코딩 금지 → 환경변수/시크릿 매니저.

> 프로젝트별 규칙은 이 아래에 추가한다 (도메인 이벤트 발행 규약, 트랜잭션 전파 정책, 공통 응답 래퍼 등).
