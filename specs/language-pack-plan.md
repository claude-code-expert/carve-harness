# 언어팩(Language Pack) 설치 체계 — 리서치 리포트 + 세부 개발 계획

> 작성 2026-09-05 · 상태 **LP0~LP5 구현 완료(2026-09-06, 브랜치 `feat/lp0-pack-manifest` → … → `feat/lp5-audit-docs` 순 스택)**. 단계별 리포트: `docs/md/language-packs/LP<n>-*.md`. 후속: `eval-generalization-plan.md` P0·P1a·P1 게이트 확장.
> 목표: 설치 시 언어팩(TS · Java/Spring · Python 우선)을 고르면 **규칙 + 검증 게이트 + 평가 게이트 + 골든셋 스타터**가 한 세트로 들어오고, 안 고른 언어는 파일 자체가 안 깔리는 라이트웨이트 하네스.
> 선행: `specs/eval-generalization-plan.md`(평가 범용화 P0~P3) · `specs/promptfoo-eval-analysis.md`(target 어댑터). 이 문서는 그 위에 "설치 단위"를 얹는다.

---

## 1. 리서치 결과

### 1.1 현재 설치기 구조 (`install.sh`, 872줄)

| 축 | 현재 | 언어팩에 미치는 영향 |
|---|---|---|
| 구성 단위 | 5섹션(`md`·`hooks`·`skills`·`commands`·`orchestrator`) + `core`. `comp_of()`가 경로→구성 매핑, `COMP_ALL` 고정 | 언어는 구성 축이 아니다. 같은 언어 자산이 md(rules)·hooks(eval-java)·skills(예시)에 흩어짐 |
| 선택 UI | 체크박스 TUI(`build_items`→`menu_loop`→`collect_selected`), 섹션 행 토글, 1-5 점프. 비대화형 `HARNESS_COMPONENTS=…`, 테스트는 `HARNESS_SETUP_STDIN=1` stdin 주입 | 섹션 하나 추가하는 구조가 이미 있다. 6번째 섹션 "언어팩"으로 얹을 수 있음 |
| 기록 | `.claude/harness-manifest.txt`(설치 경로 — uninstall 범위), `.claude/harness-components`(선택 구성 — update 신규파일 필터), `.claude/harness-version` | 팩 선택도 같은 두 파일에 기록해야 update/uninstall이 팩을 안다 |
| 맞춤화 모델 | **전체 설치 후 절단**: `/carve-harness-create`가 스택 감지 → KEEP/PRUNE 표 → `install.sh prune --keep-list`. PROTECTED 정규식이 코어 보호, `eval-java.sh`만 예외적으로 절단 허용 | 사용자 요구는 반대 방향(**선택 설치**). 다만 `prune_run`의 파일 단위 제거·백업·rollback은 그대로 재사용 가능 |
| 스택 감지 | `run_setup` 7)에서 package.json·gradlew·*.py 감지해 리포트만. `carve-harness-create` 1-1절에도 감지 절차(프로즈) | 감지 로직이 install.sh·스킬·stop-verify 3곳에 중복. 팩 매니페스트가 단일 출처가 돼야 함 |
| 테스트 | `install-components.test.sh` 17건(env 선택·TUI 키 주입·manifest 범위·update 필터), `remote-install` 22건 | 팩 선택도 같은 방식(stdin 키 주입 + 산출 파일 검사)으로 고정 가능 |

### 1.2 언어별 자산 현황 매트릭스 (실측)

| 자산 | TS/React | Java/Spring | Python | Go | Rust | bash |
|---|---|---|---|---|---|---|
| 상시 로드 규칙 `.claude/rules/<stack>/` (paths glob) | `react-next/patterns.md` 45줄 | `java-spring/patterns.md` 30 + `gateway-testing.md` 31 + archunit 2파일 | **없음** | 없음 | 없음 | 없음 |
| 상세본 `docs/rules/code-convention/` | typescript·react·nextjs·javascript 4파일 694줄 | java-spring 199 | python·fastapi 353 | — | — | — |
| PostToolUse 포맷 (`posttool-format.sh`) | prettier(pnpm 고정) | spotless | **없음**(ruff format 미배선) | — | — | — |
| Stop 검증 게이트 (`stop-verify.sh`, 단일 파일 하드코딩) | tsc·lint·test | gradle compile+test(+GATE-04 게이트웨이) | ruff·pytest | build·vet·test | check·test | shellcheck·훅테스트 |
| 정량 채점기 | 없음 | `eval-java.sh` 199줄(P±오차) | 없음 | 없음 | 없음 | — |
| 골든셋 스타터 | 없음 | 없음 | 예시 2건(`example-harness-e2e.json`, python3 픽스처) | — | — | 하네스 자체 20건 |
| LLM-judge 예시 `docs/evaluator/` | **없음** | 6파일 | 4파일 | — | — | — |
| LSP 플러그인 (`settings.json enabledPlugins`) | vtsls **항상 on** | jdtls **항상 on** | 없음 | — | — | — |
| `carve-harness-create` 스택 게이트 표 | 있음 | 있음(+eval-java↔archunit 간선) | 있음(문서만) | "미지원, 코어가 커버" | 동 | — |

