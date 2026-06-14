// forge-issue.workflow.js — runnable Claude Code workflow for the Forge operating
// model: paired principals + cheap read-only hands, with implementor fan-out across
// the planner's slices. The five-tier-issue.workflow.js script is the N=1 linear
// case of this one; Forge generalizes it to N implementor+test-runner pairs and
// gives every principal a hands-built startup index.
//
// Run via the Workflow tool with { scriptPath } pointing at this file, or save to
// .claude/workflows/ and invoke as /forge-issue. Expected args:
//
//   {
//     "issueId": "repo-42",
//     "repo": "/absolute/path/to/repo",
//     "acceptanceCriteria": ["GET /health returns 200", "..."],
//     "skills": ["/core:anti-fabrication", "/core:tdd", "/core:git"],
//     "escalationChain": ["haiku", "sonnet", "opus"],
//     "handsModel": "haiku",            // AGENT_LOOP_HANDS_MODEL — text/code research
//     "handsVisionModel": "sonnet",     // AGENT_LOOP_HANDS_VISION_MODEL — vision research
//     "stageModels": {
//       "plan":     "opus",    // Test Planner
//       "author":   "sonnet",  // Test Author
//       "testRev":  "opus",    // Test Reviewer (best-thinker tier)
//       "impl":     "sonnet",  // Implementor (× N slices)
//       "ci":       "haiku",   // Test Runner
//       "review":   "opus",    // Reviewer
//       "final":    "opus"     // Final Reviewer
//     }
//   }
//
// Models are config (12-factor): no model name is hardcoded in a prompt body, and
// the hands model is selected by capability — handsVisionModel for visual objectives,
// handsModel otherwise. Constraints (from /claude-code:claude-workflows): plain JS
// only; Date.now(), Math.random(), and argless new Date() throw — pass timestamps and
// the escalation chain through args. budget scales fan-out; resume via
// { scriptPath, resumeFromRunId } replays completed stages from cache.

export const meta = {
  name: 'forge-issue',
  description: 'Run one issue through Forge: hands-indexed plan, fanned-out impl pairs, opus reviews',
  phases: [
    { title: 'Plan', detail: 'Hands index → Test Planner slices the issue' },
    { title: 'Author', detail: 'Test Author writes failing tests' },
    { title: 'Review-tests', detail: 'Test Reviewer (opus + hands) checks plan-conformance + non-redundancy' },
    { title: 'Impl', detail: 'One Implementor + Test Runner pair per slice, by dep wave' },
    { title: 'Review', detail: 'Reviewer (opus + hands) verifies acceptance criteria' },
    { title: 'Final', detail: 'Final Reviewer (opus + hands) checks the remediation diff' },
    { title: 'Remediate', detail: 'Implementor + Test Runner pair addresses review findings' },
  ],
}

// ---------------------------------------------------------------------------
// Schemas. Tier principals carry skillProof (proof-of-loading rule); hands are
// read-only research and return an index only.
// ---------------------------------------------------------------------------

const SKILL_PROOF = {
  type: 'array', minItems: 1,
  items: { type: 'object', required: ['skill', 'quote'],
    properties: { skill: { type: 'string' }, quote: { type: 'string' } } },
}

const INDEX = {
  type: 'object', required: ['pointers'],
  properties: {
    pointers: {
      type: 'array',
      items: { type: 'object', required: ['file', 'lines', 'why'],
        properties: { file: { type: 'string' }, lines: { type: 'string' },
          why: { type: 'string' }, excerpt: { type: 'string' } } },
    },
  },
}

