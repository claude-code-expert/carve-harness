export const meta = {
  name: 'carve-verify-loop',
  description: 'Spec->checklist->build->score(0-100)->rebuild loop until every item >=95, then final verify',
  whenToUse: 'When you need every claimed implementation graded item-by-item against real code, with automatic rework of anything scoring under the threshold until all pass',
  phases: [
    { title: 'Spec', detail: 'research + decompose goal into a scored checklist (claim/acceptance/owns)' },
    { title: 'Build', detail: 'fable-builder implements each checklist item in a worktree' },
    { title: 'Score', detail: 'evaluator grades each item 0-100 against the real code' },
    { title: 'Loop', detail: 'items under threshold get their gaps fed back and rebuilt, then re-scored' },
    { title: 'Verify', detail: 'final integrated SC verdict once every item >= threshold' },
  ],
}

// args: { goal: string, tasks?: [{id, claim, acceptance, owns}], threshold?: number }
const goal = typeof args === 'string' ? args : args?.goal
if (!goal) throw new Error('args.goal required: {goal: "...", tasks?: [...], threshold?: 95}')

const THRESHOLD = args?.threshold ?? 95   // pass = score >= THRESHOLD
const MAX_ITERATIONS = 8                    // outer loop backstop (orchestration.md 5절)
const MAX_ATTEMPTS = 3                      // per-item stall guard -> escalate (orchestration.md 1절)

const CHECKLIST_SCHEMA = {
  type: 'object',
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          claim: { type: 'string' },        // "구현했다"고 주장하는 단위
          acceptance: { type: 'string' },   // 검증 가능한 완료 기준(SC)
          owns: { type: 'array', items: { type: 'string' } },
          type: { enum: ['convention', 'correctness', 'domain_safety'] },   // 선택 — domain_safety 는 100점 필수(GATE-C7)
        },
        required: ['id', 'claim', 'acceptance', 'owns'],
      },
    },
  },
  required: ['items'],
}

const BUILD_SCHEMA = {
  type: 'object',
  properties: {
    status: { enum: ['done', 'escalated', 'failed'] },
    changedFiles: { type: 'array', items: { type: 'string' } },
    testResult: { type: 'string' },
    escalation: { type: 'string' },
  },
  required: ['status', 'changedFiles', 'testResult'],
}

// 5축 루브릭(합 100). 단일 불투명 점수 대신 축별 배점 — 감사 가능 + 정책 인코딩.
// **test 축은 채점자가 신고하지 않는다.** 실행 결과(tests)를 받아 여기서 파생시킨다 —
// 숫자를 직접 받으면 "테스트 미실행이면 test=0" 은 산문일 뿐이고, 채점자가 25를 써넣으면
// 그만이었다. 실행 사실을 구조로 요구해야 배점이 거짓 완료를 막는다.
const SCORE_SCHEMA = {
  type: 'object',
  properties: {
    axes: {
      type: 'object',
      properties: {
        exists:     { type: 'number' }, // 0~25 실제 구현 존재(스텁·TODO면 0)
        match:      { type: 'number' }, // 0~25 코드가 claim과 의미적으로 일치
        contract:   { type: 'number' }, // 0~15 타입·에러·입력검증·인가 경계 안전
        no_regress: { type: 'number' }, // 0~10 기존 통과 항목·기능 퇴행 없음
      },
      required: ['exists', 'match', 'contract', 'no_regress'],
    },
    // test 축의 유일한 입력. ran=false 거나 실행 건수 0이면 test=0 → 합 ≤75 < 95.
    tests: {
      type: 'object',
      properties: {
        ran:    { type: 'boolean' }, // verify 명령을 실제로 실행했는가
        passed: { type: 'number' },
        failed: { type: 'number' },
        command: { type: 'string' }, // 실행한 명령 원문
        output:  { type: 'string' }, // 실행 출력 원문(요약 금지) — 근거를 기계가 읽을 자리
      },
      required: ['ran', 'passed', 'failed', 'command', 'output'],
    },
    gaps: { type: 'array', items: { type: 'string' } }, // <threshold일 때 무엇을 어떻게 고칠지
    evidence: { type: 'string' },                       // 파일:라인 · 테스트 결과 원문
  },
  required: ['axes', 'tests', 'gaps', 'evidence'],
}

