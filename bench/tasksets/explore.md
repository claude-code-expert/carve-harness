# Taskset ④ 탐색 지배 (codesight/LSP vs grep)

대형 코드베이스(`node bench/gen-fixture.mjs --modules 200 --out <dir>`) 위에서, 탐색 비용이
지배적인 태스크로 codesight(구조 맵)·LSP(findReferences)의 grep 대체 이점을 측정한다.

- E1: `f137`의 **모든 호출처**를 찾아 시그니처를 `(x: number)` → `(x: number, y: number)`로 바꾸고 전 호출처를 갱신.
- E2: `index.ts`의 `total` 계산에 기여하는 모듈을 역추적해 의존 그래프 깊이를 보고.
- E3: 임의 심볼 `f42`를 rename하고 영향 범위(참조 파일 수)를 산출.

측정: 동일 태스크를 A~E 하네스로 각 n>=5 → `bench/collect.mjs`로 토큰·$·컨텍스트 점유율 수집.
codesight/LSP 미적용(grep만) carve vs 적용 carve를 같은 fixture로 비교해 절약 수치를 확정한다.
주의: 소형 fixture에선 MCP 고정비용으로 절약이 작거나 역전될 수 있다(추정 금지, 실측 후 기재).
