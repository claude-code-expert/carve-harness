---
name: carve-harness-create
description: 프로젝트를 전수 분석(스택+코드베이스)해 ① CLAUDE.md·AGENTS.md 설정 정합성을 검증·제안하고 ② 스택에 필요한데 없는 요소(하네스 규칙·외부 개발도구·설정 스캐폴딩)를 보강 제안하며 ③ 불필요한 구성을 prune한다. FIX/ADD/KEEP/PRUNE 통합 제안표 → 1회 확인 → 적용 → evaluator 독립 평가표. 전체 설치 후 프로젝트에 맞게 맞춤화할 때 사용.
disable-model-invocation: true
argument-hint: "[--dry-run]"
---

# Carve Harness — 프로젝트 맞춤 구성 (검증 · 보강 · 절단)

전체 설치된 하네스를 이 프로젝트에 **맞춘다**. 세 방향으로 동작한다:

1. **검증(FIX)** — CLAUDE.md·AGENTS.md·`.claude/CLAUDE.md` 설정 오류를 검출해 **제안**한다(자동 수정 아님).
2. **보강(ADD)** — 감지된 스택에 필요한데 없는 요소(하네스 규칙·외부 개발도구·설정 스캐폴딩)를 채우도록 **제안**한다.
3. **절단(PRUNE)** — 이 스택에 불필요한 하네스 파일을 제거한다(되돌릴 수 있음).

프롬프트 주도이며 결정론 스크립트가 아니다. **분석 → 검증 → 보강 → 절단 → 통합제안 → 1회 확인 →
적용 → 평가표** 순서를 반드시 지킨다. 파괴 인접 작업이다.

> `--dry-run` 인자가 오면 **통합 제안표(5단계)까지만** 하고 아무것도 바꾸지 않는다.
> 절단은 `bash install.sh rollback`으로 되돌릴 수 있으나, 확인 없이 진행 금지. 설정 파일(CLAUDE.md 등)
> 편집은 사용자가 승인한 FIX 항목만 반영한다.

## 0. 전제 조건 점검

1. `.claude/harness-manifest.txt`가 있는가? 없으면 **중단** — "설치된 하네스가 아닙니다.
   먼저 `bash install.sh` 실행"이라고 보고하고 끝낸다.
2. git 작업트리가 clean인지 확인(`git status --porcelain`). dirty면 경고만 하고 진행 가능
   ("결과를 git diff로 검토·롤백하려면 clean 권장").

## 1. 프로젝트 전수 분석

스택·역할·규모 **및 코드베이스 신호**를 파악한다. **보수적 원칙: 확신 없으면 KEEP.**
스택을 놓쳐 필요한 규칙을 삭제하는 false-negative가 가장 위험하다.

### 1-1. 언어/스택 (규칙 선택 근거)
- Java/Spring: `gradlew`·`build.gradle`·`build.gradle.kts`·`pom.xml`, 또는
  `find . -name '*.java' -not -path '*/.git/*' -not -path '*/build/*' | head -1`
- TS/React/Next: `package.json` + `find . -name '*.tsx' -o -name '*.ts' | head -1`.
  Next = `package.json`의 `"next"` 또는 `next.config.*`
- Python/FastAPI: `find . -name '*.py' -not -path '*/.venv/*' | head -1`.
  FastAPI = `grep -rl 'from fastapi' --include='*.py' . | head -1`
- ORM/DB: `grep -rlE 'sqlalchemy|from django.db|@Entity|typeorm|prisma|drizzle' . | head -1`
- 미지원(go/rs/rb 등): 감지돼도 대응 규칙 없음 → PRUNE 대상 아님(코어 훅이 커버).

### 1-2. 코드베이스 신호 (보강·평가 근거 — 새로 수집)
- **린터/포맷터 존재**: Node면 `package.json`에 `prettier`/`eslint`/`biome` devDep + 로컬 바이너리;
  Python이면 `ruff`/`black` (`pyproject.toml` 또는 PATH); Java면 spotless 플러그인.