// <score-helper> — 항목 점수 = 5축 합(0~100). 축 결측→0(누락은 감점), 각 축 0..max 클램프.
// tests/eval-score.test.sh가 이 블록을 추출해 **그대로 실행**한다 — 테스트가 로직을
// 재구현하면 여기서 클램프를 지워도 초록으로 남는다(실제로 그런 위장 상태였다).
// 클램프 규칙은 checklist-gate.sh GATE-C8 의 jq `cl()` 과 같아야 한다 — 워크플로 경로와
// 수동 경로가 같은 checklist.json 을 두고 다른 판정을 내면 안 된다.
const AXIS_MAX = { exists: 25, match: 25, test: 25, contract: 15, no_regress: 10 }
const scoreFromAxes = (axes) => {
  if (!axes || typeof axes !== 'object') return 0
  let sum = 0
  for (const [k, max] of Object.entries(AXIS_MAX)) {
    sum += Math.max(0, Math.min(Number(axes[k]) || 0, max))
  }
  return sum
}
// test 축은 신고값이 아니라 실행 결과에서 파생된다. 돌리지 않았으면(ran !== true) 0이고,
// 나머지 네 축을 만점 받아도 합은 75 — 임계 95를 산술적으로 넘을 수 없다. 게이트에
// "테스트를 돌렸는지 확인하라"는 규칙을 더하는 대신 배점 구조가 강제한다.
const testAxis = (t) => {
  if (!t || typeof t !== 'object' || t.ran !== true) return 0
  const passed = Math.max(0, Number(t.passed) || 0)
  const failed = Math.max(0, Number(t.failed) || 0)
  if (passed + failed === 0) return 0   // "돌렸다"는 주장만 있고 수집된 테스트가 없다
  return Math.round(AXIS_MAX.test * (passed / (passed + failed)))
}
// 채점자가 준 4축 + 파생된 test 축 → checklist.json 에 실릴 5축. GATE-C8 이 이 합을 재계산한다.
const axesWithTest = (axes, tests) => ({ ...(axes || {}), test: testAxis(tests) })
// </score-helper>

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    pass: { type: 'boolean' },
    reasons: { type: 'array', items: { type: 'string' } },
  },
  required: ['pass', 'reasons'],
}

// checklist.json으로 직렬화(Stop 게이트가 읽는 스키마와 동일).
const toChecklist = (items, iteration) => JSON.stringify({
  goal, iteration, threshold: THRESHOLD,
  items: items.map((it) => ({
    id: it.id, claim: it.claim, acceptance: it.acceptance, owns: it.owns, type: it.type ?? undefined,
    score: it.score, axes: it.axes, pass: it.pass, gaps: it.gaps, evidence: it.evidence, attempts: it.attempts,
    // 실행 근거는 남기되 output 원문은 빼고 싣는다 — 게이트가 매 Stop 마다 읽는 파일이라
    // 출력 전문이 들어가면 부풀고, 원문은 evidence 가 인용한다.
    tests: it.tests ? { ran: it.tests.ran, passed: it.tests.passed, failed: it.tests.failed, command: it.tests.command } : undefined,
  })),
}, null, 2)

// 단일 writer로 specs/checklist.json 갱신(파일 오너 1개 — 레이스 방지).
const persist = (items, iteration) => agent(
  `specs/checklist.json 파일에 아래 JSON을 그대로(내용 변형·요약 금지) 덮어써라. 파일이 없으면 생성한다. 완료 후 파일 경로만 보고하라.\n\n${toChecklist(items, iteration)}`,
  { agentType: 'general-purpose', label: `persist:iter${iteration}`, phase: 'Score' }
)

// ── Phase 1: Spec / Checklist ──────────────────────────────
phase('Spec')
const research = await agent(
  `목표: ${goal}\n이 목표 구현에 필요한 사전 리서치를 수행하고 .planning/fable/RESEARCH.md에 기록하라. 핵심 결론·근거·출처를 포함하라.`,
  { agentType: 'fable-researcher', label: 'research', phase: 'Spec' }
)

