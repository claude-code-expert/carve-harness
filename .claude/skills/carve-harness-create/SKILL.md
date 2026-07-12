---
name: carve-harness-create
description: 프로젝트 스택을 감지해 불필요한 하네스 구성(규칙·에이전트·커맨드·스킬)을 잘라내 맞춤형 하네스로 만든다. KEEP/PRUNE 표를 보여주고 1회 확인 후 install.sh prune 실행. 전체 설치 후 프로젝트에 맞게 줄일 때 사용.
disable-model-invocation: true
argument-hint: "[--dry-run]"
---

# Carve Harness — 프로젝트 맞춤 구성 절단

전체 설치된 하네스를 이 프로젝트의 스택에 맞게 줄인다(prune). `install.sh`가 먼저 전체
설치했다는 전제 — 이 스킬은 그 뒤 **불필요한 파일만** 제거한다. 프롬프트 주도, 결정론
스크립트가 아니다. **감지 → 제안 → 1회 확인 → 실행 → 검증** 순서를 반드시 지킨다.

> 파괴 인접 작업이다. `--dry-run` 인자가 오면 3단계(제안)까지만 하고 **삭제하지 않는다**.
> 삭제는 언제나 되돌릴 수 있다(`bash install.sh rollback`) — 하지만 확인 없이 진행 금지.

## 전제 조건 점검

1. `.claude/harness-manifest.txt`가 있는가? 없으면 **중단** — "설치된 하네스가 아닙니다.
   먼저 `bash install.sh` 실행"이라고 보고하고 끝낸다.
2. git 작업트리가 clean인지 확인(`git status --porcelain`). dirty면 경고만 하고 진행 가능
   ("prune 결과를 git diff로 검토·롤백하려면 clean 권장").

## 1. 프로젝트 분석

아래를 실행해 스택·역할·규모를 파악한다. **보수적 원칙: 확신 없으면 KEEP.**
false-negative(스택을 놓쳐 필요한 규칙 삭제)가 false-positive보다 위험하다.

- **언어/스택** (규칙 선택 근거):
  - Java/Spring: `gradlew`·`build.gradle`·`build.gradle.kts`·`pom.xml` 존재, 또는
    `find . -name '*.java' -not -path '*/.git/*' -not -path '*/build/*' | head -1`
  - TS/React/Next: `package.json` + `find . -name '*.tsx' -o -name '*.ts' | head -1`.
    Next 여부 = `package.json`에 `"next"` 또는 `next.config.*` 존재
  - Python/FastAPI: `find . -name '*.py' -not -path '*/.venv/*' | head -1`.
    FastAPI = `grep -rl 'from fastapi' --include='*.py' . | head -1`
  - ORM/DB: `grep -rlE 'sqlalchemy|from django.db|@Entity|typeorm|prisma|drizzle' . | head -1`
  - 미지원(go/rs/rb 등): 감지돼도 대응 규칙이 없다 → **PRUNE 대상 아님**(코어 훅이 커버).
- **프론트/백**: `.tsx`/JSX 있으면 프론트 → `frontend.md`·react-next 유지. 없으면 백엔드-only.
- **모노레포**: `pnpm-workspace.yaml`·`turbo.json`·`lerna.json`·`package.json`의 `workspaces`·
  하위 `package.json` 2개+ → 다중 스택 가능성 + 오케스트레이터 유지 후보.
- **규모(오케스트레이터 필요 판단)**: `git ls-files | wc -l`, 소스 디렉토리 수. 큰 멀티모듈 →
  fable/squad 유지. 소형 단일 스택 → fable/squad 프루닝 후보.

분석 결과를 한 문단으로 요약해 사용자에게 먼저 보여준다(어떤 스택으로 판단했는지).

## 2. KEEP 세트 계산

아래 **ALWAYS-KEEP** + **감지된 스택 게이트** + **의존성 간선**을 적용해 유지할 파일 경로
집합을 만든다. 경로는 prune이 이해하는 **확장 granularity**로 쓴다(디렉토리 단위 또는
`code-convention/dev-stack-*.md` 파일 단위).

### ALWAYS-KEEP (스택 무관, 반드시 keep-list에 포함)

`install.sh prune`의 PROTECTED 정규식이 자동 보호하는 것(hooks 코어 8종·settings.json·
`safety.md`·`common/*`·`testing.md`·`CLAUDE.md`·`AGENTS.md`·`RULES.md`·`.cursorrules`·
`codex.md`·`.claude/CLAUDE.md`·`vendor`·`.githooks`·`VERSION`·스크립트)는 keep-list에 없어도
유지된다. 하지만 아래는 **PROTECTED가 아니므로 keep-list에 명시**해야 한다:

- `.claude/skills/handoff` · `.claude/skills/changelog` · `.claude/skills/version-changelog`
  · `.claude/skills/anti-ai-slop` · `.claude/skills/carve-harness-create` (프루너 자신)
- `.claude/commands/harness-audit.md` · `commit.md` · `plan.md` · `review.md` · `verify.md`
- `.claude/rules/database.md`는 ORM/DB 감지 시에만(아니면 프루닝 가능)

### 스택 게이트 (감지 시에만 KEEP, 아니면 PRUNE)

