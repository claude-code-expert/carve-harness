# ORM 개발 스택 가이드 (Drizzle · JPA/Hibernate · SQLAlchemy)

> **용도**: Claude Code 프로젝트의 `CLAUDE.md` · `.claude/rules/` · `.claude/skills/` 참조용 코딩 표준
> **대상**: 개발을 시작하는 비전공·직장인 → 실무 진입 단계
> **최종 검증일**: 2026-07-06 (KST)
> **범위**: 스택별 대표 ORM 3종 + 모든 ORM 공통 원칙

---

## 0. 결론 먼저 — ORM 공통 핵심 규칙 Top 10

| # | 규칙 | 수준 |
|---|------|------|
| 1 | **N+1 쿼리 금지** — 관계 조회는 eager join/relational query로 일괄 | MUST |
| 2 | 스키마 변경은 **마이그레이션 도구**로만, 수동 DDL 금지 | MUST |
| 3 | 기존 마이그레이션 파일 **수정 금지**(새 버전 추가) | MUST |
| 4 | 트랜잭션 경계 명시(쓰기 작업 원자성 보장) | MUST |
| 5 | 원시 SQL 문자열 보간 금지 → 파라미터 바인딩 | MUST |
| 6 | 페이지네이션은 대용량에서 offset 대신 **cursor(keyset)** | SHOULD |
| 7 | 인덱스·유니크·FK 제약을 스키마에 명시 | SHOULD |
| 8 | soft delete(`deleted_at`)·타임스탬프(`created/updated_at`) 표준화 | SHOULD |
| 9 | 타입 추론 활용(수동 타입 중복 금지) | SHOULD |
| 10 | raw SQL은 "복잡한 쿼리"에만 최소 사용(단순 조회에 남용 금지) | SHOULD |

---

## 1. Drizzle ORM (TypeScript · markflow 기본)

### 1.1 버전·특징 (2026)

- Drizzle **v1.0** 출시, **Relational Queries v2**(`defineRelations`) 도입
- 항상 **단일 SQL 쿼리** 출력, 의존성 0, 서버리스 친화
- 타입 추론: `typeof table.$inferSelect` / `$inferInsert`

### 1.2 네이밍 (출처: Drizzle Best Practices)

| 대상 | 규칙 |
|------|------|
| 테이블명 | 복수 snake_case (`users`, `blog_posts`) |
| DB 컬럼 | snake_case / TS 키 | camelCase |
| 테이블 변수 | camelCase (`users`, `blogPosts`) |

### 1.3 스키마 + 타임스탬프 + soft delete

```typescript
import { pgTable, text, timestamp } from 'drizzle-orm/pg-core';

export const users = pgTable('users', {
  id: text('id').primaryKey(),
  email: text('email').notNull().unique(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true })
    .notNull().defaultNow().$onUpdate(() => new Date()),
  deletedAt: timestamp('deleted_at', { withTimezone: true }), // soft delete
});

export type User = typeof users.$inferSelect;   // 타입 추론
export type NewUser = typeof users.$inferInsert;
```

### 1.4 N+1 방지 — relational query(단일 쿼리)

```typescript
// 좋음: 관계형 쿼리 = 1 SQL
const usersWithPosts = await db.query.users.findMany({
  with: { posts: true },
});

// 대안: 집계는 명시적 join
const counts = await db
  .select({ id: users.id, postCount: count(posts.id) })
  .from(users)
  .leftJoin(posts, eq(users.id, posts.authorId))
  .groupBy(users.id);
```

### 1.5 마이그레이션 (drizzle-kit)

```bash
drizzle-kit generate   # 스키마 변경 → SQL 마이그레이션 생성
drizzle-kit migrate    # 적용
drizzle-kit push       # 로컬 프로토타이핑(운영 비권장)
drizzle-kit studio     # GUI
```

> markflow 규약: **offset 페이지네이션 금지**(cursor 사용), **raw SQL 금지**(쿼리 빌더만), **N+1 금지**.

