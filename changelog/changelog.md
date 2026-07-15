# Changelog — 결정 기록 (append-only)

되돌리기 어려운 결정과 근거를 시간순으로 기록한다. 형식: 날짜 / 결정 / 이유 / 대안 / 영향 범위.

---

## 2026-07-15 — ponytail·caveman을 하네스에 벤더링(프로젝트 로컬)

- **결정**: ponytail(전체 upstream 플러그인)과 caveman(SKILL 단독)을 `vendor/`에 하드카피하고,
  `.claude/settings.json` SessionStart/UserPromptSubmit/SubagentStart 훅으로 배선한다.
  전역 marketplace(`~/.claude/plugins`) 설치가 아니라 install.sh가 대상 레포마다 로컬 복사한다.
- **이유**: 하네스는 프로젝트 로컬 `.claude/*`·`vendor/`를 복사하는 구조 → 벤더링이 자기완결적이고
  install만으로 활성화된다(전역 오염 없음, 레포와 함께 이동).
- **대안**: (a) install.sh가 `claude plugin marketplace add/install`로 전역 설치 — 네이티브 플러그인·
  statusline 통합은 깔끔하나 claude CLI 의존·전역 상태. (b) caveman 업스트림 전체 fetch — 로컬에
  완전본이 없어 네트워크·미확인 구조 위험. → 벤더링 + caveman은 벤치마크 SKILL 재사용 선택.
- **영향 범위**: `vendor/ponytail`·`vendor/caveman`·`.claude/hooks/caveman-activate.sh`·
  `.claude/commands/{ponytail*,caveman}.md`·`.claude/settings.json`·`.claude/hooks/tests/settings.test.sh`
  (CLAUDE_PROJECT_DIR 가드 6→10). ponytail은 node 필요(미설치 시 자동 비활성), caveman은 bash.
  PR #49 → main(v0.3.0), PR #50 → develop.

## 2026-07-15 — /carve-harness-create를 prune 전용 → 검증·보강·절단 전체 흐름으로 확장

- **결정**: 스킬을 "전수분석 → 설정검증(FIX) → 보강(ADD) → 절단(PRUNE) → 통합제안 → 1회확인 →
  적용 → evaluator 평가표" 흐름으로 확장한다. 기계적 설정검사는 신규 `config-doctor.sh`(자문형,
  항상 exit 0)로 결정론화한다. CLAUDE.md/AGENTS.md 편집(FIX)은 사용자 승인분만 반영(자동수정 금지).
- **이유**: 기존 스킬은 파일 제거(prune)만 했고, 사용자가 기대한 "필수·도움 요소 설치"와
  "CLAUDE.md/AGENTS.md 오류 검출·제안"이 없었다. 이 스킬은 프롬프트 주도 설계라 확장 = SKILL.md 재작성.
- **대안**: 별도 스킬(carve-harness-doctor) 분리 — 파괴/비파괴 관심사를 나눠 안전하나 명령이 둘로 늘어남.
  → 사용자 기대("/carve-harness-create가 내부적으로")에 맞춰 단일 스킬 확장 선택.
- **영향 범위**: `.claude/skills/carve-harness-create/SKILL.md`·`.claude/hooks/config-doctor.sh`(+test)·
  `.claude/CLAUDE.md`(유령 스킬 참조 clean-html·frontend-design → anti-ai-slop·theme-factory 수정)·
  `session-handoff.sh`(배너 모드 노출)·`install.sh`(안내 배너 범위)·`remote-install.test.sh`(vtsls
  스텁으로 setup 테스트 결정론화). PR #50 → develop.
