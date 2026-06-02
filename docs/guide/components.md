# 구성요소 레퍼런스 — 무엇이고, 어떻게 쓰나

carve가 설치하는 구성요소의 **역할**과 **사용법(트리거)**. 설치 목록은 `carve list`로도 본다.

## 어떻게 작동하나 (4가지 호출 방식)

| 종류 | 호출 방식 |
|------|-----------|
| **스킬** | Claude Code 세션에서 **자연어**로 트리거하거나, `/carve-<이름>` 커맨드로 직접 실행 |
| **훅** | **자동**. 해당 이벤트(명령 실행·파일 저장·커밋·압축 등)에 스크립트가 결정적으로 발동 — 수동 호출 없음 |
| **Squad 서브에이전트** | `/squad <멤버> [작업]`(디스패처) 또는 `/squad-<멤버>`로 직접. 키워드가 맞으면 `squad-router` 훅이 자동 위임 |
| **MCP(codesight·lsp)** | **자동**. 설치 후 Claude Code가 로드해 탐색 시 호출. 별도 명령 불필요 |

> 설치 후 첫 사용: 프로젝트에서 **Claude Code를 열기만 하면** 훅·MCP는 즉시 활성, 스킬·Squad는 위 방식으로 부른다.

---

## 토큰 효율 (MCP · 자동, 기본 탑재)

| 구성요소 | 역할 | 사용법 |
|----------|------|--------|
| **codesight** | 프로젝트 구조 맵 MCP. grep 재탐색 대신 구조를 질의 → 대형 코드베이스 탐색 토큰 실측 평균 ~11배 절감 | 자동(Claude가 탐색 시 호출). git commit 때 `.codesight/` 갱신 |
| **lsp** (cclsp) | `findReferences`·`getDiagnostics` 등 정확한 코드 네비게이션 MCP. grep 2,000+ 토큰 대신 ~500 토큰 | 자동. 언어서버 바이너리는 `carve install --lsp-servers`로 설치 |

## 핵심 스킬 (자연어 또는 `/carve-<이름>`)

| 스킬 | 역할 | 사용법 |
|------|------|--------|
| **handoff** | 세션 인계. 컨텍스트가 차거나 끝낼 때 진행·결정·다음 할 일을 남겨 다음 세션이 잇게 함 | "핸드오프", "이어서 작업" / `/carve-handoff` (PreCompact·SessionStart 연동) |
| **memory** | 프로젝트 지속 메모리. 결정·맥락을 파일로 영속화 | "이거 기억해둬" / `/carve-memory` |
| **commit** | Conventional Commit 메시지 생성 | "커밋 메시지 만들어" / `/carve-commit` |
| **changelog** | CHANGELOG 생성·갱신 | "체인지로그 갱신" / `/carve-changelog` |
| **review** | 코드 리뷰(squad-review에 위임) | "리뷰해줘" / `/carve-review` |
| **pr** | PR 본문 생성 | "PR 본문 써줘" / `/carve-pr` |
| **harness-architect** (진입) | 프로젝트 분석 → 추천 → 선택 설치 안내 | "이 프로젝트에 맞는 하네스 구성해줘", "carve 구성" |

## 훅 (자동 · 이벤트 기반)

차단형 훅(차단·보호·린트·테스트)은 **권고가 아니라 `exit 2`로 결정적 차단**한다.

| 훅 | 이벤트 | 역할 |
|----|--------|------|
| **block-destructive** | PreToolUse(Bash) | `rm -rf /`·포크밤 등 위험 명령 차단 |
| **protect-secrets** | PreToolUse(Read/Edit/Write) | `.env`·키·credentials 접근 차단 |
| **pre-commit-lint** | PreToolUse(Bash) | `git commit` 전 린터 실행, 실패 시 커밋 차단 |
| **pre-push-test** | PreToolUse(Bash) | `git push` 전 테스트 실행, 실패 시 푸시 차단 |
| **auto-format** | PostToolUse(Edit/Write) | 저장 후 포매터 실행(비차단) |
| **slack-notify** | Stop | 세션 종료 시 Slack 웹훅 알림(웹훅 env 설정 시에만) |
| **precompact-handoff** | PreCompact | 압축 직전 상태 영속화(handoff 연동) |
| **auto-commit** *(선택, 기본 OFF)* | Stop | 세션 종료 시 자동 커밋. 대화형 설치에서 직접 켤 때만 |