---

## 2. JPA / Hibernate (Java · Spring Boot)

### 2.1 핵심 규칙

- 연관관계는 **`FetchType.LAZY`** 고정 → N+1은 `JOIN FETCH`/`@EntityGraph`로 해결
- Entity에 도메인 로직 배치, 생성은 정적 팩토리
- Controller에 Entity 반환 금지 → DTO 매핑
- 마이그레이션은 **Flyway**(`V<n>__name.sql`, 기존 파일 불변)

### 2.2 예시 (N+1 해결)

```java
@Entity
@Table(name = "posts")
public class Post {
    @ManyToOne(fetch = FetchType.LAZY)   // 즉시로딩 금지
    @JoinColumn(name = "author_id")
    private User author;
}

// Repository: 함께 조회
@EntityGraph(attributePaths = "author")
List<Post> findByStatus(PostStatus status);
```

### 2.3 트랜잭션

```java
@Service
@Transactional(readOnly = true)          // 클래스: 읽기
public class PostService {
    @Transactional                       // 쓰기 메서드만
    public void publish(String id) { /* ... */ }
}
```

---

## 3. SQLAlchemy 2.0 + Alembic (Python · FastAPI)

### 3.1 핵심 규칙

- SQLAlchemy 2.0 스타일(`Mapped[...]`, `mapped_column`), async 엔진 권장
- 관계 로딩: `selectinload`/`joinedload`로 N+1 방지
- 세션은 요청 스코프(`Depends`)로 주입
- 마이그레이션: **Alembic**, 제약/인덱스 네이밍 컨벤션 고정

### 3.2 모델 예시

```python
from datetime import datetime
from sqlalchemy import String, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

class Base(DeclarativeBase):
    pass

class User(Base):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    email: Mapped[str] = mapped_column(String, unique=True)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
```

### 3.3 N+1 방지 (eager load)

```python
from sqlalchemy.orm import selectinload
from sqlalchemy import select

stmt = select(User).options(selectinload(User.posts))  # 관계 일괄 로딩
users = (await session.scalars(stmt)).all()
```

### 3.4 Alembic 네이밍 컨벤션

```python
from sqlalchemy import MetaData

naming = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}
metadata = MetaData(naming_convention=naming)
```

---

## 4. 안티패턴 (모든 ORM 공통 · 금지)

| 안티패턴 | 문제 | 대안 |
|---------|------|------|
| 반복문 안 개별 쿼리 | N+1 폭증 | eager join/relational query |
| EAGER 전면 로딩 | 불필요 데이터·조인 폭발 | LAZY + 필요시 fetch |
| 수동 DDL로 스키마 변경 | 환경 불일치 | 마이그레이션 도구 |
| 기존 마이그레이션 편집 | 체크섬/이력 붕괴 | 새 버전 추가 |
| 문자열 보간 raw SQL | SQL 인젝션 | 파라미터 바인딩 |
| 대용량 offset 페이지네이션 | 뒤로 갈수록 느려짐 | cursor/keyset |
| 단순 조회에 raw SQL | 타입 안전성 상실 | 쿼리 빌더/ORM API |
| 트랜잭션 경계 누락 | 부분 커밋·정합성 붕괴 | 명시적 트랜잭션 |

---

## 5. 엄격한 규칙 (강제 설정)

- **MUST**: 스키마 변경 = 마이그레이션 파일 커밋(수동 DB 변경 금지)
- **MUST**: 쓰기 작업은 트랜잭션 안에서, 실패 시 롤백
- **MUST NOT**: 사용자 입력을 SQL 문자열에 직접 결합
- **SHOULD**: N+1은 코드리뷰 필수 체크 항목(로그/쿼리 카운트 확인)
- **SHOULD**: 공통 컬럼(`id`, `created_at`, `updated_at`, `deleted_at`) 베이스 모델화

---
