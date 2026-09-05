# `packs/` — 언어팩 정의

설치 시 어떤 언어의 규칙·게이트·채점·골든셋·LSP를 한 세트로 넣을지 정하는 평문 매니페스트. `install.sh`와 `lib-packs.sh`가 읽고, 감지된 팩만 설치된다.

## 형식 (`<name>.pack`, jq 불요)
```
name: typescript
detect: package.json tsconfig.json     # 마커 파일(루트 또는 한 단계 하위)
detect_grep: prisma|drizzle|...         # 의존성 매니페스트 내용(마커 없는 부속 팩)
lsp: vtsls@claude-code-lsps             # 팩이 켜고 끄는 LSP 플러그인
.claude/rules/react-next                # 설치 경로 목록 = manifest/prune 단위
docs/rules/code-convention/dev-stack-typescript.md
...
```

## 팩 6종
typescript · java-spring · python · go · rust · database(ORM 부속).

> 사후 관리: `bash install.sh pack list|add <name>|remove <name>`. 무결성은 감사 AUDIT-09가 검사(경로·스택 파일·골든셋 스타터·LSP 토글). 설계: `docs/md/language-packs/`.
