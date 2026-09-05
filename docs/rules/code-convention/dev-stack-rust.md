# Rust 개발 스택 가이드

> **용도**: `.claude/rules/rust/patterns.md`(자동 로드 슬림본)의 상세본. 필요할 때만 Read.
> **작성일**: 2026-09-05 · 기준 Rust 2021 edition, stable toolchain (rustfmt · clippy · cargo test)

## 0. 결론 먼저 — 핵심 규칙 Top 10

| # | 규칙 | 수준 |
|---|------|------|
| 1 | `rustfmt` 정본, clippy 경고 신규 0 | MUST |
| 2 | 라이브러리에서 `unwrap`/`expect`/`panic!` 금지 → `Result` + `?` | MUST |
| 3 | 오류 타입은 열거형/`thiserror`, 문자열 오류는 프로토타입만 | MUST |
| 4 | `unsafe` 금지, 불가피하면 `// SAFETY:` + 리뷰 | MUST |
| 5 | `pub` 최소화, 빌림 우선·`clone` 최소 | MUST |
| 6 | 시크릿은 `std::env::var`, 리터럴 금지 | MUST |
| 7 | 새 코드엔 테스트, `cargo test` 녹색 | MUST |
| 8 | `Option`/`Result` 조합자 우선 | SHOULD |
| 9 | 동시성은 `std::sync`/채널, `static mut` 금지 | SHOULD |
| 10 | `lib.rs`는 모듈 선언·재수출만 | SHOULD |

## 1. 도구

| 목적 | 도구 | 하네스 게이트 |
|---|---|---|
| 포맷 | `rustfmt` (`cargo fmt`) | PostToolUse(`.claude/stacks/rust.sh`) |
| 정적 검사 | `cargo clippy -- -D warnings` | 권장(프로젝트 CI) |
| 컴파일·테스트 | `cargo check` · `cargo test` | Stop |
| 커버리지 | `cargo llvm-cov`(설치 시) | 평가 어댑터(LP4) |

## 2. 프로젝트 구조

```
crate/
├── Cargo.toml · Cargo.lock(커밋)
├── src/lib.rs        # pub mod 선언 + 재수출
├── src/<module>.rs
├── src/main.rs       # 바이너리 진입점만
└── tests/            # 통합 테스트(공개 API만 사용)
```

## 3. 오류 처리

```rust
#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("PAY_API_KEY is not set")]
    Missing,
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
}

pub fn api_key() -> Result<String, ConfigError> {
    std::env::var("PAY_API_KEY").map_err(|_| ConfigError::Missing)
}
```
- 외부 크레이트 없이 갈 때는 `Result<T, String>`도 허용하되 라이브러리 경계에서는 타입 오류로 승격.
- `?`로 전파, 호출자가 `match`로 분기. `unwrap`은 테스트·예제에서만.

## 4. 소유권·API

- 함수 인자는 `&str`/`&[T]`/`&T`로 빌린다. 소유권이 정말 필요할 때만 `String`/`Vec<T>`.
- 반환은 소유 타입. 라이프타임 매개변수는 정말 필요할 때만.
- `Clone`은 비용을 알고 명시적으로. 루프 안 `clone` 은 리뷰 대상.

## 5. 테스트

```rust
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn clamp_bounds() {
        assert_eq!(clamp(5, 0, 3), 3);
        assert_eq!(clamp(-1, 0, 3), 0);
        assert_eq!(clamp(2, 0, 3), 2);
    }
}
```
- 단위 테스트는 같은 파일 `#[cfg(test)]`, 통합 테스트는 `tests/`. 외부 자원은 트레이트로 추상화해 주입.

## 6. 시크릿·설정

`.env.example`에는 변수 이름만. 값은 절대 코드·설정에 넣지 않는다(하네스 가드가 차단). 없으면 `Err`로 실패 — 기본값으로 숨기지 않는다.
