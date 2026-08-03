# DECISIONS — 비가역 결정 기록 (append-only)

> 형식: 날짜 / 결정 / 이유 / 대안 / 영향 범위. 기존 항목 수정 금지.

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

## 2026-07-23 — 스택 상세본 자동 로드 제거 (v0.6.0, PR #65)

- **결정**: `dev-stack-*.md` 8종을 `.claude/rules/` → `docs/rules/code-convention/`으로 이동. 자동 로드 대상에서 제외, 필요 시 Read 참조.
- **이유**: `.claude/rules/**` 전체가 매 세션 자동 로드됨을 실측 — 스택 감지와 무관하게 8종 전량이 컨텍스트에 실려 세션당 수천 토큰 낭비("거대 프롬프트 상시 재전송" 안티패턴). 조건부 로드는 frontmatter `paths` glob이 있는 슬림 `patterns.md`가 담당.
- **대안**: (a) 상세본에 paths frontmatter 부여 — 파일당 수천 토큰이라 매칭 시 부담 여전 (b) 현행 유지 — 기각.
- **영향**: install.sh 경로(MD_PATHS·comp_of·prune), carve-harness-create 스킬/테스트, GUIDE·AGENTS·패턴 포인터 전부 동기화됨. 설치 대상 프로젝트도 update 시 같은 구조로 전환.

## 2026-07-23 — 에이전트·스킬·모드 중복 제거 (v0.6.0, PR #65)

- **결정**: squad 에이전트 8종+커맨드 9종, mattpocock 파생 스킬 18종, caveman 벤더 모드 제거. ponytail 일원화.
- **이유**: squad는 전문 리뷰어 5종·fable 팀·/verify·/review와 역할 중복(트리거 키워드 경쟁). matt 스킬은 하네스 배포물과 무관한 개인 도구. caveman/ponytail은 동일 목적(출력 압축) 이중화.
- **대안**: squad로 일원화(개별 리뷰어 제거) — 하네스 3기둥(Evaluator 분리)과 직결된 개별 리뷰어를 남기는 쪽 선택.
- **영향**: 순삭 약 3,200줄. 제거물은 git 히스토리에서 복구 가능. GUIDE·README·HARNESS_GUIDE 인벤토리 동기화.

## 2026-07-23 — AGENTS.md 규칙 정본화 (v0.6.0, PR #65)

- **결정**: 규칙 정본 = AGENTS.md 단일. 루트 CLAUDE.md는 진입점(3기둥·금지 요약·응답 언어·도메인 규칙), `.claude/CLAUDE.md`는 Claude Code 고유 지침만.
- **이유**: 3파일이 같은 규칙을 중복 보유 — 동기화 부담·드리프트·토큰 낭비.
- **대안**: "하나 고치면 나머지도 맞춰라" 수동 동기 유지 — 기각(이미 드리프트 발생).
- **영향**: 규칙 수정은 AGENTS.md에서만. 두 CLAUDE.md에 중복 조항 추가 금지.

## 2026-07-23 — 평가는 환경 상태를 채점 (v0.6.0, PR #65)

- **결정**: 골든셋에 상태 assert(`file_exists`·`file_contains`·`cmd_exit0`·`git_diff_contains`) 도입, 채점은 결정적 스크립트 `eval-state.sh` 전담. 상태/setup 케이스의 respondent는 리포 밖 격리 워크디렉토리에서 실행.
- **이유**: 텍스트 assert만으로는 허위 주장("했다")·정답 노출(리포 내 골든셋 Read) 리워드 해킹에 노출. 원칙: verifier는 에이전트의 말이 아니라 환경의 상태를 채점한다.
- **대안**: Harbor/Docker 태스크 인프라 도입 — 도구 종속·과잉으로 기각, 경량(mktemp 격리)으로 대체.
- **영향**: 골든셋 스키마 확장(setup 필드), 추이 엔트리에 VERSION·config 기록(구성 간 비교 축). llm-rubric은 상태 assert로 대체 가능하면 대체가 원칙.

## 2026-07-23 — 버전은 CI 소유 (기존 결정 준수 확인)

- **결정**: RELEASE.md 규약 재확인 — VERSION 수동 변경 금지, main 머지 시 release.yml이 커밋 타입에서 SemVer 유도. v0.6.0은 이 경로로 자동 릴리스됨.
- **영향**: /version-changelog 스킬은 수동 편집 예외용으로만 잔존.

## 2026-08-03 — 적대적 감사 결과 게이트 4종 패치 (GUARD-07/08, GATE-06/07, GATE-C5/C6)

