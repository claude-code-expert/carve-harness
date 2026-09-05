# Go 개발 스택 가이드

> **용도**: `.claude/rules/go/patterns.md`(자동 로드 슬림본)의 상세본. 필요할 때만 Read.
> **작성일**: 2026-09-05 · 기준 Go 1.22+ (표준 도구: gofmt · go vet · go test)

## 0. 결론 먼저 — 핵심 규칙 Top 10

| # | 규칙 | 수준 |
|---|------|------|
| 1 | `gofmt`가 정본, `go vet` 경고 0 | MUST |
| 2 | 오류는 반환값으로. 라이브러리에서 `panic` 금지 | MUST |
| 3 | 오류 감쌀 때 `%w`, 버리지 않기 | MUST |
| 4 | 외부 호출 함수는 `ctx context.Context` 첫 인자 | MUST |
| 5 | 고루틴은 종료 조건 필수, 공유 상태는 `sync` | MUST |
| 6 | 시크릿은 `os.Getenv`, 리터럴 금지 | MUST |
| 7 | 테이블 드리븐 테스트, `go test ./...` 녹색 | MUST |
| 8 | 인터페이스는 소비자 쪽에서 작게 | SHOULD |
| 9 | `init()`·전역 가변 상태 지양 | SHOULD |
| 10 | `util`·`common` 패키지 금지 | SHOULD |

## 1. 도구

| 목적 | 도구 | 하네스 게이트 |
|---|---|---|
| 포맷 | `gofmt -w` | PostToolUse(`.claude/stacks/go.sh`) |
| 정적 검사 | `go vet ./...` (선택: `staticcheck`) | Stop |
| 빌드·테스트 | `go build ./...` · `go test ./...` | Stop |
| 커버리지 | `go test -coverprofile=cover.out ./... && go tool cover -func=cover.out` | 평가 어댑터(LP4) |

## 2. 프로젝트 구조

```
module/
├── go.mod
├── cmd/<app>/main.go        # 진입점만 — 로직 없음
├── internal/<pkg>/          # 외부 import 차단 패키지
└── <pkg>/                   # 공개 패키지(필요할 때만)
```

## 3. 오류 처리

```go
func Load(ctx context.Context, path string) (*Config, error) {
    b, err := os.ReadFile(path)
    if err != nil {
        return nil, fmt.Errorf("load config %s: %w", path, err)   // 원인 보존
    }
    ...
}
```
- 호출자는 `errors.Is`/`errors.As`로 분기. 문자열 비교 금지.
- 센티널 오류는 패키지 수준 `var ErrNotFound = errors.New("...")`.

## 4. 동시성

- 고루틴을 띄우는 함수가 종료 책임도 진다(컨텍스트 취소 또는 `WaitGroup`).
- 채널은 보내는 쪽이 닫는다. 닫힌 채널에 보내지 않는다.
- 공유 맵은 `sync.Mutex` 또는 `sync.Map`. 경쟁 검사: `go test -race ./...`.

## 5. 테스트

```go
func TestClamp(t *testing.T) {
    cases := []struct{ v, lo, hi, want int }{{5, 0, 3, 3}, {-1, 0, 3, 0}, {2, 0, 3, 2}}
    for _, c := range cases {
        if got := Clamp(c.v, c.lo, c.hi); got != c.want {
            t.Errorf("Clamp(%d,%d,%d)=%d want %d", c.v, c.lo, c.hi, got, c.want)
        }
    }
}
```
- 외부 의존은 인터페이스로 끊고 테스트 더블 주입. 네트워크·시계는 주입 가능하게.

## 6. 시크릿·설정

```go
func APIKey() (string, error) {
    k := os.Getenv("PAY_API_KEY")
    if k == "" {
        return "", errors.New("PAY_API_KEY is not set")
    }
    return k, nil
}
```
`.env.example`에는 변수 이름만. 값은 절대 커밋하지 않는다(하네스 가드가 차단).
