# Java · Spring Boot 개발 스택 가이드 (Spring Boot 4)

> **용도**: Claude Code 프로젝트의 `CLAUDE.md` · `.claude/rules/` · `.claude/skills/` 참조용 코딩 표준
> **대상**: 개발을 시작하는 비전공·직장인 → 실무 진입 단계
> **최종 검증일**: 2026-07-06 (KST) · 기존 `spring-conventions` 스킬(Run-AI)과 정합
> **표기**: 코드 육안 검증(컨테이너에 JDK 미탑재 → 컴파일 실행 검증은 미수행, 검증표 참조)

---

## 0. 결론 먼저 — 핵심 규칙 Top 10

| # | 규칙 | 수준 |
|---|------|------|
| 1 | 계층 분리: Controller → Service → Repository, 역방향 의존 금지 | MUST |
| 2 | 생성자 주입(`@RequiredArgsConstructor`), 필드 주입 금지 | MUST |
| 3 | Controller에서 Entity 직접 반환 금지 → DTO(record) 매핑 | MUST |
| 4 | `@ManyToOne`/`@OneToMany`는 `FetchType.LAZY` 고정(N+1 방지) | MUST |
| 5 | Service 클래스 `@Transactional(readOnly=true)`, 쓰기 메서드만 `@Transactional` | MUST |
| 6 | Entity는 정적 팩토리 메서드 생성, public 생성자 지양 | SHOULD |
| 7 | 요청 검증 `@Valid` + Bean Validation, 전역 예외 핸들러 | MUST |
| 8 | Flyway 마이그레이션: 기존 파일 수정 금지, 버전 증가만 | MUST |
| 9 | 응답은 표준 래퍼(`ApiResponse<T>`/`ErrorResponse`)로 통일 | SHOULD |
| 10 | 비밀정보는 `application.yml` 하드코딩 금지 → 환경변수/시크릿 | MUST |

---

## 1. 스택 & 버전 (2026 기준)

| 항목 | 값 | 비고 |
|------|-----|------|
| Java | 21 LTS (또는 25 LTS) | record·pattern matching·virtual thread |
| Spring Boot | 4.x | Jakarta EE 기반 |
| 빌드 | Gradle (Kotlin DSL) 또는 Maven | |
| 영속성 | Spring Data JPA (Hibernate) | |
| 마이그레이션 | Flyway | |
| 게이트웨이(선택) | Spring Cloud Gateway 5.0.x | Boot 4 대응. 아티팩트 `spring-cloud-gateway-server-webflux`/`-webmvc` |

> 주의: Boot 3.5 계열은 Gateway 4.3.x. Boot 4는 5.0.x. (메모리 검증 항목 — 사용 전 릴리스 재확인)

---

## 2. 프로젝트 구조 (도메인형 권장)

```
src/main/java/com/example/app/
├── domain/<agg>/          # 도메인 단위(예: post, user)
│   ├── Post.java          # Entity
│   ├── PostController.java
│   ├── PostService.java
│   ├── PostRepository.java
│   └── dto/               # record DTO
├── global/
│   ├── config/            # Security, Web, Jpa 설정
│   ├── exception/         # 전역 예외 핸들러
│   └── response/          # ApiResponse, ErrorResponse
src/main/resources/
├── application.yml
└── db/migration/          # Flyway: V1__*.sql
```

계층형(`controller/`, `service/`…)보다 **도메인형(feature/package-by-feature)** 이 응집도·확장성 우수.

---

## 3. 네이밍 & 컨벤션 (Google Java Style 기준)

| 대상 | 규칙 | 예 |
|------|------|-----|
| 클래스 | PascalCase | `PostService` |
| 메서드·변수 | camelCase | `createPost` |
| 상수 | SCREAMING_SNAKE | `MAX_TITLE_LEN` |
| 패키지 | 전부 소문자 | `com.example.post` |
| 테스트 | `대상+Test` | `PostServiceTest` |

들여쓰기 4 spaces(또는 팀 규칙), import 와일드카드 `*` 금지.

---

## 4. 베스트 프랙티스 (검증된 코드 샘플 — Run-AI 컨벤션)

### 4.1 Entity — 정적 팩토리 + 도메인 메서드

```java
@Entity
@Table(name = "posts")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Post extends BaseTimeEntity {

    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    @Column(nullable = false, unique = true)
    private String url;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PostStatus status;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "author_id", nullable = false)
    private User author;

    public static Post create(String url, User author) {
        Post post = new Post();
        post.url = url;
        post.status = PostStatus.ANALYZING;
        post.author = author;
        return post;
    }
}
```

### 4.2 DTO — Java record + 정적 매핑

```java
public record PostCreateRequest(@NotBlank String url) {}

public record PostResponse(String id, String url, PostStatus status) {
    public static PostResponse from(Post post) {
        return new PostResponse(post.getId(), post.getUrl(), post.getStatus());
    }
}
```

### 4.3 Service — 트랜잭션 경계

```java
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PostService {

    private final PostRepository postRepository;

    @Transactional
    public PostResponse createPost(PostCreateRequest request, User user) {
        if (postRepository.existsByUrl(request.url())) {
            throw new DuplicateUrlException(request.url());
        }
        Post post = postRepository.save(Post.create(request.url(), user));
        return PostResponse.from(post);
    }
}
```

### 4.4 Controller — DTO 반환 + 표준 응답

```java
@RestController
@RequestMapping("/api/posts")
@RequiredArgsConstructor
public class PostController {

    private final PostService postService;

    @PostMapping
    public ResponseEntity<ApiResponse<PostResponse>> create(
            @Valid @RequestBody PostCreateRequest request,
            @AuthenticationPrincipal UserPrincipal principal) {
        PostResponse res = postService.createPost(request, principal.toUser());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(res, "생성되었습니다."));
    }
}
```

### 4.5 N+1 방지 — JOIN FETCH / @EntityGraph

```java
@EntityGraph(attributePaths = "author")
List<Post> findByStatus(PostStatus status); // author를 함께 조회
```

---

## 5. 안티패턴 (금지)

| 안티패턴 | 문제 | 대안 |
|---------|------|------|
| 필드 주입 `@Autowired` | 테스트·불변성 저해 | 생성자 주입 |
| Entity를 Controller에서 반환 | 순환참조·과노출 | DTO 매핑 |
| `EAGER` 페치 | N+1·과다 조회 | LAZY + fetch join |
| 서비스 전체 `@Transactional` 없음 | 읽기 최적화 상실 | readOnly=true + 쓰기만 write |
| 기존 Flyway 파일 수정 | 체크섬 불일치 | 새 버전 추가 |
| 비즈니스 로직을 Controller에 | 계층 붕괴 | Service로 이동 |
| `RuntimeException` 남발 | 원인 추적 불가 | 도메인 예외+핸들러 |

---

## 6. 엄격한 규칙 (강제 설정)

- **MUST**: 전역 예외 처리 `@RestControllerAdvice` + 표준 `ErrorResponse`
- **MUST**: 모든 외부 입력 `@Valid` 검증
- **MUST NOT**: SQL 문자열 직접 결합(인젝션) — JPQL 파라미터·Query 메서드 사용
- **SHOULD**: 정적 분석 — Checkstyle(구글 규칙) + SpotBugs, 또는 alibaba/p3c 규칙셋
- **Flyway**: `V<n>__<snake_case>.sql`, 버전 단조 증가, 기존 파일 **불변**

---
