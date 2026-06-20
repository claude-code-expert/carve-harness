---
name: codesight
description: >
  토큰 효율 컨텍스트 — 프로젝트 구조를 codesight로 파악한다. 코드 탐색·구조 파악·영향 범위가 필요할 때,
  "구조 파악", "어디서 쓰여", "영향 범위" 요청에 사용. grep/전체 읽기 대신 codesight MCP·.codesight/ 우선.
---
# codesight — 토큰 효율 컨텍스트

> 프로젝트 탐색에 수만 토큰을 낭비하지 않는다. codesight가 구조를 미리 맵핑한다(실측 평균 약 11배 절약).

- 라우트·스키마·컴포넌트·의존성·환경변수 파악은 **codesight MCP**(`codesight_get_*`) 또는 `.codesight/CODESIGHT.md`를 먼저 본다.
- 파일 변경 전 영향 범위는 `codesight_get_blast_radius`.
- grep·전체 파일 읽기는 codesight로 안 되는 것만 보조로 쓴다.
- 설치 시 `.claude/settings.json`에 codesight MCP가 등록되고, `.codesight/`는 커밋 전 훅으로 갱신된다.