- **테스트 유무**: `tests/`·`test/`·`*_test.*`·`*.test.*`·`src/test/` 존재 여부(Stop 게이트 실효성 판단).
- **CI**: `.github/workflows/`·`.gitlab-ci.yml` 존재.
- **외부 도구 PATH**: `command -v gh ruff prettier tsc npx` — 스택에 필요한데 없는 것을 ADD 후보로.
- **규모**: `git ls-files | wc -l`, 소스 디렉토리 수, 모노레포 신호(`pnpm-workspace.yaml`·`turbo.json`·
  `workspaces`·하위 `package.json` 2개+). 대규모 → fable 유지, 소형 단일 → 프루닝 후보.

분석 결과를 **한 문단**으로 먼저 요약해 보여준다(무슨 스택·규모로 판단했는지, 근거 파일 명시).

## 2. 설정 검증 (config-doctor) — 검출 후 제안만

CLAUDE.md·AGENTS.md·`.claude/CLAUDE.md`의 정합성을 점검한다. 각 항목은 **FIX 제안**으로만 모은다
(자동 편집 금지 — 사용자 승인분만 7단계에서 반영).

> 기계적 검사(깨진 @참조·죽은 하네스 경로)는 `bash .claude/hooks/config-doctor.sh`로 결정론적으로
> 돌린다(advisory, 항상 exit 0, 출력만). 나머지(3파일 정합성·placeholder·glob 의미)는 아래를 직접 확인한다:

- **깨진 @참조**: CLAUDE.md·AGENTS.md의 `@경로`(예: `@AGENTS.md`, `@.claude/rules/common/`)가 실재하는가.
  `grep -oE '@[.A-Za-z0-9_/-]+' CLAUDE.md AGENTS.md` → 각 대상 `test -e`. 없는 대상 = FIX.
- **스택 감지 glob의 대상 규칙 실재**: CLAUDE.md/AGENTS.md의 "스택 감지" 표가 가리키는
  `.claude/rules/java-spring/`·`react-next/` 등이 실재하는가. **prune으로 사라진 경로를 가리키면 FIX**
  (그 줄을 지우거나, 해당 스택이면 ADD로 복구 제안).
- **3파일 정합성**: CLAUDE.md·AGENTS.md·`.claude/CLAUDE.md`는 "같은 규칙을 공유(하나 고치면 나머지도)"가
  전제다. 공통 축(절대 금지 목록·응답 언어 프로토콜·스택 감지 표)이 서로 어긋나면 FIX로 불일치 지점 제시.
- **미채운 placeholder**: 예시 도메인 규칙("주문 금액 음수 불가" 등)이 **그대로** 남아 실제 규칙이 없으면,
  프로젝트 도메인 규칙 작성을 FIX(스캐폴딩)로 제안.
- **존재하지 않는 파일 참조**: 본문이 가리키는 스킬/커맨드/규칙 경로가 실재하는지 표본 확인.

검출이 0건이면 "설정 정합성 이상 없음"이라고 명시한다(빈 척 금지).

## 3. 보강 계산 (ADD) — 필수·도움 요소

하네스 본체는 install.sh가 이미 전부 깔았다. 여기서 ADD는 **밖에서 채워야 할 것**이다. 세 갈래:

### 3-1. 외부 개발도구 (Stop 게이트 실효성에 직결 → 필수 후보)
1-2에서 없다고 확인된 것만. 감지 스택 기준:
- Node/TS: `prettier`(포맷 게이트)·`tsc`(타입) 미설치 → `npm i -D prettier typescript` 안내.
- Python: `ruff`·`pytest` 미설치 → `pip install ruff pytest`(또는 `uv`) 안내.
- Java: gradle spotless 미구성 안내.
- `gh`(PR 워크플로)·GSD(`npx get-shit-done-cc --local`) 미설치 → 선택 안내.
> ADD는 **안내/제안**이다. 사용자 머신에 임의로 설치 실행하지 않는다(승인 후 명령 제시).

### 3-2. 누락된 하네스 구성 복구
감지 스택에 **해당하는데 규칙/에이전트가 없으면**(이전 prune 등) 복구 제안:
- 예: `*.java` 다수인데 `.claude/rules/java-spring/`·`docs/rules/code-convention/dev-stack-java-spring.md`·`eval-java.sh` 부재 → 복구.
- 복구 수단: 직전 prune이면 `bash install.sh rollback`, 아니면 `bash install.sh update`(정본 재-fetch) 안내.
- **의존성 간선 존중**(4단계 표와 동일): eval-java ⟷ archunit, fable workflow ⟷ agent는 함께 복구.

