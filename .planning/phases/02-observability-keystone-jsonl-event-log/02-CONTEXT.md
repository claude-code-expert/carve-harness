# Phase 2: Observability Keystone (JSONL Event Log) - Context

**Gathered:** 2026-07-07
**Status:** Ready for planning

<domain>
## Phase Boundary

하네스에 빠진 관측성 레이어 하나를 추가한다: **구조화된 무의존성 JSONL 이벤트 로그**.
- 모든 훅 fire가 `logs/*.jsonl`에 정확히 한 JSON 라인으로 기록된다 (event·tool·decision·timestamp) (OBS-01)
- 포맷 훅 실패(포맷터 미설치·비정상 종료)가 `/dev/null`로 사라지지 않고 실패 레코드로 가시화된다 (OBS-02, C8 해소)
- Bash+jq만, 새 런타임 의존성 0 (SC3)

**HOW만 정한다 — WHAT/WHY는 ROADMAP.md Phase 2 SC로 잠김.** 로그 회전·상한·정리는 Phase 5. `/harness-audit`가 이 로그를 소비하는 건 Phase 4.

</domain>

<decisions>
## Implementation Decisions

### 로그 파일 레이아웃 (OBS-01)
- **D-01:** 일별 파일 `logs/YYYY-MM-DD.jsonl`. SC의 `logs/*.jsonl` glob과 일치하고, 단일 파일 무한 성장을 피하며, 날짜가 곧 로테이션이라 별도 회전 로직이 불필요하다.
- **D-02:** `logs/`를 `.gitignore`에 추가한다 — **현재 리포에 `.gitignore`가 없으므로 새로 생성**한다. 로그는 커밋 대상이 아니다(PII·노이즈). 크기/일수 보관 상한과 정리 로직은 **Phase 5 hardening으로 미룬다**(이번 phase 경계 밖).

### 훅 커버리지 & 공유 헬퍼 (OBS-01)
- **D-03:** 5개 훅 진입점 **전부**가 이벤트를 기록한다 — `pretool-guard`(allow/block), `posttool-format`(ok/fail), `stop-verify`(pass/fail), `session-handoff`(start/save). SC1 "every hook fire"와 일치.
- **D-04:** 공유 `.claude/hooks/log-event.sh` 헬퍼가 **단일 출처**다. 각 훅이 `log_event <event> <tool> <decision> [target]` 형태로 호출한다. 스키마·타임스탬프·경로 마스킹을 한 곳에만 정의해 드리프트를 막는다(Phase 1 `pretool-guard`의 PROTECTED_RE 단일출처 철학과 동일). 헬퍼는 **인자로 값을 받는다 — stdin을 재소비하지 않는다**(호출 훅이 이미 stdin JSON을 소비함).
- **D-05:** **best-effort / fail-safe append (불변식).** 로그 실패(jq 부재·`logs/` 생성 실패·쓰기 실패)는 **훅의 exit code를 절대 바꾸지 않는다.** Phase 1 fail-closed 불변식을 보존한다 — 로깅이 가드를 fail-open시키거나 Stop 게이트를 무력화하면 안 된다. 헬퍼는 자체 오류를 삼키고(best-effort) 호출자 흐름/종료코드에 영향을 주지 않는다.

### Claude's Discretion (미선택 영역 — 문서화된 기본값, planner 재확정)
- **이벤트 스키마:** `{ts, event, tool, decision, target}` JSON 한 줄. `ts` = ISO8601 UTC(`date -u +%Y-%m-%dT%H:%M:%SZ`). `event` = 훅 이름(PreToolUse/PostToolUse/Stop/SessionStart/PreCompact). `tool` = 도구명(있을 때). `decision` = `allow|block|format-ok|format-fail|pass|fail|start|save` 등 훅별 결과. `target` = 파일경로/명령(있을 때).
- **PII/시크릿 마스킹:** `target`은 `pretool-guard`의 **PROTECTED_RE와 동일 보호패턴**에 매치되는 부분을 `<masked>`로 치환해 기록한다 — `security.md`의 "로그에 PII/시크릿 금지"를 준수하고 단일 출처 패턴을 재사용한다.
- **OBS-02 실패 레코드:** `posttool-format`이 포맷터 **미설치**(`command -v` 실패) 또는 **비정상 종료**(exit≠0)를 감지해 `{event:PostToolUse, tool:<formatter>, decision:format-fail, target:<file>, reason:missing|error}`를 기록한다. 포맷터의 **정상 stdout은 계속 침묵**(`2>/dev/null` 유지) — 실패 **사실만** 가시화한다(C8 해소, 노이즈 최소).
- **동시성:** 단일 짧은 JSON 라인 `>>` append는 POSIX PIPE_BUF(4096B) 이하에서 원자적 → 락 불필요(documented ceiling). 이벤트 라인은 실무상 훨씬 짧다. >4096B 라인의 인터리브는 미발생 가정 — 필요 시 `flock`은 Phase 5.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 요구·SC 출처
- `.planning/ROADMAP.md` §"Phase 2: Observability Keystone" — Goal + 3개 Success Criteria(검증 기준 정본).
- `.planning/REQUIREMENTS.md` — OBS-01(JSONL append), OBS-02(포맷 실패 가시화) 정의.
- `.planning/codebase/CONCERNS.md` §C8 — 포맷 훅 에러 은폐(OBS-02 근거).

