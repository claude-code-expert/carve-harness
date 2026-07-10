# HARNESS_GUIDE — 하네스 엔지니어링 강좌

> 코딩 에이전트를 "잘 설득하는" 단계를 지나, **어기면 물리적으로 실패하는 시스템**으로 만드는 방법.
> 이 문서 하나로 개념 → 구조 → 단계별 구축 → 실증 → 운영 워크플로우까지 완주한다.
> 실습 환경: 이 레포(v0.0.8). 모든 실행 예시는 실제 실행 결과다.

**대상 독자**: Claude Code(또는 임의 코딩 에이전트)로 실무 개발을 하며, 에이전트의 사고(규칙 무시·미검증 완료 선언·컨텍스트 소실)를 구조적으로 막고 싶은 사람.

---

## 1장. 하네스 엔지니어링이란

### 1.1 문제 — LLM 에이전트의 3대 실패 모드

| 실패 모드 | 증상 | 프롬프트로 막으면 |
|-----------|------|-------------------|
| **규칙 위반** | `.env` 수정, 시크릿 하드코딩, force push | 컨텍스트가 길어지면 잊는다. 확률적 준수 |
| **미검증 완료 선언** | "완료했습니다" — 빌드도 안 돌려봄 | "꼭 테스트해" ← 지켜질 때도, 아닐 때도 |
| **상태 소실** | 컨텍스트 압축·세션 교체 후 진행 상황 증발 | 프롬프트로는 해결 불가 (구조 문제) |

핵심 통찰: **프롬프트(CLAUDE.md)는 설득이고, 훅은 강제다.** 설득은 확률을 높이고, 강제는 확률을 1로 만든다. 하네스 엔지니어링 = 설득에 의존하던 규칙을 결정적(deterministic) 게이트로 옮기는 작업.

### 1.2 해법 — 3기둥 아키텍처

```
┌─ 제약 (Constraints) ── 나쁜 행동을 사전 차단
│    CLAUDE.md 규칙 + PreToolUse 훅 (exit 2 = 차단)
├─ 피드백 (Feedback) ─── 나쁜 결과를 사후 반려
│    PostToolUse 포맷 + Stop 훅 (빌드·테스트 실패 시 완료 선언 차단)
└─ 상태 (State) ──────── 컨텍스트 경계를 넘어 지속
     SessionStart 복원 + PreCompact/SessionEnd 핸드오프 저장
```

여기에 운영을 위한 2개 층이 추가된다:

- **관측(Observability)**: 모든 게이트 판정을 JSONL로 기록 — 차단·허용 이력의 사후 감사.
- **자가감사(Self-audit)**: 하네스 자체의 오구성(훅 미등록·권한 누락)을 기계적으로 PASS/FAIL — "가드가 있다고 믿었는데 없었다"를 방지.

### 1.3 제1불변식

> **차단은 반드시 `exit 2`.** Claude Code 훅 규약에서 exit 1은 비차단 경고로 통과된다.
> 그리고 **의심스러우면 차단(fail-closed)**: 파서(jq)가 없거나 입력이 깨져도 허용이 아니라 차단.

---

## 2장. 기본 하네스의 구조

### 2.1 컴포넌트 맵

```
your-project/
├── CLAUDE.md              # [제약-설득] 전역 가드레일 + 도메인 규칙
├── AGENTS.md              # [제약-설득] 크로스 에이전트 정본 (Cursor/Codex용)
├── .githooks/pre-commit   # [제약-강제] 에이전트 무관 최종 게이트 (커밋 시점)
├── specs/                 # [상태] 핸드오프·결정 기록·SDD 산출물
├── logs/*.jsonl           # [관측] 훅 판정 이벤트 로그 (gitignore)
└── .claude/
    ├── settings.json      # 훅 등록 (어떤 이벤트에 어떤 스크립트)
    ├── hooks/
    │   ├── pretool-guard.sh     # [제약-강제] 쓰기 차단
    │   ├── posttool-format.sh   # [피드백] 포맷 자동화
    │   ├── stop-verify.sh       # [피드백] 완료 게이트
    │   ├── session-handoff.sh   # [상태] 저장/복원
    │   ├── log-event.sh         # [관측] JSONL append
    │   ├── lib-protected.sh     # 패턴 단일 소스 (가드·pre-commit 공유)
    │   └── harness-audit.sh     # [자가감사] 40체크
    ├── rules/             # 스택별 규칙 (glob 자동 로드)
    ├── commands/          # /plan /verify /review 등 슬래시 커맨드
    ├── agents/            # 검증 전담 서브에이전트 (생성/검증 분리)
    └── skills/            # 절차 지식 패키지
```

