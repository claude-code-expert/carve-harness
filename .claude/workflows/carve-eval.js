export const meta = {
  name: 'carve-eval',
  description: 'Golden-set quantitative eval: run fixed (prompt->rubric) cases k times, score pass@k/pass^k, append a score trend, flag regression vs baseline',
  whenToUse: 'When you have a golden set of eval cases (specs/goldenset/*.json) and want a repeatable quantitative quality score tracked over time, with regression detection when a prompt/rubric/harness component changes',
  phases: [
    { title: 'Load', detail: 'read specs/goldenset/*.json into cases (via Read agent — workflow has no fs)' },
    { title: 'Run', detail: 'each case: respondent x k, grade deterministic asserts + llm-rubric' },
    { title: 'Score', detail: 'aggregate suite score, compare baseline, persist trend, flag regression' },
  ],
}

const GLOB = args?.goldenset ?? 'specs/goldenset/*.json'
const THRESHOLD = args?.threshold ?? 70      // per-case pass line (0..100)
const DELTA = args?.delta ?? 3               // regression tolerance vs baseline (points)
const K_MAX = 10                             // per-case run cap (runaway guard)

// <grade-helper> — pure deterministic grader. tests/carve-eval.test.sh extracts & evals THIS block.
// contains/regex + negations; llm-rubric is graded separately by the evaluator agent. Fail-closed.
const gradeAssertions = (output, asserts) => {
  const failed = []
  for (const a of asserts || []) {
    if (a.type === 'llm-rubric') continue
    const val = String(a.value ?? '')
    let ok
    try {
      switch (a.type) {
        case 'contains':     ok = output.includes(val); break
        case 'not_contains': ok = !output.includes(val); break
        case 'regex':        ok = new RegExp(val).test(output); break
        case 'not_regex':    ok = !new RegExp(val).test(output); break
        default:             ok = false            // unknown assert type = fail-closed
      }
    } catch (_e) { ok = false }                    // invalid regex = fail-closed
    if (!ok) failed.push(`${a.type}:${val}`)
  }
  return { passed: failed.length === 0, failed }
}
// </grade-helper>

const GOLDENSET_SCHEMA = {
  type: 'object',
  properties: {
    cases: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          suite: { type: 'string' },
          id: { type: 'string' },
          prompt: { type: 'string' },
          k: { type: 'number' },
          assert: {
            type: 'array',
            items: {
              type: 'object',
              properties: { type: { type: 'string' }, value: { type: 'string' } },
              required: ['type', 'value'],
            },
          },
        },
        required: ['id', 'prompt', 'assert'],
      },
    },
  },
  required: ['cases'],
}
const RUBRIC_SCHEMA = { type: 'object', properties: { pass: { type: 'boolean' }, reason: { type: 'string' } }, required: ['pass', 'reason'] }
const PRIOR_SCHEMA = { type: 'object', properties: { runs: { type: 'number' }, lastSuiteScore: { type: ['number', 'null'] } }, required: ['runs', 'lastSuiteScore'] }

// ── Phase 1: Load golden set (workflow has no fs → Read via agent) ──
phase('Load')
const loaded = await agent(
  `${GLOB} 파일들을 Read로 열어 JSON을 파싱하고, 모든 케이스를 하나의 배열로 병합해 반환하라. 각 케이스: {suite, id, prompt, k, assert:[{type,value}]}. 파일이 하나도 없으면 cases:[] 로 반환하라. 파일에 실재하는 내용만 — 지어내지 마라.`,
  { agentType: 'general-purpose', label: 'load-goldenset', phase: 'Load', schema: GOLDENSET_SCHEMA }
)
const cases = (loaded?.cases ?? []).filter((c) => c && c.prompt && c.id)
if (cases.length === 0) {
  log('골든셋 케이스 0개 — specs/goldenset/*.json 를 먼저 작성하라 (eval-goldenset 스킬 참고).')
  return { suiteScore: null, cases: [], note: 'empty goldenset' }
}
log(`골든셋 ${cases.length}개 케이스 로드 (케이스 임계 ${THRESHOLD}, 회귀 허용 ${DELTA}pt)`)

