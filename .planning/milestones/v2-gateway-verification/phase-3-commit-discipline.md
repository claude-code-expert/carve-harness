# Phase 3 — 커밋 규율 (Conventional Commits 게이트)

> 마일스톤 v2, Phase 3 산출물. 대상 요구사항 COMMIT-01.
> 갭 분석 2순위: 기존 pre-commit은 보호경로·시크릿·VERSION만 검사, **커밋 메시지 형식은 미검증**이었다.

---

## 0. 이 페이즈가 만든 것

| 산출물 | 역할 |
|--------|------|
| `.githooks/commit-msg` | 커밋 메시지 제목을 Conventional Commits로 기계 검증(위반 시 커밋 차단) |
| `install.sh` (chmod 확장) | `.githooks/pre-commit`만 → `.githooks/*` 전부 +x (commit-msg 포함) |
| `harness-audit.sh` (AUDIT-04 확장) | commit-msg 게이트 존재·실행권한 점검 |
| `.claude/hooks/tests/commit-msg.test.sh` | 15케이스(형식·길이·면제·주석) |

**지표**: 훅 테스트 125건(+15), audit 40 PASS(+commit-msg 체크), 스위트 11개.

---

## 1. 이론 — 왜 commit-msg 게이트인가

### 1.1 커밋 규율이 강제가 아니면 안 지켜진다
`CLAUDE.md`·`AGENTS.md`는 "Conventional Commits 영어, 제목 50자 이하"를 규칙으로 적었다. 하지만 규칙(설득)은 긴 세션 끝에서 깨진다. commitlint가 이 강제를 담당하지만, **Node 의존성**이라 하네스의 "bash+git·오프라인" 원칙과 안 맞는다. 그래서 `.githooks/commit-msg`로 **jq조차 불필요한** 순수 bash 게이트를 만들었다.

### 1.2 왜 commit-msg 훅인가 (pre-commit 아님)
git 훅은 시점이 다르다:
- `pre-commit`: 스테이징된 **내용**을 검사(보호경로·시크릿). 메시지는 아직 없다.
- `commit-msg`: 작성된 **메시지 파일**($1)을 검사. 형식 검증의 정확한 위치.

기존 pre-commit에 메시지 검사를 욱여넣지 않고 별도 훅으로 분리한 이유 — 각 훅이 자기 관심사만 본다(단일 책임).

### 1.3 에이전트 무관 강제
`.githooks/`는 `core.hooksPath`로 활성화되므로 **Claude·Cursor·Codex·사람 누구의 커밋이든** 통과 시점에 검사한다. Claude Code 훅(PreToolUse 등)은 Claude 전용이지만, git 훅은 도구 무관 — 크로스 에이전트 2차 방어선의 일부다. `--no-verify` 우회는 AGENTS.md §0에서 금지.

---

## 2. 사용 방법

### 2.1 검사 규칙
```
형식: <type>(scope)?!?: <subject>
type ∈ {feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert}
subject: 1자 이상, 전체 제목 ≤72자 (권장 50)
```
- 통과: `feat: add login`, `fix(auth): null guard`, `feat(api)!: drop v1`, `chore(ci/deploy): bump`
- 차단: `wip: ...`(미지의 type), `just changes`(type 없음), `feat add`(콜론 없음), `feat: `(빈 제목), 73자 이상 제목
- **면제**: `Merge ...`, `Revert "..."`, `fixup! ...`, `squash! ...`, 주석(`#`)·빈 줄

### 2.2 활성화 확인
```bash
git config core.hooksPath          # → .githooks (install.sh가 설정)
ls -l .githooks/commit-msg         # → -rwxr-xr-x (실행권한)
bash .claude/hooks/harness-audit.sh | grep commit-msg
#  → PASS: agent-agnostic commit-msg gate present +x (AUDIT-04)
```

### 2.3 동작 예
```bash
$ git commit -m "wip: stuff"
[commit-msg] Conventional Commits 위반 — 제목: "wip: stuff"
  형식: <type>(scope)?: <subject>   type ∈ {feat|fix|...}
# → 커밋 거부 (비영 종료)

$ git commit -m "feat(auth): add JWT refresh"
# → 통과
```

### 2.4 회귀 검증
```bash
bash .claude/hooks/tests/commit-msg.test.sh   # 15 passed (형식 5·위반 4·길이 2·면제 3·주석 1)
```

---

## 3. 확장해야 할 부분

### 3.1 조정 지점
- **type 목록**: `TYPES` 변수 한 곳. 프로젝트가 커스텀 type(예: `hotfix`)을 쓰면 여기만 추가.
- **길이 상한**: 72자 하드캡. 팀이 50자 하드 강제를 원하면 숫자만 변경(현재 50은 권장·경고 아님, 72 초과만 차단).
- **scope 규칙**: `[a-z0-9._/-]+` 허용. 스코프 화이트리스트(정해진 모듈명만)를 원하면 정규식 확장.

### 3.2 안 한 것 (의도적)
- **본문(body) 검사**: 제목만 검증. 본문 형식(BREAKING CHANGE 푸터 등)은 미검증 — YAGNI, 필요 시 확장.
- **영어 강제**: 제목 언어는 검사 안 함(형식만). AGENTS.md가 영어를 규칙으로 두지만 기계 강제는 과함(고유명사·혼용 오탐).
- **commitlint 도입**: Node 의존성 회피가 설계 목표. 순수 bash로 충분.

### 3.3 이 게이트의 한계
- **제목 형식만** 본다. "의미 있는 메시지인가"(예: `fix: fix`)는 못 잡는다 — 그건 리뷰어(사람/에이전트) 몫.
- git 훅이라 **Claude Code 실시간 차단은 없다** — 커밋 시점 차단. Claude가 커밋 전 형식을 지키도록은 `AGENTS.md` 규칙(설득)이 담당, 최종 강제는 이 훅.

---

## 4. Phase 3 완료 기준(SC) 대비 자기 점검

| SC | 상태 | 근거 |
|----|------|------|
| 1. 제목 `type(scope): subject` + 길이 검사, 위반 시 비영 종료 | ✅ | commit-msg 정규식 + 72자 캡 · 테스트 (형식·길이) |
| 2. jq 불필요(bash+git), 정상 형식 통과 | ✅ | 순수 bash · valid 5케이스 PASS |
| 3. 차단/통과 케이스 어서션 | ✅ | `commit-msg.test.sh` 15 passed |

전체: 훅 테스트 **125 passed / 0 failed**, `harness-audit` **40 PASS**, shellcheck clean.

---

*Created: 2026-07-09 · Phase 3 of milestone v2 · 미커밋(사용자 검토 대기)*
