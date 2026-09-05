---
paths: ["**/*.rs"]
---
# Rust 규칙 (자동 로드)

> 자동 로드되는 **규칙 목록**. 근거·샘플은 상세본 참조: `docs/rules/code-convention/dev-stack-rust.md`
> 게이트: `.claude/stacks/rust.sh` — `cargo check` · `cargo test`(Stop) · `rustfmt`(PostToolUse)

## 코드
- [MUST] `rustfmt` 결과가 정본. `cargo clippy` 경고를 새로 만들지 않는다.
- [MUST] 라이브러리 코드에서 `unwrap()`·`expect()`·`panic!` 금지 → `Result`와 `?`로 전파. 테스트·예제 코드만 예외.
- [MUST] 오류 타입은 의미를 담는다(열거형 또는 `thiserror`). 문자열 오류는 프로토타입에서만.
- [MUST] `unsafe` 금지. 불가피하면 블록마다 `// SAFETY:` 근거 주석 + 리뷰 승인.
- [MUST] 공개 API에 `pub` 최소화. 소유권은 빌려서(`&`/`&mut`) 넘기고, 필요할 때만 소유권 이동/`clone`.
- [SHOULD] `Option`/`Result` 조합자(`map`·`and_then`·`ok_or`) 우선. 깊은 `match` 중첩 지양.
- [SHOULD] 동시성은 `std::sync`/채널 우선. 전역 가변 상태(`static mut`) 금지.

## 프로젝트
- [MUST] 의존성은 `Cargo.toml`. 외부 크레이트 추가는 근거 제시 후 승인, `Cargo.lock` 커밋.
- [MUST] 시크릿은 `std::env::var`로만. 코드·설정 파일에 키 리터럴 금지 — 없으면 `Err`.
- [MUST] 새 코드에는 테스트(`#[cfg(test)]` 또는 `tests/`)가 있고 `cargo test`가 녹색이어야 완료.
- [SHOULD] 모듈은 파일 단위로 분리, `lib.rs`는 `pub mod` 선언과 재수출만.
