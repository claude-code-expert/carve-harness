# bench — carve-harness 정량 평가 하니스

기준: `docs/guide/carve-harness-benchmark-criteria.md` (6축). 원칙: 추정 금지, 실측 후 기재, n>=5 중앙값·IQR.

## 구조
```
bench/
├── run.mjs          # 결정론적 자기측정 (축 2·3·5·6 + 1·4 프록시) — node bench/run.mjs
├── run.sh           # 오케스트레이터: 자기측정 + 축2 비교 + 트리거 측정 + 라이브 안내
├── test-trigger.sh  # 트리거 정확도 결정적 하니스 (축 3) — routing.tsv·no-route.txt 전수
├── collect.mjs      # 라이브 수집 파서 (ccusage 토큰·$ / /context 점유율) — 순수, 라이브 호출 안 함
├── gen-fixture.mjs  # 대형 코드베이스 fixture 생성기 (축 1 토큰효율 무대) — 결정적
├── seeds/           # danger·safe·secret-bad·secret-safe·routing(정상)·no-route(오발화)
├── labels/          # config-accuracy.json (구성 정확도 정답 라벨)
├── tasksets/        # crud·multi·refactor·explore (라이브 비교용 태스크)
├── harnesses/       # A~E 셋업 가이드
├── results/         # <harness>.json (라이브 측정 결과 — 사용자 생성)
└── report.mjs       # results → 스코어카드(중앙값·축 1·3·4·5 열) — node bench/report.mjs [dir]
```

## 실행
```bash
node bench/run.mjs        # 자기측정 점수 (결정론, 즉시)
bash bench/test-trigger.sh # 트리거 정확도/오발화 (결정론, jq 필요)
bash bench/run.sh         # 위 전부 + 축2 비교 + 라이브 절차 안내
node bench/report.mjs     # 라이브 결과 합산(데이터 있을 때)
```

## results/<harness>.json 스키마
```jsonc
{ "harness": "carve",
  "tokensPerTask": [..], "costPerTask": [..],   // 축 1 (collect.mjs ccusage)
  "triggerAccuracy": [..], "contextOccupancy": [..], // 축 3·4 (옵셔널)
  "e2ePass": [..], "blockLeak": [..] }          // 축 5·2
```
수집: `npx ccusage@latest --json | node bench/collect.mjs ccusage`, `<\"/context\" 출력> | node bench/collect.mjs context`.

## 측정 구분
- **자기측정(즉시)**: 축 2 제어/안전·3 라우팅·5 기능·6 구성 — 결정론적, 재현 가능.
- **결정적 비교(즉시)**: 축 2 carve(누출 0%) vs no-harness(누출 100%) + 축 3 트리거(`test-trigger.sh`).
- **라이브 비교(보류)**: 축 1 효율·4 컨텍스트 점유율 + cross-harness 5 — LLM·API·타 하네스 셋업 필요.
  대형 fixture(`gen-fixture.mjs`) 위에서 `harnesses/`·`tasksets/explore` 실행 → `collect.mjs` 수집 →
  `results/`에 기록 → `report.mjs`. 측정 전 "X배" 주장 금지(criteria §10).
