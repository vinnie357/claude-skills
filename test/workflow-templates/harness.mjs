#!/usr/bin/env node
// harness.mjs — syntax-checks and executes an agent-loop workflow template
// (forge-issue.workflow.js / five-tier-issue.workflow.js) against stub
// agent/parallel/phase/log/workflow/budget functions, verifying the
// reviewer-evidence contract (execution hands answering a reviewer's
// evidenceRequests) without spawning any real agent or touching the
// network.
//
// Usage:
//   node harness.mjs <templatePath> syntax   # node --check on the wrapped file
//   node harness.mjs <templatePath> run      # execute stub scenarios, assert the contract
//
// Wrapping recipe (shared by both modes): strip
// the leading "export " from every top-level `export const|function ...`
// declaration (today there is exactly one: `export const meta`), then wrap
// the whole body in
//   async function __wf(agent, parallel, pipeline, phase, log, workflow, args, budget) { ... }
// so the module's top-level `return` statements land inside a real
// function. Without the wrap, `export const meta = {...}` followed by a
// top-level `return` is a SyntaxError at ES module scope ("Illegal return
// statement") — that is the exact defect `syntax` below is designed to
// catch, and why `node --check` on the raw file is not a usable check.
//
// Scope note: the harness drives each template with N=1 slice/test-plan
// entry only -- forge's plan stub returns a single slice ('s1'), five-tier's
// plan stub returns a single test-plan entry. Multi-slice/multi-wave fan-out
// is out of scope for this contract.
//
// FINDING_LINE contract: the template's top-level `const FINDING_LINE = ...`
// must be a single string literal -- a quoted string or a template literal
// with no `${}` interpolation -- so the harness can evaluate it via
// Function('return ' + literal)() and compare the real string value, not
// the raw source text between the quotes.
//
// Nushell (project default per CLAUDE.md) cannot dynamically import an ES
// module and invoke it with live JS closures for agent/parallel/phase/log —
// the "run" mode below requires the Node runtime and JS semantics. This
// file is deliberately JS; the orchestrator that calls it
// (test/validate-workflow-templates.nu) is nushell, per convention.

import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { tmpdir } from 'node:os'
import { join, basename } from 'node:path'
import { pathToFileURL } from 'node:url'
import { randomUUID } from 'node:crypto'

const [, , arg2, arg3] = process.argv

// --self-check runs the dispatch-key regression fixtures once, independent
// of any template — isPrincipalReviewCall's selection rule (by opts.model,
// never by label presence/absence) is the same function for every template
// and every scenario, so asserting it per-template duplicated an identical
// check with no template-specific content. See runSelfCheck() below.
if (arg2 === '--self-check') {
  process.exit(runSelfCheck() ? 0 : 1)
}

const templatePath = arg2
const mode = arg3
if (!templatePath || !mode) {
  console.error('usage: node harness.mjs <templatePath> <syntax|run>\n       node harness.mjs --self-check')
  process.exit(2)
}

const templateName = basename(templatePath).replace(/\.workflow\.js$/, '')
const rawSource = readFileSync(templatePath, 'utf8')

function wrap(source) {
  // Generalized beyond "just meta": strips every top-level export so a
  // future top-level `export const FINDING_LINE = ...` (or similar) does
  // not silently reintroduce a SyntaxError inside the wrapped function body.
  const stripped = source.replace(/^export (const|let|var|function|async function) /gm, '$1 ')
  if (stripped === source) {
    throw new Error('no top-level "export ..." found — template shape changed unexpectedly')
  }
  return (
    'export async function __wf(agent, parallel, pipeline, phase, log, workflow, args, budget) {\n' +
    stripped +
    '\n}\n'
  )
}

const tempDirs = []
function writeTempModule(content) {
  const dir = mkdtempSync(join(tmpdir(), 'workflow-template-harness-'))
  tempDirs.push(dir)
  const file = join(dir, `wrapped-${randomUUID()}.mjs`)
  writeFileSync(file, content, 'utf8')
  return file
}
process.on('exit', () => {
  for (const dir of tempDirs) {
    try { rmSync(dir, { recursive: true, force: true }) } catch { /* best-effort cleanup */ }
  }
})

