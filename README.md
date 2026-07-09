# Claude 하네스 (언어 무관 드롭인)

[English](README.en.md) · 현재 버전 **v0.0.8** · 변경 내역 [CHANGELOG.md](CHANGELOG.md) · 강좌 [HARNESS_GUIDE.md](HARNESS_GUIDE.md)

코딩 에이전트의 규칙 위반을 "설득"이 아니라 **훅 exit 2로 차단**하는 가드레일 템플릿.
프로젝트 루트에 드롭인하면 즉시 동작한다.

## 특징

| 기둥 | 동작 |
|------|------|
| **제약** | 보호 경로(`.env`·prod·마이그레이션)·하드코딩 시크릿 쓰기를 PreToolUse 훅이 차단. jq 부재·JSON 파손 시 fail-closed |
| **피드백** | Stop 훅이 빌드·타입·테스트 실패 시 완료 선언 차단 — 변경된 스택만 증분 검증 |
| **상태** | 세션 종료·압축 시 핸드오프 자동 저장(실제 TODO·결정 수집), 시작 시 복원 |
| **관측** | 모든 훅 판정을 `logs/*.jsonl`에 기록 (PII 마스킹), 리포트·회전 지원 |
| **자가감사** | `/harness-audit` — 40개 기계 체크로 하네스 오구성 PASS/FAIL |

**구성 요소**: 훅 8종(Claude Code 전용, 6 이벤트) · 슬래시 커맨드 14종 · 에이전트 16종 · 스킬 23종 · 규칙 18종 · 테스트 11 스위트(125건)

**크로스 에이전트**: 훅 차단은 Claude Code 전용. Cursor/Codex 등은 `AGENTS.md` 정본 + `.githooks/pre-commit`이 커밋 시점에 최종 차단.

**오프라인 완결**: jq·shellcheck 정적 바이너리 내장(`vendor/bin`, SHA256 검증) — 인터넷 없이 설치 가능.

## 설치

```bash
cd /path/to/your-project
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash
```

- 기존 파일은 건드리지 않는다(SKIP 보고) — 설치 목록은 `.claude/harness-manifest.txt`에 기록.
- 설치 끝에 `/harness-audit` 자동 실행 — 40 PASS면 전 게이트 활성.

### 사설(private) 소스 레포 토큰

하네스 소스는 private 레포(`wevesolutions/harness`)다. GitHub은 **인증 없는** raw/codeload 접근에 404를 반환하므로, 같은 org(`wevesolutions`) 멤버여도 토큰이 필요하다. 아래 명령은 설치·업데이트 공통(마지막 `bash` 인자만 `-s -- update`로 바꾸면 업데이트).

**방법 1 — gh CLI (가장 간단, 권장):**
```bash
GITHUB_TOKEN=$(gh auth token)
curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
  https://raw.githubusercontent.com/wevesolutions/harness/main/install.sh \
  | GITHUB_TOKEN=$GITHUB_TOKEN bash
```
`gh` 없으면 `gh auth login`(GitHub.com → HTTPS → 브라우저) 후 실행. SSO도 자동 인가돼 방법 2의 SSO 함정이 없다.

**방법 2 — PAT 직접 발급:**
1. GitHub → Settings → Developer settings → Personal access tokens
2. Classic은 `repo` 스코프 / Fine-grained는 Resource owner=`wevesolutions`, Repository=`harness`, **Contents: Read**
3. 발급된 토큰으로:
```bash
export GITHUB_TOKEN=ghp_xxxxxxxx
curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
  https://raw.githubusercontent.com/wevesolutions/harness/main/install.sh \
  | GITHUB_TOKEN=$GITHUB_TOKEN bash
```

**방법 3 — 토큰 없이 (오프라인/로컬 클론):**
```bash
HARNESS_SRC_DIR=/path/to/harness bash /path/to/harness/install.sh          # 설치
HARNESS_SRC_DIR=/path/to/harness bash /path/to/harness/install.sh update   # 업데이트
```

주의:
- 토큰이 **두 번** 들어간다 — 앞 `-H`는 install.sh 스크립트 다운로드용, 뒤 `GITHUB_TOKEN=` 환경변수는 스크립트가 소스 tarball을 codeload에서 받을 때 쓴다. 하나만 빠져도 404.
- **SSO**: org가 SAML SSO를 강제하면 PAT(방법 2)를 토큰 목록에서 "Configure SSO → Authorize"로 `wevesolutions`에 인가해야 200이 된다. 방법 1은 해당 없음.
- **토큰 노출 금지**: `ghp_...`를 커밋·로그·`.env`에 넣지 마라(하네스 가드가 `ghp_` 하드코딩 쓰기를 차단). 셸 세션 환경변수로만.
- **최소 권한**: 업데이트만이면 fine-grained + Contents:Read로 충분. classic `repo`는 과함.
- 공개 미러에서 받으려면 `HARNESS_REPO=<owner>/<public-repo>`로 소스를 바꾼다(토큰 불필요).

**초기 설정** (선택, 모든 항목 엔터로 skip):

```bash
bash install.sh setup
```

git init · jq PATH · LICENSE 생성(MIT/Apache-2.0) · 보호 경로 추가 · 도메인 규칙 수집 · 스택 감지 리포트 · GSD 설치 제안.
도메인 규칙·스택 게이트 보강은 `GUIDE.md` §8 참고.

## 업데이트 / 롤백

모든 명령은 **대상 프로젝트 루트에서** 실행.

