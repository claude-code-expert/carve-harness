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

// args may arrive as an object or a JSON-encoded string depending on the caller — accept both.
const ARGS = (() => { try { return typeof args === 'string' ? JSON.parse(args) : (args ?? {}) } catch (_e) { return {} } })()
const GLOB = ARGS.goldenset ?? 'specs/goldenset/*.json'
const THRESHOLD = ARGS.threshold ?? 70       // per-case pass line (0..100)
const DELTA = ARGS.delta ?? 3                // regression tolerance vs baseline (points)
const K_MAX = 10                             // per-case run cap (runaway guard)

// <grade-helper> — pure deterministic grader. tests/carve-eval.test.sh extracts & evals THIS block.
// contains/regex + negations; llm-rubric is graded by the evaluator agent, STATE
// types by .claude/hooks/eval-state.sh against the run workdir (환경 상태 채점 —
// 에이전트의 말이 아니라 상태를 믿는다). Fail-closed.
const STATE_TYPES = ['file_exists', 'file_contains', 'cmd_exit0', 'git_diff_contains']
const gradeAssertions = (output, asserts) => {
  const failed = []
  for (const a of asserts || []) {
    if (a.type === 'llm-rubric' || STATE_TYPES.includes(a.type)) continue
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
          setup: { type: 'string' },
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
const PRIOR_SCHEMA = { type: 'object', properties: { runs: { type: 'number' }, lastSuiteScore: { type: ['number', 'null'] }, version: { type: ['string', 'null'] } }, required: ['runs', 'lastSuiteScore'] }
const WORKDIR_SCHEMA = { type: 'object', properties: { dir: { type: 'string' } }, required: ['dir'] }
const STATE_SCHEMA = { type: 'object', properties: { failed: { type: 'array', items: { type: 'string' } } }, required: ['failed'] }

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
  const stateAsserts = (c.assert || []).filter((a) => STATE_TYPES.includes(a.type))
  const needsEnv = stateAsserts.length > 0 || !!c.setup
  const allStateFailed = stateAsserts.map((a) => `${a.type}:${a.value}`)

  // 실행 1회 체인: 격리 workdir(리포 밖 — 골든셋 assert 비노출) → respondent →
  // eval-state.sh 상태 채점(자기 보고 불신) → 정리. env/채점 실패는 fail-closed.
  const runOnce = async (i) => {
    let dir = null
    if (needsEnv) {
      const env = await agent(
        `Bash로 'mktemp -d'를 실행해 새 임시 작업 디렉토리를 만들어라.${c.setup ? ` 이어서 그 디렉토리 안(cd)에서 아래 setup 스크립트를 실행하라:\n\`\`\`bash\n${c.setup}\n\`\`\`` : ''}\n생성된 절대경로를 dir로 반환하라. 실재 결과만 — 지어내지 마라.`,
        { agentType: 'general-purpose', label: `env:${c.id}#${i + 1}`, phase: 'Run', schema: WORKDIR_SCHEMA }
      )
      dir = env?.dir || null
      if (!dir) return { text: '', stateFailed: allStateFailed.length ? allStateFailed : ['env:setup-failed'] }
    }
    const prompt = dir
      ? `작업 디렉토리는 ${dir} 이다. 모든 파일 작업은 그 디렉토리 안에서만 하라. 이 저장소의 specs/ 와 .claude/ 는 읽지 마라(평가 기준 비노출).\n\n${c.prompt}`
      : c.prompt
    const out = await agent(prompt, { agentType: 'general-purpose', label: `run:${c.id}#${i + 1}`, phase: 'Run' })
    let stateFailed = []
    if (stateAsserts.length && dir) {
      const v = await agent(
        `다음을 순서대로 수행하라: (1) 아래 JSON 배열을 임시 파일에 그대로 저장 (2) Bash로 \`bash .claude/hooks/eval-state.sh '${dir}' <저장한 파일 경로>\` 실행 (3) stdout의 JSON을 파싱해 failed 배열을 그대로 반환 (4) \`rm -rf '${dir}'\` 로 작업 디렉토리 정리. 스크립트 출력 외의 판단을 보태거나 지어내지 마라.\n\n${JSON.stringify(stateAsserts)}`,
        { agentType: 'general-purpose', label: `state:${c.id}#${i + 1}`, phase: 'Run', schema: STATE_SCHEMA }
      )
      stateFailed = Array.isArray(v?.failed) ? v.failed : allStateFailed
    } else if (dir) {
      await agent(`Bash로 \`rm -rf '${dir}'\` 를 실행해 임시 작업 디렉토리를 정리하고 done만 반환하라.`,
        { agentType: 'general-purpose', label: `clean:${c.id}#${i + 1}`, phase: 'Run', effort: 'low' })
    }
    return { text: typeof out === 'string' ? out : '', stateFailed }
  }

  // k independent respondent runs — pass@k(능력)와 pass^k(일관성)를 분리 측정하려면 반복이 필요.
  const outputs = await parallel(Array.from({ length: k }, (_, i) => () => runOnce(i)))
  let greens = 0
  const failSamples = []
  for (const r of outputs) {
    const text = r?.text ?? ''
    const det = gradeAssertions(text, c.assert)
    const stateFailed = r ? r.stateFailed : allStateFailed.length ? allStateFailed : ['run:missing']
    let llmOk = true
    for (const a of llmAsserts) {
      const v = await agent(
        `아래 출력이 기준을 충족하는지 판정하라(pass/fail + 이유). 기준: ${a.value}\n\n출력:\n${text}`,
        { agentType: 'evaluator', label: `rubric:${c.id}`, phase: 'Run', schema: RUBRIC_SCHEMA }
      )
      if (!v?.pass) { llmOk = false; break }
    }
    const green = det.passed && stateFailed.length === 0 && llmOk
    if (green) greens += 1
    else if (failSamples.length < 2) {
      failSamples.push([...det.failed, ...stateFailed].join('; ') || 'llm-rubric fail')
    }
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
  `(1) specs/eval-score.json 을 Read로 열어라. 없으면 runs:0, lastSuiteScore:null. 있으면 .runs 배열 길이를 runs로, 마지막 원소의 suiteScore를 lastSuiteScore로. (2) VERSION 파일을 Read로 열어 내용(trim)을 version으로. 없으면 null. 지어내지 마라.`,
  { agentType: 'general-purpose', label: 'read-baseline', phase: 'Score', schema: PRIOR_SCHEMA }
)
const prev = prior?.lastSuiteScore ?? null
const runOrdinal = (prior?.runs ?? 0) + 1
const regressed = prev != null && suiteScore < prev - DELTA
const belowThreshold = graded.filter((r) => r.caseScore < THRESHOLD).map((r) => `${r.id}(${r.caseScore})`)

// 구성 기록 — 같은 골든셋으로 하네스 버전/구성 간 비교하는 축(환경·태스크 고정, 구성만 교체).
const entry = {
  run: runOrdinal, version: prior?.version ?? null, config: ARGS.config ?? null,
  suiteScore, threshold: THRESHOLD, cases: graded,
}
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
