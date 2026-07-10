# Fable 팀 가이드 — 오케스트레이터 에이전트 팀 호출법

> `docs/md/orchestration.md`의 규칙을 Fable 5의 개발 절차로 구체화한 팀.
> **핵심 원칙: 이 프로세스는 모델에 의존하지 않는다.** Fable 5가 아니어도(opus/sonnet 세션)
> 아래 SOP를 따르면 동일하게 동작한다. Fable은 이 프로세스를 "기본 반사"로 수행할 뿐이다.

---

## 1. 팀 구성

오케스트레이터는 **별도 에이전트가 아니라 메인 세션**이다
(orchestration.md 3절: 서브에이전트는 자기 서브에이전트를 못 띄운다 → 만능 오케스트레이터 에이전트는 안티패턴).

| 역할 | 에이전트 | 모델 | 파일 소유권 | 담당 |
| --- | --- | --- | --- | --- |
| 지휘·분해·종합 | (메인 세션) | fable/opus · high | tasks.json, 공유 계약 | Phase 설계, 승인 게이트, 결과 종합 |
| 개발 | `fable-builder` | sonnet | 배정된 `owns` glob | 구현 + 테스트, worktree 격리 |
| 문서 | `fable-doc-writer` | sonnet | `docs/**`, `*.md` | README·가이드·API 문서 |
| 이미지 | `fable-visualizer` | sonnet | `docs/img/**`, `*.puml`, `*.svg` | 다이어그램·목업 (시각 게이트 준수) |
| 리서치 | `fable-researcher` | sonnet | `.planning/**`, `docs/research/**` | 조사·근거·RESEARCH.md |
| 검증 | `evaluator` (기존 재사용) | sonnet | 없음 (read-only) | SC 대비 통과/불통과 판정 |

파일 하나에 오너 하나 — 소유권 glob이 겹치면 배정 자체가 잘못된 것이다.

---

## 2. Fable 5 개발 절차 → 프로세스 매핑

Fable 5의 차별점과, 그것을 도구/규칙으로 재현하는 방법:

| Fable 5 차별점 | 프로세스로 재현 |
| --- | --- |
| 위임 우선 (파일 덤프 대신 결론만 수신) | 탐색·리뷰는 항상 서브에이전트에 위임, 메인 컨텍스트는 종합만 |
| 조율 로직을 코드가 보유 | `fable-team-pipeline` 워크플로 — 분기·루프·fan-out이 스크립트에 고정 |
| 배리어 없는 파이프라인 | `pipeline()`: 태스크 A 검증 중에 태스크 B 빌드 진행 |
| 구조화 출력 | `schema` 옵션 — 빌더 보고가 검증된 JSON으로 강제됨 |
| 파일 충돌 격리 | `isolation: worktree` — 병렬 빌더가 서로 못 밟음 |
| 생성/검증 분리 | 빌더 완료 즉시 `evaluator`(read-only)가 SC 판정 |
| 지속 대화 | `SendMessage`로 이미 띄운 에이전트에 컨텍스트 유지한 채 후속 지시 |
| 백그라운드 실행 | `run_in_background` / 완료 시 알림 수신 |
| 토큰 예산 | 발화에 `+500k` 지시 → 워크플로 `budget`으로 깊이 자동 조절 |

**4-Phase 흐름** (워크플로가 자동 실행):

```
P1 Spec      fable-researcher 리서치 → 태스크 3~5개 분해 (owns·acceptance 필수)
P2 Build     태스크별 fable-builder(worktree) → 완료 즉시 evaluator 검증  [파이프라인]
P3 Document  fable-doc-writer + fable-visualizer 병렬                     [배리어: 전체 빌드 결과 필요]
P4 Verify    evaluator 최종 SC 판정 → {passed, escalations, finalVerdict} 반환
```

---

## 3. 호출 방법 (발화 및 사용법)

### 3.1 개별 에이전트 (서브에이전트로 단건 위임)

| 발화 예 | 라우팅 |
| --- | --- |
| "fable-researcher로 Next.js 16 캐시 정책 조사해줘" | Agent(subagent_type: fable-researcher) |
| "fable-builder한테 src/api 구현 맡겨줘" | Agent(fable-builder, isolation: worktree) |
| "fable-doc-writer로 이번 변경 문서화해줘" | Agent(fable-doc-writer) |
| "fable-visualizer로 인증 흐름 다이어그램 그려줘" | Agent(fable-visualizer) |
| "아까 그 리서처한테 이어서 물어봐줘: ~" | SendMessage (컨텍스트 유지 후속 지시) |
| "백그라운드로 돌려놓고 다른 것 하자" | run_in_background: true |

### 3.2 팀 파이프라인 (Workflow — 권장 진입점)