- **결정**: 우회 시나리오 34종을 실행한 적대적 감사에서 뚫린 축을 우선순위대로 패치.
  ① **GUARD-07 자기보호** — 설치본(`.claude/harness-manifest.txt` 존재)에서 `.claude/hooks/`·`settings.json`·manifest의 수정·삭제를 차단. 소스 레포는 manifest가 없어 자동 예외(자기 훅 개발 가능).
  ② **GATE-06/07 스택 확대** — Go(build·vet·test)·Rust(cargo check·test) 게이트 신설, Python 감지를 `requirements.txt`/`setup.py`/`setup.cfg`까지 확대(기존엔 `pyproject.toml`만).
  ③ **GATE-C5/C6 평가 게이트 경화** — 미달 시 tombstone(`specs/.checklist-active`) 생성, checklist.json을 지워도 계속 차단. threshold는 하한 95로 클램프(`CARVE_CHECKLIST_FLOOR`로만 조정).
  ④ **GUARD-08** — 보호 경로의 삭제·생성(`rm`·`unlink`·`shred`·`truncate`·`touch`) 차단, 루트/홈/프로젝트 재귀 삭제 차단, `env`/`sudo`/`VAR=` 접두 우회 커버.
- **이유**: 게이트가 자기를 못 지키면(훅에 `exit 0` 쓰기, settings.json 비우기) 하네스 전체가 한 번의 쓰기로 무력화된다. 앱·CLI 프로젝트(Go·Rust)는 게이트가 아예 없어 "설득만 있고 강제는 없는" 상태였고, 평가 게이트는 채점당하는 주체가 채점표를 지워 끝낼 수 있었다.
- **대안**: (a) `.claude/.harness-dev` 마커로 자기보호 해제 — 마커 생성 자체를 막아야 해서 부트스트랩 불가(실제로 시도했다가 자기 잠금 발생), manifest 기반으로 전환. (b) checklist.json을 보호 경로로 지정 — 검증 루프가 스스로 점수를 써야 해서 기각, tombstone으로 대체. (c) 모든 `rm -rf` 차단 — 정상 정리 작업까지 막아 기각, "재귀 플래그 + 치명적 대상" 이중 조건으로 한정.
- **영향**: `lib-protected.sh`(패턴 4개 추가 — 그룹핑 버그도 함께 수정: 확장 패턴이 top-level `|`로 붙어 상위 정규식 밖으로 새던 결함), `pretool-guard.sh`, `stop-verify.sh`, `checklist-gate.sh`, 테스트 4스위트(230→260건), README ko/en·GUIDE·checklist-loop 스킬. 남은 천장(변수 간접 쓰기·base64 시크릿·셸 alias 우회·`curl -o`+bash·6스택 외 미검증)은 README "한계" 절에 실측 기준으로 명시 — 로드맵으로 이관.

## 2026-07-28 — 강한 모델(Opus 5) 기준 하네스 감량

- **결정**: 약한-모델 보상용 산출물 제거 — `.planning/`(완료 GSD 아카이브)·`vendor/bin`(오프라인 jq/shellcheck 19MB)·구식 문서 3종(HARNESS-TEMPLATE-MANUAL·harness-install-list·superclaude 가이드)·단일 관점 에이전트 5종(code-reviewer·silent-failure-hunter·state-reviewer·tdd-guide·e2e-runner)·RULES.md·`changelog/`(DECISIONS.md로 이관)·중복 규칙 2종(rules/testing.md·frontend.md → react-next/patterns.md 흡수)·AGENTS.md §2/§3/§5 행동 프로즈. checklist-loop 스킬·ponytail 배선은 유지(사용자 지정).
- **이유**: 강한 모델에서 줄어드는 건 설득 기둥(프로즈 지침·세분화 에이전트·수동 SOP)이지 강제 기둥이 아니다. 결정적 훅·게이트는 전부 유지. 단일 관점 리뷰어는 /review 1회가 다관점 커버.
- **대안**: 오프라인 설치 유지(vendor/bin 존치) — 온라인 환경 전제로 기각. install.sh는 바이너리 부재 시 WARN 후 시스템 PATH 사용(기존 폴백 경로).
- **영향**: 약 9,000줄+19MB 순삭. install.sh(MD_PATHS·comp_of·PROTECTED)·session-handoff 배너·review 커맨드·carve-harness-create 스킬/테스트·remote-install 테스트·GUIDE/HARNESS_GUIDE/README 인벤토리 동기화. AGENTS.md 섹션 번호는 참조 유지 위해 재부여 안 함(§0·1·4·6~10 잔존). 오프라인(에어갭) 설치 기능 소멸 — 필요 시 git 히스토리에서 vendor/bin 복구. 전 테스트 스위트 통과·harness-audit 46 PASS 확인.
