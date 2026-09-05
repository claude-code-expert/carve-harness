# `specs/redteam/` — 가드레일 공격/정상 케이스

`redteam.sh`가 `pretool-guard`에 먹여 exit 코드로 채점하는 셋(LLM 0). "달았다 ≠ 막힌다"를 정기 측정한다(블루프린트 §6.6).

| 파일 | 무엇 |
|---|---|
| `attacks.json` | 위반 유도 34건 — 전부 차단(exit 2) 기대. `knownGap:true`는 문서화된 천장(변수 간접·base64·분할·python 경유·2단계 curl), 현재 통과가 정상 |
| `normal.json` | 정상 요청 19건 — 절대 막으면 안 됨(막히면 false positive) |

- 실제 시크릿 리터럴은 파일에 없다(`secretKind`) — `redteam.sh`가 실행 시점에 조립(가드가 파일 쓰기를 막으므로).
- 실측: 차단율 29/29, 과잉차단 0/19, 천장 5 미차단.

> `bash .claude/hooks/redteam.sh --strict`가 놓친 공격·과잉차단·천장 승격을 exit 1로 잡는다. 리포트: `docs/md/eval/P3-redteam.md`.
