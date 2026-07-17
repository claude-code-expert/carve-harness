export const meta = {
  name: 'spec-conformance-loop',
  description: 'Spec-conformance scoring loop: build -> exhaustive checklist -> 2-lens score (min) -> 95 gate -> feed deficiencies back until every item passes',
  whenToUse: 'A clear spec with many implementation claims that must be proven item-by-item against real code+tests, converging a develop<->verify loop automatically. Contract: .claude/rules/conformance.md',
  phases: [
    { title: 'Spec', detail: 'decompose goal into owned tasks' },
    { title: 'Build', detail: 'fable-builder implements (generator)' },
    { title: 'Checklist', detail: 'spec-checklist enumerates claims (spec x diff)' },
    { title: 'Score', detail: 'conformance-scorer 2 lenses, per-item min' },
    { title: 'Gate', detail: 'all >= threshold? persist SCORE.json, loop or done' },
  ],
}

// args: { goal, slug, threshold?, tasks?: [{id, goal, owns, acceptance}] }
const goal = typeof args === 'string' ? args : args?.goal
if (!goal) throw new Error('args.goal required: {goal, slug, threshold?, tasks?}')
const slug = args?.slug || 'conformance'
const threshold = args?.threshold || 95
const MAX_ITER = 8   // contract §5

const TASKS_SCHEMA = {
  type: 'object',
  properties: {
    tasks: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' }, goal: { type: 'string' },
          owns: { type: 'array', items: { type: 'string' } },
          acceptance: { type: 'string' },
        },
        required: ['id', 'goal', 'owns', 'acceptance'],
      },
    },
  },
  required: ['tasks'],
}
const CHECKLIST_SCHEMA = {
  type: 'object',
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' }, claim: { type: 'string' },
          targets: { type: 'array', items: { type: 'string' } },
          acceptance: { type: 'string' }, verify: { type: 'string' },
        },
        required: ['id', 'claim', 'targets', 'acceptance', 'verify'],
      },
    },
  },
  required: ['items'],
}
const LENS_SCHEMA = {
  type: 'object',
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' }, score: { type: 'number' },
          deficiencies: { type: 'array', items: { type: 'string' } },
        },
        required: ['id', 'score', 'deficiencies'],
      },
    },
  },
  required: ['items'],
}

// ── Phase 1: Spec — decompose into owned tasks ────────────────
phase('Spec')
let tasks = args?.tasks
if (!tasks) {
  const plan = await agent(
    `목표: ${goal}\n이 목표를 3~5개의 독립 빌드 태스크로 분해하라. 각 태스크 owns(glob)는 서로 겹치면 안 되고, acceptance는 검증 가능한 완료기준(SC)으로 쓴다.`,
    { label: 'decompose', phase: 'Spec', schema: TASKS_SCHEMA }
  )
  tasks = plan.tasks
}

let iteration = 0
let feedback = null          // deficiencies from the previous round
let lastSignature = null     // stall detection: identical failing set
let stall = 0
let done = false
let merged = []