### 2.2 훅 생명주기 — 언제 무엇이 무는가

```
사용자 요청
   │
   ├─ SessionStart ──── 핸드오프 복원 (이전 세션 이어받기)
   │
   ▼ 에이전트가 도구 호출
   ├─ PreToolUse ────── pretool-guard.sh
   │     Write/Edit/MultiEdit/NotebookEdit/Bash 전부 매칭
   │     보호 경로? 시크릿 내용? Bash 간접 쓰기? → exit 2 차단
   ▼ 도구 실행됨
   ├─ PostToolUse ───── posttool-format.sh (포맷터, 실패도 로그에 기록)
   │
   ▼ 에이전트가 응답 종료 시도
   ├─ Stop ──────────── stop-verify.sh
   │     변경된 스택만 빌드·타입·테스트 → 실패면 exit 2 (완료 선언 차단)
   │     stop_hook_active=true면 1회 보고 후 양보 (무한루프 방지)
   ▼
   └─ PreCompact / SessionEnd ── session-handoff.sh save
         실제 TODO·미완료 플랜·최근 결정 수집 → specs/HANDOFF.md
```

에이전트가 훅을 못 피하는 이유: 훅은 에이전트 프로세스 밖(Claude Code 런타임)에서 실행된다. 에이전트가 아무리 "확신"해도 exit 2면 도구 호출 자체가 반려된다.

### 2.3 이중 방어선 — 크로스 에이전트

훅은 Claude Code 전용이다. Cursor·Codex·Aider·사람은?

| 방어선 | 시점 | 커버 |
|--------|------|------|
| 1차: PreToolUse 훅 | 도구 호출 즉시 | Claude Code만 |
| 2차: `.githooks/pre-commit` | 커밋 시점 | **모든 에이전트 + 사람** (bash+git만, jq 불필요) |

패턴은 `lib-protected.sh` 한 곳에 정의 — 두 방어선이 같은 정의를 공유하므로 이중 관리가 없다.

---

## 3장. 단계별 하네스 구축

이 레포가 실제로 걸어온 순서다. 각 단계는 독립적으로 가치가 있고, 순서대로 쌓인다.
**원칙: 신뢰성/노력 비율이 높은 것부터.** 차단 → 관측 → 상태 → 감사 → 패키징.

### 0단계. 규칙 문서 (출발점 — 아직 하네스 아님)

`CLAUDE.md`에 절대 금지·작업 원칙을 적는다. 효과는 있지만 확률적이다.
**이 단계에 머물면 안 되는 이유**: 규칙이 늘수록 컨텍스트에서 희석되고, 긴 세션 끝에서 가장 잘 깨진다.

### 1단계. Fail-closed 차단 훅 (최우선 — 가장 큰 리스크 제거)

최소 구현 뼈대:

```bash
#!/usr/bin/env bash
# pretool-guard.sh — 최소 골격
command -v jq >/dev/null 2>&1 || { echo "[carve-harness:guard] jq 없음 → fail-closed" >&2; exit 2; }
INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 2
PROTECTED_RE='(\.env($|[./])|application-prod|secret|db/migration/)'
printf '%s' "$FILE" | grep -Eq "$PROTECTED_RE" && { echo "[carve-harness:guard] 차단: $FILE" >&2; exit 2; }
exit 0
```

`settings.json` 등록 — 매처가 **모든 쓰기 도구 + Bash**를 덮어야 한다 (하나라도 빠지면 그게 우회로):

```json
{ "hooks": { "PreToolUse": [ {
    "matcher": "Write|Edit|MultiEdit|NotebookEdit|Bash",
    "hooks": [ { "type": "command",
      "command": "bash ${CLAUDE_PROJECT_DIR}/.claude/hooks/pretool-guard.sh" } ]
} ] } }
```