// Planner output: slices, each an independent test group with its own deps.
const TEST_PLAN = {
  type: 'object', required: ['slices', 'skillProof'],
  properties: {
    slices: {
      type: 'array', minItems: 1,
      items: {
        type: 'object', required: ['id', 'tests', 'testFiles'],
        properties: {
          id: { type: 'string' },
          tests: { type: 'array', minItems: 1,
            items: { type: 'object', required: ['name', 'criterion'],
              properties: { name: { type: 'string' }, criterion: { type: 'string' } } } },
          testFiles: { type: 'array', items: { type: 'string' } },
          deps: { type: 'array', items: { type: 'string' } },
        },
      },
    },
    skillProof: SKILL_PROOF,
  },
}

const COMMIT = {
  type: 'object', required: ['sha', 'summary', 'skillProof'],
  properties: { sha: { type: 'string' }, summary: { type: 'string' }, skillProof: SKILL_PROOF },
}

const DIFF = { // mechanical probe — no skills to prove
  type: 'object', required: ['nonEmpty'],
  properties: { nonEmpty: { type: 'boolean' }, diff: { type: 'string' } },
}

const CI_RESULT = {
  type: 'object', required: ['green', 'output', 'skillProof'],
  properties: { green: { type: 'boolean' }, output: { type: 'string' }, skillProof: SKILL_PROOF },
}

const VERDICT = {
  type: 'object', required: ['approved', 'findings', 'skillProof'],
  properties: { approved: { type: 'boolean' },
    findings: { type: 'array', items: { type: 'string' } }, skillProof: SKILL_PROOF },
}

// ---------------------------------------------------------------------------
// Prompt builders. Each principal names its role, loads skills, stays in stage,
// and proves loading. Hands get a focused objective and the index output contract.
// ---------------------------------------------------------------------------

function skillBlock(skills) {
  return [
    'FIRST step: invoke the Skill tool for each skill below by exact name.',
    'Quote one verbatim sentence from each loaded skill in the skillProof field',
    'of your structured output — "I loaded X" is insufficient evidence.',
    ...skills.map(s => `- ${s}`),
  ].join('\n')
}

function startingIndex(index) {
  if (!index || !index.pointers || index.pointers.length === 0) return '## Starting index\n(none)'
  return ['## Starting index (read only these lines; spawn focused hands for anything more)',
    ...index.pointers.map(p => `- ${p.file}:${p.lines} — ${p.why}`)].join('\n')
}

function handsPrompt(objective, vision) {
  return [
    'You are read-only research hands. Do NOT design, edit, write code, or commit.',
    `Objective: ${objective}`,
    vision
      ? 'The objective requires vision: use the harness visual tools (WebFetch / Playwright / image reader).'
      : 'Use Read, Grep, Glob (and Bash for which/ls).',
    'Return an INDEX: pointers of {file, lines, why, excerpt}. Each excerpt ≤ ~15 lines.',
    'Never dump whole files; never drop the file:line provenance.',
  ].join('\n')
}

// Route by capability: vision → handsVisionModel (no Explore, needs multimodal);
// text → Explore subagent + handsModel.
function handsPass(objective, opts = {}) {
  const vision = !!opts.vision
  const o = { phase: opts.phase || 'Plan', label: opts.label || 'hands', schema: INDEX,
    model: vision ? args.handsVisionModel : args.handsModel }
  if (!vision) o.agentType = 'Explore'
  return agent(handsPrompt(objective, vision), o)
}

function planPrompt(a, index) {
  return [
    `You are the Test Planner for issue ${a.issueId} in repo ${a.repo}.`,
    skillBlock(a.skills),
    startingIndex(index),
    'Design the test list from these acceptance criteria:',
    ...a.acceptanceCriteria.map(c => `- ${c}`),
    'Decompose into independent SLICES — each a test group that can be implemented on its own.',
    'For each slice give: id, its tests ({name, criterion}), the testFiles it lives in, and deps',
    '(ids of slices that must land first; empty when independent). Prefer many small slices.',
    'STAY IN STAGE: plan only. Do NOT write tests or implementation, run CI, or review.',
  ].join('\n')
}