// ── Phase 2: Run each case k times, grade (deterministic + llm-rubric) ──
phase('Run')
const runCase = async (c) => {
  const k = Math.max(1, Math.min(Number(c.k) || 1, K_MAX))
  const llmAsserts = (c.assert || []).filter((a) => a.type === 'llm-rubric')
  // k independent respondent runs — pass@k(능력)와 pass^k(일관성)를 분리 측정하려면 반복이 필요.
  const outputs = await parallel(
    Array.from({ length: k }, (_, i) => () =>
      agent(c.prompt, { agentType: 'general-purpose', label: `run:${c.id}#${i + 1}`, phase: 'Run' })
    )
  )
  let greens = 0
  const failSamples = []
  for (const out of outputs) {
    const text = typeof out === 'string' ? out : ''
    const det = gradeAssertions(text, c.assert)
    let llmOk = true
    for (const a of llmAsserts) {
      const v = await agent(
        `아래 출력이 기준을 충족하는지 판정하라(pass/fail + 이유). 기준: ${a.value}\n\n출력:\n${text}`,
        { agentType: 'evaluator', label: `rubric:${c.id}`, phase: 'Run', schema: RUBRIC_SCHEMA }
      )
      if (!v?.pass) { llmOk = false; break }
    }
    const green = det.passed && llmOk
    if (green) greens += 1
    else if (failSamples.length < 2) failSamples.push(det.failed.join('; ') || 'llm-rubric fail')
  }
  const caseScore = Math.round((greens / k) * 100)   // 일관성률(green/k)
  return {
    suite: c.suite || 'default', id: c.id, k, greens,
    pass_at_k: greens >= 1, pass_pow_k: greens === k,
    caseScore, failed: failSamples,
  }
}
const graded = (await pipeline(cases, runCase)).filter(Boolean)

// ── Phase 3: Aggregate, baseline compare, persist trend ──
phase('Score')
const suiteScore = graded.length
  ? Math.round(graded.reduce((s, r) => s + r.caseScore, 0) / graded.length)
  : 0

// 직전 baseline 읽기(없으면 runs:0). 워크플로는 Date 사용 불가 → run 서수는 기존 엔트리 수 +1.
const prior = await agent(
  `specs/eval-score.json 을 Read로 열어라. 없으면 {"runs":0,"lastSuiteScore":null}. 있으면 .runs 배열 길이를 runs로, 마지막 원소의 suiteScore를 lastSuiteScore로 반환하라. 지어내지 마라.`,
  { agentType: 'general-purpose', label: 'read-baseline', phase: 'Score', schema: PRIOR_SCHEMA }
)
const prev = prior?.lastSuiteScore ?? null
const runOrdinal = (prior?.runs ?? 0) + 1
const regressed = prev != null && suiteScore < prev - DELTA
const belowThreshold = graded.filter((r) => r.caseScore < THRESHOLD).map((r) => `${r.id}(${r.caseScore})`)

const entry = { run: runOrdinal, suiteScore, threshold: THRESHOLD, cases: graded }
await agent(
  `specs/eval-score.json 을 갱신하라. 없으면 {"runs":[]} 로 생성. 기존 .runs 배열 끝에 아래 원소를 append 하라(기존 원소 변형·삭제 금지). 저장 후 경로만 보고하라.\n\n${JSON.stringify(entry, null, 2)}`,
  { agentType: 'general-purpose', label: `persist-trend#${runOrdinal}`, phase: 'Score' }
)

log(`suite ${suiteScore}/100 (run #${runOrdinal}${prev != null ? `, baseline ${prev}` : ', baseline 없음'}) — ${regressed ? '⚠ 회귀' : 'OK'}`)
if (regressed) log(`[REGRESSION] suite ${prev}→${suiteScore} (>${DELTA}pt 하락). 임계 미달: ${belowThreshold.join(', ') || '없음'}`)

return {
  suiteScore, threshold: THRESHOLD, run: runOrdinal, baseline: prev,
  regressed, belowThreshold,
  passAtK: graded.filter((r) => r.pass_at_k).length,
  passPowK: graded.filter((r) => r.pass_pow_k).length,
  total: graded.length,
  cases: graded,
}