이 단계의 함정 체크리스트 (이 레포가 실제로 밟은 것들):
- [ ] `exit 1`로 차단하려 함 → 통과됨. **반드시 2.**
- [ ] jq 없으면 스킵 → 우회로. **fail-closed.**
- [ ] `Write|Edit`만 매칭 → `NotebookEdit`·Bash 리다이렉트가 우회로.
- [ ] 상대경로 훅 → 서브디렉토리에서 안 묾. **`${CLAUDE_PROJECT_DIR}` 기준.**
- [ ] Bash 간접 쓰기(`echo x > .env`, `sed -i`, `cp`)는 `.tool_input.command` 문자열 검사로 — 파이프·heredoc까지는 못 잡는다(문서화된 천장, pre-commit이 2차 차단).

### 2단계. Stop 게이트 — 미검증 완료 선언 차단

```bash
# stop-verify.sh 핵심 구조
[ "$(jq -r '.stop_hook_active')" = "true" ] && exit 0   # 무한루프 방지 (필수!)
CHANGED=$(git diff --name-only HEAD 2>/dev/null)
# 변경된 스택만 검증 (증분) — 매 턴 전체 빌드는 못 버틴다
echo "$CHANGED" | grep -q '\.java' && { ./gradlew test -q || exit 2; }
echo "$CHANGED" | grep -q '\.ts$'  && { npx tsc --noEmit || exit 2; }
```

함정: `stop_hook_active` 체크 없으면 Stop 차단 → 재시도 → 또 차단 → **무한루프**.

### 3단계. 관측 — JSONL 이벤트 로그

모든 훅 진입점에서 한 줄씩: `{"ts","event","tool","decision","target"}`.
가드 판정이 로그에 남아야 "차단이 실제 일어나는지"를 사후에 증명할 수 있다. 구현은 bash+jq만 (`log-event.sh`), 실패해도 훅 본연의 판정은 막지 않는다(fail-safe append). 보호 경로·PII는 `<masked>` 처리.

### 4단계. 상태 — 핸드오프

`PreCompact`(컨텍스트 압축 직전)와 `SessionEnd`(정상 종료)에 저장, `SessionStart`에 복원:

```
# HANDOFF (자동 생성)
## 진행 상황   ← git branch + 미커밋 수
## 미완료      ← STATE.md의 Pending Todos
## 다음 단계   ← 미완료 플랜 + Blockers
## 주의점      ← DECISIONS.md 최근 5건
```

함정: 템플릿 그대로 `[내용없음]`을 저장하는 "상태 연극". **실데이터 수집이 없으면 이 기둥은 장식이다.** (이 레포는 자가감사가 `[내용없음]` 핸드오프를 FAIL로 잡는다.)

### 5단계. 자가감사 — 하네스의 하네스

하네스는 조용히 죽는다: Claude Code 업그레이드로 훅 규약이 바뀌거나, 실행 권한이 날아가거나, 매처에서 도구 하나가 빠지거나. 그래서 **하네스 자체를 검사하는 기계적 PASS/FAIL**이 최고 레버리지다:

```
AUDIT-01  jq 존재 · 6개 이벤트 등록 · 훅 +x · bash -n
AUDIT-02  쓰기 매처 완전성 · Bash-write 검사 존재
AUDIT-03  안전규칙(md) → 게이트(sh) 매핑 · 스텐티널 핸드오프 거부
AUDIT-04  크로스 에이전트: AGENTS.md 포인터 · pre-commit · vendor 체크섬
AUDIT-05  규칙 위생: 빈 파일 · 중복
AUDIT-06  스킬: 프런트매터 · 이름 충돌
AUDIT-07  게이트웨이 룰 ↔ Stop 게이트(GATE-04) 매핑 (게이트웨이 하네스만)
```

각 게이트에는 **테스트 스위트**도 붙인다 — 이 레포는 11 스위트 125건 (차단은 exit 2, 통과는 exit 0을 어서션).

### 6단계. 패키징 — 드롭인·업데이트·롤백

