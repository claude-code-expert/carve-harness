# vendor/ — 프로젝트 로컬 벤더링

| 디렉토리 | 내용 |
|----------|------|
| `ponytail/` | ponytail 모드(업스트림 플러그인 하드카피) — `.claude/settings.json` 훅으로 배선, install.sh가 대상 레포에 복사 |

> 오프라인용 정적 바이너리(`bin/` jq·shellcheck)는 v0.6.x에서 제거됨 — 온라인 환경 전제,
> `install.sh`는 바이너리 부재 시 WARN 후 시스템 PATH의 jq/shellcheck를 사용한다.
> 필요하면 git 히스토리(`vendor/bin`)에서 복구.
