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

const SCORE_SCHEMA = {
  type: 'object',
  properties: {
    score: { type: 'number' },                          // 0~100, 코드 대조 채점
    gaps: { type: 'array', items: { type: 'string' } }, // <threshold일 때 무엇을 어떻게 고칠지
    evidence: { type: 'string' },                       // 파일:라인 · 테스트 결과 원문
  },
  required: ['score', 'gaps', 'evidence'],
}

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
    id: it.id, claim: it.claim, acceptance: it.acceptance, owns: it.owns,
    score: it.score, pass: it.pass, gaps: it.gaps, evidence: it.evidence, attempts: it.attempts,
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
    `목표: ${goal}\n리서치 요약:\n${research}\n\n목표를 3~7개의 독립 체크리스트 항목으로 분해하라. 각 항목:\n- claim: "구현했다"고 주장할 단위(구체 기능/엔드포인트/규칙 하나).\n- acceptance: 코드+테스트로 검증 가능한 완료 기준(SC).\n- owns: 담당 파일 glob. 항목끼리 겹치면 안 된다(파일 오너 1개).`,
    { label: 'decompose', phase: 'Spec', schema: CHECKLIST_SCHEMA }
  )
  decomposed = plan.items
}

// 작업 상태를 담은 항목 객체(항목마다 독립 → pipeline 병렬 변이 안전).
const items = decomposed.map((t) => ({
  id: t.id, claim: t.claim, acceptance: t.acceptance, owns: t.owns,
  attempts: 0, score: null, pass: false, gaps: [], evidence: '', lastBuild: null,
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
      `체크리스트 항목을 채점 모드로 평가하라.\nclaim: ${it.claim}\nacceptance(SC): ${it.acceptance}\n변경 파일: ${build.changedFiles.join(', ')}\n빌더 테스트 보고: ${build.testResult}\n\n실제 코드를 열고 테스트를 실행해 claim이 acceptance를 충족하는지 대조하고 0~100으로 채점하라. 주장만 믿지 마라. ${THRESHOLD} 미만이면 gaps에 "무엇을 어떻게 고쳐야 넘는지" 구체적으로 써라.`,
      { agentType: 'evaluator', label: `score:${it.id}#${it.attempts}`, phase: 'Score', schema: SCORE_SCHEMA }
    ).then((v) => {
      it.score = v?.score ?? 0
      it.gaps = v?.gaps ?? []
      it.evidence = v?.evidence ?? ''
      it.pass = it.score >= THRESHOLD
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