### 3-3. 설정 스캐폴딩
- CLAUDE.md 도메인 규칙 섹션이 비었으면 `## 도메인 규칙` 스캐폴드 제안(2단계 placeholder와 연동).
- 보호 경로가 필요해 보이면(`.pem`·`config/prod/` 등 감지) `protected-extra.regex` 추가 제안.

## 4. 절단 계산 (PRUNE) — KEEP/PRUNE 집합

**ALWAYS-KEEP** + **감지 스택 게이트** + **의존성 간선**으로 유지 경로 집합을 만든다. 경로는 prune이
이해하는 확장 granularity(디렉토리 단위 또는 `docs/rules/code-convention/dev-stack-*.md` 파일 단위)로 쓴다.

### ALWAYS-KEEP (스택 무관, 반드시 keep-list 포함)
`install.sh prune`의 PROTECTED 정규식이 자동 보호하는 것(hooks 코어·settings.json·`safety.md`·
`common/*`·`testing.md`·CLAUDE.md·AGENTS.md·RULES.md·`.cursorrules`·`codex.md`·`.claude/CLAUDE.md`·
`vendor`·`.githooks`·`VERSION`·스크립트)은 keep-list에 없어도 유지된다. 아래는 PROTECTED가 아니므로
**keep-list에 명시**한다:
- `.claude/skills/handoff` · `changelog` · `version-changelog` · `anti-ai-slop` · `carve-harness-create`(자신)
- `.claude/commands/harness-audit.md` · `commit.md` · `plan.md` · `review.md` · `verify.md`
- `.claude/rules/database.md`는 ORM/DB 감지 시에만.

### 스택 게이트 (감지 시에만 KEEP, 아니면 PRUNE)
| 감지 | KEEP |
| --- | --- |
| Java/Spring | `.claude/rules/java-spring`(dir 전체, archunit 포함) · `dev-stack-java-spring.md` · **`.claude/hooks/eval-java.sh`** |
| TS/React/Next | `.claude/rules/react-next` · `frontend.md` · `dev-stack-typescript.md` · `dev-stack-react.md` · `dev-stack-nextjs.md` · `dev-stack-javascript.md` (감지된 하위스택만) |
| Python/FastAPI | `dev-stack-python.md` · `dev-stack-fastapi.md`(FastAPI 감지 시) |
| ORM/DB | `.claude/rules/database.md` · `dev-stack-orm.md` |

> `dev-stack-*.md` 상세본의 경로는 `docs/rules/code-convention/` (자동 로드 아님, 참조본).

### 하드 의존성 간선 (묶어서 keep 또는 prune — 절대 분리 금지)
1. **eval-java ⟷ archunit** (★최우선): `eval-java.sh` keep면 `java-spring`(archunit 포함)도 keep.
   한쪽만 남기면 `harness-audit` **AUDIT-08 FAIL**. Java 미감지 → 둘 다 prune.
2. **fable**: `workflows/fable-team-pipeline.js` ⟷ `agents/fable-*`(4) + `docs/md/orchestration.md` +
   `docs/md/fable-team-guide.md`. 함께.
3. **review ⟷ 리뷰어**: `commands/review.md`(ALWAYS-KEEP)가 `code-reviewer`·`security-reviewer`·
   `silent-failure-hunter`를 참조 → 이 3개 에이전트 keep.

소형 단일 스택: fable 프루닝 후보. 멀티모듈/모노레포/대규모: 유지. 애매하면 KEEP.

## 5. 통합 제안표 (FIX / ADD / KEEP / PRUNE)

manifest 확장 전 항목 + 2·3단계 결과를 하나의 표로 제시한다:
- **🔒 코어(ALWAYS-KEEP/PROTECTED)**: 상단 잠금 표시 — "절대 변경 안 됨".
- **FIX (설정 검증)**: 파일·위치·문제·제안 각 1줄.
- **ADD (보강)**: 도구/규칙/스캐폴딩·사유·실행 방법.
- **KEEP / PRUNE (절단)**: 2열, 각 PRUNE에 사유 1줄("Java 미감지 → java-spring 불필요").