let decomposed = args?.tasks
if (!decomposed) {
  const plan = await agent(
    `목표: ${goal}\n리서치 요약:\n${research}\n\n목표를 3~7개의 독립 체크리스트 항목으로 분해하라. 각 항목:\n- claim: "구현했다"고 주장할 단위(구체 기능/엔드포인트/규칙 하나).\n- acceptance: 코드+테스트로 검증 가능한 완료 기준(SC).\n- owns: 담당 파일 glob. 항목끼리 겹치면 안 된다(파일 오너 1개).\n- type(선택): convention | correctness | domain_safety. CLAUDE.md 의 도메인 규칙(불변식)을 구현·보호하는 항목은 반드시 domain_safety — 그 항목은 95가 아니라 100점이어야 게이트를 통과한다.\n\n**중요(격리 제약):** 각 항목은 격리된 worktree에서 빌드·채점되어 다른 항목의 파일을 볼 수 없다. 상호의존 파일(구현 + 그 테스트, 모듈 + 그 마이그레이션 등)은 반드시 같은 항목의 owns에 함께 둔다. 항목의 acceptance는 그 항목 owns 안의 파일만으로 검증 가능해야 한다. 구현과 테스트를 별개 항목으로 쪼개지 마라 — 테스트 항목이 구현 파일을 못 봐 영구 미달이 된다.`,
    { label: 'decompose', phase: 'Spec', schema: CHECKLIST_SCHEMA }
  )
  decomposed = plan.items
}

// 작업 상태를 담은 항목 객체(항목마다 독립 → pipeline 병렬 변이 안전).
const items = decomposed.map((t) => ({
  id: t.id, claim: t.claim, acceptance: t.acceptance, owns: t.owns, type: t.type ?? null,
  attempts: 0, score: null, axes: null, tests: null, pass: false, gaps: [], evidence: '', lastBuild: null,
}))
await persist(items, 0)
log(`체크리스트 ${items.length}개 항목 (임계 ${THRESHOLD}점, 항목 재시도 상한 ${MAX_ATTEMPTS})`)

// 한 항목의 build -> score 1회. attempts 증가, 결과를 항목에 반영.
const buildAndScore = (it, iteration) => {
  const isRework = it.attempts > 0
  const buildPrompt = isRework
    ? `재작업(반성 프롬프트). 항목 "${it.claim}"은 직전 채점 ${it.score}점으로 임계 ${THRESHOLD} 미달이다.\n미해결 gap:\n${it.gaps.map((g) => `- ${g}`).join('\n')}\n\n먼저 스스로 물어라: 무엇이 실패했나? 어떤 구체적 변경이 ${THRESHOLD}점을 넘기나? 같은 접근을 반복하고 있지 않나?\n그다음 gap만 외과적으로 수정하고 테스트를 다시 실행하라. 파일 소유권(owns): ${it.owns.join(', ')} 밖 쓰기 금지.`
    : `배정 항목: ${it.claim}\n수용 기준: ${it.acceptance}\n파일 소유권(owns): ${it.owns.join(', ')} — 이 밖에 쓰기 금지.\n리서치: .planning/fable/RESEARCH.md 참고.\n플랜 3~5줄 → 구현 → 테스트 실행 순서로 진행하라.`

  return agent(buildPrompt, {
    agentType: 'fable-builder', label: `build:${it.id}#${it.attempts + 1}`,
    phase: 'Build', isolation: 'worktree', schema: BUILD_SCHEMA,
  }).then((build) => {
    it.attempts += 1
    it.lastBuild = build
    if (!build || build.status === 'escalated' || build.status === 'failed') {
      it.gaps = [build?.escalation || `빌드 ${build?.status || 'null'} — 진행 불가`]
      it.evidence = build?.testResult || ''
      return it
    }
    return agent(
      `체크리스트 항목을 채점 모드로 평가하라.\nclaim: ${it.claim}\nacceptance(SC): ${it.acceptance}\n변경 파일: ${build.changedFiles.join(', ')}\n빌더 테스트 보고: ${build.testResult}\n\n실제 코드를 열고 **테스트를 직접 실행**해 채점하라(주장·빌더 보고만 믿지 마라).\n\n네가 채점할 축은 네 개다:\n- exists(0~25): 실제 구현 존재 — 스텁·TODO·미구현이면 0\n- match(0~25): 코드가 claim과 의미적으로 일치\n- contract(0~15): 타입·에러 처리·입력 검증·인가 경계 안전\n- no_regress(0~10): 기존 통과 기능 퇴행 없음\n\n**test 축(0~25)은 네가 점수를 매기지 않는다.** 대신 verify 명령을 Bash로 직접 실행하고 그 결과를 tests에 보고하라: ran(실행 여부)·passed·failed·command(실행한 명령)·output(출력 원문, 요약 금지). 점수는 이 값에서 파생된다 — 실행하지 않았으면(ran=false) test=0이고 나머지를 만점 받아도 합이 75라 임계를 넘지 못한다. 명령 성공 ≠ 결과 정확이니 실패·스킵·미수집을 구분해서 세라.\n\n합(=항목점수)이 ${THRESHOLD} 미만이면 gaps에 "무엇을 어떻게 고쳐야 넘는지"를 빌더가 바로 실행 가능하게 구체적으로 써라.`,
      { agentType: 'evaluator', label: `score:${it.id}#${it.attempts}`, phase: 'Score', schema: SCORE_SCHEMA }
    ).then((v) => {
      it.tests = v?.tests ?? null
      it.axes = axesWithTest(v?.axes, v?.tests)   // test 축은 파생 — 채점자 신고값을 받지 않는다
      it.score = scoreFromAxes(it.axes)
      it.gaps = v?.gaps ?? []
      it.evidence = v?.evidence ?? ''
      it.pass = it.type === 'domain_safety' ? it.score >= 100 : it.score >= THRESHOLD   // GATE-C7 와 동일 규칙
      return it
    })
  })
}