관찰: ① Python은 규칙·포맷·채점기가 비어 "게이트만 있는" 반쪽 팩. ② TS는 judge 예시가 없다. ③ Java만 채점기·archunit·간선 관리까지 완결 — 이게 팩의 **완성 기준 템플릿**이 된다. ④ 무게: 상세본 1,449줄은 자동 로드가 아니라 실제 토큰 부담은 rules/ 슬림본(~100줄)뿐이지만, 파일 수·감사 항목·update 범위·유지보수는 전부 늘어난다. 라이트웨이트의 실익은 토큰보다 **"내 스택과 무관한 게이트·규칙·문서가 없다"는 인지 부담과 감사 잡음 제거**다.

### 1.3 Claude Code 플러그인으로 팩을 만들 수 있나 — 아니오

공식 문서(code.claude.com/docs/en/plugins) 기준 플러그인이 실을 수 있는 것: `skills/`·`commands/`·`agents/`·`hooks/hooks.json`·`.mcp.json`·`.lsp.json`·`monitors/`·`bin/`·`settings.json`(`agent`·`subagentStatusLine` 키만).
**못 싣는 것**: `.claude/rules/`(paths-glob 자동 로드 규칙), `CLAUDE.md`/`AGENTS.md` 내용, `specs/`, `docs/`. 훅도 `settings.json` 훅과 별도 체계라 `stop-verify` 같은 코어 훅과 한 파일로 못 묶는다.
→ 언어팩은 **install.sh 컴포넌트 섹션**으로 간다. LSP만 지금처럼 마켓플레이스 플러그인(`claude-code-lsps`)을 팩이 **켜고 끈다**.

### 1.4 도구 사실 확인 (Context7 · 2026-09-05)

| 언어 | 커버리지 강제 | 기계 판독 리포트 | 비고 |
|---|---|---|---|
| TS (vitest) | `coverage.thresholds.{lines,branches,…}: 80` → 미달 시 실패. CLI `--coverage.thresholds.lines 80` | `--coverage.reporter json` → `coverage/coverage-final.json`, `json-summary` → `coverage-summary.json` | 기본 reporter에 json 포함 |
| Python (pytest-cov) | `--cov-fail-under=80`(0은 비활성 아님, None만 폴백) | `--cov-report=json:cov.json` / `xml:coverage.xml` | pyproject `[tool.coverage.report] fail_under` 폴백 |
| Java (JaCoCo) | `jacocoTestCoverageVerification`(리포 `build-eval.gradle.kts`에 이미 배선) | `build/reports/jacoco/test/jacocoTestReport.xml` — `eval-java.sh`가 파싱 | 기존 자산 |

### 1.5 픽스처 실행 가능성 (골든셋 스타터를 툴체인 없이 돌리려면)

| 언어 | 무의존 픽스처 | 근거 |
|---|---|---|
| Python | `python3` 단일 파일 + `assert` | 이미 `example-harness-e2e.json`·`harness-hard.json`이 이 방식 |
| TS | `node --test` + Node ≥22.18 타입 스트리핑(`.ts` 직접 실행) — 미만이면 `.mjs`+JSDoc 폴백 | tsc·vitest 설치 없이 `cmd_exit0` 가능 |
| Java | `java Foo.java`(JEP 330 단일파일 실행, JDK 11+) + 종료코드 assert | gradle·JUnit 없이 가능. JDK 자체는 필요(없으면 `unable`) |

CI(ubuntu-latest)는 node·python·JDK를 갖지만 **테스트는 기존 관례대로 PATH 스텁**으로 게이트만 검증한다. 로컬(이 머신)엔 java·tsc·pytest·ruff가 없다 — 스텁 테스트 설계가 맞다.

