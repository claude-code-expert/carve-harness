# carve-harness 설치 매뉴얼

> 프로젝트를 분석해 그 프로젝트에 맞는 하네스(스킬·훅·서브에이전트·커맨드)를 **대화형으로 선택해** 설치하는 CLI.
> carve = 범용 자산을 프로젝트에 맞게 **깎아냄**. 일괄 설치는 하지 않는다.

영문 매뉴얼: [INSTALL.en.md](./INSTALL.en.md) · 개요: [README.md](./README.md)

---

## 1. 요구사항

| 항목 | 값 |
|------|----|
| Node.js | **>= 22.18** (타입 스트리핑으로 `.ts` 직접 실행 — 빌드 단계 없음) |
| OS | macOS · Linux (생성 훅은 bash 스크립트) |
| git | 선택 — 커밋/푸시 관련 훅을 쓸 때만 |
| 패키지 매니저 | 자동 탐지(npm·pnpm·yarn·bun·pip·poetry·cargo·go) |

설치 대상은 **현재 디렉토리의 `.claude/`** 와 프로젝트 루트의 가이드 문서다. carve는 소스 코드를 수정하지 않는다.

---

## 2. 빠른 시작 — 풀 설치 흐름 (글로벌 설치 권장)

```bash
npm i -g carve-harness         # carve CLI 설치 (전체 기능 권장)
carve install                  # 1. 대화형 선택 설치 (탐지 → 추천 → 선택)
carve init-claude              # 2. CLAUDE.md 베이스라인 + 언어 스택 규칙 생성
carve doctor                   # 3. 설치 점검 (구성·훅 문법)
```

세션(Claude Code) 안에서는 **"이 프로젝트에 맞는 하네스 구성해줘"** 한마디로 `harness-architect` 스킬이
같은 1–3단계를 안내한다.

---

## 3. 설치 방식

### 3.1 글로벌 설치 (권장 — 전체 기능)
```bash
npm i -g carve-harness       # 이후 carve install · update · diff · doctor 를 영구 명령으로
```
`carve`가 PATH에 남아 반복 CLI(`update`·`diff`·`doctor`)까지 편하게 쓴다. 이 문서의 `carve <명령>`은 이 설치 기준이다.
글로벌 없이 한 번만/CI에서는 `npx carve-harness@latest <명령>`(예: `npx carve-harness@latest install`)으로 일회성 실행한다.

### 3.2 bash 래퍼 (리포 clone 또는 curl 시에만)
`install.sh`는 **npm 패키지에 포함되지 않는다.** 이 리포를 clone했거나 `curl`로 받았을 때만 존재하는 편의 래퍼이며,
내부적으로 로컬 소스가 있으면 `node bin/carve.ts`, 없으면 `npx carve-harness@latest`를 호출한다. 일반 프로젝트 설치는 3.1(npx)을 쓴다.
```bash
bash install.sh              # 현재 디렉토리에 설치 (리포 안에서)
bash install.sh --uninstall  # 제거
curl -fsSL <repo-raw-url>/install.sh | bash   # 리포에서 직접 받아 실행
```

### 3.3 로컬 클론 (개발/검토)
```bash
git clone <repo> && cd carve-harness
node bin/carve.ts install <대상-프로젝트-경로>
```

---

## 4. 설치 모드 — 어떻게 고를까

| 모드 | 명령 | 언제 |
|------|------|------|
| **대화형 선택** (기본) | `carve` 또는 `carve install` | 추천을 보고 체크박스로 고르고 싶을 때 (TTY) |
| **명시 선택** | `carve install --only commit,handoff,block-destructive` | CI·스크립트 등 비대화형으로 특정 구성요소만 |
| **레벨 강제** | `carve install --level full` | 자동 판정을 무시하고 레벨을 직접 정할 때 |
| **언어서버 자동설치** | `carve install --lsp-servers` | LSP 추천 시 탐지 언어의 언어서버(`npm i -g`)까지 설치 |

> 대화형 설치는 추천 항목을 **기본 체크**로 제시하되, **사용자가 고른 것만** 설치한다(일괄 자동 설치 없음).
> 옵션은 조합 가능: `carve install --level standard --only commit,pr,block-destructive`.

---

## 5. 설치 레벨

프로필(타입·언어 수·CI)로 자동 판정하며 `--level`로 강제할 수 있다.

> 레벨에 따라 달라지는 건 **훅 개수와 추가 스킬**이다. 코어 스킬·**Squad 9 에이전트**·anti-slop은 *모든 레벨*에서 기본 추천된다(코어).

| 레벨 | 자동 판정 기준 | 포함 |
|------|----------------|------|
| `minimal` | 소형 CLI·라이브러리·배치·미분류 | 코어 스킬 + **Squad 9 에이전트** + anti-slop + **필수 훅 3종(차단·보호·핸드오프)** |
| `standard` (기본) | 일반 앱(웹·모바일·데스크탑) | minimal + **나머지 코어 훅(총 7개: +커밋전 린트·푸시전 테스트·자동포맷·Slack)** |
| `full` | CI 있음 + 다중 언어 | standard + **추가 스킬(verify·security-scan·test-gen·parallel-agents·coordinator 등)** |

