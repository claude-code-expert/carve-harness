# DECISIONS — 비가역 결정 기록 (append-only)

> 형식: 날짜 / 결정 / 이유 / 대안 / 영향 범위. 기존 항목 수정 금지.

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