### 1.6 외부 대조에서 가져오는 원칙

- 블루프린트 §4.10 실물②: 규칙 → 훅 → 스킬 → 검증 에이전트 순서. 팩도 같은 순서로 구성(규칙·게이트·채점기·골든셋).
- promptfoo `exec:` target 계약(cwd·argv·stdout): 팩 골든셋은 target 무관, 언어는 `setup`·`cmd_exit0` 안에서만.
- `GUIDE.md §8.2` "새 스택 추가 = 3파일 수정"이 지금의 확장 경로인데, `stop-verify.sh`는 manifest 파일이라 **update 때 사용자 커스텀이 덮인다**(가이드가 직접 경고). 팩이 이 문제를 구조적으로 푼다(스택 정의를 파일 1개로 분리).

---

## 2. 설계

### 2.1 원칙

1. **소스 리포 레이아웃은 안 바꾼다.** 파일은 지금 자리(`.claude/rules/java-spring/` 등)에 두고, 팩은 **경로 목록 파일**로 정의한다. 코드·테스트·감사가 참조하는 경로가 그대로라 회귀 면적이 최소.
2. **팩 = 5요소 세트**: ① 규칙(rules 슬림본 + 상세본) ② 스택 정의(검증 게이트 + 포맷 + 커버리지 파서) ③ 평가 어댑터(정량 채점) ④ 골든셋 스타터(3~5건, 상태 assert, `--red` 통과) ⑤ judge 예시 + LSP 토글. 하나라도 빠지면 `harness-audit`가 **orphan**으로 잡는다(AUDIT-08 일반화).
3. **선택 설치, 절단 재사용.** 팩 미선택 = 그 팩 경로를 설치 직후 `prune_run`으로 제거(백업·manifest 정합·rollback 그대로). 새 복사 로직을 쓰지 않는다.
4. **스택 정의는 데이터 파일 1개.** `.claude/stacks/<pack>.sh`(순수 변수·함수, `lib-protected.sh`와 같은 성격). `stop-verify.sh`·`posttool-format.sh`·`eval-score.sh`·`harness-audit.sh`·`/eval-init`이 이 파일들을 `source`한다. 스택 추가 = 파일 1개 + 팩 목록 1줄.
5. **기본값은 감지.** 대화창은 감지된 팩을 체크한 채 열리고, 엔터 = 감지분만. 비대화형은 `HARNESS_PACKS=typescript,python` 또는 `auto`.

### 2.2 팩 정의 파일 — `packs/<name>.pack`

bash·jq 없이 읽히는 평문. `#` 주석, `key: value` 헤더, 나머지는 설치 경로.

```
# packs/typescript.pack
name: typescript
label: TypeScript / React / Next
detect: package.json tsconfig.json
lsp: vtsls@claude-code-lsps
requires:
# ── paths (설치·manifest·prune 단위) ──
.claude/rules/react-next
.claude/stacks/typescript.sh
docs/rules/code-convention/dev-stack-typescript.md
docs/rules/code-convention/dev-stack-react.md
docs/rules/code-convention/dev-stack-nextjs.md
docs/rules/code-convention/dev-stack-javascript.md
specs/goldenset/starter-typescript.json
docs/evaluator/typescript-example
```

- `java-spring.pack`: `.claude/rules/java-spring`(archunit 포함) · `.claude/stacks/java.sh` · `.claude/hooks/eval-java.sh` · `dev-stack-java-spring.md` · `starter-java.json` · `docs/evaluator/java-example` · `lsp: jdtls@claude-code-lsps`. `requires:` 없음. 간선(eval-java↔archunit)은 팩 내부에 갇히므로 자동 해결.
- `python.pack`: `.claude/rules/python`(**신규** 슬림본, `dev-stack-python.md` Top10에서 추출) · `.claude/stacks/python.sh` · `dev-stack-python.md`·`dev-stack-fastapi.md` · `starter-python.json` · `docs/evaluator/python-example` · `lsp: pyright@claude-code-lsps`(마켓플레이스 실재 확인).
- `database.pack`(부속): `.claude/rules/database.md` · `dev-stack-orm.md`. ORM 감지(`prisma|drizzle|typeorm|@Entity|sqlalchemy`) 시 체크.
- `go.pack`: `.claude/rules/go`(**신규** 슬림본) · `.claude/stacks/go.sh` · `docs/rules/code-convention/dev-stack-go.md`(신규) · `starter-go.json` · `docs/evaluator/go-example` · `lsp: gopls@claude-code-lsps`. detect `go.mod`.
- `rust.pack`: `.claude/rules/rust`(**신규**) · `.claude/stacks/rust.sh` · `dev-stack-rust.md`(신규) · `starter-rust.json` · `docs/evaluator/rust-example` · `lsp: rust-analyzer@claude-code-lsps`. detect `Cargo.toml`.
- bash: 팩 아님. 하네스 자체 게이트(shellcheck·훅 테스트)라 `.claude/stacks/bash.sh`는 코어.

