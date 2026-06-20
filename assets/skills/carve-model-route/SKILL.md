---
name: model-route
description: >
  작업→모델 3-Tier 라우팅. 작업 성격에 맞는 모델(Haiku/Sonnet/Opus)을 골라 비용·품질을 최적화한다.
  "모델 라우팅", "model route", "어떤 모델 쓸까" 요청에 사용.
---
# model-route — 작업→모델 라우팅

> 되는 가장 싼 모델을 쓴다. 기본 Sonnet, 조건부 Opus 승급.

| 작업 | 모델 |
|------|------|
| 탐색·검색·단순 편집·문서 | Haiku |
| 다중 파일 구현(기본) | Sonnet |
| 복잡한 아키텍처·보안·복잡 디버깅 | Opus |
| PR 리뷰 | Sonnet |

Opus 승급 조건: 첫 시도 실패 · 5개 이상 파일 · 아키텍처 결정 · 보안. 의식적으로 라우팅한다.