| 감지 | KEEP |
| --- | --- |
| Java/Spring | `.claude/rules/java-spring`(dir 전체, archunit 포함) · `.claude/rules/code-convention/dev-stack-java-spring.md` · **`.claude/hooks/eval-java.sh`** |
| TS/React/Next | `.claude/rules/react-next` · `.claude/rules/frontend.md` · `dev-stack-typescript.md` · `dev-stack-react.md` · `dev-stack-nextjs.md` · `dev-stack-javascript.md` (감지된 하위스택만) |
| Python/FastAPI | `dev-stack-python.md` · `dev-stack-fastapi.md`(FastAPI 감지 시) |
| ORM/DB | `.claude/rules/database.md` · `dev-stack-orm.md` |

### 하드 의존성 간선 (묶어서 keep 또는 prune — 절대 분리 금지)

1. **eval-java ⟷ archunit** (★ 최우선): `.claude/hooks/eval-java.sh`가 keep면
   `.claude/rules/java-spring`(archunit 포함)도 keep. eval-java를 prune하면 java-spring도 prune.
   **한쪽만 남기면 `harness-audit` AUDIT-08 FAIL.** Java 미감지 → 둘 다 prune.
2. **squad**: `.claude/commands/squad*.md`(9) ⟷ `.claude/agents/squad-*.md`(8). 커맨드가
   서브에이전트를 이름으로 호출 → 함께 keep 또는 함께 prune. 분리 시 `/squad-plan` dangling.
3. **fable**: `.claude/workflows/fable-team-pipeline.js` ⟷ `.claude/agents/fable-*`(4) +
   `docs/md/orchestration.md` + `docs/md/fable-team-guide.md`. 함께 keep 또는 함께 prune.
4. **review ⟷ 리뷰어**: `.claude/commands/review.md`(ALWAYS-KEEP)가 `code-reviewer`·
   `security-reviewer`·`silent-failure-hunter`를 참조 → 이 3개 에이전트는 keep.

### 오케스트레이터(fable·squad·리뷰어 에이전트) 판단

- 소형 단일 스택 프로젝트: squad×17·fable×7 프루닝 후보(오케스트레이션 과함).
- 멀티모듈/모노레포/대규모: 유지(병렬 빌드·계획 가치).
- 애매하면 KEEP. 리뷰어/misc 에이전트(code-reviewer·security-reviewer·evaluator·tdd-guide 등)는
  가벼워 기본 KEEP.

## 3. KEEP/PRUNE 제안 표 제시

manifest를 확장한 전 항목을 **KEEP / PRUNE 2열 표**로 보여준다. 각 PRUNE 항목에 사유 1줄
("Java 미감지 → java-spring 불필요"). ALWAYS-KEEP/PROTECTED 코어는 상단에 잠금(🔒) 표시로
분리해 "이건 절대 삭제 안 됨"을 명확히 한다.

**`--dry-run`이면 여기서 정지.** 표만 보여주고 아무것도 삭제하지 않는다.

## 4. 1회 확인 후 실행

- 사용자에게 묻는다: "위 PRUNE N개를 삭제합니다(KEEP M개 유지). 진행할까요? KEEP 목록을
  조정하고 싶으면 말씀하세요." — **놓친 스택을 복구할 마지막 안전판.**
- 확인 시: KEEP 경로 전체를 `mktemp` 파일에 1줄씩 기록한다. **PROTECTED 코어까지 포함**해도
  무방하지만, 최소한 위 ALWAYS-KEEP(비보호분)과 스택 매칭분·의존성 keep분은 반드시 넣는다.
- 실행: `bash install.sh prune --keep-list <tmp>`
  - prune이 manifest를 확장 → keep-list 밖 비보호 파일을 `logs/harness-backup/`에 백업 후 제거
    → manifest·harness-components 갱신.

## 5. 검증

- `bash .claude/hooks/harness-audit.sh` 실행. **exit 0(전 항목 pass) 필수.**
- FAIL이면(orphan 정책 — 예: gateway 규칙 남았는데 트리거 없음, 또는 eval-java↔archunit 불일치)
  즉시 `bash install.sh rollback` 안내하고 **중단 보고**. 임의로 추가 삭제하지 않는다.

## 6. 보고 + 정리

- KEEP/PRUNE 최종 수, 남은 스택 규칙, `harness-audit` 결과를 **한국어로 요약**.
- `.claude/harness-create-pending` 마커가 있으면 삭제(설치 직후 1회 안내용).
- tmp keep-list 파일 삭제.
- "되돌리려면 `bash install.sh rollback`, 커밋 전 `git diff`로 검토 권장" 안내.

## 주의

- 미지원 스택(go/rust/ruby 등)은 대응 규칙이 없어 프루닝 대상이 아니다 — 코어 훅이 그대로 커버.
- prune은 되돌릴 수 있지만(`install.sh rollback`), 여러 번 prune/update를 한 버전에서 섞으면
  백업이 겹칠 수 있다 — clean 버전에서 한 번에 prune 권장.
- 이 스킬은 모델 무관이다. fable/squad는 의존성 간선이 있는 경로 집합으로만 다룬다 — 미설치
  프로젝트면 해당 manifest 항목이 없어 자동으로 건너뛴다.
