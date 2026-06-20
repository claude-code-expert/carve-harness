<!--
  Document : Gotchas
  Purpose  : carve-harness 고유 버그·함정 로그(증상→근본원인→수정→날짜). 비자명한 재발 버그는 즉시 기록.
  Stack    : TypeScript (ESM, Node >=22.18)
  Version  : 1.1.0 (2026-06-02)
-->
# Gotchas

> carve 고유 함정 로그. 비자명한 버그가 재발하면 **즉시** 여기 기록한다(기억에 의존 금지).
> 각 항목: 증상 → 근본원인 → 수정 → 날짜.

---

## Entries

### node_modules 아래에서 .ts 타입 스트리핑 불가
- 증상: `npx carve-harness` 설치 후 첫 실행이 `ERR_UNSUPPORTED_NODE_MODULES_TYPE_STRIPPING`로 죽음.
- 근본원인: Node 타입 스트리핑은 `node_modules` 아래 `.ts`를 의도적으로 지원하지 않는다. "빌드리스 .ts 직접 실행"은 *개발 시*에만 유효.
- 수정: 배포 시 `prepack`이 `tsconfig.build.json`(`rewriteRelativeImportExtensions`)으로 `.ts`→`.js` in-place 컴파일. `bin`→`carve.js`, `files`=`.js`+assets.
- 날짜: 2026-06-02

### 상대 import 확장자 / 자산 경로
- 증상: 빌드 후 모듈 not found 또는 자산 파일 못 읽음.
- 근본원인: 모든 상대 import가 `.ts` 명시 확장자 사용 + 자산을 `new URL('../assets/', import.meta.url)`로 해석. 출력 깊이가 바뀌면 둘 다 깨짐.
- 수정: in-place 컴파일(src/bin 옆에 .js)로 상대경로 보존. `rewriteRelativeImportExtensions`가 정적·동적 import의 `.ts`를 `.js`로 재작성.
- 날짜: 2026-06-02

### .claude/CLAUDE.md 자동 로드 안 됨
- 증상: `init-claude` 후에도 베이스라인·rules가 세션에 안 실림.
- 근본원인: Claude Code는 `.claude/CLAUDE.md`를 자동 로드하지 않는다. 루트 `CLAUDE.md`의 `@import`만 로드됨.
- 수정: `installer.installClaudeBase()`가 루트 `CLAUDE.md`에 `@import` 블록을 marker 기준 멱등 추가(그래서 루트 패치 필수).
- 날짜: 2026-06-01

### npm publish 2FA — classic "Publish" 토큰은 우회 못 함
- 증상: 토큰을 줬는데도 `403 ... two-factor authentication ... required`.
- 근본원인: classic "Publish" 토큰은 2FA를 우회하지 않는다(특히 2FA가 패스키면 로컬 `--otp` 자체가 불가).
- 수정: **Granular Access Token**(Read and write + All packages) 또는 classic **Automation**. CI는 GitHub Secret `NPM_TOKEN`으로만.
- 날짜: 2026-06-02

### 생성 훅 명령은 상대경로면 설치 후 실행 실패
- 증상: `carve install` 후 대상 프로젝트에서 훅이 `bash: .claude/hooks/carve-*.sh: No such file or directory`로 죽음. 파일은 정상 설치돼 있음.
- 근본원인: `generator.ts`의 `hookRegsFor()`가 settings.json 훅 `command`를 상대경로(`bash .claude/hooks/...`)로 기록. Claude Code가 훅을 실행하는 cwd가 프로젝트 루트라는 보장이 없어 bash가 스크립트를 못 찾음.
- 수정: 모든 훅 `command`를 `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/...` 절대경로로 등록(리포 자신의 `.claude/settings.json` 규약과 동일, 설치 스크립트도 `${CLAUDE_PROJECT_DIR:-.}` 전제). artifact의 **파일 경로**는 루트 기준 상대경로가 맞으니 그대로 둠 — "실행 명령"과 "파일 경로"는 다른 축. 회귀 테스트는 `test/unit/generator.test.ts`의 `hookRegsFor: $CLAUDE_PROJECT_DIR` 케이스. 기존 피해 설치는 `uninstall→install` 재설치 필요(멱등 병합이 command 문자열 일치로만 중복 제거).
- 날짜: 2026-06-11

### `git add a b c` — 누락 pathspec이면 전체 스테이징 중단
- 증상: 여러 파일을 add했는데 일부만(또는 아무것도) 스테이징됨 → 커밋에 본문 변경이 빠짐.
- 근본원인: pathspec 중 하나라도 매치 안 되면 `git add`가 fatal로 멈춰 유효 파일도 스테이징 안 됨.
- 수정: 삭제 파일은 `git rm`로 먼저 처리하고, 커밋 직전 `git status --short`로 스테이징 상태 확인.
- 날짜: 2026-06-02