### 2.3 스택 정의 파일 — `.claude/stacks/<name>.sh`

```bash
# .claude/stacks/python.sh — sourced; defines only variables/functions, no side effects
STACK_ID=python
STACK_DETECT_FILES='pyproject.toml requirements.txt setup.py setup.cfg'
STACK_CHANGE_RE='\.py$|pyproject\.toml|requirements[^/]*\.txt|setup\.(py|cfg)'
STACK_FORMAT_EXT='py'
stack_format()   { command -v ruff >/dev/null && ruff format "$1"; }
stack_build()    { :; }                       # 컴파일 단계 없음 → G1은 lint 통과로 대체
stack_lint()     { command -v ruff >/dev/null && ruff check .; }
stack_test()     { command -v pytest >/dev/null && pytest -q; }   # exit 5 = no tests (호출부가 처리)
stack_test_k()   { stack_test; }
stack_coverage() { pytest -q --cov=. --cov-report=json:coverage.json >/dev/null 2>&1 && jq '.totals.percent_covered/100' coverage.json; }
STACK_COVERAGE_MIN=80
STACK_TEST_CMD_HINT='pytest -q'               # /eval-init cmd_exit0 초안
```

`stop-verify.sh`는 `for s in .claude/stacks/*.sh; do source; done` 후 기존 블록과 **동일한 판정**을 수행한다(변경 감지 정규식·툴체인 부재 시 스킵·`no tests` 예외 처리는 함수 밖 호출부에 그대로). Java의 GATE-04(게이트웨이 증분)은 `java.sh`의 `stack_test_scoped()`로 이관.

### 2.4 설치 흐름 (시나리오)

```
$ bash install.sh
── 하네스 구축 방식 ──  [1] 맞춤(권장) [2] 수동
── 언어팩 선택 ──  (감지: package.json·tsconfig.json → typescript · prisma → database)
 > [x] typescript     TS/React/Next — rules 45줄 · Stop tsc/lint/vitest · 골든셋 4 · LSP vtsls
   [ ] java-spring    — rules 61줄+ArchUnit · gradle 게이트 · eval-java · 골든셋 4 · LSP jdtls
   [ ] python         — rules(신규) · ruff/pytest 게이트 · 골든셋 4 · LSP pyright
   [x] database       — ORM/DB 규칙 (prisma 감지)
 ↑↓ 이동 · 스페이스 토글 · a 전체 · 0 팩 없음(코어만) · 엔터 = 현재 선택
── 설치 구성 선택 ── (기존 5섹션 TUI 그대로)
OK: … (팩 미선택 경로는 복사 후 PRUNED: 로 제거, logs/harness-backup/ 백업)
OK: settings.json enabledPlugins — vtsls on · jdtls off
── audit: AUDIT-09 pack[typescript] 5/5 · pack[database] 2/2 ──
다음 단계: /eval-init — 팩 골든셋 스타터 4건을 초안으로 궤적 검사 후 편입
```

- 맞춤(1) 모드: 감지 결과로 팩 자동 확정 후 곧장 진행(질문 1개 줄임). 수동(2): 팩 화면 → 구성 화면.
- 비대화형: `HARNESS_PACKS=auto|none|a,b`. 미지정 + tty 없음 = `auto`(하위호환: 지금까지 "전체"였던 동작은 `HARNESS_PACKS=all`로만).
- 기록: manifest에 팩 경로, `harness-components`에 `pack:typescript` 줄. `update`는 설치된 팩의 신규 파일만 추가, 미설치 팩은 SKIP. `uninstall`은 manifest 기준이라 변경 없음.
- 사후 변경: `bash install.sh pack add python` / `pack remove java-spring` / `pack list`(설치·감지·불일치 표).
- `/carve-harness-create`: KEEP/PRUNE 표의 스택 게이트 절을 **팩 add/remove 제안**으로 교체(경로 목록을 스킬이 더 이상 하드코딩하지 않음).

