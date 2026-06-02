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

### `git add a b c` — 누락 pathspec이면 전체 스테이징 중단
- 증상: 여러 파일을 add했는데 일부만(또는 아무것도) 스테이징됨 → 커밋에 본문 변경이 빠짐.
- 근본원인: pathspec 중 하나라도 매치 안 되면 `git add`가 fatal로 멈춰 유효 파일도 스테이징 안 됨.
- 수정: 삭제 파일은 `git rm`로 먼저 처리하고, 커밋 직전 `git status --short`로 스테이징 상태 확인.
- 날짜: 2026-06-02
