---
doc: CONVENTIONS
mapped: 2026-07-06
last_mapped_commit: (not a git repo)
---

# CONVENTIONS — 컨벤션

## 문서/설정 컨벤션 (이 저장소가 스스로 지키는 것)

- **언어**: 한국어 본문 + 영문 기술용어. 결론 우선(conclusion-first) 서술.
- **Frontmatter 필수**: 에이전트·스킬·규칙·커맨드 파일은 YAML frontmatter로 시작.
  - 에이전트: `name`, `description`, `tools`, `model`
  - 규칙: `paths: [...]` (glob)
  - 스킬: `name`, `description`
  - 커맨드: `description` (+ 본문에 `$ARGUMENTS`)
- **스텁 표기**: 미완성 자리는 `> [ ... — 내용없음]` 인용구로 명시 (예: `CLAUDE.md`, `security.md`, `specs/README.md`). 의도적 빈칸임을 표시하는 관례.
- **표 중심**: 기능/매핑은 Markdown 표로. 3기둥 매핑이 여러 문서에 반복 등장.

## Bash 훅 컨벤션 (핵심 자산)

`.claude/hooks/*.sh` 전반의 규칙:

1. **셔뱅 고정**: `#!/usr/bin/env bash`.
2. **stdin JSON 파싱은 jq**: `jq -r '.tool_input.file_path // empty'`. 환경변수 방식 아님 (구식으로 간주 — `HARNESS-TEMPLATE-MANUAL.md §2.2`).
3. **차단은 반드시 `exit 2`**: `exit 1`은 비차단 → 위험동작 통과. 이 불변식이 하네스의 안전성 근간.
4. **정상 종료 `exit 0`**: 후처리 훅(format)은 실패해도 0으로 흘려보냄 (`2>/dev/null`).
5. **언어 감지 = case + 확장자/마커파일**: `*.java` / `*.ts|*.tsx` / `gradlew` / `package.json`.
6. **모노레포 대비**: 루트 + `backend/`·`frontend/` 하위 경로 둘 다 탐지 (`stop-verify.sh`).

## 대상 프로젝트에 강제하는 코드 규칙 (rules/)

이 저장소가 드롭인되는 프로젝트에 glob으로 적용:

**공통** (`.claude/rules/common/`, `**/*`):
- 시크릿 코드/커밋 금지. 입력 불신(검증·이스케이프).
- Conventional Commits. force push·히스토리 재작성 금지.
- red→green(실패 테스트 먼저)로 완료 증명.

**Java/Spring** (`**/*.java`):
- `@Transactional` 내 외부 API 호출 금지.
- Controller에서 Entity 직접 반환 금지 → DTO(record) 매핑.
- 연관관계 `FetchType.LAZY` 기본 (N+1 방지).
- `domain` 패키지 → `infrastructure` import 금지 (단방향 의존).

**React/Next** (`**/*.ts,tsx`):
- `any` 금지, 명시적 타입.
- `fetch` 직접 호출 금지 → api client 경유.
- 서버/클라이언트 상태 경계 명확히 (전역상태 남용 금지).

## 에이전트 협업 규약 (AGENTS.md)

- 생성(Generator)과 검증(Evaluator) **분리** — Self-Eval Blindspot 방지.
- 출력은 완료 기준(SC) 대비 자기 점검 후 제출.
- 아키텍처 변경·반복 실패·스펙 충돌·비가역 작업 → 자율 판단 금지, `[ESCALATION]` 보고.

## 에러 처리 스타일

- 훅: 게이트 실패는 stderr(`>&2`)로 이유 출력 + `exit 2`. 후처리 실패는 조용히 삼킴(`2>/dev/null`) — 의도적 (포맷 실패가 작업을 막지 않도록).
- 에이전트: "확정된 사실만, 추측 금지" (`review.md`, `code-reviewer.md`).