## Squad 서브에이전트 9종 (`/squad <멤버> [작업]` 또는 키워드 위임)

`/squad review`처럼 부르거나, `/squad-review [scope]`로 직접. 프롬프트에 키워드가 있으면 `squad-router` 훅이 자동 위임한다.

| 멤버 | 역할 |
|------|------|
| **squad-review** | 코드 리뷰 — 보안·성능·스타일 |
| **squad-plan** | 기능 기획 — 유저스토리·와이어프레임 |
| **squad-refactor** | 리팩터링 — 추출·단순화·이름변경·제거 |
| **squad-qa** | 테스트 실행·QA 리포트 |
| **squad-debug** | 에러 분석·근본 원인 |
| **squad-docs** | 문서 생성·갱신 |
| **squad-gitops** | 커밋 메시지·PR·체인지로그 |
| **squad-audit** | 보안 감사·취약점 스캔 |
| **squad-evaluator** | 완료 기준·Sprint Contract 대비 **독립 평가**(스스로의 결과를 과신하는 Self-Eval Blindspot 대응) |

## anti-ai-slop 팩 (문서·이미지 생성 시)

HTML·SVG·카드뉴스·리포트·슬라이드·문서의 **AI 슬롭**(과한 그라데이션·글로우·글래스모피즘·마케팅 문구 등)을 제거.
생성·수정 후 `check-slop.mjs` 린터가 **결정적으로 게이트**(경고 모드, 의도적 사용은 예외경로).

> 사용법: "슬롭 없는 HTML 만들어", "이 html 디슬롭 해줘" 등 자연어. 생성 시 자동으로 린터가 검사한다.

## 추가 스킬 (`full` 레벨 · 자연어 또는 `/carve-<이름>`)

| 스킬 | 역할 | 사용법 |
|------|------|--------|
| **verify** | `build→lint→test→typecheck` 검증 루프 | "검증해줘" / `/carve-verify` |
| **security-scan** | squad-audit 위임 보안 게이트 | "보안 스캔" / `/carve-security-scan` |
| **test-gen** | UAT 기준 테스트 생성 | "테스트 생성" / `/carve-test-gen` |
| **tdd** | red-green-refactor 테스트 우선 개발 *(mattpocock/skills, MIT)* | "TDD로 진행" / `/carve-tdd` |
| **caveman** | 토큰 ~75% 절감 초압축 커뮤니케이션 *(MIT)* | "caveman 모드" / `/carve-caveman` |
| **write-a-skill** | 재사용 스킬 `SKILL.md` 스캐폴딩 *(MIT)* | "스킬 만들어줘" / `/carve-write-a-skill` |
| **zoom-out** | 시스템 수준 시야로 모듈·호출 관계 매핑 *(MIT)* | "전체 구조 조망" / `/carve-zoom-out` |
| **model-route** | 작업 → Haiku/Sonnet/Opus 3-Tier 라우팅(비용 최적화) | "모델 라우팅" / `/carve-model-route` |
| **parallel-agents** | 3~4 에이전트 최소 병렬화 + git worktree 격리 | "병렬로 처리" / `/carve-parallel-agents` |
| **evaluator-tuning** | 평가자 오판 수집 → few-shot 보정 루프 | `/carve-evaluator-tuning` |
| **harness-audit** | 설치된 하네스 자기 점검(doctor + 등록·문법·자산 정합) | "하네스 감사" / `/carve-harness-audit` |
| **coordinator** | 멀티에이전트 메일박스/TeamCreate 조율 패턴 가이드 | `/carve-coordinator` |

---

> 어떤 레벨에서 무엇이 기본 추천되는지는 [INSTALL.md §5 설치 레벨](../../INSTALL.md) 참고.
> 점수(`carve list`의 괄호 숫자)는 등재 기준(≥75)이며, 높을수록 일반적 유용성이 크다는 carve의 내부 평가다.