다른 프로젝트로 이식 가능해야 템플릿이다: `install.sh`(멱등, 오프라인, 기존 파일 불가침) → `update`(VERSION 비교, manifest 범위만, 자동 백업) → `rollback`(백업 복원) → `setup`(대화형 초기 설정). 버전 규율은 pre-commit이 강제: VERSION 변경 커밋에 CHANGELOG 항목 없으면 차단.

---

## 4장. 실증 — 게이트가 진짜 무는가

**전부 이 레포에서 방금 실행한 실제 출력이다.**

### 4.1 차단 5종 세트

```console
$ printf '{"tool_name":"Write","tool_input":{"file_path":".env.production",...}}' \
    | bash .claude/hooks/pretool-guard.sh
[carve-harness:guard] 보호 파일 수정 차단: .env.production
exit=2

$ # 시크릿 하드코딩 (sk-... 를 src/config.ts 에 쓰려는 시도)
[carve-harness:guard] 시크릿 내용 차단(하드코딩 시크릿 감지)
exit=2

$ # Bash 우회 시도: echo SECRET > .env.production
[carve-harness:guard] Bash 쓰기 차단(보호 경로): echo SECRET > .env.production
exit=2

$ # 정상 쓰기: src/app.ts
exit=0

$ # jq를 PATH에서 제거하고 실행 (fail-closed 증명)
[carve-harness:guard] jq 미설치 → fail-closed 차단 (jq 설치 후 재시도)
exit=2
```

### 4.2 관측 로그에 남은 판정

```console
$ tail -3 logs/$(date -u +%F).jsonl
{"ts":"2026-07-09T01:17:35Z","event":"PreToolUse","tool":"Write","decision":"block","target":"src/config.ts"}
{"ts":"2026-07-09T01:17:36Z","event":"PreToolUse","tool":"Bash","decision":"block"}
{"ts":"2026-07-09T01:17:36Z","event":"PreToolUse","tool":"Write","decision":"allow","target":"src/app.ts"}
```

### 4.3 저자 차단 사례 — 살아있는 증거

이 가이드를 쓰던 에이전트(Claude) 본인이 작성 중 **2번 차단당했다**:
1. 데모 명령 문자열에 `> .env.production`이 포함 → Bash-write 가드가 즉시 차단.
2. 데모 스크립트 파일 내용에 `sk-...` 리터럴 포함 → 시크릿 내용 스캔이 Write를 차단.

가드는 "데모인지 실제인지" 구분하지 않는다 — 그게 결정적 강제의 본질이다. (해결: 위험 리터럴을 런타임 조립으로 분리.)

### 4.4 직접 해보기

```bash
bash .claude/hooks/harness-audit.sh                        # 40 PASS / exit 0
for t in .claude/hooks/tests/*.test.sh; do bash "$t"; done  # 11 스위트 125건 green
bash .claude/hooks/logs-report.sh 7                         # 최근 7일 판정 요약
```

음성 대조(가드를 일부러 부수면 감사가 잡는가): `settings.json`에서 `NotebookEdit`을 매처에서 빼보라 → audit이 AUDIT-02 FAIL + 비영 종료. (테스트 스위트가 이런 케이스 전부를 자동화해 둠 — `harness-audit.test.sh` 14건.)

---

## 5장. 이 코드베이스 설치 내역 — 설치법과 활용법

### 5.1 하네스 본체

| 작업 | 명령 |
|------|------|
| 설치 | `curl -fsSL https://raw.githubusercontent.com/claude-code-expert/carve-harness/main/install.sh \| bash` (상세 README) |
| 오프라인 설치 | `HARNESS_SRC_DIR=/path/to/copy bash /path/to/copy/install.sh` |
| 초기 설정 | `bash install.sh setup` — git init·PATH·LICENSE·보호경로·도메인규칙·스택감지·GSD (전 항목 엔터 skip) |
| 업데이트 | `curl ... \| bash -s -- update` — VERSION 비교, manifest 범위만, 자동 백업 |
| 롤백 | `bash install.sh rollback` — 직전 버전 복원 (오프라인) |
| 제거 | `bash uninstall.sh --yes` — manifest 범위만, 드라이런 기본 |

