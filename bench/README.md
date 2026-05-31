# bench — carve-harness 정량 평가 하니스

기준: `docs/guide/carve-harness-benchmark-criteria.md` (6축). 원칙: 추정 금지, 실측 후 기재, n>=5 중앙값·IQR.

## 구조
```
bench/
├── run.mjs      # 결정론적 자기측정 (축 2·3·5·6 + 1·4 프록시) — node bench/run.mjs
├── run.sh       # 오케스트레이터: 자기측정 + 축2 carve↔no-harness 결정적 비교 + 라이브 안내
├── seeds/       # danger·safe·secret-bad·secret-safe·routing (위험/안전/트리거 시드)
├── labels/      # config-accuracy.json (구성 정확도 정답 라벨)
├── tasksets/    # crud·multi·refactor (라이브 비교용 태스크)
├── harnesses/   # A~E 셋업 가이드
├── results/     # <harness>.json (라이브 측정 결과 — 사용자 생성)
└── report.mjs   # results → 스코어카드(중앙값) — node bench/report.mjs
```

## 실행
```bash
node bench/run.mjs    # 자기측정 점수 (결정론, 즉시)
bash bench/run.sh     # 위 + 축2 비교 + 라이브 절차 안내
node bench/report.mjs # 라이브 결과 합산(데이터 있을 때)
```

## 측정 구분
- **자기측정(즉시)**: 축 2 제어/안전·3 라우팅·5 기능·6 구성 — 결정론적, 재현 가능.
- **결정적 비교(즉시)**: 축 2 carve(누출 0%) vs no-harness(누출 100%) — 훅 유무로 결정됨.
- **라이브 비교(보류)**: 축 1 효율·4 컨텍스트 + cross-harness 3·5 — LLM·API·타 하네스 셋업 필요.
  `harnesses/`·`tasksets/` 따라 실행 후 `results/`에 기록 → `report.mjs`. 측정 전 "X배" 주장 금지.