let failed = false
function report(assertion, ok, reason) {
  if (ok) {
    console.log(`PASS ${templateName} ${assertion}`)
  } else {
    failed = true
    console.log(`FAIL ${templateName} ${assertion}: ${reason}`)
  }
}

// ---------------------------------------------------------------------------
// Mode: syntax
// ---------------------------------------------------------------------------

if (mode === 'syntax') {
  try {
    const wrapped = wrap(rawSource)
    const file = writeTempModule(wrapped)
    execFileSync(process.execPath, ['--check', file], { stdio: 'pipe' })
    report('syntax', true)
  } catch (e) {
    const detail = e.stderr ? e.stderr.toString().trim().split('\n')[0] : e.message
    report('syntax', false, detail)
  }
  process.exit(failed ? 1 : 0)
}

if (mode !== 'run') {
  console.error(`unknown mode: ${mode}`)
  process.exit(2)
}

// ---------------------------------------------------------------------------
// Mode: run — execute stub scenarios against the template's __wf export.
// ---------------------------------------------------------------------------

let kind
if (/forge-issue/.test(templatePath)) kind = 'forge'
else if (/five-tier-issue/.test(templatePath)) kind = 'five-tier'
else {
  console.error(`cannot detect template kind (expected "forge-issue" or "five-tier-issue" in path): ${templatePath}`)
  process.exit(2)
}

const SP = [{ skill: '/core:tdd', quote: 'RED: Write a test that fails.' }]

function verdictApprove() {
  return { approved: true, findings: [], skillProof: SP }
}
function verdictEvidence() {
  return {
    approved: false,
    findings: [],
    evidenceRequests: [{ command: 'mise run ci', question: 'does CI pass' }],
    skillProof: SP,
  }
}

// Selects a PRINCIPAL reviewer call (not a hands call) by model, never by
// label absence. A correct fix can legitimately attach a label to a
// re-invoked reviewer call (e.g. to distinguish it in /workflows progress
// output), and "no label = reviewer" silently stops counting that call.
// Hands calls (research AND execution) always run on args.handsModel per
// the AGENT_LOOP_HANDS_MODEL contract, so excluding that one model — while
// requiring some model be set at all, which rules out the model-less
// diff-boundary and head-of-HEAD probes — is sufficient to isolate the
// principal call, independent of whatever label it carries.
function isPrincipalReviewCall(callLike, args) {
  return typeof callLike.model !== 'undefined' && callLike.model !== args.handsModel
}

// Synthetic, mutually-distinct model literals — never the harness's real
// stage models — so `opts.model === args.handsModel` can never collide
// with a principal-stage call by accident.
function buildArgsForge() {
  return {
    issueId: 'test-issue',
    repo: '/tmp/fake-repo',
    acceptanceCriteria: ['AC1 holds', 'AC2 holds'],
    skills: ['/core:tdd'],
    escalationChain: ['STAGEMODEL'],
    handsModel: 'HANDSMODEL',
    handsVisionModel: 'HANDSVISIONMODEL',
    stageModels: {
      plan: 'STAGEMODEL', author: 'STAGEMODEL', testRev: 'STAGEMODEL',
      impl: 'STAGEMODEL', ci: 'STAGEMODEL', review: 'STAGEMODEL', final: 'STAGEMODEL',
    },
  }
}

function buildArgsFiveTier() {
  return {
    issueId: 'test-issue',
    repo: '/tmp/fake-repo',
    acceptanceCriteria: ['AC1 holds', 'AC2 holds'],
    testFiles: ['test/x_test.exs'],
    skills: ['/core:tdd'],
    escalationChain: ['STAGEMODEL'],
    // Not consumed by the template as shipped today — provided so five-tier's
    // P5 stage can wire to the same evidence mechanism forge uses, per the
    // AGENT_LOOP_HANDS_MODEL contract.
    handsModel: 'HANDSMODEL',
    handsVisionModel: 'HANDSVISIONMODEL',
    stageModels: { plan: 'STAGEMODEL', test: 'STAGEMODEL', impl: 'STAGEMODEL', ci: 'STAGEMODEL', review: 'STAGEMODEL' },
  }
}