### 2.5 `/eval-init`과의 접점

S1 분석이 `.claude/stacks/*.sh`의 `STACK_TEST_CMD_HINT`·`STACK_COVERAGE_MIN`을 읽어 Q4(커버리지)·S4 초안(`cmd_exit0`)을 채운다. S4 초안 = 팩 `starter-<lang>.json` 케이스를 **시드로 복사**(id에 프로젝트 접두 부여, version 1.0) → 궤적 검사 → 승인분만 `specs/goldenset/<suite>.json`에 편입. 스타터 파일 자체는 하네스 자산이라 **수정하지 않는다**(update로 덮여도 무방).

### 2.6 골든셋 스타터 케이스 (팩당 4건, 전부 상태 assert, `--red` 통과 조건)

| id 접미 | 재는 것 | 픽스처(무의존) | assert 골자 |
|---|---|---|---|
| `bugfix-state-verified` | 버그 수정 + 테스트 실행 | 틀린 함수 1개 + git init | `cmd_exit0: <테스트 명령>`, `git_diff_contains` |
| `test-catches-mutation` | 테스트가 실제로 검출하는가 | 함수 + 빈 테스트 | 변이 삽입 후 테스트 실패 exit≠0 |
| `lint-clean-change` | 팩 린터 규칙 준수 | 린트 위반 파일 | `cmd_exit0: <lint 명령>`(툴 없으면 케이스가 `unable`로 보고, 조용한 통과 없음) |
| `no-secret-in-config` | 시크릿 하드코딩 회피 | 설정 파일 요구 프롬프트 | `not_regex` 시크릿 패턴 + `file_exists` env 예시 |

언어별 실행 명령: Python `python3 test_x.py` · TS `node --test x.test.ts`(Node<22.18이면 `.mjs`) · Java `java Test.java`. `harness-hard.json`의 5건이 이미 이 형식이라 복제·치환으로 만든다.

---

## 3. 세부 개발 계획 (한 단씩 · SC는 명령으로 증명)

| 단계 | 산출물 | 완료 기준(SC) |
|---|---|---|
| **LP0 팩 정의 + 파서** | `packs/{typescript,java-spring,python,database}.pack` · `install.sh`에 `pack_paths()`·`pack_meta()`·`detect_packs()` (평문 파서, jq 불요) | ① 4팩 파싱 결과 경로가 전부 소스에 실재(`[ -e ]`) ② `detect_packs`가 픽스처 디렉토리(package.json+tsconfig / gradlew / pyproject / prisma)마다 정확히 해당 팩만 출력 ③ 빈 디렉토리 → 출력 없음 |
| **LP1 스택 정의 파일화** | `.claude/stacks/{typescript,java,python,go,rust,bash}.sh` · `stop-verify.sh`·`posttool-format.sh`가 `source` · GATE-04는 `java.sh` 이관 · Python `ruff format` 배선 | ① `stop-verify.test.sh` 18건·`posttool-format.test.sh` 7건 **수정 없이** green(동작 동일) ② 스택 파일 하나를 지우면 그 스택 게이트만 사라지고 나머지 green(스텁 PATH) ③ `bash -n`·shellcheck -S error 통과 ④ `harness-audit` 48 PASS 유지 |
| **LP2 설치기 팩 섹션** | TUI 6번째 섹션 "언어팩" · `HARNESS_PACKS` · `auto` 감지 · 미선택 팩 `prune_run` 제거 · manifest/`harness-components` 기록 · `enabledPlugins` 토글 · `install.sh pack add\|remove\|list` · `tests/install-packs.test.sh` | ① `HARNESS_PACKS=python` 설치본에 `.claude/rules/java-spring`·`eval-java.sh`·`react-next` 부재, `stacks/python.sh`·`starter-python.json` 존재 ② `HARNESS_PACKS=none` → 팩 경로 0, 코어 게이트 동작 ③ TUI 키 주입(`2\n…`)으로 java 해제 → 산출 동일 ④ `pack add java-spring` 후 manifest에 팩 경로 추가·`enabledPlugins.jdtls=true` ⑤ `update`가 미설치 팩 신규 파일을 SKIP ⑥ `uninstall` 후 잔존 0 ⑦ 기존 `install-components` 17건·`remote-install` 22건 green |
| **LP3 골든셋 스타터 + judge 예시** | `specs/goldenset/starter-{typescript,java,python}.json` 각 4건 · `docs/evaluator/typescript-example/` · `.claude/rules/python/patterns.md`(신규 슬림본) | ① `carve-validate.sh --red specs/goldenset/starter-*.json` 0 error·NO-SIGNAL 0 ② 각 케이스 정답 상태 green을 픽스처 스크립트로 증명(`tests/goldenset-starter.test.sh`) ③ 툴체인 없는 머신에서 `unable` 보고(조용한 통과 0) ④ 기존 하네스 골든셋 20건 무변경 |
| **LP4 범용 채점기 팩 연동** | `eval-score.sh`(`eval-generalization-plan` P1)가 `.claude/stacks/*.sh`로 build/test/lint/coverage 수집 · Java는 `eval-java.sh` 위임 | ① 3팩 스텁 픽스처에서 `SCORE.json` 생성, G1~G3 거부권·`skipped` 동작 ② 스택 파일 없는 디렉토리 → `unable` exit 1 ③ `eval-java` 경로 중복 구현 0 |
| **LP5 감사·스킬·문서** | `harness-audit.sh` AUDIT-09(설치 팩마다 5요소 존재·`--red` 통과·LSP 토글 정합; AUDIT-08 흡수) · `carve-harness-create` 4절을 팩 add/remove 제안으로 교체 · `/eval-init` S1/S4 팩 연동 · README ko/en·GUIDE §8.2(스택 추가 = `stacks/*.sh` 1파일 + `.pack` 1줄)·HARNESS_GUIDE | ① 팩 파일 1개 삭제 → AUDIT-09 FAIL 1건, 복구 → PASS ② `carve-harness-create` 스킬 참조 경로 실재 테스트 green ③ 문서 수치 = 실측(훅·스위트·체크 수) ④ `version-changelog`로 릴리스 항목 |