function authorPrompt(a, plan) {
  return [
    `You are the Test Author for issue ${a.issueId} in repo ${a.repo}.`,
    skillBlock(a.skills),
    'Write FAILING tests for every slice in this plan (one test per entry):',
    JSON.stringify(plan.slices),
    'Run mise run ci and confirm the ONLY failures are the new tests, then commit with a',
    'test: conventional commit and push. The deliberate red is the spec.',
    'STAY IN STAGE: write tests only — no implementation, no review.',
    'Return the commit sha and a one-line summary.',
  ].join('\n')
}

function testReviewPrompt(a, plan, index) {
  return [
    `You are the Test Reviewer for issue ${a.issueId} in repo ${a.repo}.`,
    skillBlock(a.skills),
    startingIndex(index),
    'The starting index points at ONLY the author\'s new tests. Judge two things:',
    '1. Do the tests follow the planner\'s plan (every slice + criterion covered, none invented)?',
    JSON.stringify(plan.slices),
    '2. Are any tests redundant or duplicated? Flag them.',
    'STAY IN STAGE: read and judge only. Do NOT edit tests or write implementation.',
    'Return approved true/false plus findings (empty when approved).',
  ].join('\n')
}

function implPrompt(a, slice, testSha) {
  return [
    `You are an Implementor for issue ${a.issueId}, slice ${slice.id}, in repo ${a.repo}.`,
    skillBlock(a.skills),
    `Make the failing tests for slice ${slice.id} pass. Test files are FROZEN: ${slice.testFiles.join(', ')}.`,
    `Verify before commit: git diff ${testSha.sha}..HEAD -- ${slice.testFiles.join(' ')} is empty,`,
    `and git status --porcelain -- ${slice.testFiles.join(' ')} is empty (no uncommitted test edits).`,
    'If a test is genuinely wrong, STOP and say so in your summary — do not edit it.',
    'STAY IN STAGE: implement this slice only. Do NOT rewrite tests or self-review.',
    'Commit with a conventional commit and return the commit sha and a one-line summary.',
  ].join('\n')
}

function ciPrompt(a, label) {
  return [
    `You are the Test Runner for issue ${a.issueId} (${label}) in repo ${a.repo}.`,
    skillBlock(a.skills),
    'Run mise run ci. Capture verbatim output and report green or red.',
    'Require a clean working tree before reporting green — a dirty tree green is an illusion.',
    'STAY IN STAGE: run and report only. Do NOT fix, edit, or commit.',
  ].join('\n')
}

function fixPrompt(a, findings, frozen) {
  return [
    `You are the Remediation Implementor for issue ${a.issueId} in repo ${a.repo}.`,
    skillBlock(a.skills),
    'Address these review findings, then commit:',
    ...findings.map(f => `- ${f}`),
    `Test files are FROZEN: ${frozen.join(', ')}. Do NOT modify them.`,
    'STAY IN STAGE: fix the findings only — no new features, no test rewrites.',
    'Return the commit sha and a one-line summary.',
  ].join('\n')
}

function reviewPrompt(a, index, role) {
  return [
    `You are the ${role} for issue ${a.issueId} in repo ${a.repo}.`,
    skillBlock(a.skills),
    startingIndex(index),
    'Verify each acceptance criterion is exercised by a test and satisfied by the implementation:',
    ...a.acceptanceCriteria.map(c => `- ${c}`),
    'Check for overfit-to-tests and missed edge cases. Use the starting index; spawn focused',
    'hands for anything more — do NOT sweep the tree yourself.',
    'STAY IN STAGE: read and judge only. Do NOT edit, fix, or commit.',
    'Return approved true/false plus findings (empty when approved).',
  ].join('\n')
}

// ---------------------------------------------------------------------------
// Escalation ladder — start at the stage model, escalate through the chain suffix,
// two attempts per model. Returns null when the whole ladder fails.
// ---------------------------------------------------------------------------