function fallback(ctx, opts) {
  console.error(`[harness] UNHANDLED CALL phase=${opts.phase} label=${opts.label} model=${opts.model}`)
  return {
    approved: true, findings: [], skillProof: SP,
    sha: 'FALLBACKSHA', summary: 'fallback', green: true, output: '',
    nonEmpty: false, diff: '', pointers: [],
    tests: [{ name: 't', criterion: 'c' }], slices: [],
  }
}

// The stage under test in both templates: forge's post-impl "Reviewer"
// (phase 'Review', not 'Review-tests' or 'Final') and five-tier's sole P5
// reviewer (also phase 'Review'). n counts calls at this phase so far,
// INCLUDING the current one (it is pushed to ctx.calls before dispatch runs).
function reviewerVerdict(ctx) {
  const matching = ctx.calls.filter(c => c.phase === ctx.kind.targetReviewPhase && isPrincipalReviewCall(c, ctx.args))
  const n = matching.length
  if (ctx.scenario === 'happy') return verdictApprove()
  if (n === 1) return verdictEvidence()
  if (ctx.scenario === 'evidence-escalate') return verdictEvidence()
  return verdictApprove()
}

function forgeDispatch(prompt, opts, ctx) {
  const { phase, label } = opts
  if (phase === 'Plan' && label === 'planner hands') return { pointers: [] }
  if (phase === 'Plan' && !label) {
    return { slices: [{ id: 's1', tests: [{ name: 't1', criterion: 'c1' }], testFiles: ['test/x_test.exs'], deps: [] }], skillProof: SP }
  }
  if (phase === 'Author' && !label) return { sha: 'TESTSHA1', summary: 'add tests', skillProof: SP }
  if (phase === 'Review-tests' && label === 'test-reviewer hands') return { pointers: [] }
  if (phase === 'Review-tests' && isPrincipalReviewCall({ model: opts.model }, ctx.args)) return verdictApprove()
  if (phase === 'Impl' && label === 'impl:s1') {
    ctx.commitSeqs.push(ctx.calls.length - 1)
    return { sha: 'IMPLSHA1', summary: 'impl', skillProof: SP }
  }
  if (phase === 'Impl' && label === 'diff-boundary gate') return { nonEmpty: false, diff: '' }
  if (phase === 'Impl' && label === 'ci:s1') return { green: true, output: 'ok', skillProof: SP }
  if (phase === 'Review' && label === 'reviewer hands') return { pointers: [] }
  if (phase === 'Review' && isPrincipalReviewCall({ model: opts.model }, ctx.args)) return reviewerVerdict(ctx)
  if (phase === 'Remediate' && !label) {
    ctx.commitSeqs.push(ctx.calls.length - 1)
    return { sha: 'FIXSHA1', summary: 'fix', skillProof: SP }
  }
  if (phase === 'Remediate' && label === 'diff-boundary gate') return { nonEmpty: false, diff: '' }
  if (phase === 'Remediate' && label === 'ci:remediation') return { green: true, output: 'ok', skillProof: SP }
  if (phase === 'Final' && label === 'final-reviewer hands') return { pointers: [] }
  if (phase === 'Final' && isPrincipalReviewCall({ model: opts.model }, ctx.args)) return verdictApprove()
  return fallback(ctx, opts)
}

function fiveTierDispatch(prompt, opts, ctx) {
  const { phase, label } = opts
  if (phase === 'Plan') return { tests: [{ name: 't1', criterion: 'c1' }], skillProof: SP }
  if (phase === 'Test' && !label) return { sha: 'TESTSHA1', summary: 'tests', skillProof: SP }
  if (phase === 'Impl' && label && label.startsWith('P3-')) {
    ctx.commitSeqs.push(ctx.calls.length - 1)
    return { sha: 'IMPLSHA1', summary: 'impl', skillProof: SP }
  }
  if (phase === 'Impl' && label === 'diff-boundary gate') return { nonEmpty: false, diff: '' }
  if (phase === 'CI' && label === 'diff-boundary gate') return { nonEmpty: false, diff: '' }
  if (phase === 'CI' && !label) return { green: true, output: 'ok', skillProof: SP }
  if (phase === 'Review' && isPrincipalReviewCall({ model: opts.model }, ctx.args)) return reviewerVerdict(ctx)
  return fallback(ctx, opts)
}

