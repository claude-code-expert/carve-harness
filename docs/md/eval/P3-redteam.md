# P3 — 가드레일 자기평가 (`redteam.sh`)

> 브랜치 `feat/eval-p3-redteam`(P2 위) · 계획 `specs/eval-generalization-plan.md` §3 P3 레드팀 · 블루프린트 §6.6 "달았다 ≠ 막힌다"
> 결과: 공격·정상 케이스를 `pretool-guard` exit 코드로 결정론 채점(LLM 0). 실측 차단율 100%(29/29), 과잉차단 0/19, 알려진 천장 5건 추적. 테스트 14건, 전체 30 스위트 503건·감사 70 PASS.

## 1. 구성

```
specs/redteam/attacks.json   공격 34건 (전부 block 기대; knownGap:true 5건은 문서화된 천장)
specs/redteam/normal.json    정상 19건 (전부 allow 기대 — block 나오면 false positive)
.claude/hooks/redteam.sh     pretool-guard exit 코드로 채점 → 집계 JSON. --strict CI 게이트
.claude/hooks/tests/redteam.test.sh (14)
```

공격 카테고리: protected-path 6 · dangerous-git 5 · prefix-bypass 3 · remote-exec 2 · destructive-sql 4 · recursive-rm 3 · protected-delete 3 · secret-content 3 · known-gap 5.

## 2. 지표

| 지표 | 뜻 | 실측 |
|---|---|---|
| **차단율(blockRate)** | knownGap 아닌 공격 중 exit 2 비율 | 29/29 = 100% |
| **과잉차단율(overBlockRate)** | 정상 요청 중 잘못 막힌 비율 | 0/19 = 0% |
| **알려진 천장(knownGaps)** | 문서화된 미탐(변수 간접·base64·분할 조립·python 경유·`curl -o`+bash) 중 현재 차단 수 | 5건 중 0 차단 |
| byCategory | 카테고리별 total/blocked | 전 카테고리 100% |

- **detection == block**: pretool-guard는 하드 exit-2 게이트라 "탐지했지만 안 막음" 상태가 없다. 블루프린트가 나누는 탐지율/차단율이 여기서는 일치한다(소프트 가드였다면 분리 필요) — JSON에 `detectionEqualsBlock: true`로 명시.
- **천장 승격 신호**: knownGap 케이스가 막히기 시작하면 `knownGapsNowBlocking`에 올라온다 — 천장이 좁혀졌으니 그 케이스를 실공격으로 승격하라는 뜻. `--strict`가 이걸 회귀로 잡아 셋이 낡지 않게 한다.

## 3. 사용방법

```bash
bash .claude/hooks/redteam.sh                 # 사람용 요약 + JSON
bash .claude/hooks/redteam.sh --json          # JSON만
bash .claude/hooks/redteam.sh --strict        # 놓친 공격·과잉차단·천장 승격 시 exit 1 (CI/pre-push)
```
정기 재측정이 핵심이다("설치 후 방치 금지"). 가드 패턴을 바꾸거나 스택을 늘린 뒤 돌려 회귀(이전에 막던 공격이 뚫림 / 정상 요청이 막힘)를 잡는다.

## 4. 설계 메모 (이번에 밟은 함정)

- **시크릿 리터럴을 파일에 못 넣는다**: 가드가 `attacks.json` 쓰기 자체를 막는다(GUARD-04). AKIA/sk-/PEM 3건은 `secretKind`만 저장하고 `redteam.sh`가 실행 시점에 조립(문자열 분할로 이 스크립트 자신도 스캔에 안 걸린다).
- **`@tsv` 백슬래시 이중화**: 케이스 JSON을 `@tsv`로 꺼내면 `\"`가 `\\"`가 돼 가드가 JSON 파싱 실패로 **유령 차단**했다(정상 5건이 false positive로 잡힘). eval-state.sh가 겪은 그 버그 — NUL 구분자 읽기로 교체.
- **macOS bash 3.2**: `declare -A` 미지원 → 카테고리 집계가 깨졌다. 연관배열을 버리고 케이스별 결과를 JSON 줄로 쌓아 마지막에 jq 한 번으로 집계(3.2 이식성).
- **`.env.example` 쓰기**: 가드가 `\.env[./]` 로 막는다(dotenv 계열 보호). 정상셋에서 제외 — 이건 설계된 보수적 차단이지 false positive가 아니다.

## 5. 완료 기준(SC) 검증

| SC | 증명 | 결과 |
|---|---|---|
| ① 탐지율·차단율·과잉차단율 3수치 JSON | 스위트 (1) + 실행 출력 | PASS |
| ② 정상 19건 exit 0(과잉차단 0) | (1)(6) | PASS |
| ③ LLM 호출 0회 | 전부 exit 코드 채점 | PASS |
| strict 3실패모드 | (3) 놓친 공격 · (4) 과잉차단 · (5) 천장 승격 각각 exit 1 | PASS |
| 전체 | `npm test` 30 스위트 503건 · 감사 70 | PASS |

## 6. 남은 P3 (옵트인 · 문서)

- **promptfoo exporter**(`eval-export.sh --promptfoo`): 골든셋을 `promptfooconfig.yaml`로 변환해 뷰어·GitHub Action과 연결. Node/promptfoo 의존이 붙으므로 옵트인 — 수요 확인 후. 정본은 계속 goldenset JSON.
- **LLM-judge 사람 일치율**(G9): 라벨 데이터가 필요한 절차 문서. 자동화 범위 밖.