function ladderFor(stageModel) {
  const idx = args.escalationChain.indexOf(stageModel)
  return idx === -1 ? args.escalationChain.slice() : args.escalationChain.slice(idx)
}

async function withEscalation(prompt, opts, stageModel) {
  const ladder = ladderFor(stageModel)
  for (let i = 0; i < ladder.length; i++) {
    const model = ladder[i]
    const isLast = i === ladder.length - 1
    for (let attempt = 0; attempt < 2; attempt++) {
      try { return await agent(prompt, { ...opts, model }) }
      catch (e) {
        if (!isLast || attempt === 0) log(`${opts.phase || 'stage'}: failed on ${model} (attempt ${attempt + 1})`)
      }
    }
    if (!isLast) log(`${opts.phase || 'stage'}: promoting ${model} → ${ladder[i + 1]}`)
  }
  return null
}

function escalate(reason, extra) {
  return { status: 'escalate', issueId: args.issueId, reason, ...extra }
}

// Diff-boundary gate: the implementor must not have touched the frozen test files,
// committed OR uncommitted. Re-checkable after the fix loop.
async function frozenIntact(testFiles, sha, phase) {
  const probe = await agent([
    `In repo ${args.repo}, run BOTH:`,
    `  git diff ${sha}..HEAD -- ${testFiles.join(' ')}`,
    `  git status --porcelain -- ${testFiles.join(' ')}`,
    'Report nonEmpty=true if EITHER produces any output, with the combined text.',
    'Run and report only — do not edit anything.',
  ].join('\n'), { phase, label: 'diff-boundary gate', schema: DIFF })
  return probe && !probe.nonEmpty
}

// ---------------------------------------------------------------------------
// Forge pipeline.
// ---------------------------------------------------------------------------

log(`forge-issue: starting ${args.issueId}`)

// Plan — hands build the planner's startup index, then the planner slices.
phase('Plan')
const planIndex = await handsPass(
  `Index the specs/acceptance-criteria sources and the target modules for issue ${args.issueId}.`,
  { phase: 'Plan', label: 'planner hands' })
const plan = await withEscalation(planPrompt(args, planIndex), { phase: 'Plan', schema: TEST_PLAN }, args.stageModels.plan)
if (!plan) return escalate('Test Planner failed across escalation chain')
const allTestFiles = [...new Set(plan.slices.flatMap(s => s.testFiles))]
log(`forge-issue: ${plan.slices.length} slice(s)`)

// Author tests — one commit for the whole plan; test files frozen from here.
phase('Author')
const testSha = await withEscalation(authorPrompt(args, plan), { phase: 'Author', schema: COMMIT }, args.stageModels.author)
if (!testSha) return escalate('Test Author failed across escalation chain', { plan })

// Review tests — opus reviewer, haiku hands showing ONLY the new tests.
phase('Review-tests')
const testReviewIndex = await handsPass(
  `Index only the test changes in ${testSha.sha} across ${allTestFiles.join(', ')} — one pointer per new test.`,
  { phase: 'Review-tests', label: 'test-reviewer hands' })
const testReview = await withEscalation(
  testReviewPrompt(args, plan, testReviewIndex), { phase: 'Review-tests', schema: VERDICT }, args.stageModels.testRev)
if (!testReview) return escalate('Test Reviewer failed across escalation chain', { plan, testSha })
if (!testReview.approved) return escalate('tests rejected — re-author needed', { plan, testSha, findings: testReview.findings })