const KIND = {
  forge: { reviewerPhases: ['Review-tests', 'Review', 'Final'], targetReviewPhase: 'Review', buildArgs: buildArgsForge, dispatch: forgeDispatch },
  'five-tier': { reviewerPhases: ['Review'], targetReviewPhase: 'Review', buildArgs: buildArgsFiveTier, dispatch: fiveTierDispatch },
}[kind]

// --- regression: isPrincipalReviewCall selects by model, not label absence ---
// A labeled re-invoke of the principal reviewer (e.g. a fixed template names
// its evidence-round re-invoke for /workflows progress display) must still
// be counted as the reviewer, and a labeled-but-hands call must still be
// excluded. Template-independent — see the --self-check invocation above.
function runSelfCheck() {
  const fakeArgs = { handsModel: 'HANDSMODEL' }
  const labeledPrincipal = { model: 'STAGEMODEL', label: 'reviewer re-invoke' }
  const labeledHands = { model: 'HANDSMODEL', label: 'reviewer hands' }
  const modelLessProbe = { label: undefined }
  const ok =
    isPrincipalReviewCall(labeledPrincipal, fakeArgs) === true &&
    isPrincipalReviewCall(labeledHands, fakeArgs) === false &&
    isPrincipalReviewCall(modelLessProbe, fakeArgs) === false
  if (ok) {
    console.log('PASS harness self-check')
  } else {
    console.log('FAIL harness self-check: isPrincipalReviewCall must select by opts.model !== args.handsModel (with a model defined), never by label presence/absence')
  }
  return ok
}

// scenario:
//   happy            — every reviewer call approves immediately (used for
//                       no-reviewer-clone / finding-line, which only need
//                       one clean pass through every reviewer stage)
//   evidence-fresh    — first call at the target review phase returns
//                       evidenceRequests; the hands record's revision
//                       MATCHES the revision under review
//   evidence-stale    — same, but the hands record's revision DIFFERS
//   evidence-escalate — every call at the target review phase (not just
//                       the first) returns evidenceRequests
//   evidence-command-mismatch — like evidence-fresh, but the hands record's
//                       command differs from the requested command
//   evidence-exit-nonint      — like evidence-fresh, but the hands record's
//                       exit is 0.5 instead of an integer
//   evidence-cwd-empty        — like evidence-fresh, but the hands record's
//                       cwd is '' instead of a non-empty string
async function runScenario(mod, scenario) {
  const ctx = {
    kind: KIND,
    scenario,
    calls: [],
    handsExecCalls: [],
    headProbes: [],
    commitSeqs: [],
    revisionUnderReview: null,
    handsResultMarker: `HANDS_RESULT_MARKER_${randomUUID()}`,
  }
  const args = KIND.buildArgs()
  ctx.args = args

  const agentStub = async (prompt, opts = {}) => {
    ctx.calls.push({ seq: ctx.calls.length, phase: opts.phase, label: opts.label, model: opts.model, agentType: opts.agentType, prompt })

    // Head probe (contract 6, AMENDED): the revision under review is defined
    // by an agent() call with no opts.model whose prompt contains
    // "git rev-parse HEAD" — kept distinct from the existing diff-boundary
    // probe below (also model-less, but its prompt contains "git diff", a
    // string this literal never matches), so the two probes are handled
    // separately and neither swallows the other.
    if (!opts.model && prompt.includes('git rev-parse HEAD')) {
      ctx.headProbes.push({ seq: ctx.calls.length - 1, phase: opts.phase, prompt })
      ctx.revisionUnderReview = 'HEADSHA1'
      return { sha: 'HEADSHA1' }
    }

    // Execution hands: the hands model, WITHOUT the research-hands
    // agentType:'Explore' tag. Existing handsPass() calls in both
    // templates always set agentType:'Explore' for non-vision research, so
    // this branch fires only when a hands call actually runs a command.
    //
    // Contract item 7 (evidence-metadata-validated): a hands record is kept
    // for the re-invoked reviewer only if revision, command, exit (integer),
    // and cwd (non-empty string) all validate. 'evidence-command-mismatch',
    // 'evidence-exit-nonint', and 'evidence-cwd-empty' below deliberately
    // violate exactly one of those fields each — command, exit, and cwd
    // respectively — while leaving the other three fields valid, so a
    // correct implementation must inspect all four fields, not just
    // revision.
    if (opts.model === args.handsModel && !opts.agentType) {
      const record = {
        command: scenario === 'evidence-command-mismatch' ? 'mise run wrong-command' : 'mise run ci',
        revision: scenario === 'evidence-stale' ? 'OTHERSHA' : ctx.revisionUnderReview,
        cwd: scenario === 'evidence-cwd-empty' ? '' : args.repo,
        exit: scenario === 'evidence-exit-nonint' ? 0.5 : 0,
        result: ctx.handsResultMarker,
        excerpt: 'mise run ci output excerpt',
        log: '/tmp/mise-ci.log',
      }
      ctx.handsExecCalls.push({ seq: ctx.calls.length - 1, prompt, opts, record })
      return record
    }
    return KIND.dispatch(prompt, opts, ctx)
  }

  // Matches the real parallel(): a thunk that throws (sync or async) resolves
  // to null instead of rejecting the whole batch.
  const parallelStub = thunks => Promise.all(thunks.map(fn => Promise.resolve().then(fn).catch(() => null)))
  const pipelineStub = async (items, ...stages) => {
    let out = items
    for (const stage of stages) out = await Promise.all(out.map(stage))
    return out
  }
  const phaseStub = () => {}
  const logStub = () => {}
  const workflowStub = async () => { throw new Error('workflow() not expected by these templates') }
  const budgetStub = { total: 0, spent: () => 0, remaining: () => 0 }

  let result
  let threw = null
  try {
    result = await mod.__wf(agentStub, parallelStub, pipelineStub, phaseStub, logStub, workflowStub, args, budgetStub)
  } catch (e) {
    threw = e
  }
  return { ctx, result, threw }
}