```bash
# 현재 설치 버전 확인
cat .claude/harness-version

# 업데이트 — 온라인 (권장: 새 설치기 기준이라 신규 파일까지 수신)
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | bash -s -- update

# 업데이트 — 로컬 설치본의 설치기로
bash install.sh update

# 업데이트 — 오프라인 (새 버전 복사본 지정)
HARNESS_SRC_DIR=/path/to/new-harness bash install.sh update

# 특정 브랜치/태그 고정
curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh | HARNESS_REF=v0.0.4 bash -s -- update

# 같은 버전 강제 재패치 (파일 복구 용도)
HARNESS_FORCE=1 bash install.sh update

# 롤백 — 직전 버전 복원 (네트워크 불필요, 연속 실행 시 한 단계씩 과거로)
bash install.sh rollback
```

- **토큰**: 온라인 `update`도 사설 소스라 `GITHUB_TOKEN`이 필요하다 — 위 "사설 소스 레포 토큰" 3방법과 동일(마지막 인자만 `bash -s -- update`). 오프라인·로컬 경로는 토큰 불필요.
- update: 원격 `VERSION` vs 로컬 `.claude/harness-version` 비교(같으면 no-op) → manifest 범위만 패치, 변경 파일은 `logs/harness-backup/v<이전>/` 자동 백업, 사용자 파일(설치 때 SKIP분) 불가침.
- rollback: 최신 백업 복원 + 버전 스탬프 복귀. 백업은 소비 — 연속 실행 시 그 이전 버전으로.
- 배포 절차는 `RELEASE.md`.

## 제거

```bash
bash uninstall.sh          # 드라이런 — 삭제 목록만 출력
bash uninstall.sh --yes    # 실제 제거 (manifest 범위만, 원래 있던 파일 안전)
```

## 사용법

설치하면 게이트는 자동이다 — 보호 경로 쓰기 시도는 차단되고, 응답 종료 시 변경 스택만 검증되고, 세션 경계에서 상태가 저장된다. 수동 도구:

| 명령 | 용도 |
|------|------|
| `/harness-audit` | 하네스 구성 40체크 PASS/FAIL |
| `/plan` `/verify` `/review` `/commit` | SC 분해 · SC 검증 · 코드 검토 · 커밋 준비 |
| `/squad-*` (8종) | 기획→리뷰→QA→리팩토링→디버그→보안→문서→Git 파이프라인 |
| `bash .claude/hooks/logs-report.sh [days]` | 훅 판정 로그 요약 (`--rotate N` 회전) |

커스터마이징(보호 경로·포맷터·검증 명령·새 스택)·전체 레퍼런스는 **`GUIDE.md`** 참고.

## 구조

```
├── CLAUDE.md / AGENTS.md    # 규칙 정본 (Claude / 크로스 에이전트)
├── VERSION · CHANGELOG.md · RELEASE.md
├── install.sh / uninstall.sh   # 설치·update·rollback·setup / 제거
├── vendor/bin/              # 내장 jq·shellcheck (+ SHA256SUMS)
├── .githooks/pre-commit     # 에이전트 무관 커밋 게이트
├── specs/                   # 상태: 핸드오프·결정 기록
└── .claude/
    ├── settings.json        # 훅 6이벤트 등록
    ├── hooks/  (8종 + tests 11 스위트)
    ├── commands/ (14종) · agents/ (16종) · skills/ (23종) · rules/ (18종)
```

## 한계

- 훅 차단은 Claude Code 전용 — 타 에이전트는 pre-commit이 커밋 시점 차단.
- Bash 쓰기 가드는 best-effort: 파이프·heredoc 간접 우회 미탐 (pre-commit이 2차 차단).
- Stop 게이트 스택: Java/Node/Python/bash — 그 외는 미검증 통과.
- `rules/` 상시 로드로 세션 시작 토큰 증가.

## 로드맵

- [ ] 스택 게이트 확장: Go·Rust (감지→gofmt/vet/test, cargo)
- [ ] Bash 간접 쓰기(파이프·heredoc) 탐지 강화
- [ ] deny 패턴 변형 커버 (`rm -r -f` 등)
- [ ] rollback 시 신규 추가 파일 정리 (manifest diff)
- [ ] 시맨틱 버전 비교 (다운그레이드 방지)
- [ ] 스킬 트리거 문구(description) 수준 중복 검사

## 버전 이력

| 버전 | 날짜 | 요약 |
|------|------|------|
| v0.0.8 | 2026-07-09 | 게이트웨이 검증 계층(룰+Stop 게이트 GATE-04/05+AUDIT-07) · commit-msg 규율 게이트 · 테스트 서브에이전트 3종 · anti-ai-slop 스킬 |
| v0.0.7 | 2026-07-09 | revert v0.0.6 (소스는 사설이 정상) + 사설 레포 토큰 안내 복원 (404 원인=인증 누락) |
| v0.0.6 | 2026-07-09 | ~~소스 레포 공개 전환~~ (0.0.7에서 원복 — 잘못된 수정) |
| v0.0.5 | 2026-07-09 | CLAUDE.md 응답 언어 프로토콜(영문 요약→한글 결론) 추가 |
| v0.0.4 | 2026-07-09 | fix: 설치 목록에 VERSION 포함 — 설치본 셀프테스트 실패·체인 설치 버전 소실 수정 · 하네스 강좌(HARNESS_GUIDE.md) 추가 |
| v0.0.3 | 2026-07-08 | 대화형 설정 `setup` · update-안전 패턴 확장 파일 · LICENSE 자동 생성 |
| v0.0.2 | 2026-07-08 | `update`/`rollback` CLI · VERSION↔CHANGELOG pre-commit 게이트 · 배포 문서 |
| v0.0.1 | 2026-07-08 | 최초 완성본 — fail-closed 가드·Stop 게이트·JSONL 관측·핸드오프·자가감사·오프라인 설치기 |

상세는 [CHANGELOG.md](CHANGELOG.md).