// ── Phase 2~4: Build / Score / Loop ────────────────────────
let iteration = 0
while (iteration < MAX_ITERATIONS) {
  const unresolved = items.filter((it) => !it.pass && it.attempts < MAX_ATTEMPTS)
  if (unresolved.length === 0) break
  iteration += 1
  phase(iteration === 1 ? 'Build' : 'Loop')
  log(`라운드 ${iteration}: 미달 ${unresolved.length}개 build+score`)

  // 미달 항목만 재작업(전수 아님, 외과적). 항목 독립 → pipeline 병렬.
  await pipeline(unresolved, (it) => buildAndScore(it, iteration))
  await persist(items, iteration)

  const stillPending = items.filter((it) => !it.pass)
  const stalled = stillPending.filter((it) => it.attempts >= MAX_ATTEMPTS)
  log(`라운드 ${iteration} 후: 통과 ${items.filter((i) => i.pass).length}/${items.length}, 교착 ${stalled.length}`)
}

const passed = items.filter((it) => it.pass)
const failed = items.filter((it) => !it.pass)   // 교착(3회)·빌드실패로 임계 미달
if (failed.length > 0) {
  log(`[ESCALATION] ${failed.length}개 항목이 ${MAX_ATTEMPTS}회 재작업에도 ${THRESHOLD}점 미달: ${failed.map((f) => `${f.id}(${f.score ?? 'null'})`).join(', ')}. 사람 판단 필요.`)
}

// ── Phase 5: Final integrated verify ───────────────────────
phase('Verify')
const buildSummary = passed.map((b) => `- ${b.id}: ${(b.lastBuild?.changedFiles || []).join(', ')}`).join('\n')
const finalVerdict = await agent(
  `목표 "${goal}" 전체 산출물을 최종 검증하라. 항목별 수용 기준:\n${items.map((t) => `- ${t.id}: ${t.acceptance} (현재 ${t.score ?? 'null'}점)`).join('\n')}\n통과 항목 변경 요약:\n${buildSummary}\n통합 관점(항목 간 계약 위반·회귀·미달)을 점검하라.`,
  { agentType: 'evaluator', label: 'final-verify', phase: 'Verify', schema: VERDICT_SCHEMA }
)

return {
  goal,
  threshold: THRESHOLD,
  iterations: iteration,
  total: items.length,
  passed: passed.map((b) => ({ id: b.id, score: b.score })),
  failed: failed.map((b) => ({ id: b.id, score: b.score, gaps: b.gaps })),
  allPassed: failed.length === 0,
  finalVerdict,
}
