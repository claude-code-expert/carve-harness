---
name: lsp
description: >
  토큰 효율 코드 인텔리전스 — LSP로 정확한 코드 네비게이션. 참조 찾기·정의 이동·타입 에러 확인 시,
  "어디서 참조", "정의로 이동", "타입 에러" 요청에 사용. grep 대신 findReferences/getDiagnostics 우선.
---
# lsp — 코드 인텔리전스 (토큰 효율)

> grep은 100파일에서 2,000+ 토큰, LSP는 정확한 결과만 약 500 토큰.

- 참조 찾기: `findReferences` — 주석·문자열 제외, 실제 코드 참조만 반환.
- 정의·심볼: `goToDefinition` · `documentSymbol` · `hover`.
- 수정 후 검증: `getDiagnostics` — 빌드 없이 타입 에러 즉시 확인.
- 설치 시 cclsp MCP가 `.claude/settings.json`에 등록되고, 언어서버 바이너리는 carve가 탐지 언어로 설치한다.
- 더 낮은 토큰을 원하면 공식 빌트인 LSP 플러그인(`/plugin install vtsls@claude-code-lsps`)으로 업그레이드한다.