### 아키텍처·불변식 (로깅이 깨면 안 되는 것)
- `.planning/codebase/ARCHITECTURE.md` §"제어 흐름"·§"핵심 불변식" — 차단=exit 2/허용=exit 0. 로깅은 이 종료코드를 절대 바꾸지 않는다(D-05).
- `HARNESS-TEMPLATE-MANUAL.md` §2.2 — exit code 의미.
- `.claude/rules/common/security.md` §"개인정보(PII) 취급 기준" — 로그에 PII/시크릿 금지 → target 마스킹 근거.

### 수정/재사용 대상 파일
- `.claude/hooks/pretool-guard.sh` — PROTECTED_RE **단일 출처**(경로 마스킹에 재사용). guard allow/block 지점에 `log_event` 호출 추가.
- `.claude/hooks/posttool-format.sh` — OBS-02 대상(포맷 실패 감지 + 실패 레코드).
- `.claude/hooks/stop-verify.sh`, `.claude/hooks/session-handoff.sh` — pass/fail·start/save 이벤트 기록 추가.
- `.claude/hooks/log-event.sh` — **신규** 공유 헬퍼(단일 출처 스키마/마스킹/append).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `pretool-guard.sh`의 `PROTECTED_RE='(\.env($|[./])|application-prod|secret|db/migration/)'` — target 마스킹에 **동일 패턴 재사용**(별도 정의 금지, 단일 출처). Phase 1에서 단일출처로 정착시킴.
- 훅들의 `jq` stdin 파싱 패턴 — 이미 정착. 헬퍼는 stdin이 아니라 인자를 받으므로 재소비 충돌 없음.

### Established Patterns
- **불변식:** 차단=exit 2, 허용=exit 0. 로깅은 이 코드를 바꾸지 않는다(D-05).
- **zero-dep:** Bash+jq만. `date -u`(coreutils)로 타임스탬프. 새 도구 금지(SC3).
- **단일 출처:** Phase 1이 PROTECTED_RE를 단일화. Phase 2는 로그 스키마/마스킹을 `log-event.sh`로 단일화.

### Integration Points
- 각 훅은 `${CLAUDE_PROJECT_DIR}`로 실행됨(Phase 1 settings.json) → 헬퍼는 자기 위치를 견고하게 해석(`$(dirname …)` 또는 `${CLAUDE_PROJECT_DIR}`)해 테스트/서브디렉토리에서도 동작해야 함.
- `posttool-format.sh`의 `case` 블록에 포맷터 미설치/오류 감지 분기 추가(OBS-02).
- **settings.json 변경 불필요** — 로깅은 훅 스크립트 내부에서 일어남(훅 command 문자열은 그대로). 단, 로그 디렉토리 `logs/`는 `${CLAUDE_PROJECT_DIR}` 기준으로 생성.

</code_context>

<specifics>
## Specific Ideas

- 이벤트 라인 예:
  `{"ts":"2026-07-07T02:15:03Z","event":"PreToolUse","tool":"Write","decision":"block","target":"<masked>"}`
- SC1 검증: 훅 트리거 후 `logs/*.jsonl` 마지막 줄에 `jq .` → 파싱 성공.
- SC2 검증: 포맷터 미설치 상태로 `posttool-format.sh` 실행 → JSONL에 `format-fail` 레코드 등장.

</specifics>

<deferred>
## Deferred Ideas

- **로그 회전·보관 상한·정리** — 크기/일수 기반 정리. **Phase 5 hardening**으로 미룸.
- **`.gitignore`에 `.env*` 추가** — Phase 1 보안 천장("`.gitignore .env*` + security.md")의 근본 방어인데 현재 `.gitignore`가 부재. Phase 2가 `logs/`용 `.gitignore`를 새로 만들 때 함께 넣을지는 planner/사용자 판단 — 기본은 **Phase 2 범위 밖**(observability), `logs/`만 추가. (관측된 보안 갭으로 기록.)
- **큰(>4096B) 이벤트 라인 원자성** — 현실적으로 미발생. 필요 시 `flock`, Phase 5.

</deferred>

---

*Phase: 2-Observability Keystone (JSONL Event Log)*
*Context gathered: 2026-07-07*
