export const meta = {
  name: 'fable-team-pipeline',
  description: 'Fable 5 3-phase team pipeline: spec/research -> parallel build+verify -> docs+diagrams -> final verify',
  whenToUse: 'Multi-module work needing research, 3-5 parallel builders with file ownership, docs, diagrams, and independent verification',
  phases: [
    { title: 'Spec', detail: 'fable-researcher + task decomposition with file ownership' },
    { title: 'Build', detail: 'fable-builder per task in worktree, evaluator verifies each' },
    { title: 'Document', detail: 'fable-doc-writer + fable-visualizer in parallel' },
    { title: 'Verify', detail: 'final SC check by evaluator' },
  ],
}

// args: { goal: string, tasks?: [{id, goal, owns, acceptance}] }
const goal = typeof args === 'string' ? args : args?.goal
if (!goal) throw new Error('args.goal required: {goal: "...", tasks?: [...]}')

const TASKS_SCHEMA = {
  type: 'object',
  properties: {
    tasks: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          goal: { type: 'string' },
          owns: { type: 'array', items: { type: 'string' } },
          acceptance: { type: 'string' },
        },
        required: ['id', 'goal', 'owns', 'acceptance'],
      },
    },
  },
  required: ['tasks'],
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

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    pass: { type: 'boolean' },
    reasons: { type: 'array', items: { type: 'string' } },
  },
  required: ['pass', 'reasons'],
}

// ── Phase 1: Spec ──────────────────────────────────────────
phase('Spec')
const research = await agent(
  `목표: ${goal}\n이 목표 구현에 필요한 사전 리서치를 수행하고 .planning/fable/RESEARCH.md에 기록하라. 핵심 결론·근거·출처를 포함하라.`,
  { agentType: 'fable-researcher', label: 'research', phase: 'Spec' }
)

let tasks = args?.tasks
if (!tasks) {
  const plan = await agent(
    `목표: ${goal}\n리서치 요약:\n${research}\n\n목표를 3~5개의 독립 빌드 태스크로 분해하라. 각 태스크의 owns(glob 패턴)는 서로 겹치면 안 된다. acceptance는 검증 가능한 완료 기준(SC)으로 쓴다.`,
    { label: 'decompose', phase: 'Spec', schema: TASKS_SCHEMA }
  )
  tasks = plan.tasks
}
if (tasks.length > 5) log(`경고: 태스크 ${tasks.length}개 — 권장 상한 5개 초과 (orchestration.md 3절). 전부 실행함.`)

// ── Phase 2: Build (pipeline: 태스크별 빌드 → 즉시 검증) ──
const built = await pipeline(
  tasks,
  (t) => agent(
    `배정 태스크: ${t.goal}\n파일 소유권(owns): ${t.owns.join(', ')} — 이 밖에 쓰기 금지.\n수용 기준: ${t.acceptance}\n리서치: .planning/fable/RESEARCH.md 참고.\n플랜 3~5줄 → 구현 → 테스트 실행 순서로 진행하라.`,
    { agentType: 'fable-builder', label: `build:${t.id}`, phase: 'Build', isolation: 'worktree', schema: BUILD_SCHEMA }
  ),
  (result, t) => {
    if (!result || result.status !== 'done') return { task: t.id, ...result, verdict: null }
    return agent(
      `태스크 "${t.goal}"의 산출물을 수용 기준 "${t.acceptance}" 대비 검증하라. 변경 파일: ${result.changedFiles.join(', ')}. 테스트 결과: ${result.testResult}`,
      { agentType: 'evaluator', label: `verify:${t.id}`, phase: 'Build', schema: VERDICT_SCHEMA }
    ).then((v) => ({ task: t.id, ...result, verdict: v }))
  }
)

const escalations = built.filter(Boolean).filter((b) => b.status === 'escalated')
const passed = built.filter(Boolean).filter((b) => b.verdict?.pass)
log(`빌드 ${tasks.length}건 중 검증 통과 ${passed.length}건, 에스컬레이션 ${escalations.length}건`)

// ── Phase 3: Document (barrier 정당 — 문서·다이어그램은 전체 빌드 결과 필요) ──
phase('Document')
const buildSummary = passed.map((b) => `- ${b.task}: ${b.changedFiles.join(', ')}`).join('\n')
const [docs, visuals] = await parallel([
  () => agent(
    `목표 "${goal}" 구현이 완료됐다. 변경 요약:\n${buildSummary}\n실제 코드를 읽고 docs/에 문서를 작성/갱신하라.`,
    { agentType: 'fable-doc-writer', label: 'docs', phase: 'Document' }
  ),
  () => agent(
    `목표 "${goal}" 구현 결과의 아키텍처/흐름 다이어그램을 제작하라. 변경 요약:\n${buildSummary}\n실제 코드에서 확인한 구조만 그린다.`,
    { agentType: 'fable-visualizer', label: 'diagrams', phase: 'Document' }
  ),
])

// ── Phase 4: Verify ────────────────────────────────────────
phase('Verify')
const finalVerdict = await agent(
  `목표 "${goal}" 전체 산출물을 최종 검증하라. 태스크별 수용 기준:\n${tasks.map((t) => `- ${t.id}: ${t.acceptance}`).join('\n')}\n통합 관점에서 계약 위반·미달 항목을 찾아라.`,
  { agentType: 'evaluator', label: 'final-verify', phase: 'Verify', schema: VERDICT_SCHEMA }
)

return {
  goal,
  tasks: tasks.length,
  passed: passed.map((b) => b.task),
  escalations,
  docs,
  visuals,
  finalVerdict,
}
