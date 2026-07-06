# Phase 1: Fail-Closed Enforcement Core - Context

**Gathered:** 2026-07-06
**Status:** Ready for planning

<domain>
## Phase Boundary

제약 기둥과 Stop 게이트를 **우회 불가**로 만든다:
- 가드가 `jq` 부재/JSON 파싱 실패 시 **fail-closed**(exit 2)로 차단 (GUARD-01)
- 매처가 전 쓰기 도구(`Write|Edit|MultiEdit|NotebookEdit`)를 포착 (GUARD-02)
- Bash 쓰기 명령(`echo >`, `sed -i`, `cp`, `tee` 등)이 보호경로 대상이면 차단 (GUARD-03)
- Stop 게이트가 `stop_hook_active` 루프도, 60s 타임아웃 침묵 무력화도 못 하게 (GATE-01, GATE-02)
- 훅 경로 `${CLAUDE_PROJECT_DIR}` 기준 (CFG-02), 크리티컬 규칙 always-on (CFG-01), `commit` 자동호출 차단 (CFG-03), `settings.json` `$schema` (CFG-04)

**HOW만 정한다 — WHAT/WHY는 ROADMAP.md Phase 1 SC로 잠김.** 새 능력 추가는 다른 Phase.

</domain>

<decisions>
## Implementation Decisions

### Fail-closed 폭발반경 (GUARD-01)
- **D-01:** `jq` 부재 또는 JSON 파싱 실패 시 hard-fail(exit 2) 대상은 **쓰기 경로만** — `pretool-guard.sh`와 Bash-write 검사(GUARD-03). 이 둘은 `jq`/파싱 실패 시 무조건 exit 2로 차단.
- **D-02:** Stop 게이트(`stop-verify.sh`)는 `jq` 없으면 **비차단** — 해당 스택 테스트 스텝만 스킵하고 stderr에 경고 출력. (검증까지 hard-fail하면 `jq` 미설치 환경에서 완료 자체가 불가 → 작업 마비. 쓰기 차단만 fail-closed, 검증은 best-effort.)
- **D-03:** 가드가 fail-closed 차단할 때 stderr에 **사유 명시**(예: `[guard] jq 미설치/JSON 파싱 실패 → fail-closed 차단`)해서 차단당한 사용자가 원인을 알게 한다.

### Always-on 규칙 범위 (CFG-01)
- **D-04:** `common/` 3개 전부(`git-workflow.md`·`security.md`·`testing.md`)에서 frontmatter `paths:` **키 자체를 제거** → 파일 무관 항상 주입(압축 후 자동 재주입 포함). 현재 셋 다 `paths: ["**/*"]` — glob 로딩 자체가 C10 버전 드리프트 대상이라 키 제거로 면역화.
- **D-05:** java-spring/react-next 스택 규칙은 확장자 scoped 유지 (`**/*.java`, `**/*.ts,tsx`) — 스택 무관 always-on으로 올리지 않는다.

### Stop 타임아웃 대응 (GATE-02)
- **D-06:** `settings.json` Stop 훅에 **명시 `timeout`** 추가(넉넉하게, 예: 300–600s) → 60s 기본 타임아웃에 조용히 잘려 게이트가 침묵 무력화되는 것을 제거. 정확한 값은 planner 재량, 단 실제 빌드가 잘리지 않을 만큼 크게.
- **D-07:** 검증 자체는 compile+test로 **경량 유지**. 변경모듈 증분화는 **Phase 5 GATE-03**로 미룬다(이번 Phase 경계 넘지 않음).

### Claude's Discretion
- **Bash-write 커버리지 (GUARD-03) — 사용자 미논의, Claude 재량 기본값:**
  - **차단 대상 (in-scope):** 리다이렉트(`>`, `>>`, `tee`), in-place 편집(`sed -i`, `perl -i`), 복사/이동(`cp`, `mv`, `install`)이 **보호 경로 패턴**(`.env`/`.env.*`/`application-prod*`/`*secret*`/`db/migration/*`)을 대상으로 할 때. 탐지는 `.tool_input.command` 문자열에서 보호패턴 매치.
  - **명시적 out-of-scope 천장 (documented ceiling, NOT a bug):** 파이프 경유 쓰기, 변수치환·난독화된 경로, `less`/`head` 등 읽기 경로, heredoc 우회. best-effort — STATE.md가 이미 "documented ceiling"으로 인정. 근본 방어는 `.gitignore .env*` + 규칙(security.md).
  - 보호 경로 패턴은 `pretool-guard.sh`의 file_path case와 **단일 출처 공유** 권장(중복 정의 회피).