### 맨 동사형 스킬 이름은 Claude Code 내장 슬래시 명령과 충돌(`/memory` 이중 등록)
- 증상: 대상 프로젝트에 carve 설치 후 슬래시 메뉴에 `/memory`가 **두 개** 뜸(내장 + carve). `/verify`·`/pr`·`/review`도 동일.
- 근본원인: Claude Code는 `.claude/skills/<dir>/SKILL.md`를 **디렉터리 이름** 그대로 `/<dir>` 슬래시로 노출한다. carve는 커맨드 shim만 `carve-` 네임스페이스를 주고(`carve-memory.md`→`/carve-memory`) **스킬 디렉터리 이름엔 접두사를 안 줘서**, `memory`·`verify`·`pr`·`review` 같은 맨 동사형 id가 내장 명령을 그대로 가린다. shim(`/carve-memory`)은 충돌하지 않음 — 범인은 스킬 디렉터리.
- 수정: 해당 4개를 카탈로그에서 `status: 'hidden'`으로 fade-out(`designer.ts`가 hidden을 available·recommended·`--only`에서 완전 제외 → 신규 설치 충돌 소멸). 자산·엔트리는 보존(라이프사이클 cadence상 삭제는 다음 단계). `iterate`가 `verify` 스킬에 의존하던 1줄은 게이트 단계 인라인으로 풀었다. 회귀 가드: `designer.test.ts`의 "hidden 4종 제외" + `lifecycle.test.ts`의 "hidden 설치분 보고". **신규 스킬 추가 시 id가 내장 슬래시 명령과 겹치지 않는지 먼저 확인**(내장 목록: memory·verify·pr·review·init·run·config·review 등). 기존 피해 설치는 `.claude/skills/<id>/` + manifest 항목 수동 삭제(skill은 훅·MCP 미등록이라 settings.json 무관).
- 후속(구조적 해소): 아래 "스킬 슬래시 이중 노출" 항목에서 **모든** 스킬 디렉터리를 `carve-<id>`로 접두 → 슬래시가 전부 `/carve-<id>`가 돼 내장 충돌 클래스 자체가 소멸. 이 hidden 우회는 그 변경의 선행 임시조치였다.
- 날짜: 2026-06-13

### 스킬 슬래시 이중 노출(`/workflow` + `/carve-workflow`) — shim 레이어 폐지로 해소
- 증상: 대상 프로젝트 슬래시 메뉴에 한 스킬당 두 개(`/workflow`와 `/carve-workflow`)가 떴다. 16개 스킬 전부.
- 근본원인: Claude Code가 `.claude/skills/<dir>/SKILL.md`를 **디렉터리 이름** 그대로 `/<dir>` 슬래시로 자동 노출한다. carve는 스킬 디렉터리를 bare id(`workflow`)로 깔고, 별도로 `carve-<id>` 커맨드 shim(`/carve-workflow`)도 깔아 둘이 공존했다. 스킬은 `$ARGUMENTS`를 **네이티브 지원**하므로 shim의 인자 전달 명분도 이미 사라진 상태였다(공식 문서: code.claude.com/docs/en/skills).
- 수정: 스킬 디렉터리를 `carve-<id>`로 접두(`assets/skills/carve-<id>/`) → 슬래시가 `/carve-<id>` 하나로 수렴, 내장 충돌 클래스 소멸. shim 자산(`assets/commands/carve-<id>.md`) 16개 전부 삭제. **카탈로그 id는 bare 유지**(designer·scoring·테스트 불변), 경로 생성부(`generator.ts`)와 역매핑부(`lifecycle.ts` — `byId(dir)` 없으면 `carve-` 접두 제거)만 갱신. 회귀 가드: `assets.test.ts`(shim 부재·carve- 경로 존재), `generator.test.ts`(shim 미emit), `orphan-cleanup.test.ts`(마이그레이션).
- 주의(규약): **신규 스킬 디렉터리는 반드시 `carve-<id>`**, 카탈로그 id는 bare. 향후 carve- 접두 스킬을 tombstone에 넣을 땐 `carve-<id>`(접두 포함)로 적는다(orphanRef가 디렉터리 세그먼트를 그대로 id로 환원하므로). 부수효과: `/workflow`(단수) vs 내장 `/workflows`(복수) 혼동도 함께 소멸.
- 마이그레이션: 구설치(접두 이전)는 `cmdInstall`이 `install()` 직전 `removeOrphanedComponents(root, RENAMED_SKILL_IDS)`로 old `skills/<id>/`+옛 shim을 해시 가드로 1회 제거 후 새 경로 기록(클린 스왑). 사용자 수정 old 스킬은 보존·안내. 확실한 클린은 `uninstall`→`install`.
- 날짜: 2026-06-21
