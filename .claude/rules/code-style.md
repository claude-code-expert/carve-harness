<!--
  Document : Code Style
  Purpose  : carve-harness 코드 스타일 — ESM·strict TS·`.ts` 명시 import·주입식 IO·의존성 최소·결정적 훅. 기존 코드를 먼저 따른다.
  Stack    : TypeScript (ESM, Node >=22.18)
  Version  : 1.1.0 (2026-06-02)
-->
# Code Style

> carve 기준선. **기존 코드를 먼저 맞춘다** — 아래는 기본값이지 덮어쓰기가 아니다.

## TypeScript / ESM
- `strict: true` 항상. **`any` 금지** — 정확한 타입 또는 `unknown` + 좁히기.
- 컴파일러를 속이는 non-null `!` 금지 — null 경우를 처리한다.
- `verbatimModuleSyntax`: 타입 전용 import는 `import type { X } from './m.ts'`.
- 상대 import는 **확장자 명시**(`'./designer.ts'`). 빌드가 `.js`로 재작성한다.
- 경로 alias 없음(`@/*` 미사용) — 상대경로만 쓴다.

## 의존성
- 런타임 의존성은 `@clack/prompts` 하나뿐. **새 라이브러리 추가 금지**(승인 필요). 표준 라이브러리(`node:fs`·`node:path`·`node:child_process`)로 푼다.
- `vendor/` 비의존 — 자산은 `assets/`에서만 읽는다.

## 출력 / 로깅
- 앱 코드(`src/`)에서 `console.*` 직접 호출 금지 — 주입식 **`IO` 인터페이스**(`io.log`/`io.error`)를 쓴다. 진입점(`bin`)에서 `console`을 IO로 주입하고, 테스트는 캡처용 IO를 주입한다.
- 에러를 조용히 삼키지 않는다(`.catch(() => {})` 금지) — 최소한 맥락과 함께 보고.

## 네이밍 & 구조
- 함수/변수 `camelCase`, 타입/클래스 `PascalCase`, 상수 `UPPER_SNAKE`.
- 이름은 의도를 드러낸다(`shouldRetry`, `flag2` 아님). 한 모듈 = 한 책임, 작게 유지.
- 중복 제거, 의존을 명시적으로, 공유 가변 상태 최소화.
- 주석·CLI 문자열은 주변 파일 관례를 따른다(현 코드베이스는 한국어 주석·한국어 사용자 메시지).

## 비동기
- 원시 `.then()` 체인보다 `async/await`. rejection은 항상 처리.

## 안전 (코드 차원)
- secret·API 키·토큰 하드코딩 금지. `.env*`나 실제 자격증명 파일 커밋 금지.
- 생성하는 훅/커맨드는 secret 노출·과도 권한·hook injection이 없어야 한다(`auditor` 통과 필수).
- 생성·수정한 스크립트는 커밋 전 검증: TS `tsc --noEmit`(`npm run check`), Shell `bash -n`, JSON `JSON.parse`.
