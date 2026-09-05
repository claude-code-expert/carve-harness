# `.claude/stacks/` — 스택 정의 (언어팩 단위)

스택 하나 = 파일 하나. `stop-verify.sh`(검증 게이트)·`posttool-format.sh`(포맷)·`eval-score.sh`(채점 어댑터)가 이 파일들을 `source`한다. 언어팩(`packs/`)이 설치·제거하는 단위이며, 미선택 언어는 파일이 없다.

| 파일 | 스택 | 게이트·포맷 |
|---|---|---|
| `typescript.sh` | TS/React/Next | tsc·lint·test · prettier |
| `java-spring.sh` | Java/Spring | gradle compile/test(게이트웨이 증분) · spotless · eval-java |
| `python.sh` | Python | ruff check·pytest · ruff format |
| `go.sh` | Go | build/vet/test · gofmt |
| `rust.sh` | Rust | cargo check/test · rustfmt |
| `bash.sh` | 하네스 자체 | shellcheck·훅 자가테스트 (코어 — 팩 아님) |

**계약**(모든 파일): `STACK_ID` · `STACK_CHANGE_RE`(증분 트리거) · `STACK_FORMAT_RE`/`STACK_FORMAT_TOOL` · `stack_format` · `stack_gate` · 채점 어댑터(`stack_detect`/`build`/`test`/`lint`/`coverage`, `STACK_COVERAGE_MIN`). 소싱 시 부작용 없음. 새 스택은 파일 1개로 붙는다(`GUIDE.md` §8.2).
