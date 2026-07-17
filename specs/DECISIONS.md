# DECISIONS

되돌리기 어려운 결정을 append-only로 기록한다. 형식: 날짜 / 결정 / 이유 / 대안 / 영향 범위.
새 항목은 맨 아래에 추가한다. 기존 항목은 수정하지 않는다(정정은 새 항목으로).

---

## 2026-07-17 — carve-eval 스펙 정합성 채점 루프 구현

### D1. 커맨드만 carve-eval로 rebranding, 내부 표면명은 계약 이름 유지
- **결정**: 진입 커맨드는 `/carve-eval`(발화: evaluator·평가지표·스펙 정합성·구현 내역 평가). 에이전트/스킬/워크플로/훅은 이미 커밋된 계약 `.claude/rules/conformance.md`가 쓰던 이름(`conformance-scorer`·`spec-checklist`·`spec-conformance-loop.js`·`conformance-gate.sh`) 그대로.
- **이유**: 사용자는 *커맨드*만 carve-eval로 요구. 계약 파일은 이미 이 이름들로 시스템을 설명 중 → 내부명을 바꾸면 계약이 거짓말이 됨. 최소 churn으로 계약을 진실로 만듦.
- **대안**: (a) 전부 carve-eval-* 프리픽스로 통일 — 계약 파일 대량 수정 필요, 기각. (b) 커맨드도 specloop 유지 — 사용자 요구 위반, 기각.
- **영향**: `docs/md/spec-loop.md`(커맨드 참조 3곳)·`conformance.md` §6·`.codesight/skills.md` 갱신. 서브시스템 개념명 "specloop"은 doc에 존치.

### D2. 정합성 게이트를 별도 훅으로, stop-verify의 loop-yield 가드 미러링
- **결정**: `conformance-gate.sh`를 stop-verify.sh와 별도 훅으로 두고 Stop 배열에 추가. `stop_hook_active=true` → exit 0(yield) 패턴을 그대로 복제.
- **이유**: 게이트는 조기 완료 선언 *차단* 장치이지 루프 *드라이버*가 아님(루프는 워크플로/커맨드가 돌림). loop-yield 없으면 강제 continuation이 세션을 wedge. stop-verify와 동일 하네스 동작으로 일관성 유지. 단일 책임(SCORE.json 게이트)이라 stop-verify에 안 섞음 — 독립 테스트 가능.
- **대안**: (a) stop-verify.sh에 게이트 로직 병합 — 책임 혼합, 기각. (b) loop-yield 없이 계속 차단 — 세션 wedge, 기각.
- **영향**: `.claude/settings.json` Stop 배열 2개 훅. `settings.test.sh` CLAUDE_PROJECT_DIR 카운트 6→7.

### D3. jq-absent = best-effort skip, malformed JSON = fail-closed (비대칭)
- **결정**: 게이트에서 jq 미설치 → exit 0(스킵), SCORE.json이 있으나 파싱 불가/빈 items → exit 2(차단).
- **이유**: jq-absent는 환경 한계(하네스 전역 best-effort 관례: log-event·stop-verify와 정합). 루프 자체가 JSON 구동이라 jq 없는 박스는 애초에 못 돎. malformed는 "다 됐다 증명 불가" → 안전하게 차단(계약 §8).
- **대안**: jq-absent도 fail-closed — jq 없는 무관 세션에 stale SCORE.json 있으면 wedge, 기각.
- **영향**: `conformance-gate.sh` 분기 + 테스트 9·5·6번으로 고정.

### D4. 2렌즈 min을 워크플로 JS에서 결정론적으로 계산 (에이전트 아님)
- **결정**: `spec-conformance-loop.js`에서 code-match·test-pass 렌즈를 독립 에이전트로 병렬 실행 후 `Math.min()`을 JS 코드로 계산. 에이전트에 min 위임 안 함.
- **이유**: 한 렌즈 에이전트가 다른 렌즈 점수를 넘겨 부풀리는 낙관 편향을 산술 계층에서 차단. 결정론적·재현 가능.
- **대안**: 단일 스코어러가 두 렌즈+min 모두 수행 — Self-Eval 편향 위험, 기각(단, 커맨드 수동 SOP 경로에서는 계약대로 단일 스코어러가 min까지 하되 2렌즈 독립 계산 지시).
- **영향**: 워크플로는 per-lens 결과만 받고 JS가 min·게이트 판정. 스코어러 에이전트는 "렌즈 지정 시 그 렌즈만 반환" 동작 명시.