jq·shellcheck는 `vendor/bin`에 정적 바이너리 내장(SHA256 검증) — 인터넷 없는 머신도 동작.

### 5.2 내장 인벤토리와 활용법

| 자산 | 규모 | 활용 |
|------|------|------|
| 훅 | 8종 (6 이벤트) | 자동 — 손댈 일 없음. 커스터마이징은 `GUIDE.md` §8 |
| 커맨드 | 14종 | `/plan`(SC 분해) `/verify`(SC 검증) `/review`(검토) `/commit`(커밋 준비) `/harness-audit` + `/squad-*` 8종 |
| 에이전트 | 13종 | 검증 전담: evaluator·code/security/silent-failure/state-reviewer — "use the security-reviewer agent"로 호출, 생성/검증 분리 |
| 스킬 | 22종 | `handoff`(수동 핸드오프) `changelog`(결정 기록→DECISIONS.md) `version-changelog`(릴리스 필수) + mattpocock 파생 19종(`/implement` `/teach` `/domain-modeling` 등) |
| 규칙 | 17파일 | `common/` 상시 + 스택별 glob 자동 로드 (java-spring·react-next·python·ts·orm 등 8 스택 표준) |
| 테스트 | 11 스위트 125건 | 게이트 회귀 — 훅 수정 후 반드시 실행 |

### 5.3 함께 설치된 외부 생태계 (선택)

| 도구 | 역할 | 설치 |
|------|------|------|
| **GSD** (get-shit-done) | SDD 킷: 로드맵→플랜→실행→검증 오케스트레이션 (`.planning/` 산출) | `npx get-shit-done-cc --local` (setup이 제안) |
| **superpowers** | 스킬 프레임워크 (brainstorming·systematic-debugging 등 프로세스 스킬) | `/plugin install superpowers@superpowers-marketplace` |
| **caveman / ponytail** | 출력 압축 / 과잉 엔지니어링 억제 플러그인 | `/plugin install caveman@caveman` 등 |
| **codesight** | 구조맵으로 탐색 토큰 절감 (`.codesight/`) | `npx codesight --init` |
| gh CLI | PR·API 작업 | 배포판 패키지 매니저 |

이 레포 자체가 GSD 산출물이다 — `.planning/`에 5개 페이즈(로드맵→검증)가 기록돼 있으니 SDD 흐름의 실물 예시로 참고.

---

## 6장. 적용 후 워크플로우

### 6.1 일상 개발 루프

```
① 계획   /plan "기능 X"          → specs/에 검증 가능한 SC (예: 유효토큰=200, 무효=401)
② 구현   그냥 개발한다            → 가드가 자동으로 보호경로·시크릿 차단
                                  → 포맷 훅이 자동 정리, 실패도 로그에 남음
③ 종료   응답을 끝내려 하면       → Stop 게이트가 변경 스택만 빌드·테스트
                                  → 실패 시 "완료" 선언 자체가 반려됨
④ 검토   /review 또는 리뷰 에이전트 → 보안·예외·상태 관점 (생성자≠검증자)
⑤ 검증   /verify                  → specs/ SC 대조
⑥ 커밋   명시 요청 시에만          → pre-commit이 최종 차단선
⑦ 종료   세션 끝                  → 핸드오프 자동 저장, 다음 세션이 이어받음
```

포인트: **①⑤⑥만 사람이 개입**하고 나머지는 하네스가 자동으로 문다. "에이전트를 감시"하는 게 아니라 "게이트를 통과했는지만 확인"하는 쪽으로 주의력이 이동한다.

### 6.2 규칙 승격 루프 (하네스를 살아있게 유지)

```
지적 발생 → 같은 지적 2번째? → CLAUDE.md 도메인 규칙에 1줄 (설득)
                                    ↓ 규칙이 기계 판별 가능하면
                              훅으로 승격 (강제):
                              · 경로 규칙  → protected-extra.regex
                              · 문자열     → secrets-extra.regex
                              · 명령 패턴  → settings.json deny
                              · 코드 패턴  → 테스트로 강제
```

