# LP0 — 언어팩 매니페스트 + 리더 라이브러리

> 브랜치 `feat/lp0-pack-manifest` · 계획 `specs/language-pack-plan.md` §3 LP0
> 결과: 팩 6개 정의(`packs/*.pack`), 리더 `.claude/hooks/lib-packs.sh`, 테스트 20건 green, 전 스위트·감사 통과.

## 1. 구성

```
packs/
├── typescript.pack     TS/React/Next   detect: package.json tsconfig.json   lsp: vtsls
├── java-spring.pack    Java/Spring     detect: gradlew build.gradle(.kts) pom.xml   lsp: jdtls
├── python.pack         Python/FastAPI  detect: pyproject.toml requirements.txt setup.py setup.cfg   lsp: pyright
├── go.pack             Go              detect: go.mod   lsp: gopls        (경로는 LP1/LP3에서 채움)
├── rust.pack           Rust            detect: Cargo.toml   lsp: rust-analyzer   (동)
└── database.pack       ORM/DB 부속     detect_grep: prisma|drizzle|typeorm|…|sqlalchemy|…|gorm.io|diesel|sqlx|sea-orm
.claude/hooks/lib-packs.sh          리더(소싱 전용, 부작용 없음)
.claude/hooks/tests/lib-packs.test.sh  20건
```

팩 파일 형식 — bash만으로 읽히는 평문(설치 시점엔 jq가 없을 수 있다):

```
# 주석
name: typescript                 ← 헤더 = `식별자:` 줄
label: TypeScript / React / Next
summary: rules react-next · Stop tsc/lint/test · LSP vtsls   ← 설치 대화창 한 줄 설명
detect: package.json tsconfig.json     ← 마커 파일(루트 또는 한 단계 하위 디렉토리)
detect_grep: prisma|drizzle            ← 의존성 매니페스트 내용 정규식(마커 없는 부속 팩용)
lsp: vtsls@claude-code-lsps            ← 팩이 켜고 끄는 마켓플레이스 플러그인
.claude/rules/react-next               ← 설치 경로(한 줄 하나) = manifest/prune 단위
docs/rules/code-convention/dev-stack-typescript.md
```

경로 줄과 헤더 줄의 구분: 헤더는 `^[a-z_]+:`, 경로는 `/`나 `.`가 먼저 온다. 팩 경로는 **소스 리포의 현재 위치 그대로** — 레이아웃을 옮기지 않는다(설계 원칙 2.1-1).

현 시점 팩별 경로(전부 실재 검증됨):

| 팩 | 경로 |
|---|---|
| typescript | `.claude/rules/react-next` · `dev-stack-{typescript,react,nextjs,javascript}.md` |
| java-spring | `.claude/rules/java-spring`(archunit 포함) · `.claude/hooks/eval-java.sh` · `dev-stack-java-spring.md` · `docs/evaluator/java-example` |
| python | `dev-stack-{python,fastapi}.md` · `docs/evaluator/python-example` |
| go · rust | (비어 있음 — LP1 스택 정의, LP3 규칙·스타터·judge 예시에서 추가) |
| database | `.claude/rules/database.md` · `dev-stack-orm.md` |

## 2. 구현 — `lib-packs.sh` API

| 함수 | 입력 → 출력 | 비고 |
|---|---|---|
| `pack_list` | → 팩 이름 줄 단위 | `packs/*.pack` 글롭 순(정렬) |
| `pack_meta NAME KEY` | → 헤더 값(없으면 빈 문자열) | 팩 없음 → rc 1 |
| `pack_paths NAME` | → 설치 경로 줄 단위 | 경로 0개여도 rc 0 |
| `pack_check NAME [SRC]` | → SRC에 없는 경로 출력 | 하나라도 없으면 rc 1 — 설치 전 dangling 검출 |
| `pack_detect [DIR]` | → DIR에서 감지된 팩 이름들 | 마커: `DIR/<m>` 또는 `DIR/*/<m>`(backend/gradlew·frontend/package.json 관례). `detect_grep`: `PACK_MANIFESTS`(package.json·pyproject.toml·requirements.txt·build.gradle(.kts)·pom.xml·go.mod·Cargo.toml) 내용 grep |
| `PACKS_DIR` | env 오버라이드 | 기본 = 라이브러리 기준 `../../packs`. install.sh는 `$SRC/packs`, 테스트는 픽스처 |

설계 메모
- `requires:` 헤더는 넣지 않았다. 현재 어떤 팩도 다른 팩을 요구하지 않는다(java↔archunit 간선은 팩 내부). 필요해지면 그때 추가.
- Go·Rust는 `detect`·`lsp`만 있는 빈 팩으로 먼저 등록했다 — LP1(스택 파일)·LP3(규칙·스타터)에서 경로를 채운다. 빈 팩도 `pack_paths` rc 0이라 파이프라인이 깨지지 않는다.
- 이 리포 자체를 감지하면 `typescript`가 나온다(`package.json`이 npm test 래퍼). 하네스 소스 리포는 설치 대상이 아니므로 무해.

## 3. 사용방법

```bash
# 리더 소싱 (bash 전용 — zsh에서 직접 source하면 BASH_SOURCE가 없어 PACKS_DIR 계산이 틀린다)
bash -c 'source .claude/hooks/lib-packs.sh; pack_list'
bash -c 'source .claude/hooks/lib-packs.sh; pack_detect /path/to/project'      # 감지
bash -c 'source .claude/hooks/lib-packs.sh; pack_paths java-spring'            # 설치 경로
bash -c 'source .claude/hooks/lib-packs.sh; pack_check python . && echo ok'    # dangling 검사
bash .claude/hooks/tests/lib-packs.test.sh                                     # 20건
```

새 팩 추가 = `packs/<name>.pack` 1파일. 헤더 4줄 + 경로 목록. `pack_check`가 실재를 강제하므로 존재하지 않는 경로는 테스트(4번 항목)에서 바로 잡힌다.

## 4. 완료 기준(SC) 검증

| SC | 명령 | 결과 |
|---|---|---|
| ① 파싱된 경로 전부 소스에 실재 | `lib-packs.test.sh` "all pack paths exist in source" | PASS |
| ② 픽스처별 정확한 팩만 감지(ts·java 하위·py·go·rust·prisma→database+ts·모노레포) | 같은 스위트 (5)절 8건 | PASS |
| ③ 빈 디렉토리 → 감지 없음 | "empty dir -> no pack" | PASS |
| 회귀 | `npm test` · `harness-audit` | 22 스위트 345건 PASS · 감사 49 PASS(신규 훅 +x 검사 1건 증가) |

## 5. 다음 단계(LP1)

`.claude/stacks/{typescript,java,python,go,rust,bash}.sh` 스택 정의 파일을 만들고 `stop-verify.sh`·`posttool-format.sh`가 이를 source 하도록 바꾼다. 안전판: 기존 `stop-verify.test.sh` 18건·`posttool-format.test.sh` 7건을 **수정 없이** green. 각 팩 `.pack`에 자기 스택 파일 경로를 추가한다.
