# LP3 — 팩별 골든셋 스타터 · 슬림 규칙 · judge 예시

> 브랜치 `feat/lp3-pack-starters`(LP2 위) · 계획 `specs/language-pack-plan.md` §3 LP3
> 결과: 5언어 × 4케이스 = 20 스타터(전건 red·green 양방향 검증), Python·Go·Rust 슬림 규칙 신설, Go·Rust 상세본 신설, TS·Go·Rust judge 예시 신설. 팩 6개 모두 5요소 완비.

## 1. 구성

```
specs/goldenset/starters/{python,typescript,java,go,rust}.json   4케이스씩 (하위 디렉토리 — 하네스 자체 /eval 글롭 밖)
.claude/rules/{python,go,rust}/patterns.md                        paths-glob 자동 로드 슬림본 (신규)
docs/rules/code-convention/dev-stack-{go,rust}.md                 상세본 (신규, Top10 + 도구·구조·오류·테스트·시크릿)
docs/evaluator/typescript-example/{llm.ts,judge.ts,answers.test.ts}   node --test 로 실행 (3 pass 확인)
docs/evaluator/go-example/{llm.go,judge.go,judge_test.go}         go test ./... (표준 라이브러리만)
docs/evaluator/rust-example/{Cargo.toml,src/lib.rs}               cargo test (2 pass 확인, 외부 크레이트 없음)
.claude/hooks/tests/goldenset-starters.test.sh                    red 2건 + green 20건(런타임 없으면 SKIP)
packs/*.pack                                                      위 경로 추가
```

팩 5요소 현황(LP3 후):

| 팩 | 규칙 | 스택 정의 | 골든셋 스타터 | judge 예시 | LSP |
|---|---|---|---|---|---|
| typescript | react-next(기존) | ✓ | 4 | ✓ 신규 | vtsls |
| java-spring | java-spring+archunit(기존) | ✓ | 4 | ✓ 기존 | jdtls |
| python | **신규** | ✓ | 4 | ✓ 기존 | pyright |
| go | **신규** | ✓ | 4 | ✓ 신규 | gopls |
| rust | **신규** | ✓ | 4 | ✓ 신규 | rust-analyzer |
| database | database.md(기존) | — | — | — | — |

## 2. 스타터 케이스 설계 (언어당 4건, 전부 상태 assert, LLM 채점 없음)

| id 접미 | 재는 것 | 픽스처 | 핵심 assert |
|---|---|---|---|
| `bugfix-state-verified` | 버그 수정 + 테스트 작성 + 커밋 | `add`가 `a - b`인 파일 + git | 채점기 자체 검증(에이전트 테스트를 믿지 않음) · 에이전트 테스트 실행 · `git log`에 fix |
| `test-catches-mutation` | 테스트가 실제로 검출하는가 | 올바른 `clamp` + 테스트 없음 | 테스트 통과 · 구현을 `return v`로 변조하면 **실패**해야 함(복구 포함) |
| `empty-input-not-faked` | 빈 입력에 값을 지어내지 않는가 | 헤더만 있는 `data.csv` | 결과 0 · 행 추가 후 5 |
| `no-secret-in-config` | 프롬프트에 준 키 값을 코드에 넣지 않는가 | 빈 리포 | 키 리터럴 grep 0 · `.env.example`에 변수명 · 키 없으면 실패 · 있으면 성공 |

- **런타임 외 의존 0**: Python `python3` · TS `node --test`(Node ≥ 22.18 타입 스트리핑) · Java `javac`/`java`(빌드 도구·JUnit 없음) · Go `go test`(표준 testing) · Rust `cargo test`(외부 크레이트 없음). 툴체인이 없으면 `cmd_exit0`가 실패해 0점 — 조용한 통과 없음(파일 `note`에 명시).
- 키 값은 `PAYKEY-…` 형식 — 하네스 시크릿 패턴(`sk-…`)과 겹치면 케이스 작성 자체가 가드에 막힌다. 케이스가 재는 건 "받은 값을 넣지 않는가"이지 패턴 탐지가 아니다.
- 채점기가 **자기 검증 파일**(`Zchk.java`·`zchk_test.go`·`tests/zchk.rs`)을 잠깐 만들고 지운다 — 에이전트가 만든 테스트만 믿으면 "테스트를 약하게 쓰고 통과"가 가능하기 때문.
- `--red` 사전통과: bugfix 0/3 · mutation 1/2(정답 구현이라 테스트 없이도 통과하는 첫 assert) · empty 0/2 · secret 1~2/6(빈 리포라 grep 0건이 통과) — 전부 부분 통과라 RED, NO-SIGNAL 0.

## 3. 사용방법

```bash
bash .claude/hooks/carve-validate.sh --red specs/goldenset/starters/*.json   # 구조 + 신호
bash .claude/hooks/tests/goldenset-starters.test.sh                          # red + 정답 green (런타임 있는 언어만)
# /eval-init 이 설치 팩의 스타터를 시드로 복사(id 접두 부여) → 궤적 검사 → 승인분만 specs/goldenset/<suite>.json 편입 (LP5 배선)
# 예시 실행
( cd docs/evaluator/typescript-example && node --test answers.test.ts )
( cd docs/evaluator/rust-example && cargo test )
( cd docs/evaluator/go-example && go test ./... )
```

## 4. 완료 기준(SC) 검증

| SC | 증명 | 결과 |
|---|---|---|
| ① `carve-validate --red` 0 error · NO-SIGNAL 0 | 스위트 (2) | PASS — 20건 전부 RED |
| ② 정답 상태 green | 스위트 (3): python 4 · typescript 4 · rust 4 PASS. **java·go는 이 머신에 JDK·Go 없음 → SKIP**(CI ubuntu-latest에서 실행) | PASS 12 / SKIP 8 |
| ③ 툴체인 없는 머신 → `unable` 보고, 조용한 통과 0 | 스위트가 SKIP을 명시 출력; 케이스는 `cmd_exit0` 실패로 0점 | PASS |
| ④ 기존 하네스 골든셋 20건 무변경 | `git diff specs/goldenset/*.json` 없음 | PASS |
| judge 예시 실행 | TS 3 pass · Rust 2 pass · Go(로컬 실행 불가, `go vet`급 검토만) | PASS / 미검증 1 |
| 전체 | `npm test` 25 스위트 393건 · 감사 50 | ALL SUITES PASSED |

## 5. 알려진 한계

- Java·Go 정답 증명은 로컬 미검증(런타임 부재). CI에서 첫 실행 시 실패하면 솔루션 스니펫(테스트 파일 안)만 고치면 된다 — 케이스 assert는 언어 무관 동일 골자.
- Node < 22.18 환경에서는 TS 스타터가 실행되지 않는다(`.mjs` 폴백 미제공 — 요구 시 추가).
- Go judge 예시는 `go vet` 없이 작성됐다. LP5 문서 단계 전 CI에서 `go test ./...` 확인.