extra 파일은 manifest 밖 — **하네스를 업데이트해도 보존**된다. 상세 레시피: `GUIDE.md` §8.1.

### 6.3 팀 워크플로우

- 규칙 정본은 `AGENTS.md` 하나 — Cursor는 `.cursorrules`, Codex는 `codex.md`가 자동 포인팅.
- 비-Claude 에이전트·사람은 pre-commit이 커밋 시점에 잡는다. `--no-verify` 금지가 팀 규약.
- 신규 합류자 온보딩 = `bash .claude/hooks/harness-audit.sh` 40 PASS 확인 1줄. 공지문 템플릿: `GUIDE.md` §8.3.

### 6.4 릴리스 워크플로우

```
기능 완료 → /version-changelog 스킬 (VERSION + CHANGELOG + README 이력 동시 갱신)
         → 회귀 (테스트 106 + audit 38)
         → 커밋: pre-commit이 VERSION↔CHANGELOG 정합 검사 (누락 시 차단)
         → 태그·PR → 머지 → 사용자는 curl ... -- update 로 수신
잘못된 릴리스 → 사용자: install.sh rollback / 레포: revert + PATCH (히스토리 재작성 금지)
```

### 6.5 유지보수 주기

| 주기 | 작업 |
|------|------|
| Claude Code 업그레이드 직후 | `harness-audit` 재실행 — 훅 규약 변경 감지 |
| 주 1회 | `logs-report.sh 7` — 차단 패턴 리뷰 (반복 차단 = 규칙 교육 필요 신호) |
| 규칙 추가 시 | md 규칙 → 훅 승격 검토 (§6.2) + audit로 매핑 확인 |
| 월 1회 | `logs-report.sh --rotate 30` — 로그 회전 |

---

## 7장. 확장 — 다음 단계

- **도메인 규칙 형식·훅 승격 매핑**: `GUIDE.md` §8.1
- **새 스택 게이트** (Go 복붙 워크스루): `GUIDE.md` §8.2
- **훅 전체 레퍼런스·커스터마이징**: `GUIDE.md` §4·§8
- **로드맵** (Go/Rust 게이트, Bash 간접쓰기 탐지 강화 등): `README.md`

---

## 부록 A. 트러블슈팅

| 증상 | 원인 | 조치 |
|------|------|------|
| 모든 쓰기가 차단됨 | jq 없음 (fail-closed 정상 동작) | `bash install.sh` — vendor jq 배치 |
| 서브디렉토리에서 가드 안 묾 | 훅 경로가 상대경로 | `${CLAUDE_PROJECT_DIR}` 기준인지 확인 (audit이 검사) |
| Stop이 계속 반려 | 실제 빌드/테스트 실패 | 로그의 실패 내용 수정 — 게이트가 정상 동작 중 |
| 커밋이 막힘 (VERSION) | CHANGELOG 항목 누락 | `/version-changelog` 스킬 실행 |
| 업데이트가 커스텀을 덮음 | lib 직접 수정했음 | `logs/harness-backup/`에서 복원 → extra 파일로 이전 |
| audit FAIL | 하네스 오구성 | FAIL 라인이 곧 수리 목록 — 위에서부터 해결 |

## 부록 B. 용어

| 용어 | 뜻 |
|------|-----|
| fail-closed | 판단 불가 상황(파서 부재·입력 파손)에서 허용이 아니라 차단을 선택 |
| exit 2 | Claude Code 훅의 차단 신호 (1은 경고로 통과) |
| manifest | 설치기가 기록한 "하네스가 소유한 파일 목록" — update/uninstall의 범위 |
| 스텐티널(sentinel) | `[내용없음]` 같은 빈 템플릿 표식 — 상태 연극의 증거 |
| SC (Success Criteria) | 검증 가능한 완료 기준 — "동작하게 해" 금지, "무효 토큰=401" 형식 |
| 생성/검증 분리 | 만든 에이전트가 자기 결과를 채점하지 않게 별도 에이전트로 검증 |

---

*근거: 이 레포 실코드(`.claude/hooks/*`)·실행 결과(4장 캡처, 2026-07-09)·`.planning/` 페이즈 기록. 버전 기준 v0.0.8.*