**`--dry-run`이면 여기서 정지.** 표만 보여주고 아무것도 바꾸지 않는다.

## 6. 1회 확인

사용자에게 한 번 묻는다: "FIX N건(설정 수정 제안) · ADD M건(보강) · PRUNE K개(삭제)를 적용합니다.
KEEP 조정·FIX 취사선택이 필요하면 말씀하세요." — **놓친 스택·원치 않는 편집을 막을 마지막 안전판.**
각 방향을 **개별 승인**할 수 있게 한다(예: PRUNE만 진행, FIX는 보류).

## 7. 적용 (승인된 것만, 순서 고정)

1. **FIX**: 사용자가 승인한 CLAUDE.md/AGENTS.md 수정만 부분 편집(Edit). 3파일 공유 축을 고쳤으면
   **세 파일 모두** 동기화한다(정합성 전수 점검). 미승인 항목은 건드리지 않는다.
2. **ADD(복구)**: 승인 시 `install.sh rollback` 또는 `update`로 하네스 구성 복구. 외부 도구는 명령만 제시
   (임의 설치 실행 금지). 스캐폴딩은 승인분만 append.
3. **PRUNE**: KEEP 경로를 `mktemp` 파일에 1줄씩 기록(PROTECTED 포함 무방, 최소한 비보호 ALWAYS-KEEP·
   스택 매칭·의존성 keep 포함) → `bash install.sh prune --keep-list <tmp>`.
   - prune이 manifest 확장 → keep-list 밖 비보호 파일을 `logs/harness-backup/`에 백업 후 제거 → manifest 갱신.

## 8. 검증 + evaluator 평가표

1. `bash .claude/hooks/harness-audit.sh` — **exit 0(전 항목 pass) 필수.** FAIL이면(orphan 정책 —
   gateway 규칙 남았는데 트리거 없음, eval-java↔archunit 불일치 등) 즉시 `bash install.sh rollback`
   안내하고 **중단 보고**. 임의 추가 삭제 금지.
2. **evaluator 독립 평가표**: `evaluator` 서브에이전트를 띄워(생성/검증 분리) 적용 결과를 완료기준(SC)
   대비 독립 채점하게 한다. 평가 축과 SC:
   - **스택 커버리지**: 감지 스택마다 대응 규칙이 존재하는가(누락=감점).
   - **설정 정합성**: FIX 후 깨진 @참조·glob·3파일 불일치가 0인가.
   - **게이트 실효성**: 스택 린터/포맷터·테스트가 갖춰져 Stop 게이트가 실제로 무는가.
   - **절단 안전성**: `harness-audit` 0 fail, 의존성 간선 온전.
   evaluator 결과를 **PASS/WARN/FAIL × 축** 표로 사용자에게 제시한다. Generator(이 스킬)와 분리 운용.

## 9. 보고 + 정리

- FIX·ADD·PRUNE 최종 수, 남은 스택 규칙, `harness-audit` 결과, **evaluator 평가표**를 한국어로 요약.
- `.claude/harness-create-pending` 마커가 있으면 삭제. tmp keep-list 삭제.
- "되돌리려면 `bash install.sh rollback`, 커밋 전 `git diff`로 검토 권장" 안내.

## 주의
- 미지원 스택(go/rust/ruby 등)은 대응 규칙이 없어 프루닝·복구 대상 아님 — 코어 훅이 커버.
- 설정 파일 편집(FIX)은 **되돌리기 위해 git 필요** — dirty 트리면 diff 검토 후 커밋 권장.
- 외부 도구·GSD 설치는 **안내만** 한다 — 사용자 머신 상태를 임의로 바꾸지 않는다.
- prune은 되돌릴 수 있으나 한 버전에서 prune/update를 섞으면 백업이 겹칠 수 있다 — clean 버전에서 한 번에 권장.
- 이 스킬은 모델 무관 경로 집합으로 fable을 다룬다 — 미설치면 manifest에 없어 자동으로 건너뛴다.
