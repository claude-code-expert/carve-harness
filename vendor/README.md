# vendor/ — 오프라인(에어갭) 동작용 내장 바이너리

인터넷 없는 환경에서 하네스가 자급자족하도록 정적 바이너리를 레포에 내장한다.
`install.sh`가 아키텍처를 감지해 `.claude/bin/`으로 배치한다 (PATH 오염 없음, 레포 로컬).

## 내용물

| 파일 | 버전 | 용도 | 출처 | 라이선스 |
|------|------|------|------|----------|
| `bin/jq-linux-amd64` | jq 1.8.2 | 훅 필수 (없으면 fail-closed로 쓰기 마비) | github.com/jqlang/jq releases | MIT |
| `bin/jq-linux-arm64` | jq 1.8.2 | 동일 (ARM 서버/맥 VM) | 동일 | MIT |
| `bin/shellcheck-linux-x86_64` | 0.11.0 | Stop 게이트 bash 정적분석 (선택 — 없으면 스킵) | github.com/koalaman/shellcheck releases | GPL-3.0 |

- 무결성: `bin/SHA256SUMS` (`sha256sum -c SHA256SUMS`로 검증).
  jq 2종은 업스트림 `sha256sum.txt`와 대조 완료(2026-07-08), shellcheck는 공식 릴리스 tar.xz에서 추출.
- 다운로드일: 2026-07-08 (온라인 환경에서 수행).

## 갱신 절차 (온라인 머신에서)

```bash
# jq
curl -sLO https://github.com/jqlang/jq/releases/download/jq-<ver>/jq-linux-amd64
# shellcheck
curl -sL https://github.com/koalaman/shellcheck/releases/download/v<ver>/shellcheck-v<ver>.linux.x86_64.tar.xz \
  | tar -xJ --strip-components=1 shellcheck-v<ver>/shellcheck
sha256sum jq-linux-* shellcheck-* > SHA256SUMS   # 업스트림 체크섬과 대조 후 커밋
```

## 의도적으로 내장하지 않은 것

| 항목 | 이유 |
|------|------|
| prettier / pnpm / gradle | 대상 프로젝트 스택 도구 — 프로젝트가 자체 보유(훅은 없으면 skip 기록 후 통과) |
| ruff / pytest | Python 프로젝트 자체 가상환경 소관 — Stop 게이트는 best-effort 감지 |
| Claude Code 본체·플러그인(GSD 등) | 레포 밖 사용자 환경 — 하네스 코어는 이것 없이도 훅+git 게이트로 동작 |
| Windows 네이티브 바이너리 | 하네스 훅이 bash 전제 — Windows는 WSL 사용 |
