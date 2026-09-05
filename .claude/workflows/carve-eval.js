export const meta = {
  name: 'carve-eval',
  description: 'Golden-set quantitative eval: run fixed (prompt->rubric) cases k times, score pass@k/pass^k, append a score trend, flag regression vs baseline',
  whenToUse: 'When you have a golden set of eval cases (specs/goldenset/*.json) and want a repeatable quantitative quality score tracked over time, with regression detection when a prompt/rubric/harness component changes',
  phases: [
    { title: 'Validate', detail: 'carve-validate.sh preflight — 설정 오류를 비싼 런 전에 분리(에이전트 0회)' },
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
          file: { type: 'string' },
          version: { type: 'string' },
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
const PRIOR_SCHEMA = {
  type: 'object',
  properties: {
    runs: { type: 'number' },
    lastSuiteScore: { type: ['number', 'null'] },
    version: { type: ['string', 'null'] },
    lastCaseVersions: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          caseVersion: { type: ['string', 'null'] },
          caseScore: { type: ['number', 'null'] },
        },
        required: ['id'],
      },
    },
  },
  required: ['runs', 'lastSuiteScore'],
}
const WORKDIR_SCHEMA = {
  type: 'object',
  properties: { dir: { type: 'string' }, setupExit: { type: 'number' } },
  required: ['dir'],
}
const STATE_SCHEMA = { type: 'object', properties: { failed: { type: 'array', items: { type: 'string' } } }, required: ['failed'] }
const VALIDATE_SCHEMA = {
  type: 'object',
  properties: { exitCode: { type: 'number' }, output: { type: 'string' } },
  required: ['exitCode', 'output'],
}

// ── Phase 0: Preflight — separate "골든셋이 깨졌다" from "에이전트가 못했다" ──
// 채점기는 전부 fail-closed라 assert 타입 오타 하나가 조용히 0점이 된다. 검증은
// 에이전트 0회이므로 k×N 런을 태우기 전에 항상 먼저 돌린다.
phase('Validate')
const preflight = await agent(
  `Bash로 \`bash .claude/hooks/carve-validate.sh ${GLOB}\` 를 실행하고, 종료코드를 exitCode에, stdout 전문을 output에 담아 반환하라. 판단을 보태거나 지어내지 마라.`,
  { agentType: 'general-purpose', label: 'preflight', phase: 'Validate', effort: 'low', schema: VALIDATE_SCHEMA }
)
if (!preflight || preflight.exitCode !== 0) {
  log(`[PREFLIGHT FAIL] 골든셋 설정 오류 — 런을 시작하지 않는다(비용 보호).\n${preflight?.output ?? 'validator 실행 실패'}`)
  return { suiteScore: null, cases: [], preflight: preflight?.output ?? 'validator 실행 실패', note: 'preflight failed' }
}

