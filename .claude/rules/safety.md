<!--
  Document : Safety Rules
  Purpose  : carve-harness 안전 규칙 — 설치 멱등성·생성물 audit 게이트·자산 경계·의존성/배포 변경 승인. CLAUDE.md 가드레일 확장.
  Stack    : TypeScript (CLI, no DB/Docker/production runtime)
  Version  : 1.1.0 (2026-06-02)
-->
# Safety Rules

> carve 한정 안전 규칙. CLAUDE.md의 가드레일을 확장한다. (이 프로젝트엔 DB·Docker·프로덕션 런타임이 없다 — 일반 웹앱 규칙은 해당 없음.)

## 절대 금지

### 설치/생성 (carve의 핵심 계약)
- **멱등성 위반 금지**: 재설치 시 사용자가 수정한 자산을 덮어쓰지 않는다. 충돌은 diff 제시 후 확인, 원본은 `.bak`로 1회 보존.
- 대상 프로젝트의 **소스 코드를 수정하지 않는다**. 쓰기는 `.claude/` + 지정된 루트 가이드 파일 + `carve-manifest.json`으로 한정.
- `auditor`를 통과하지 못한 생성물은 설치하지 않는다(secret 노출·과도 권한·hook injection·셸 문법 오류).
- 결정적 차단 훅(`block-destructive`·`protect-secrets`, `exit 2`)을 약화시키지 않는다.

### 파일/git
- `rm -rf`를 프로젝트 루트나 핵심 디렉토리에 실행 금지.
- `git push --force`·`git reset --hard`·`git commit --no-verify` 금지.
- **명시 요청 없이 커밋/푸시 금지.** `main` 직접 작업 금지(릴리스 시 develop→main PR 승격). devleop의 경우 요청할 경우만 커밋/푸시. 이전에 요청했다고 다시 자동으로 승인없이 커밋/푸시 하지 말것.
- `.env*` 파일 직접 생성·편집 금지. 코드·로그에 키/토큰 노출 금지.

## 명시적 승인 필요
- **의존성 추가/버전 변경**(`package.json`) — carve는 의존성 최소가 정체성(@clack 하나).
- **빌드·배포 설정 변경**: `tsconfig.json`·`tsconfig.build.json`·`package.json`의 `bin`/`files`/`scripts`·`.github/workflows/release.yml`.
- `vendor/` 복원 또는 런타임 vendor 의존 재도입.
- 문서 파일 삭제.

## 베스트 프랙티스
- 생성/수정한 스크립트는 커밋 전 문법 검증(`npm run check`·`bash -n`·`JSON.parse`).
- 자산 경로(`new URL('../assets/', import.meta.url)`)에 영향 주는 파일 이동·빌드 출력 위치 변경은 신중히 — 깨지기 쉽다.
- `npm publish`는 CI(태그 push)로만 — 토큰은 GitHub Secret(`NPM_TOKEN`), 로컬에 두지 않는다.