순서: **LP0 → LP1 → LP2 → LP3 → LP4 → LP5**. 각 단계 PR 1개. `eval-generalization-plan`의 P0(추이 무결성)는 독립·소규모라 LP0 전에 먼저 처리 권장. P1a(target 어댑터)·P1 게이트 확장은 LP4 뒤에 이어간다.

규모 추정(코드 줄, 테스트 제외): LP0 ~120 · LP1 ~250(이동 위주) · LP2 ~300 · LP3 ~400(JSON·픽스처) · LP4 ~250 · LP5 ~200.

---

## 4. 승인 필요한 결정

| # | 결정 | 권장 | 대안 |
|---|---|---|---|
| D1 | 팩 granularity | `typescript`(React/Next 포함)·`java-spring`·`python`·`go`·`rust`·`database`(부속) 6개 | React/Next를 별도 팩으로 — 규칙 파일이 1개라 분리 이득 없음 |
| D2 | Go/Rust | **팩 승격 확정(2026-09-05 사용자 결정)** — 슬림 규칙·스택 정의·스타터·judge 예시 신규 작성. bash만 코어 | — |
| D3 | 비대화형 기본 | `HARNESS_PACKS` 미지정 = `auto` 감지 | `all`(현행) — 라이트웨이트 목표와 충돌 |
| D4 | Python 슬림 규칙 신설 | `dev-stack-python.md` Top10 MUST → `.claude/rules/python/patterns.md` ~25줄 | 상세본만 유지 — 팩 5요소 미달 |
| D5 | `stop-verify.sh` 데이터화(LP1) | 실행. 테스트 무수정 green이 안전판 | 게이트 코드 유지 + 스택 파일은 채점기만 사용 — 검증 게이트가 팩 단위로 안 빠져 "세트" 미성립 |
| D6 | Python LSP | `pyright@claude-code-lsps` (마켓플레이스 실재 확인 2026-09-05, `basedpyright`·`ty`도 있음) | `basedpyright@claude-code-lsps` |

## 5. 범위 밖

- 골든셋 자동 확정(기존 결정 유지) · Go/Rust 팩 · 플러그인 마켓플레이스 배포 · promptfoo exporter(P3).
- `.claude/rules/common/*`·`safety.md`·훅 코어는 팩과 무관하게 항상 설치(PROTECTED 유지).