// ── Phase 1: Load golden set (workflow has no fs → Read via agent) ──
phase('Load')
const loaded = await agent(
  `${GLOB} 파일들을 Read로 열어 JSON을 파싱하고, 모든 케이스를 하나의 배열로 병합해 반환하라. 각 케이스: {suite, id, file, version, prompt, setup, k, assert:[{type,value}]}. file은 그 케이스가 정의된 파일의 리포 기준 상대경로다(상태 채점기가 원본에서 직접 읽는다). version은 케이스 정의의 버전 문자열이며 그대로 옮겨라. 파일이 하나도 없으면 cases:[] 로 반환하라. 파일에 실재하는 내용만 — 지어내지 마라.`,
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
      // CARVE_SRC = 하네스 소스 경로. setup이 훅을 복사해 픽스처를 세우는 케이스가
      // 이걸 참조한다. 안 넣어주면 골든셋의 하드코딩 절대경로 폴백으로 떨어져
      // 작성자 머신에서만 픽스처가 세워진다. carve-validate --red도 같은 값을 쓴다.
      const env = await agent(
        `Bash로 'mktemp -d'를 실행해 새 임시 작업 디렉토리를 만들어라.${c.setup ? ` 이어서 그 디렉토리 안(cd)에서 아래 setup 스크립트를 실행하고, 그 스크립트의 종료코드를 setupExit로 보고하라(성공 0). 실패해도 고치려 들지 말고 코드를 그대로 보고하라 — 실패 자체가 결과다:\n\`\`\`bash\nexport CARVE_SRC="\${CARVE_SRC:-\$CLAUDE_PROJECT_DIR}"\n${c.setup}\n\`\`\`` : ''}\n생성된 절대경로를 dir로 반환하라. 실재 결과만 — 지어내지 마라.`,
        { agentType: 'general-purpose', label: `env:${c.id}#${i + 1}`, phase: 'Run', schema: WORKDIR_SCHEMA }
      )
      dir = env?.dir || null
      // setup 실패를 그냥 두면 픽스처 없는 워크디렉토리에서 assert가 우수수 실패해
      // "에이전트가 못했다"로 위장된다. 원인을 원인으로 보고한다.
      if (!dir) return { text: '', stateFailed: ['env:mktemp-failed'] }
      if (c.setup && env?.setupExit !== 0) {
        // 워크디렉토리는 일부러 지우지 않는다 — setup이 왜 깨졌는지 볼 수 있어야 한다.
        return { text: '', stateFailed: [`env:setup-failed(exit ${env?.setupExit ?? '?'}) at ${dir}`] }
      }
    }
    const prompt = dir
      ? `작업 디렉토리는 ${dir} 이다. 모든 파일 작업은 그 디렉토리 안에서만 하라. 이 저장소의 specs/ 와 .claude/ 는 읽지 마라(평가 기준 비노출).\n\n${c.prompt}`
      : c.prompt
    const out = await agent(prompt, { agentType: 'general-purpose', label: `run:${c.id}#${i + 1}`, phase: 'Run' })
    let stateFailed = []
    if (stateAsserts.length && dir) {
      // assert 값을 프롬프트로 릴레이하지 않는다 — LLM을 한 번 경유할 때마다 JSON 재직렬화로
      // 백슬래시가 두 배가 되어(`\+`→`\\+`) 정규식이 영구 미매칭된다. 채점기가 원본 파일에서
      // 직접 읽게 하고, 여기서는 파일 경로와 id만 넘긴다.
      if (!c.file) {
        stateFailed = allStateFailed.length ? allStateFailed : ['state:file-unknown']
      } else {
        const v = await agent(
          `다음을 순서대로 수행하라: (1) Bash로 \`bash .claude/hooks/eval-state.sh '${dir}' '${c.file}' --case '${c.id}'\` 실행 (2) stdout의 JSON을 파싱해 failed 배열을 그대로 반환 (3) \`rm -rf '${dir}'\` 로 작업 디렉토리 정리. 스크립트 출력 외의 판단을 보태거나 지어내지 마라.`,
          { agentType: 'general-purpose', label: `state:${c.id}#${i + 1}`, phase: 'Run', schema: STATE_SCHEMA }
        )
        stateFailed = Array.isArray(v?.failed) ? v.failed : allStateFailed
      }
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
  // caseVersion — 케이스 정의가 바뀌면 과거 run과 같은 문제를 푼 점수가 아니다.
  // 이 값 없이 점수만 쌓으면 추이 비교가 조용히 무의미해진다.
  return {
    suite: c.suite || 'default', id: c.id, caseVersion: c.version ?? null, k, greens,
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

// 직전 baseline — 추이 파일은 LLM이 아니라 eval-trend.sh 가 읽는다. 에이전트가 JSON을 직접
// 파싱·재구성하게 두면 다른 워크스페이스 파일로 덮어쓰거나 version을 지어낸다(실제 발생, DECISIONS
// 2026-09-06). 에이전트는 스크립트 stdout을 그대로 옮기는 릴레이만 한다.
const prior = await agent(
  `Bash로 \`bash .claude/hooks/eval-trend.sh read\` 를 실행하고 stdout의 JSON 객체를 그대로 반환하라. 파일을 직접 열거나 값을 보태지 마라. 스크립트가 실패하면 runs:0, lastSuiteScore:null, version:null, lastCaseVersions:[] 를 반환하라.`,
  { agentType: 'general-purpose', label: 'read-baseline', phase: 'Score', effort: 'low', schema: PRIOR_SCHEMA }
)
const prev = prior?.lastSuiteScore ?? null
const runOrdinal = (prior?.runs ?? 0) + 1
const belowThreshold = graded.filter((r) => r.caseScore < THRESHOLD).map((r) => `${r.id}(${r.caseScore})`)

// suiteScore는 케이스를 추가·제거·수정하면 곧바로 비교 불가가 된다(평균의 모집단이 바뀐다).
// 회귀는 **양쪽 run에 같은 버전으로 존재하는 케이스**만으로 판정한다 — 그게 유일한 동일 조건 비교.
const priorCases = new Map((prior?.lastCaseVersions ?? []).map((c) => [c.id, c]))
const versionChanged = graded
  .filter((r) => priorCases.has(r.id) && (priorCases.get(r.id).caseVersion ?? null) !== (r.caseVersion ?? null))
  .map((r) => `${r.id}(${priorCases.get(r.id).caseVersion}→${r.caseVersion ?? 'null'})`)
const added = graded.filter((r) => !priorCases.has(r.id)).map((r) => r.id)
const removed = [...priorCases.keys()].filter((id) => !graded.some((r) => r.id === id))

const comparable = graded.filter((r) => {
  const p = priorCases.get(r.id)
  return p && (p.caseVersion ?? null) === (r.caseVersion ?? null) && typeof p.caseScore === 'number'
})
const mean = (xs) => (xs.length ? Math.round(xs.reduce((s, x) => s + x, 0) / xs.length) : null)
const comparableNow = mean(comparable.map((r) => r.caseScore))
const comparablePrev = mean(comparable.map((r) => priorCases.get(r.id).caseScore))
const regressed = comparablePrev != null && comparableNow < comparablePrev - DELTA

// 구성 기록 — 같은 골든셋으로 하네스 버전/구성 간 비교하는 축(환경·태스크 고정, 구성만 교체).
// run·version은 여기 적어도 eval-trend.sh 가 덮어쓴다(서수 = 기존 길이+1, VERSION 파일). 에이전트는
// 엔트리를 임시 파일에 그대로 쓰고 스크립트를 부르는 릴레이만 — 추이 파일을 직접 편집하지 않는다.
// 스크립트는 이전 run 해시(prevHash)를 검사해 변조된 추이엔 append 하지 않는다(exit 1).
const entry = { config: ARGS.config ?? null, suiteScore, threshold: THRESHOLD, cases: graded }
const persisted = await agent(
  `다음을 순서대로 수행하라: (1) 아래 JSON을 \`mktemp\` 로 만든 임시 파일에 **그대로**(변형·요약 금지) 저장 (2) Bash로 \`bash .claude/hooks/eval-trend.sh append <그 파일>\` 실행 (3) stdout의 JSON을 그대로 반환. specs/eval-score.json 을 직접 열거나 편집하지 마라. 스크립트가 exit 1이면 stderr 메시지를 error 필드로 반환하라.\n\n${JSON.stringify(entry, null, 2)}`,
  { agentType: 'general-purpose', label: `persist-trend#${runOrdinal}`, phase: 'Score', effort: 'low',
    schema: { type: 'object', properties: { run: { type: ['number', 'null'] }, version: { type: ['string', 'null'] }, suiteScore: { type: ['number', 'null'] }, error: { type: ['string', 'null'] } } } }
)
if (persisted?.error) log(`[TREND NOT SAVED] ${persisted.error} — 점수는 위 리포트에만 있다. 추이를 고친 뒤 재실행하라.`)

log(`suite ${suiteScore}/100 (run #${runOrdinal}, 케이스 ${graded.length}건)`)
if (comparable.length) {
  log(`동일 케이스 ${comparable.length}건 기준: ${comparablePrev}→${comparableNow} — ${regressed ? '⚠ 회귀' : 'OK'}`)
} else {
  log('직전 run과 겹치는 케이스가 없다 — 회귀 판정 불가(비교 기준 없음).')
}
if (regressed) log(`[REGRESSION] 동일 케이스 ${comparablePrev}→${comparableNow} (>${DELTA}pt 하락). 임계 미달: ${belowThreshold.join(', ') || '없음'}`)
if (added.length || removed.length) {
  log(`[CASE SET CHANGED] 추가 ${added.join(', ') || '없음'} / 제거 ${removed.join(', ') || '없음'} — suite ${prev}→${suiteScore} 비교는 모집단이 달라 무의미하다. 위 동일 케이스 기준만 보라.`)
}
if (versionChanged.length) log(`[VERSION CHANGED] ${versionChanged.join(', ')} — 이 케이스들은 직전 run과 같은 문제가 아니라 비교에서 제외했다.`)

return {
  suiteScore, threshold: THRESHOLD, run: runOrdinal, baseline: prev,
  comparableNow, comparablePrev, comparableCount: comparable.length,
  regressed, belowThreshold, versionChanged, added, removed,
  passAtK: graded.filter((r) => r.pass_at_k).length,
  passPowK: graded.filter((r) => r.pass_pow_k).length,
  total: graded.length,
  cases: graded,
}