워크플로는 **옵트인**이다. 아래 중 하나로 명시해야 실행된다:

- 발화에 **`ultracode`** 키워드 포함
- **"워크플로우로 돌려줘"** / "run a workflow" 등 직접 요청
- 저장된 워크플로 이름 지정: **"fable-team-pipeline 실행해줘"**

발화 예:

```
"fable-team-pipeline으로 '주문 취소 API + 문서 + 흐름도' 돌려줘"
"ultracode: 결제 모듈 리팩터링, 태스크는 네가 분해해"
"+300k 예산으로 fable-team-pipeline 실행. goal은 ~"
```

인자 형식 (태스크를 직접 지정할 때):

```json
{
  "goal": "주문 취소 API 구현",
  "tasks": [
    { "id": "api",  "goal": "src/api/cancel 구현",  "owns": ["src/api/**"],  "acceptance": "테스트 통과 + api-spec 준수" },
    { "id": "docs", "goal": "취소 정책 문서",        "owns": ["docs/**"],     "acceptance": "docs/cancel.md 존재 + 실코드 예시" }
  ]
}
```

`tasks` 생략 시 P1에서 리서치 기반으로 자동 분해한다(3~5개, owns 비중복 강제).

### 3.3 Agent Teams (워커 간 상호 대화가 필요할 때)

패턴 선택 기준(orchestration.md 2절 Q2): **발견 공유·상호 반박이 필요할 때만** Teams. 보고만 받으면 서브에이전트로 충분하다.

```bash
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude
```

발화 예:

```
"fable-builder 2명 + fable-doc-writer로 팀 만들어서 진행해.
 빌더끼리 API 계약 어긋나면 서로 지적하게 하고, 나한테는 합의된 결과만 보고해."
```

### 3.4 패턴 선택 요약

| 상황 | 발화 → 패턴 |
| --- | --- |
| 단건 조사/리뷰/구현 | "fable-X로 ~해줘" → 서브에이전트 |
| 다단계 전체 (스펙→구현→문서→그림→검증) | "fable-team-pipeline 실행" → Workflow |
| 워커 간 합의 필요 | Teams env + "팀 만들어서" → Agent Teams |
| 서로 무관한 작업 여러 개 | "백그라운드로" → 백그라운드 세션 |

---

## 4. Fable 없이 재현하기 — 모델 무관 SOP

Fable 5가 아닌 세션(opus/sonnet)이나 훅 없는 다른 에이전트(Cursor·Codex 등)에서도
아래 절차를 **그대로 수동 실행**하면 동일 프로세스가 된다. 권위는 도구가 아니라 이 절차에 있다.

**모델 라우팅 (Fable 부재 시):**

| 역할 | 대체 모델 |
| --- | --- |
| 오케스트레이터(메인 세션) | opus · high |
| 워커 4종 | sonnet (frontmatter에 이미 고정 — 세션 모델과 무관) |
| 기계적 변환·포맷 | haiku |

**오케스트레이터 SOP (매 작업, 순서 고정):**

```
S0. 3단 질문 (orchestration.md 2절) — 단일 세션으로 충분하면 여기서 끝.
S1. Spec 먼저: fable-researcher 위임 → 공유 계약·tasks.json 작성 → 사용자 플랜 승인.
S2. 소유권 검사: 태스크별 owns glob 비중복 확인. 겹치면 재분해.
S3. Build: 태스크당 fable-builder 1개, worktree 격리, 동시 3~5개 상한.
    - Workflow 사용 가능 → fable-team-pipeline 호출 (조율을 코드에 위임)
    - Workflow 불가(타 에이전트) → tasks.json의 status 필드를 손으로 갱신하며 순차/병렬 실행
S4. 즉시 검증: 빌더 완료마다 evaluator(read-only)에 SC 판정 위임. 통과분만 수신.
S5. Document: 빌드 확정 후 doc-writer + visualizer 병렬. 실코드 근거 강제.
S6. 종료 기준: 동일 오류 3회 교착 → [ESCALATION] 후 중단. 예산 85% → 일시정지 보고.
S7. 회고: REFLECTION.md 1건 기록. AGENTS.md 직접 수정 금지(사람 승인 병합).
```

**불변 규칙 (모델·도구 무관):**
- 에이전트 간 통신은 항상 파일 기반 (tasks.json, RESEARCH.md, 공유 계약 문서).
- 생성자와 검증자는 절대 동일 에이전트가 아니다.
- 완료 선언은 SC 충족 증거(테스트 원문 포함)로만.
- 피처 브랜치에서만. 커밋·푸시는 명시 요청 시에만.

---

## 참고
- 규칙 원본: `docs/md/orchestration.md`
- 에이전트 정의: `.claude/agents/fable-*.md`
- 워크플로: `.claude/workflows/fable-team-pipeline.js`