- GATE-01 루프 방지 문구/exit 처리, CFG-02/03/04 기계적 적용은 SC대로 — 재량.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 요구·SC 출처
- `.planning/ROADMAP.md` §"Phase 1: Fail-Closed Enforcement Core" — Goal + 5개 Success Criteria(검증 기준의 정본).
- `.planning/REQUIREMENTS.md` — GUARD-01/02/03, GATE-01/02, CFG-01/02/03/04 정의 및 Traceability.
- `.planning/codebase/CONCERNS.md` — C4(가드 우회구멍, 해소분 포함), C5(시크릿 읽기 천장), C9(Stop 풀빌드), C10(버전 드리프트) 배경.

### 아키텍처·불변식
- `.planning/codebase/ARCHITECTURE.md` §"제어 흐름"·§"핵심 불변식" — 훅 라이프사이클 + **차단은 반드시 exit 2**(exit 1은 비차단 통과).
- `HARNESS-TEMPLATE-MANUAL.md` §2.2 — exit code 의미. §6 — 훅/`rules` frontmatter 버전 취약성(CFG-01 근거).

### 수정 대상 파일
- `.claude/hooks/pretool-guard.sh` — GUARD-01/02/03 대상.
- `.claude/hooks/stop-verify.sh` — GATE-01/02 대상 (이미 `set -o pipefail` 있음).
- `.claude/settings.json` — 매처 확장(GUARD-02), 훅 경로(CFG-02), Stop timeout(GATE-02), `$schema`(CFG-04).
- `.claude/commands/commit.md` — `disable-model-invocation: true`(CFG-03).
- `.claude/rules/common/{git-workflow,security,testing}.md` — `paths:` 키 제거(CFG-01).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `pretool-guard.sh` file_path case 패턴(`*.env|*.env.*|*application-prod*|*secret*|*db/migration/*`): GUARD-03 Bash-write 검사가 **동일 패턴을 재사용**해야 함 — 별도 정의 금지, 단일 출처.
- `stop-verify.sh`: 이미 `set -o pipefail`(Phase 0 근본수정) + `jq -e '.scripts.test'` 스택감지 로직 존재 — GATE-01/02는 이 위에 `stop_hook_active` 가드 + timeout만 얹음.

### Established Patterns
- **차단 불변식:** 모든 차단은 `exit 2`, 허용은 `exit 0`. `exit 1` 금지(비차단 통과).
- **스택 자동감지:** 확장자·마커파일(`gradlew`/`package.json`)로 판별 — 새 로직도 이 패턴 유지.
- **런타임 의존성 0:** Bash+jq만. 무거운 도구 도입 금지.

### Integration Points
- `settings.json` `hooks.PreToolUse.matcher` — 현재 `"Write|Edit"` → `"Write|Edit|MultiEdit|NotebookEdit"`로 확장(GUARD-02). Bash 쓰기 차단(GUARD-03)은 `Bash` 매처 PreToolUse 훅 엔트리 추가 필요(별 매처 or 통합 훅).
- 훅 command 문자열 `bash .claude/hooks/*.sh` → `bash ${CLAUDE_PROJECT_DIR}/.claude/hooks/*.sh`(CFG-02).

</code_context>

<specifics>
## Specific Ideas

- fail-closed 차단 메시지는 **원인 특정형**(jq 미설치 vs JSON 파싱 실패 구분)이면 디버깅에 유리.
- Bash-write 검사와 file_path 가드는 **같은 보호패턴 리스트를 공유**(중복 정의 시 드리프트 위험).

</specifics>

<deferred>
## Deferred Ideas

- **변경모듈 증분 검증** — Stop 게이트를 변경 모듈만 검증하도록 스코프 축소. **Phase 5 GATE-03**에 이미 배정됨. Phase 1에서는 timeout 명시로 침묵 무력화만 제거하고 증분화는 넘긴다.
- **시크릿 내용 스캔(파일 내용 AKIA/sk-/ghp-/PEM/JWT)** — GUARD-04, **Phase 5**. Phase 1은 경로 기반 차단만.
- **Bash 읽기 경로 완전차단**(`less`/`head`/`grep` 등) — REQUIREMENTS Out of Scope. deny-list best-effort로 충분, 근본은 `.gitignore .env*`.

</deferred>

---

*Phase: 1-Fail-Closed Enforcement Core*
*Context gathered: 2026-07-06*
