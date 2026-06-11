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
