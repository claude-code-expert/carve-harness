# 릴리스 가이드 — develop에서 개발해 npm에 배포하기

`carve-harness`를 npm에 배포하는 전체 순서. **배포는 버전 태그를 push하면 GitHub Actions가
main 기준으로 자동 게시**한다(`.github/workflows/release.yml`). 로컬에서 `npm publish`를 직접 칠 일은 없다.

## 핵심 원리

- **빌드**: 개발 중엔 빌드가 없지만(`.ts` 직접 실행), `node_modules` 아래에선 타입 스트리핑이 막힌다.
  그래서 배포 시 `prepack`이 `.ts`→`.js`로 컴파일해 싣는다(`tsconfig.build.json`).
- **게시 트리거**: `vX.Y.Z` 형식 **태그 push**. main 머지만으론 안 돈다(같은 버전 중복 게시 방지).
- **검증 게이트**: `npm publish`가 `prepublishOnly`(타입체크+테스트) → `prepack`(빌드)를 자동 실행한다.
  **테스트 실패 시 게시되지 않는다.**
- **토큰**: GitHub Secret `NPM_TOKEN`(2FA 우회 granular)으로만 인증. 로컬·이 저장소엔 토큰이 없다.

## 사전 설정 (최초 1회)

저장소 → **Settings → Secrets and variables → Actions → New repository secret**
- Name: `NPM_TOKEN`
- Secret: npmjs.com에서 발급한 **Granular Access Token** (Permissions: *Read and write*, Packages: *All packages*)
  - 신규 패키지 생성 권한이 필요하므로 첫 배포 토큰은 *All packages*여야 한다. 이후 `carve-harness`만 허용하도록 좁혀도 된다.
  - classic "Publish" 토큰은 2FA를 우회하지 못해 실패한다. 반드시 granular(또는 classic *Automation*).

> 이 시크릿은 등록 완료된 상태다. 토큰을 교체할 때만 다시 만진다.

## 릴리스 순서

### 1. develop에서 개발·검증

```bash
# feature 브랜치 → develop PR 머지 (main 직접 작업 금지)
git switch develop && git pull
npm run check && npm test     # 로컬에서 먼저 통과 확인
```

> ⚠️ **로컬에 `shellcheck`를 설치하라**(`brew install shellcheck`). auditor의 셸 문법 검사는 shellcheck가 있으면 그걸, 없으면 `bash -n`(느슨)을 쓴다. CI(ubuntu)엔 shellcheck가 있으므로, 로컬에 없으면 `bash -n`이 못 잡는 문제(예: zsh shebang → SC1071)가 **CI에서만 테스트를 깨고 게시를 막는다.** 로컬 검사를 CI와 일치시켜야 한다.

### 2. 버전 올리기 (develop에서, 태그는 아직 만들지 않음)

`package.json`의 버전만 올리고 커밋한다. 태그는 main 승격 후 4단계에서 단다.

```bash
npm version patch --no-git-tag-version   # 1.0.0 → 1.0.1 (package.json만 수정)
git commit -am "chore: release v$(node -p "require('./package.json').version")"
git push origin develop
```

| 변경 성격 | 명령 | 예 |
|-----------|------|-----|
| 버그 수정·문서 | `npm version patch` | 1.0.0 → 1.0.1 |
| 하위호환 기능 추가 | `npm version minor` | 1.0.1 → 1.1.0 |
| 호환 깨지는 변경 | `npm version major` | 1.1.0 → 2.0.0 |

### 3. develop → main 승격 (PR)

```bash
gh pr create --base main --head develop \
  --title "release: v$(node -p "require('./package.json').version")" \
  --body "릴리스 승격"
gh pr merge --merge        # 또는 GitHub 웹에서 머지
```

### 4. main에 태그를 달아 게시 트리거

CI는 **태그가 가리키는 커밋을 체크아웃**한다. 태그를 main에 달아야 main 기준으로 빌드·게시된다.

```bash
git switch main && git pull origin main
VER=$(node -p "require('./package.json').version")
git tag "v$VER"
git push origin "v$VER"     # → release 워크플로 시작
```

### 5. 결과 검증

- **GitHub → Actions** 탭에서 `release` 워크플로가 **녹색**인지 확인
- 레지스트리 반영 확인:
  ```bash
  npm view carve-harness version          # 방금 올린 버전과 일치해야 함
  ```
- 실제 설치 확인(깨끗한 디렉토리에서):
  ```bash
  npx -y carve-harness@latest --help
  ```

## 빠른 참고 (한 번에)

```bash
# develop에서
git switch develop && git pull
npm run check && npm test
npm version patch --no-git-tag-version
git commit -am "chore: release v$(node -p "require('./package.json').version")"
git push origin develop
gh pr create --base main --head develop --title "release: v$(node -p "require('./package.json').version")" --body "릴리스 승격"
gh pr merge --merge
# main에서
git switch main && git pull origin main
VER=$(node -p "require('./package.json').version"); git tag "v$VER" && git push origin "v$VER"
```

## 문제 해결

| 증상 | 원인 | 해결 |
|------|------|------|
| Actions에서 `403 ... 2fa ... required` | `NPM_TOKEN`이 2FA 우회 안 되는 종류 | granular(R/W, All packages) 또는 classic *Automation*으로 교체 |
| `403 ... cannot publish over previously published version` | `package.json` 버전이 이미 게시됨 | 2단계로 돌아가 버전을 올린다 |
| 워크플로가 아예 안 돈다 | 태그가 `v`로 시작 안 함 / 태그 push 누락 | `vX.Y.Z` 형식으로 태그를 push했는지 확인 |
| 테스트 실패로 게시 중단 | `prepublishOnly` 게이트 | 로컬에서 `npm test` 고치고 다시 릴리스 |
| 로컬은 통과인데 CI만 테스트 실패 | 로컬에 shellcheck 없어 `bash -n` 폴백(CI는 shellcheck) | `brew install shellcheck` 후 `npm test` 재현·수정 |
| 게시 전 단계(테스트)에서 막혀 npm엔 안 올라감 | 게이트가 publish 전에 차단 | 수정을 main까지 보낸 뒤, **그 버전이 npm에 없으므로** 같은 태그를 재사용 가능: `git push origin :vX.Y.Z`(원격 삭제) → `git tag -f vX.Y.Z`(수정 커밋) → `git push origin vX.Y.Z`. 또는 다음 patch로 올린다 |

## 롤백 / 회수

- npm은 한 번 게시한 버전을 **덮어쓸 수 없다**. 잘못 냈으면 **다음 patch로 올려서** 고친다.
- 게시 직후(72시간 내) 한정으로 `npm unpublish carve-harness@X.Y.Z` 가능하나 권장하지 않는다.
- 결함 버전은 설치 유도를 막기 위해 `npm deprecate carve-harness@X.Y.Z "사유"`로 표시한다.