while (iteration < MAX_ITER && !done) {
  iteration++

  // ── Phase 2: Build (generator) ──────────────────────────────
  phase('Build')
  if (iteration === 1) {
    // First pass: parallel builders with non-overlapping file ownership.
    await parallel(tasks.map((t) => () => agent(
      `배정 태스크: ${t.goal}\n파일 소유권(owns): ${t.owns.join(', ')} — 이 밖에 쓰기 금지.\n수용 기준: ${t.acceptance}\n플랜 3~5줄 → 구현 → 테스트 작성/실행 순서로 진행하라.`,
      { agentType: 'fable-builder', label: `build:${t.id}`, phase: 'Build', isolation: 'worktree' }
    )))
  } else {
    // ponytail: retries fix reported deficiencies in the main tree, not per-task
    // worktrees — the failing set spans items, not owns partitions.
    await agent(
      `아래 정합성 미진사항을 수정하라. 목표: ${goal}\n미진사항(항목별):\n${feedback}\n각 항목의 지적을 코드+테스트로 해소하되, 이미 통과한 항목을 퇴행시키지 마라.`,
      { agentType: 'fable-builder', label: `fix:iter${iteration}`, phase: 'Build' }
    )
  }

  // ── Phase 3: Checklist — exhaustive claim enumeration ───────
  phase('Checklist')
  const checklist = await agent(
    `.claude/skills/spec-checklist/SKILL.md 의 SOP를 따르라. 목표: ${goal}\n스펙의 완료기준(SC)과 실제 git diff를 교차해 "구현 주장" 요소를 전수 열거하라(누락·허위 동시 포착). 각 항목에 id·claim·targets(실제 경로)·acceptance·verify(실행 가능한 명령)를 채운다.`,
    { label: 'checklist', phase: 'Checklist', schema: CHECKLIST_SCHEMA }
  )
  const items = checklist.items
  const itemsBrief = items.map((i) => `- ${i.id}: ${i.claim} | targets=${i.targets.join(',')} | verify=${i.verify}`).join('\n')

  // ── Phase 4: Score — 2 independent lenses, per-item min ─────
  phase('Score')
  const lensPrompt = (lens, how) =>
    `너는 conformance-scorer의 "${lens}" 렌즈다(read-only, 코드 수정 금지). 아래 CHECKLIST 항목마다 0~100점을 매겨라.\n${how}\n5축 배점: exists25/match25/test25/contract15/no-regress10. 증거(파일:라인·테스트 원문) 없는 가점 금지. 이 렌즈 점수만 반환하라(min 결합은 상위에서 한다). 각 항목에 id·score·deficiencies(미진사항).\n\nCHECKLIST(slug=${slug}):\n${itemsBrief}`
  const [codeMatch, testPass] = await parallel([
    () => agent(lensPrompt('code-match', 'verify 실행 없이 코드·타입·계약을 정적 대조한다(파일 읽기·grep). test축은 테스트 코드의 실재·형태로만 판단.'),
      { agentType: 'conformance-scorer', label: 'lens:code-match', phase: 'Score', schema: LENS_SCHEMA }),
    () => agent(lensPrompt('test-pass', '각 항목의 verify 명령을 실제 실행해 test축을 원문 근거로 채점하고, 실행 관찰로 exists/match를 교차 확인한다.'),
      { agentType: 'conformance-scorer', label: 'lens:test-pass', phase: 'Score', schema: LENS_SCHEMA }),
  ])

  // Deterministic min in code — a lens cannot inflate the item past the other.
  const byId = (r, id) => (r?.items || []).find((x) => x.id === id)
  merged = items.map((it) => {
    const a = byId(codeMatch, it.id)
    const b = byId(testPass, it.id)
    const sa = typeof a?.score === 'number' ? a.score : 0   // missing lens result → 0 (fail-closed)
    const sb = typeof b?.score === 'number' ? b.score : 0
    const score = Math.min(sa, sb)
    const deficiencies = [...(a?.deficiencies || []), ...(b?.deficiencies || [])]
    return { id: it.id, claim: it.claim, score, pass: score >= threshold, deficiencies }
  })

  // ── Phase 5: Gate ───────────────────────────────────────────
  phase('Gate')
  const failing = merged.filter((m) => !m.pass)
  done = failing.length === 0 && merged.length > 0
  log(`iter ${iteration}: ${merged.length - failing.length}/${merged.length} pass (threshold ${threshold})`)

  // Persist SCORE.json (active=!done) + EVAL-<n>.md via one writer. active stays
  // true while items fail so conformance-gate.sh blocks a premature "done".
  const score = {
    slug, active: !done, threshold, iteration,
    items: merged.map((m) => ({ id: m.id, score: m.score, pass: m.pass, deficiencies: m.deficiencies })),
  }
  await agent(
    `specs/${slug}/SCORE.json 에 아래 JSON을 그대로 써라(디렉토리 없으면 생성):\n\n${JSON.stringify(score, null, 2)}\n\n그리고 specs/${slug}/EVAL-${iteration}.md 에 항목별 점수·미진사항을 사람이 읽는 근거로 요약하라. 코드는 수정하지 마라.`,
    { label: `persist:iter${iteration}`, phase: 'Gate' }
  )

  if (done) break

  // Stall guard: identical failing set 3 rounds → escalate (contract §5).
  const signature = failing.map((f) => f.id).sort().join(',')
  stall = signature === lastSignature ? stall + 1 : 0
  lastSignature = signature
  if (stall >= 2) {   // 0-indexed: 3rd identical round
    log(`[ESCALATION] 동일 미달 항목 [${signature}] 3회 교착 — 중단. 임의 판단 진행 금지.`)
    break
  }
  feedback = failing.map((f) => `- ${f.id} (${f.claim}) [${f.score}점]: ${f.deficiencies.join('; ') || '근거 부족'}`).join('\n')
}

return {
  slug, goal, threshold, iterations: iteration, done,
  passed: merged.filter((m) => m.pass).map((m) => m.id),
  remaining: merged.filter((m) => !m.pass).map((m) => ({ id: m.id, score: m.score, deficiencies: m.deficiencies })),
  note: done
    ? 'DONE — 전 항목 통과, SCORE.json active=false (게이트 해제).'
    : iteration >= MAX_ITER
      ? `MAX_ITER(${MAX_ITER}) 도달 — 미달 항목 잔존, SCORE.json active=true (게이트 유지).`
      : '동일 오류 교착으로 중단(ESCALATION) — SCORE.json active=true.',
}
