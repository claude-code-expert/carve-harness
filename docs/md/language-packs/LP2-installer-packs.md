# LP2 — 설치기 언어팩 섹션 (`install.sh`)

> 브랜치 `feat/lp2-installer-packs`(LP1 위) · 계획 `specs/language-pack-plan.md` §3 LP2
> 결과: 설치 시 팩 선택(감지 기본) → 미선택 팩 경로 미설치 → `harness-packs` 기록 → LSP 토글. `install.sh pack list|add|remove`. 신규 `install-packs.test.sh` 19건, 기존 설치 스위트 4종(75건) 무수정 green.

## 1. 구성

| 요소 | 위치 | 역할 |
|---|---|---|
| 팩 선택 | `select_packs()` | `HARNESS_PACKS` env → 구성 env(전체) → 맞춤 모드(감지) → tty 한 줄 질문 → 감지 |
| 경로 추가 | install 분기 | 선택 팩 경로 중 coarse 복사에 안 들어오는 것(`docs/evaluator/*`)을 `SELECTED_PATHS`에 추가 |
| 경로 제외 | `pack_exclude_unselected()` → `prune_run … nobak=1` | coarse 복사(`.claude/rules`·`.claude/stacks`·`docs/rules`)에 딸려온 미선택 팩 경로 제거. 백업 없음(`EXCLUDED:` 로그), manifest는 파일 단위로 재작성 |
| 기록 | `.claude/harness-packs` | 한 줄 한 팩. gitignore 블록에 추가. update·pack·uninstall이 읽는다 |
| LSP 토글 | `pack_lsp_toggle()` (bootstrap 4.44) | `settings.json enabledPlugins[<lsp>]` = 선택 여부. 소스에 없던 키(pyright·gopls·rust-analyzer)도 추가 |
| 사후 관리 | `install.sh pack list\|add\|remove` | list: 설치/감지/누락 표. add: 소스에서 팩 경로 복사 + manifest. remove: `prune_run`(백업 → `rollback` 복원) |
| update | update 분기 | 설치된 팩의 경로만 신규 파일 대상. 기록 없는 설치본(팩 이전)은 전체로 간주하고 기록 생성 |
| rollback 정합 | `prune_run` | 제거 시 manifest·harness-packs도 백업 → rollback이 기록까지 되돌린다(이전엔 파일만 복원돼 uninstall 범위 이탈) |
| uninstall | `uninstall.sh` | `harness-packs` 삭제 + 파일 단위 manifest가 남기는 빈 디렉토리 정리 |
| 소스 자산 | `CORE_PATHS`에 `packs` | 설치본이 `pack list/add/remove`를 알 수 있게 팩 정의를 동봉 |

## 2. 설치 시나리오

```
$ bash install.sh                       # tty, 감지: package.json → typescript
── 하네스 구축 방식 ──  [1] 맞춤(권장)  [2] 수동
1 →  구성 전체 + 언어팩 = 감지분(typescript). 질문 없음.
2 →  구성 체크박스 TUI → 이어서:
     ── 언어팩 선택 ── (감지: typescript)
       [x] typescript   rules react-next · Stop tsc/lint/test · LSP vtsls
       [ ] java-spring  rules java-spring+ArchUnit · gradle gate · eval-java scorer · LSP jdtls
       [ ] python       ruff/pytest gate · LSP pyright
       [ ] go           go build/vet/test gate · LSP gopls
       [ ] rust         cargo check/test gate · LSP rust-analyzer
       [ ] database     rules database.md · ORM conventions
     엔터=감지분 · a=전체 · 0=없음 · 이름 콤마목록(예: typescript,python):
...
EXCLUDED: .claude/rules/java-spring (언어팩 미선택)      ← 미선택 팩은 파일 자체가 없다
── 언어팩 제외: 14 개 경로 미설치 ──
OK: settings.json enabledPlugins — 언어팩 LSP 토글 (on: typescript)
```

비대화형:

| 상황 | 결과 |
|---|---|
| `curl … \| bash` (tty 없음, env 없음) | **auto** — 감지된 팩만 (라이트웨이트 기본) |
| `HARNESS_PACKS=python,go` | 지정 팩만. 모르는 이름은 WARN 후 무시 |
| `HARNESS_PACKS=all` / `none` / `auto` | 전체 / 팩 없음(코어만) / 감지 |
| `HARNESS_COMPONENTS=…`만 지정 | **all** — 기존 스크립트·테스트 회귀 가드(팩 개념 이전과 동일 결과) |

팩 질문은 구성 TUI **뒤**에 나온다. TUI가 키 입력을 한 글자씩 소비하므로 앞에 두면 stdin 주입(테스트·파이프)이 깨진다.

## 3. 사용방법

```bash
bash install.sh pack list                       # 언어팩 / 설치 / 감지 / 요약 (누락 경로 있으면 표시)
HARNESS_SRC_DIR=/path/to/harness bash install.sh pack add java-spring   # 오프라인 소스에서 추가
bash install.sh pack add rust                   # 온라인: GitHub에서 받아 추가
bash install.sh pack remove typescript          # 제거(백업) → bash install.sh rollback 으로 복원
bash install.sh update                          # 설치된 팩의 신규 파일만 받는다
```

## 4. 완료 기준(SC) 검증 — `install-packs.test.sh`

| SC | 검증 | 결과 |
|---|---|---|
| ① `HARNESS_PACKS=python` → java/react/eval-java/타 스택 부재, python 스택·예시·문서 존재 | (1) | PASS |
| ② `none` → 팩 경로 0, `bash.sh`·코어 훅 동작 | (2) + stop-verify 실행 | PASS |
| ③ 대화형(stdin `2\n\ntypescript,go\n`) → 두 팩 | (5) | PASS |
| ④ `pack add java-spring` → 경로·manifest·기록·jdtls on, audit PASS(AUDIT-08 간선) | (7) | PASS |
| ⑤ update가 미설치 팩 신규 파일 SKIP, 설치 팩 파일은 도착 | (10) | PASS |
| ⑥ uninstall 후 잔존 0(빈 디렉토리 포함) | (11) | PASS |
| ⑦ 기존 `install-components` 17 · `remote-install` 22 · `carve-harness-create` 15 · `settings` 9 무수정 green | 실행 | PASS |
| 추가 | auto(go.mod→go) · 레거시 가드 · 미지 팩 WARN · LSP 토글 · list 표시 · remove+rollback | (3)(4)(6)(8)(9) | PASS |
| 전체 | `npm test` 24 스위트 · `harness-audit` | ALL SUITES PASSED · 50 PASS |

## 5. 알려진 한계 / 다음

- `pack add`는 hooks 구성이 설치돼 있어야 한다(`lib-packs.sh`가 hooks에 속함). hooks 미선택 설치본에선 `install.sh update` 후 사용.
- 팩 질문은 한 줄 텍스트 입력이다(체크박스 TUI 아님). 감지 기본값이 맞으면 엔터 한 번.
- LP3: 팩별 골든셋 스타터(4건)·judge 예시(TS·Go·Rust)·Python/Go/Rust 슬림 규칙 → 각 `.pack`에 경로 추가.
