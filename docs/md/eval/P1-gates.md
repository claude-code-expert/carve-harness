# P1 — 게이트 확장: `required` 태그 · `suspicious` · `stale`

> 브랜치 `feat/eval-p1-gates`(P1a 위) · 계획 `specs/eval-generalization-plan.md` §3 P1 게이트 확장 · 블루프린트 §6.5 관문 ①, §6.7, R8
> 결과: `eval-gate.sh` 판정 5종(unable → stale → suspicious → regressed → ok). 골든셋 `tags`. CI 워크플로가 PR 변경 목록을 넘겨 stale 판정. 테스트 18건, 기존 `eval-init` 20건 무수정 green.

## 1. 구성

| 요소 | 변경 |
|---|---|
| `eval-gate.sh` | `--changed LIST`(콤마/개행 구분 경로) 추가. 판정: `stale`(프롬프트 파일 변경 + 추이 미갱신) · `suspicious`(최근 run 케이스 ≥3건 전부 0 또는 전부 100) · `regressed`에 **required 케이스 미green** 조건 추가. JSON에 `changed[]`·`extreme`·`requiredFailed[]` |
| 골든셋 스키마 | 케이스 `tags: ["required", "category:<이름>"]`(선택). `carve-validate`가 형식 검증, required 0건이면 NOTE(`--strict`면 ERROR) |
| `carve-eval.js` | `tags`를 로드해 추이 엔트리 케이스에 기록(게이트가 추이만 읽으므로), `[REQUIRED FAIL]` 로그, 반환 `requiredFailed` |
| `specs/goldenset/harness-guard.json` | 5건 `required` + `category:domain_safety` (version 불변 — 재는 내용은 같다) |
| `.github/workflows/eval-gate.yml` + 템플릿 | 트리거 경로에 `CLAUDE.md`·`AGENTS.md`·`.claude/**`. PR이면 `git diff --name-only base...HEAD`를 `--changed`로 전달 |
| `tests/eval-gate.test.sh` (18) | required 거부권·untagged 하위호환·all-zero/all-full·2건 예외·stale 5경로·순서·라이브 추이 |

프롬프트 파일 정의(`PROMPT_RE`): `CLAUDE.md` · `AGENTS.md` · `.claude/**` · `specs/goldenset/**` · `prompts/**`. 이 중 하나가 PR에서 바뀌고 `specs/eval-score.json`이 같은 PR에 없으면 **측정 안 된 변경**이다.

## 2. 사용방법

```bash
bash .claude/hooks/eval-gate.sh --mode report                                   # 로컬: 판정만
bash .claude/hooks/eval-gate.sh --mode block --changed "$(git diff --name-only origin/develop...HEAD | tr '\n' ',')"
bash .claude/hooks/carve-validate.sh --strict                                   # required 0건이면 ERROR (CI용)
jq '.cases[] | select(.tags | index("required")) | .id' specs/goldenset/*.json  # 어떤 케이스가 거부권을 갖나
```
CI(`eval-gate.yml`)는 report 모드로 배선돼 있다 — 판정은 Step Summary에 보이고 잡은 안 실패한다. 차단은 `/eval-init` Q7에서 block을 고르거나 `MODE: block`으로 바꾼다.

## 3. 완료 기준(SC) 검증

| SC | 증명 | 결과 |
|---|---|---|
| ① required 케이스 caseScore 하락 → 평균 무관 `regressed` | (1): 평균 80→95 상승인데 required 50 → regressed, block exit 1, `requiredFailed:["a"]` | PASS |
| ② 전 케이스 0 또는 100 → `suspicious`(block exit 1) | (2): all-zero·all-full block 1 / report 0; 2건은 예외; 혼합은 ok | PASS |
| ③ `--changed`에 CLAUDE.md 있고 추이 미갱신 → `stale` | (3): 5경로 + 순서(stale > required) | PASS |
| ④ 기존 `eval-init` 스위트 green 유지 | 20/20 무수정 | PASS |
| 회귀 | `npm test` 29 스위트 487건 · 감사 69 | PASS |

## 4. 발견·수정

- `emit`의 기본 인자 `"${3:-{\}}"`가 bash 파라미터 확장에서 `}`를 먼저 닫아 JSON이 깨졌다(초기 구현 버그, 기존 unable 경로 3건이 잡아냄). `[ -n ] || extra='{}'`로 교체.
- required 0건 메시지를 WARN이 아니라 NOTE로: WARN은 요약 카운트에 들어가 태그를 안 쓰는 프로젝트의 `--red`까지 소음이 된다. 강제는 `--strict`로.

## 5. 한계

- `suspicious`는 케이스 ≥3건일 때만. 소형 골든셋은 극단 점수를 경보하지 않는다.
- `stale`은 `--changed`를 넘길 때만 — 로컬 실행에서는 호출자가 목록을 만든다(위 예시).
- required 판정은 caseScore < 100 기준. k=1이면 한 번 실패 = 차단, k=3이면 세 번 다 green이어야 한다(의도: required는 일관성까지 요구).