const wrapped = wrap(rawSource)
const file = writeTempModule(wrapped)
const mod = await import(pathToFileURL(file).href)

const happy = await runScenario(mod, 'happy')
const evFresh = await runScenario(mod, 'evidence-fresh')
const evEscalate = await runScenario(mod, 'evidence-escalate')
const evStale = await runScenario(mod, 'evidence-stale')
const evCommandMismatch = await runScenario(mod, 'evidence-command-mismatch')
const evExitNonint = await runScenario(mod, 'evidence-exit-nonint')
const evCwdEmpty = await runScenario(mod, 'evidence-cwd-empty')

// --- assertion: no-reviewer-clone ---------------------------------------
{
  if (happy.threw) {
    report('no-reviewer-clone', false, `happy-path run threw: ${happy.threw.stack || happy.threw.message}`)
  } else {
    const reviewerPrompts = happy.ctx.calls.filter(c => KIND.reviewerPhases.includes(c.phase) && isPrincipalReviewCall(c, happy.ctx.args))
    const offenders = reviewerPrompts.filter(c => c.prompt.includes('git clone'))
    if (reviewerPrompts.length === 0) {
      report('no-reviewer-clone', false, 'no reviewer prompts captured during the happy-path run')
    } else if (offenders.length > 0) {
      report('no-reviewer-clone', false,
        `reviewer prompt(s) at phase(s) [${[...new Set(offenders.map(c => c.phase))].join(', ')}] contain "git clone"`)
    } else {
      report('no-reviewer-clone', true)
    }
  }
}