---

## 6. 단계별 구성요소 (무엇을 고르나)

대화형 설치에서 제시되는 그룹과 선택 가이드. **각 구성요소의 역할·호출법(트리거)은 → [README.md](./README.md)의 "일상 워크플로우" · "더 깊게 — 시나리오별 명령" 절 참고.**

### 토큰 효율 (기본 추천)
- **codesight** — 프로젝트 구조 맵 MCP. grep 재탐색 비용 제거(대형 코드베이스 실측 평균 약 11배).
- **lsp** (cclsp MCP) — `findReferences`/`getDiagnostics`로 정확 탐색. grep 2,000+ 토큰 대신 약 500 토큰.
- 설치 시 `.claude/settings.json`의 `mcpServers`에 자동 등록. 언어서버 바이너리는 대화형 또는 `--lsp-servers`에서만 설치.

### 6 핵심 스킬
`handoff` · `memory` · `commit` · `changelog` · `review` · `pr` — 자연어로 트리거되며 `/carve-*` 커맨드 shim도 함께 설치.

### 진입 스킬
`harness-architect` — "이 프로젝트에 맞는 하네스 구성해줘" 같은 자연어로 설치 흐름을 안내.

### 7 필수 훅
| 훅 | 이벤트 | 동작 |
|----|--------|------|
| 파괴적 명령 차단 | PreToolUse(Bash) | `rm -rf /`·포크밤 등 → **exit 2 차단** |
| 비밀파일 보호 | PreToolUse(Read/Edit/Write) | `.env`·키·credentials 접근 차단 |
| 커밋 전 린트 | PreToolUse(Bash) | 린트 실패 시 커밋 차단 |
| 푸시 전 테스트 | PreToolUse(Bash) | 테스트 실패 시 푸시 차단 |
| 자동 포맷 | PostToolUse(Edit/Write) | 저장 후 포맷터 실행 |
| Slack 알림 | — | 이벤트 알림(선택 구성) |
| PreCompact 핸드오프 | PreCompact | 압축 전 컨텍스트 영속화 |

### 1 선택 훅
`auto-commit` — 기본 미추천. 대화형에서 직접 켠다.

### Squad 서브에이전트 9종
`review` · `plan` · `refactor` · `qa` · `debug` · `docs` · `gitops` · `audit` · `evaluator`(완료 기준 독립 평가).
키워드 라우팅(`squad-router`)·체이닝(`subagent-chain`) 훅 + `/squad <member>` 디스패처 커맨드가 함께 설치된다.

### anti-ai-slop 팩 (타입 무관 기본 추천)
HTML·SVG·카드뉴스·리포트·슬라이드·문서의 AI 슬롭을 제거. 생성 후 `check-slop.mjs` 린터가 결정적으로 게이트(경고 모드, 의도적 사용은 예외경로).

### 추가 스킬 (full 레벨)
`verify` · `security-scan` · `test-gen` · `tdd` · `caveman` · `write-a-skill` · `zoom-out` 등(점수 75↑).

---

## 7. CLAUDE.md 베이스라인 + 스택 규칙 (`carve init-claude`)

설치 후 실행하면 작업 지침 베이스라인과 언어 스택별 규칙을 깎아 생성한다.

```bash
carve init-claude
```

생성물:
- **`.claude/CLAUDE.md`** — 스택 무관 베이스라인: 짜기 전 사고 · 단순함 · 외과적 변경 · TDD · 커밋 규율 · 응답 제어 · 할루시네이션 가드 · 안전 가드레일.
- **`.claude/rules/*.md`** — 탐지 언어 베스트 프랙티스 6종(`techstack` · `project-structure` · `commands` · `code-style` · `safety` · `gotchas`) + 스택 무관 `anti-ai-slop`(시각·문서 산출물 슬롭 방지).
- 루트 `CLAUDE.md`가 위 파일들을 **`@import`** 하도록 자동 연결(멱등). 세션마다 함께 로드된다.

스택 자동 선택:

| 탐지 언어 | 적용 번들 |
|-----------|-----------|
| TypeScript / JavaScript | `typescript` |
| Python | `python` |
| Go | `go` |
| Rust | `rust` |
| Java / Kotlin | `java` |
| Dart / Flutter | `dart` |
| 그 외 / 미탐지 | `_default` |

패키지매니저·테스트/린트/포맷 명령은 프로젝트에서 탐지한 값으로 치환된다(미탐지 시 스택 기본값).

> Claude Code는 `.claude/CLAUDE.md`를 자동 로드하지 않으므로, 루트 `CLAUDE.md`의 `@import`로 로드된다(그래서 루트 연결이 필수이며 멱등 처리됨).

---

## 8. 생성되는 파일 (대상 프로젝트)