// Implement — one Implementor + Test Runner pair per slice, dispatched by dep wave.
phase('Impl')
const done = new Set()
let remaining = plan.slices.slice()
while (remaining.length > 0) {
  const ready = remaining.filter(s => (s.deps || []).every(d => done.has(d)))
  if (ready.length === 0) return escalate('slice dependency cycle or unsatisfiable deps', { stranded: remaining.map(s => s.id) })
  const results = await parallel(ready.map(slice => async () => {
    const impl = await withEscalation(implPrompt(args, slice, testSha),
      { phase: 'Impl', label: `impl:${slice.id}`, schema: COMMIT, isolation: 'worktree' }, args.stageModels.impl)
    if (!impl) return { id: slice.id, ok: false, reason: 'implementor failed' }
    if (!(await frozenIntact(slice.testFiles, testSha.sha, 'Impl')))
      return { id: slice.id, ok: false, reason: 'frozen test files modified' }
    const ci = await agent(ciPrompt(args, `slice ${slice.id}`),
      { phase: 'Impl', label: `ci:${slice.id}`, schema: CI_RESULT, model: args.stageModels.ci })
    return { id: slice.id, ok: !!(ci && ci.green), reason: ci && ci.green ? 'green' : 'ci red', impl }
  }))
  const passed = results.filter(r => r && r.ok)
  if (passed.length === 0) return escalate('no slice advanced this wave', { results })
  passed.forEach(r => done.add(r.id))
  remaining = remaining.filter(s => !done.has(s.id))
  log(`forge-issue: ${done.size}/${plan.slices.length} slices green`)
}

// Review — opus reviewer with a hands-built startup index (diff + ADRs).
phase('Review')
const reviewIndex = await handsPass(
  `Index git diff main...HEAD for issue ${args.issueId} plus any decision records (ADRs) it touches.`,
  { phase: 'Review', label: 'reviewer hands' })
let review = await withEscalation(
  reviewPrompt(args, reviewIndex, 'Reviewer'), { phase: 'Review', schema: VERDICT }, args.stageModels.review)
if (!review) return escalate('Reviewer failed across escalation chain')

// Remediate — Implementor + Test Runner pair on findings, bounded at 3 cycles.
let cycles = 0
while (review && !review.approved && cycles < 3) {
  phase('Remediate')
  log(`forge-issue: remediation cycle ${cycles + 1} of 3`)
  const fix = await withEscalation(fixPrompt(args, review.findings, allTestFiles),
    { phase: 'Remediate', schema: COMMIT }, args.stageModels.impl)
  if (!fix) return escalate('remediation implementor failed', { findings: review.findings })
  if (!(await frozenIntact(allTestFiles, testSha.sha, 'Remediate')))
    return escalate('remediation modified frozen test files', { fix })
  const ci = await agent(ciPrompt(args, 'post-remediation'),
    { phase: 'Remediate', label: 'ci:remediation', schema: CI_RESULT, model: args.stageModels.ci })
  if (!ci || !ci.green) return escalate('CI red after remediation', { ci })
  phase('Review')
  const reIndex = await handsPass(
    `Index the remediation diff and the prior review findings for issue ${args.issueId}.`,
    { phase: 'Review', label: 'reviewer hands' })
  review = await withEscalation(
    reviewPrompt(args, reIndex, 'Reviewer'), { phase: 'Review', schema: VERDICT }, args.stageModels.review)
  cycles++
}
if (!review || !review.approved) return escalate('review unresolved after remediation', { review, cycles })

// Final review — opus, fresh context, hands index of prior notes + remediation diff.
phase('Final')
const finalIndex = await handsPass(
  `Index the prior review notes and the full git diff main...HEAD for issue ${args.issueId}.`,
  { phase: 'Final', label: 'final-reviewer hands' })
const final = await withEscalation(
  reviewPrompt(args, finalIndex, 'Final Reviewer'), { phase: 'Final', schema: VERDICT }, args.stageModels.final)
if (!final) return escalate('Final Reviewer failed across escalation chain')

log(`forge-issue: ${args.issueId} → ${final.approved ? 'done' : 'rework'}`)

// Merge approval stays operator-owned — the workflow stops at the green PR.
return {
  status: final.approved ? 'done' : 'rework',
  issueId: args.issueId,
  slices: plan.slices.map(s => s.id),
  testSha: testSha.sha,
  remediationCycles: cycles,
  review,
  final,
}
