# LP1 — 스택 정의 파일화 (`.claude/stacks/<pack>.sh`)

> 브랜치 `feat/lp1-stack-files`(LP0 위) · 계획 `specs/language-pack-plan.md` §3 LP1
> 결과: `stop-verify.sh`·`posttool-format.sh`가 스택별 하드코딩 블록 대신 `.claude/stacks/*.sh`를 source. 기존 `stop-verify` 18건·`posttool-format` 7건 **무수정 green**, 신규 `stacks.test.sh` 13건, 감사 50 PASS.

## 1. 구성

```
.claude/stacks/
├── java-spring.sh   gradle compile+test · GATE-04 게이트웨이 증분(JAVA_GW_RE) · spotless
├── typescript.sh    tsc(tsconfig 있을 때)·lint/test 스크립트 있을 때 · prettier(pnpm)
├── python.sh        ruff check · pytest(exit 5 허용) · ruff format  ← 포맷은 이번에 신규 배선
├── go.sh            go build/vet/test("no test files" 허용) · gofmt
├── rust.sh          cargo check/test · rustfmt
└── bash.sh          shellcheck -S error · 훅 테스트 전수 (코어 — 팩 아님)
.claude/hooks/stop-verify.sh      공통 골격만: 루프가드 → jq → 변경 감지 → 스택 순회 → 로그   (157→57줄)
.claude/hooks/posttool-format.sh  스택 순회로 포맷터 라우팅                                     (34→36줄)
.claude/hooks/tests/stacks.test.sh 13건
packs/*.pack                      각 언어팩에 `.claude/stacks/<pack>.sh` 경로 추가
```

스택 파일 이름 = 팩 이름(`java-spring.sh`, 계획 초안의 `java.sh` 대신). 팩 ↔ 스택 1:1을 테스트가 강제한다.

### 스택 파일 계약 (모든 `.claude/stacks/*.sh`)

| 심볼 | 의미 |
|---|---|
| `STACK_ID` | 팩 이름(파일명과 동일) |
| `STACK_CHANGE_RE` | `git status --porcelain` 경로에 대한 ERE — 맞을 때만 게이트 실행(GATE-03 증분). git 없으면 항상 실행 |
| `STACK_FORMAT_RE` | 쓰기된 파일 경로 ERE — 맞으면 PostToolUse 포맷(`''` = 포맷 없음) |
| `STACK_FORMAT_TOOL` | JSONL에 기록될 도구명(`spotless`·`prettier`·`ruff`·`gofmt`·`rustfmt`) |
| `stack_format FILE` | rc 0 ok · 1 포맷터 오류 · 2 도구 없음 → `format-ok` / `format-fail:error` / `format-fail:missing` |
| `stack_gate` | rc 0 통과 · 1 실패(→ Stop exit 2). `$CHANGED` `$have_git` `$HOOKS_DIR`를 읽는다 |

소싱 시 부작용 없음(변수·함수 정의만). 훅은 파일마다 `unset -f stack_gate stack_format` 후 source → 즉시 실행이라 스택끼리 함수 이름이 섞이지 않는다. 스택 내부 보조 함수는 접두어로 구분(`ts_verify_dir`).

## 2. 구현 메모

- **동작 동일성**: 변경 감지 정규식·툴체인 부재 시 스킵·`pytest` exit 5·`go test` "no test files"·gradle `--tests` 매칭 0 → best-effort 스킵·`tail -20` 출력 절단까지 원문 그대로 옮겼다. `set -o pipefail`은 골격에 남아 스택 함수 안 `cmd | tail || return 1`에 그대로 적용된다.
- **GATE-04 이관**: 게이트웨이 판별 정규식은 `java-spring.sh`의 `JAVA_GW_RE`. `harness-audit` AUDIT-07이 이제 이 파일에서 `GatewayIntegration` 트리거를 확인한다(정책↔게이트 매핑 유지).
- **자기보호 확장**: `lib-protected.sh` GUARD-07 그룹에 `stacks/` 추가 — 설치본에서 에이전트가 `stack_gate`를 무력화하는 쓰기를 차단. 소스 리포는 manifest가 없어 예외(기존과 동일).
- **감사**: AUDIT-01에 "모든 `.claude/stacks/*.sh` bash -n" 집계 검사 1건 추가(49→50). 스택 파일의 문법 오류는 두 훅을 동시에 죽이므로 별도 검사가 필요했다.
- **설치기**: `HOOK_PATHS`에 `.claude/stacks` 추가(hooks 구성 소속). `prune_expand_manifest`가 파일 단위로 펼치고, HEAL 분기가 누락 파일만 채운다 — LP2의 팩 단위 제거·추가가 이 두 지점을 그대로 쓴다.
- **신규 동작 1건**: `.py` 쓰기 시 `ruff format`(없으면 `format-fail:missing`). 이전엔 `format-skip`. 계획 LP1 항목대로.

## 3. 사용방법

```bash
# 스택이 무엇을 재는지 보기
cat .claude/stacks/python.sh
# 검증 명령·포맷터 바꾸기 → 해당 스택 파일만 편집 (훅은 건드리지 않는다)
# 새 스택 추가 → GUIDE.md §8.2 (Ruby 예시: 파일 1개)
# 스택 하나 끄기(임시) → 파일을 옮겨두면 그 게이트만 사라진다
mv .claude/stacks/rust.sh /tmp/   # rust 게이트 off, 나머지 그대로
bash .claude/hooks/tests/stacks.test.sh   # 계약·팩 1:1·제거 시 격리 13건
```

## 4. 완료 기준(SC) 검증

| SC | 증명 | 결과 |
|---|---|---|
| ① `stop-verify.test.sh` 18 · `posttool-format.test.sh` 7 **무수정** green | 두 파일 diff 없음, 실행 | PASS 18/18 · 7/7 |
| ② 스택 파일 하나 제거 → 그 게이트만 소실, 나머지 green | `stacks.test.sh` (2): go.sh 제거 후 Go 픽스처 exit 0 · Rust 픽스처 exit 2 · 복구 후 Go exit 2 | PASS |
| ③ `bash -n`·shellcheck | 전 스택 파일 bash -n; shellcheck는 이 머신 부재(CI에서 Stop 게이트가 실행) | PASS |
| ④ `harness-audit` PASS 유지 | 50 passed, 0 failed(+1: 스택 bash -n) | PASS |
| 포맷 라우팅도 스택 파일 기준 | `stacks.test.sh` (3): go.sh 있으면 `format-ok:gofmt`, 제거하면 `format-skip` | PASS |
| 전체 회귀 | `npm test` 23 스위트 | ALL SUITES PASSED |

## 5. 다음 단계(LP2)

설치기 6번째 섹션 "언어팩": `pack_detect`로 기본 체크, `HARNESS_PACKS=auto|none|a,b`, 미선택 팩 경로를 복사 직후 `prune_run`으로 제거, manifest/`harness-components`에 `pack:<name>` 기록, `enabledPlugins` LSP 토글, `install.sh pack add|remove|list`.