```
<project>/
├── CLAUDE.md                  # (install) 하네스 안내 + (init-claude) @import 블록
├── flight-rules.md            # 금지/필수 규칙 (훅이 강제)
├── evaluation-criteria.md     # 측정 가능 품질 기준
├── sprint-contract.md         # 스프린트 계약
├── HARNESS-GUIDE.md           # 하네스 사용법
├── carve-manifest.json        # 설치 추적(멱등·제거 기준)
└── .claude/
    ├── settings.json          # 훅·MCP 병합(carve 마커)
    ├── CLAUDE.md              # (init-claude) 베이스라인
    ├── rules/*.md             # (init-claude) 스택 규칙 6종 + 공용 anti-ai-slop
    ├── skills/                # 선택 스킬 + 커맨드 shim
    ├── hooks/                 # 선택 훅 스크립트
    ├── agents/                # Squad 서브에이전트
    └── commands/              # 커맨드(/squad 등)
```

---

## 9. 명령 레퍼런스

| 명령 | 설명 |
|------|------|
| `carve` / `carve install` | 대화형 선택 설치 |
| `carve install --level <minimal\|standard\|full>` | 레벨 강제 |
| `carve install --only a,b,c` | 명시 선택(비대화형) |
| `carve install --lsp-servers` | LSP 언어서버 자동설치 |
| `carve init-claude` | CLAUDE.md 베이스라인 + `.claude/rules/*` 생성 |
| `carve list` | 설치 가능/설치된 구성요소 목록 |
| `carve doctor` | 설치 점검(구성 목록 + 훅 셸 문법) |
| `carve uninstall` | 클린 제거(.bak 복원) |
| `carve diff` | 설치본을 매니페스트/현 carve 자산과 3-way 비교(읽기 전용) |
| `carve update` | carve 갱신분만 제자리 갱신·사용자 수정 보존(`--force`·`--yes`) |
| `carve migrate` | v1 매니페스트를 v2로 승급(파일별 해시 back-fill) |
| `carve report` | 설치 훅의 로컬 효과 텔레메트리 집계(opt-in) |
| `carve --version` · `carve --help` | 버전 / 도움말 |

---

## 10. 멱등성 & 재설치

- 재설치는 안전하다. 사용자가 수정한 파일은 **`.bak`로 1회 보존** 후 기록한다.
- `settings.json`의 훅·MCP는 carve 마커 기준으로 **중복 없이 병합**된다.
- `init-claude`는 루트 `CLAUDE.md`의 `@import` 블록을 **marker 기준 멱등** 추가(두 번 실행해도 1회).

---

## 11. 제거 (uninstall)

```bash
carve uninstall              # = bash install.sh --uninstall
```

- `carve-manifest.json` 기준으로 carve가 설치한 파일만 제거하고, `.bak`가 있으면 **원본을 복원**한다.
- `settings.json`에서 carve 훅·MCP 항목만 정확히 제거한다(사용자 항목 보존).
- 참고: 파일만 제거하므로 비어 버린 디렉토리(예: `.claude/rules/`)는 남을 수 있다 — 필요 시 수동 정리.

---

## 12. 점검 (doctor)

```bash
carve doctor
```
설치 매니페스트(버전·파일·훅·백업 수)와 설치된 훅의 **셸 문법**(`shellcheck` 있으면 사용, 없으면 `bash -n`)을 검사한다.

---

## 13. 안전 — 왜 "결정적"인가

위험 명령·비밀파일 차단은 **권고가 아니라 PreToolUse 훅의 `exit code 2`** 로 강제된다.
모델 판단이 아닌 결정론적 스크립트라, 동일 입력에 동일 결과 — 누출이 구조적으로 0이다.
설치 전 `auditor`가 생성물의 secret 노출·과도 권한·훅 주입·셸 문법을 스캔하고, 통과해야 설치된다.

---

## 14. 문제 해결

| 증상 | 해결 |
|------|------|
| `node: bad option` / 타입 스트리핑 오류 | Node **>= 22.18** 확인 (`node -v`) |
| MCP(codesight/cclsp) 미동작 | `.claude/settings.json`의 `mcpServers` 등록 확인, `npx codesight --mcp`·`npx cclsp` 수동 점검 |
| 언어서버 미설치 | `carve install --lsp-servers` 재실행 또는 `lsp` 스킬의 수동 안내(go/rust 등) 참조 |
| 훅이 발동하지 않음 | `carve doctor`로 문법 확인, `.claude/settings.json` 훅 등록 확인 |
| `shellcheck` 없음 | 자동으로 `bash -n` 폴백 — 동작에 문제 없음 |

---

## 참고

- 개요·특징: [README.md](./README.md)
- 아키텍처: [ARCHITECTURE.md](./ARCHITECTURE.md)
- 정량 평가: [docs/guide/carve-harness-benchmark-results.md](./docs/guide/carve-harness-benchmark-results.md)
- 변경 이력: [CHANGELOG.md](./CHANGELOG.md)
