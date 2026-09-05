---
paths: ["**/*.go"]
---
# Go 규칙 (자동 로드)

> 자동 로드되는 **규칙 목록**. 근거·샘플은 상세본 참조: `docs/rules/code-convention/dev-stack-go.md`
> 게이트: `.claude/stacks/go.sh` — `go build` · `go vet` · `go test ./...`(Stop) · `gofmt -w`(PostToolUse)

## 코드
- [MUST] `gofmt` 결과가 정본. 손 정렬·임의 스타일 금지. `go vet` 경고 0.
- [MUST] 오류는 반환값으로 전파한다. 라이브러리 코드에서 `panic`·`log.Fatal` 금지(main 진입점만 허용).
- [MUST] 오류를 버리지 않는다(`_ = f()` 금지). 감쌀 때는 `fmt.Errorf("...: %w", err)`로 원인 보존.
- [MUST] 블로킹·외부 호출 함수는 첫 인자로 `context.Context`를 받는다. 컨텍스트를 구조체에 저장하지 않는다.
- [MUST] 고루틴은 종료 조건이 있어야 한다(컨텍스트 취소·채널 닫힘). 누수 금지. 공유 상태는 `sync`로 보호.
- [SHOULD] 인터페이스는 사용하는 쪽에서 작게 정의. 구현체 패키지에서 인터페이스를 미리 만들지 않는다.
- [SHOULD] `init()` 지양. 전역 가변 상태 지양.

## 프로젝트
- [MUST] `go.mod` 단일 모듈 기준. 외부 모듈 추가는 근거 제시 후 승인.
- [MUST] 시크릿은 `os.Getenv`로만. 코드·설정 파일에 키 리터럴 금지 — 없으면 오류 반환.
- [MUST] 테스트는 표준 `testing` + 테이블 드리븐. 새 코드에는 `_test.go`가 있고 `go test ./...`가 녹색이어야 완료.
- [SHOULD] 패키지명은 소문자 단일 단어. `util`·`common` 같은 잡동사니 패키지 금지.
