# P0 — 추이 파일 무결성 (`eval-trend.sh`)

> 브랜치 `feat/eval-p0-trend` · 계획 `specs/eval-generalization-plan.md` §3 P0
> 결과: `specs/eval-score.json` 읽기·append를 결정론 스크립트로 이관. 변조된 추이엔 append 거부. 테스트 15건, 전체 27 스위트 434건·감사 68 PASS.

## 1. 구성

```
.claude/hooks/eval-trend.sh          read | append <entry.json> [--file PATH]
.claude/hooks/tests/eval-trend.test.sh   15건
.claude/workflows/carve-eval.js      read-baseline · persist-trend 에이전트 → 스크립트 릴레이(effort: low)
```

| 명령 | 동작 |
|---|---|
| `read` | `{runs, lastSuiteScore, version, lastCaseVersions[{id,caseVersion,caseScore}]}` — 워크플로의 `PRIOR_SCHEMA` 그대로. 파일 없음 → runs 0. 파싱 실패 → exit 1 |
| `append ENTRY.json` | 엔트리를 다음 run으로 추가. **run 서수 = 기존 길이+1, `version` = VERSION 파일** — 호출자가 적은 값은 무시. `prevHash` = 이전 `.runs` 정규화 JSON(sorted keys, compact)의 sha256. append 전에 마지막 run의 `prevHash`가 그 앞 run들과 맞는지 검사 → 불일치면 `trend tampered` exit 1, 파일 무변경. 쓰기는 tmp+mv |

## 2. 왜

`carve-eval.js`가 추이 파일 읽기·쓰기를 LLM 에이전트에 맡겼다. 이번 패치에서 그 에이전트가 다른 워크스페이스의 파일로 덮어써 run 1이 사라지고 version이 `0.6.0`으로 오기록됐다(블루프린트 R5 "증거는 파일", R10 "채점기부터 의심"). 스크립트가 서수·버전·해시 체인을 강제하면 에이전트는 JSON을 옮기는 릴레이로 격하되고, 조용한 덮어쓰기는 다음 append에서 exit 1로 드러난다.

## 3. 사용방법

```bash
bash .claude/hooks/eval-trend.sh read                       # baseline 요약
bash .claude/hooks/eval-trend.sh append /tmp/entry.json     # /eval 이 내부적으로 호출
bash .claude/hooks/eval-trend.sh read --file other.json     # 다른 추이 파일(모델·구성 비교용)
```

사람이 추이를 정정해야 할 때(오기록 등): 손으로 고치고 `specs/DECISIONS.md`에 기록한다. 고친 뒤 첫 append는 마지막 run의 `prevHash`가 있으면 그 앞 run들의 변조를 잡으므로, **마지막 run 이전을 고쳤다면** 그 run의 `prevHash`를 지우거나 `--file`로 새 추이를 시작해야 한다(의도된 마찰).

## 4. 완료 기준(SC) 검증

| SC | 증명 | 결과 |
|---|---|---|
| ① 기존 run 1바이트 변조 후 append → exit 1, 파일 무변경 | (5) | PASS |
| ② append가 VERSION을 파일에서 읽어 기록(에이전트 입력 무시) | (2) 호출자 `run:999, version:9.9.9` → 저장은 1 / 1.2.3 | PASS |
| ③ run 서수 = length+1 | (2)(3)(8) | PASS |
| ④ `read`가 PRIOR_SCHEMA 필드를 그대로 출력 | (1)(4) | PASS |
| ⑤ 스위트 26→27 green | `npm test` 434건 | PASS |
| 워크플로 | `carve-eval.js` 두 에이전트 호출을 스크립트 릴레이로 교체, AsyncFunction 래핑 구문 검사 통과 | PASS |

## 5. 한계

- 해시 체인은 "마지막 append 이후 이전 run이 바뀌었는가"만 잡는다. 마지막 run 자체를 고치고 `prevHash`까지 맞춰 쓰면 못 잡는다(로컬 파일이라 위조 방지가 아니라 실수 방지가 목적).
- 릴레이 에이전트가 엔트리 JSON을 임시 파일에 쓰는 단계는 여전히 LLM 손을 거친다 — 서수·버전은 스크립트가 덮지만 케이스 점수 자체를 바꾸면 못 잡는다. P1a(target 어댑터·assert별 결과 파일 보존)에서 채점 산출물을 스크립트가 직접 만들면 이 구간도 사라진다.