// --- assertion: finding-line ---------------------------------------------
{
  const m = rawSource.match(/^(?:export )?const FINDING_LINE = (['"`])((?:\\.|(?!\1)[\s\S])*)\1/m)
  if (!m) {
    report('finding-line', false, 'no top-level `const FINDING_LINE = ...` found in source')
  } else {
    // Evaluate the matched literal rather than comparing the raw source text
    // between the quotes — escape sequences and template-literal contents
    // otherwise differ from the real runtime string value.
    let value, evalError
    try {
      value = Function('return ' + m[1] + m[2] + m[1])()
    } catch (e) {
      evalError = e
    }
    if (evalError) {
      report('finding-line', false, `FINDING_LINE literal failed to evaluate: ${evalError.message}`)
    } else if (typeof value !== 'string') {
      report('finding-line', false, `FINDING_LINE must evaluate to a string, got ${typeof value}`)
    } else if (!value.includes('defect and impact; basis')) {
      report('finding-line', false, `FINDING_LINE value does not contain "defect and impact; basis": ${JSON.stringify(value)}`)
    } else if (happy.threw) {
      report('finding-line', false, `happy-path run threw: ${happy.threw.stack || happy.threw.message}`)
    } else {
      const reviewerPrompts = happy.ctx.calls.filter(c => KIND.reviewerPhases.includes(c.phase) && isPrincipalReviewCall(c, happy.ctx.args))
      const missing = reviewerPrompts.filter(c => !c.prompt.includes(value))
      if (reviewerPrompts.length === 0) {
        report('finding-line', false, 'no reviewer prompts captured during the happy-path run')
      } else if (missing.length > 0) {
        report('finding-line', false,
          `reviewer prompt(s) at phase(s) [${[...new Set(missing.map(c => c.phase))].join(', ')}] do not include FINDING_LINE's text`)
      } else {
        report('finding-line', true)
      }
    }
  }
}

// --- assertion: evidence-round --------------------------------------------
{
  if (evFresh.threw) {
    report('evidence-round', false, `evidence-fresh run threw: ${evFresh.threw.stack || evFresh.threw.message}`)
  } else {
    const { ctx } = evFresh
    const reviewerCalls = ctx.calls.filter(c => c.phase === KIND.targetReviewPhase && isPrincipalReviewCall(c, ctx.args))
    if (ctx.handsExecCalls.length !== 1) {
      report('evidence-round', false,
        `expected exactly 1 execution-hands call (opts.model === args.handsModel, no opts.agentType) after the first reviewer verdict; found ${ctx.handsExecCalls.length}`)
    } else if (!ctx.handsExecCalls[0].prompt.includes('mise run ci')) {
      report('evidence-round', false, 'the execution-hands call prompt does not contain "mise run ci"')
    } else if (reviewerCalls.length < 2) {
      report('evidence-round', false,
        `expected a second reviewer call after the execution-hands record; found ${reviewerCalls.length} reviewer call(s) total`)
    } else if (!reviewerCalls[1].prompt.includes(ctx.handsResultMarker)) {
      report('evidence-round', false, "the re-invoked reviewer prompt does not include the hands record's RESULT text")
    } else {
      report('evidence-round', true)
    }
  }
}

// --- assertion: second-request-escalates ------------------------------------
{
  if (evEscalate.threw) {
    report('second-request-escalates', false, `evidence-escalate run threw: ${evEscalate.threw.stack || evEscalate.threw.message}`)
  } else {
    const { ctx, result } = evEscalate
    const reviewerCalls = ctx.calls.filter(c => c.phase === KIND.targetReviewPhase && isPrincipalReviewCall(c, ctx.args))
    if (ctx.handsExecCalls.length !== 1) {
      report('second-request-escalates', false,
        `expected exactly 1 execution-hands call before the reviewer is re-invoked; found ${ctx.handsExecCalls.length} — evidence-gathering is not implemented`)
    } else if (reviewerCalls.length !== 2) {
      report('second-request-escalates', false,
        `expected exactly 2 reviewer calls (first + re-invoked) before escalation; found ${reviewerCalls.length}`)
    } else if (!result || result.status !== 'escalate') {
      report('second-request-escalates', false,
        `expected the workflow to return status: 'escalate' after the second evidenceRequests; got status=${result && result.status}`)
    } else {
      report('second-request-escalates', true)
    }
  }
}

// --- assertion: stale-record-dropped ----------------------------------------
{
  if (evStale.threw) {
    report('stale-record-dropped', false, `evidence-stale run threw: ${evStale.threw.stack || evStale.threw.message}`)
  } else {
    const { ctx } = evStale
    const reviewerCalls = ctx.calls.filter(c => c.phase === KIND.targetReviewPhase && isPrincipalReviewCall(c, ctx.args))
    if (reviewerCalls.length === 0) {
      report('stale-record-dropped', false, 'no reviewer call captured at the target review phase')
    } else if (ctx.headProbes.length === 0) {
      report('stale-record-dropped', false,
        'no head probe observed — expected an agent() call with no opts.model whose prompt contains "git rev-parse HEAD" to define the revision under review')
    } else {
      // Contract: the revision under review comes from a head probe made
      // AFTER the last implement/fix commit call and BEFORE the first
      // principal reviewer call of the target review stage.
      const firstReview = reviewerCalls[0].seq
      const priorCommits = ctx.commitSeqs.filter(s => s < firstReview)
      const lastCommit = priorCommits.length > 0 ? Math.max(...priorCommits) : null
      if (lastCommit === null) {
        report('stale-record-dropped', false, 'no implement/fix commit call observed before the first reviewer call')
      } else if (!ctx.headProbes.some(p => p.seq > lastCommit && p.seq < firstReview)) {
        report('stale-record-dropped', false,
          `no head probe between the last implement/fix commit (seq ${lastCommit}) and the first reviewer call (seq ${firstReview})`)
      } else if (ctx.handsExecCalls.length !== 1) {
        report('stale-record-dropped', false,
          `expected exactly 1 execution-hands call to test staleness against; found ${ctx.handsExecCalls.length} — evidence-gathering is not implemented`)
      } else if (ctx.handsExecCalls[0].record.revision === ctx.revisionUnderReview) {
        report('stale-record-dropped', false,
          'test setup error: the evidence-stale record.revision unexpectedly matches revisionUnderReview')
      } else if (reviewerCalls.length < 2) {
        report('stale-record-dropped', false,
          `expected a re-invoked reviewer call after the stale record; found ${reviewerCalls.length} reviewer call(s) total`)
      } else if (reviewerCalls[1].prompt.includes(ctx.handsResultMarker)) {
        report('stale-record-dropped', false,
          "the re-invoked reviewer prompt includes the stale record's RESULT text — a mismatched revision must be dropped, not trusted")
      } else {
        report('stale-record-dropped', true)
      }
    }
  }
}

// --- assertion: evidence-metadata-validated ---------------------------------
// A hands record is kept for the re-invoked reviewer only if ALL of
// revision, command, exit (integer), and cwd (non-empty string) validate —
// not revision alone. Each case below violates exactly one other field
// while revision matches, so stale-record-dropped's revision-only check
// cannot accidentally cover this.
{
  let failReason = null
  const cases = [
    ['evidence-command-mismatch', evCommandMismatch, 'a command differing from the requested command'],
    ['evidence-exit-nonint', evExitNonint, 'a non-integer exit (0.5)'],
    ['evidence-cwd-empty', evCwdEmpty, 'an empty cwd'],
  ]
  for (const [name, run, label] of cases) {
    if (failReason) break
    if (run.threw) {
      failReason = `${name} run threw: ${run.threw.stack || run.threw.message}`
      break
    }
    const { ctx } = run
    const reviewerCalls = ctx.calls.filter(c => c.phase === KIND.targetReviewPhase && isPrincipalReviewCall(c, ctx.args))
    if (ctx.handsExecCalls.length !== 1) {
      failReason = `${name}: expected exactly 1 execution-hands call; found ${ctx.handsExecCalls.length}`
    } else if (reviewerCalls.length < 2) {
      failReason = `${name}: expected a re-invoked reviewer call after the execution-hands record; found ${reviewerCalls.length}`
    } else if (reviewerCalls[1].prompt.includes(ctx.handsResultMarker)) {
      failReason = `${name}: the re-invoked reviewer prompt includes the RESULT text of a record with ${label} — a record failing metadata validation must be dropped, not trusted`
    }
  }
  report('evidence-metadata-validated', failReason === null, failReason)
}

process.exit(failed ? 1 : 0)
