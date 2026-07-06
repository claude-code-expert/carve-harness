---
doc: CONCERNS
mapped: 2026-07-06
last_mapped_commit: (not a git repo)
---

# CONCERNS — 기술 부채 · 리스크 · 갭

> 사용자 목표("문서·특징 비교해 하네스 구축")에 가장 직접적인 문서. 채워야 할 구멍을 심각도순으로 정리.

## 🔴 High — 하네스 신뢰성에 직접 영향

### C1. `install.md` 빈 파일 (0 bytes)
- `README.md`는 드롭인 설치 절차를 담지만 `install.md`는 완전히 비어 있음. 진입 문서 불일치.
- **조치**: 설치 절차를 `install.md`로 채우거나 파일 삭제.

### C2. 테스트 게이트 부재 — 규칙과 실제 게이트 불일치 ✅ 해소 (2026-07-06)
- `rules/common/testing.md`: "완료는 테스트로 증명한다"고 강제하지만, `stop-verify.sh`는 **컴파일·타입체크만** 실행. 테스트 실행 없음.
- **수정 완료**: `stop-verify.sh`에 `gradlew ... test` / `pnpm test`(스크립트 존재 시) 추가. 커버리지 80%는 jacoco/vitest 임계값(빌드 설정)에 위임.
- **잠복버그 동반 수정**: 기존 `cmd | tail || fail=1`은 `tail` 종료코드(항상 0)를 봐서 **게이트가 실패를 전혀 못 잡던** 상태였음 → `set -o pipefail`로 근본 수정. mktemp 스텁 테스트 3케이스(실패→exit2 / 통과→exit0 / 스택없음→exit0) 통과 검증.

### C3. Git 저장소 아님
- `.git` 없음. 그런데 `git-workflow.md`·`commit.md`·`session-handoff.sh`(`git branch --show-current`)가 git 전제.
- GSD `map-codebase`의 `last_mapped_commit` 드리프트 스탬프도 커밋 SHA 필요 → 동작 불가 (본 문서들에 `(not a git repo)` 표기).
- **조치**: `git init` (커밋·핸드오프·드리프트 추적 활성화).

## 🟡 Medium — 커버리지 갭 / 우회 가능

### C4. 보호 패턴 우회 구멍 (pretool-guard.sh) ✅ 해소 (2026-07-06)
- 기존: `*.env` = 끝이 `.env`인 파일만 → `.env.production`·`.env.local` 미차단. `application-prod.yml`만 매치 → `-production.yaml` 미차단.
- **추가 발견**: `*/db/migration/*`는 앞 `/` 필요 → **레포 루트 `db/migration/*` 미차단** (잠복 구멍).
- **수정 완료**: case → `*.env|*.env.*|*application-prod*|*secret*|*db/migration/*`. `.environment.ts` 등 false positive 없음 검증. 스텁 테스트로 block/allow 케이스 통과.

### C5. 시크릿 읽기는 Bash 우회 가능 ✅ 부분 해소 (2026-07-06)
- `settings.json` deny에 `Read(./**/.env*)`(패턴 확장)·`Bash(cat *.env*)`·`Bash(cat *secret*)` 추가.
- **한계(천장)**: deny-list는 best-effort — `less`/`head`/`grep`/`xxd`/`while read` 등 다른 읽기 경로는 못 막는다. 근본 방어는 "시크릿을 레포에 두지 않기"(env/시크릿 매니저)이며 이는 `security.md`·`CLAUDE.md` 규칙으로 이미 강제. 완전 차단이 필요하면 Bash matcher PreToolUse 훅으로 명령 문자열 검사 추가.

### C6. 스텁 다수 — 뼈대만 존재
- `[내용없음]` 자리표시: `CLAUDE.md`(도메인 규칙), `security.md`(프로젝트 보안), `testing.md`(커버리지 기준), `specs/README.md`, java/react `patterns.md`(추가 규칙).
- 스킬(`handoff`, `changelog`)·에이전트 본문도 스텁 (`MANUAL §5`: "본문은 ECC에서 가져와 채운다").
- **조치**: 프로젝트 도메인에 맞춰 스텁 채우기 — 이번 하네스 구축의 핵심 작업.
- **진행 (2026-07-06, 범용 템플릿 방향)**: `security.md`(PII 베이스라인)·`testing.md`(라인 80%) 구체값 삽입 완료. `CLAUDE.md` 도메인 규칙은 가이드형 자리표시로 전환. 남은 스텁(`specs/README`, java/react `[추가 규칙]`, 스킬 본문)은 범용 특성상 의도적 placeholder 유지.

### C7. 핸드오프가 실제 상태를 수집하지 않음
- `session-handoff.sh save`가 쓰는 TODO는 `"[자동 수집 — 내용없음]"` 하드코딩. branch만 실제 값.
- 상태 기둥의 연속성이 형식적 — 실제 미완료 작업이 인계되지 않음.
- **조치**: `handoff` 스킬 본문으로 TODO/다음단계 수집 로직 채우기.

## 🟢 Low — 관측성 / 성능 / 위생

### C8. 포맷 훅 에러 은폐
- `posttool-format.sh`가 모든 출력 `2>/dev/null` → 포맷터 미설치·실패가 조용히 무시됨(silent failure). 의도적이나 관측성 부재.

### C9. Stop 훅 매 응답마다 풀 빌드
- `stop-verify.sh`가 Stop마다 `gradlew compileJava` + `tsc --noEmit` 전체 실행 → 큰 프로젝트에서 응답 지연. 증분/캐시 고려 여지.

### C10. 버전 취약성 (문서가 이미 경고)
- 훅/스킬/`rules` frontmatter 문법은 Claude Code 버전에 따라 변동 (`MANUAL §6` ⚠️ 2건). 특히 `rules`의 `paths:` 로딩은 버전 편차 — 핵심 규칙은 `CLAUDE.md`에 중복 권장.

### C11. 위생 파일 부재
- `.gitignore`, `LICENSE` 없음. 드롭인 배포 템플릿에는 있는 편이 안전.

## 요약 우선순위 (하네스 구축 착수 순서 제안)
1. `git init` (C3) — 나머지 상태·핸드오프·드리프트 기능 활성화.
2. 스텁 채우기 (C6) — 도메인 규칙/보안/커버리지 기준.
3. 테스트 게이트 (C2) + 보호 패턴 강화 (C4, C5).
4. 핸드오프 실질화 (C7), 관측성 (C8).
