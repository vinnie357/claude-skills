// five-tier-issue.workflow.js — runnable Claude Code workflow script for the
// five-tier pipeline (P1 plan / P2 test / P3 impl / P4 CI / P5 review).
// Complete version of the abbreviated example in references/workflows-execution.md.
//
// Run via the Workflow tool with { scriptPath } pointing at this file, or save
// to .claude/workflows/ and invoke as /five-tier-issue. Expected args:
//
//   {
//     "issueId": "repo-42",
//     "acceptanceCriteria": ["GET /health returns 200", "..."],
//     "testFiles": ["test/health_test.exs"],
//     "skills": ["/core:anti-fabrication", "/core:tdd", "/core:git"],
//     "escalationChain": ["haiku", "sonnet", "opus"],
//     "repo": "/absolute/path/to/repo"
//   }
//
// Constraints (from /claude-code:claude-workflows): plain JavaScript only;
// Date.now(), Math.random(), and argless new Date() throw — pass timestamps
// and the escalation chain through args. The script has no filesystem or
// shell access; agents do that work.

export const meta = {
  name: 'five-tier-issue',
  description: 'Run one issue through the five-tier pipeline: plan, test, implement, CI, review',
  phases: [
    { title: 'Plan', detail: 'P1 designs the test list from acceptance criteria' },
    { title: 'Test', detail: 'P2 writes failing tests and commits them' },
    { title: 'Impl', detail: 'P3 makes the tests pass; test files frozen' },
    { title: 'CI', detail: 'P4 runs mise run ci; fix loop bounded at 3 cycles' },
    { title: 'Review', detail: 'P5 verifies acceptance criteria and approves or rejects' },
  ],
}

// ---------------------------------------------------------------------------
// Schemas — every tier stage requires skillProof (proof-of-loading rule).
// Schema validation happens at the tool-call layer and retries on mismatch,
// so a stage result without proof never reaches the script.
// ---------------------------------------------------------------------------

const SKILL_PROOF = {
  type: 'array',
  minItems: 1,
  items: {
    type: 'object',
    required: ['skill', 'quote'],
    properties: { skill: { type: 'string' }, quote: { type: 'string' } },
  },
}

const TEST_PLAN = {
  type: 'object',
  required: ['tests', 'skillProof'],
  properties: {
    tests: {
      type: 'array',
      minItems: 1,
      items: {
        type: 'object',
        required: ['name', 'criterion'],
        properties: { name: { type: 'string' }, criterion: { type: 'string' } },
      },
    },
    skillProof: SKILL_PROOF,
  },
}

const COMMIT = {
  type: 'object',
  required: ['sha', 'summary', 'skillProof'],
  properties: {
    sha: { type: 'string' },
    summary: { type: 'string' },
    skillProof: SKILL_PROOF,
  },
}

// Mechanical diff probe — not one of the five tiers, no skills to prove.
const DIFF = {
  type: 'object',
  required: ['nonEmpty'],
  properties: { nonEmpty: { type: 'boolean' }, diff: { type: 'string' } },
}

const CI_RESULT = {
  type: 'object',
  required: ['green', 'output', 'skillProof'],
  properties: {
    green: { type: 'boolean' },
    output: { type: 'string' },
    skillProof: SKILL_PROOF,
  },
}

const VERDICT = {
  type: 'object',
  required: ['approved', 'findings', 'skillProof'],
  properties: {
    approved: { type: 'boolean' },
    findings: { type: 'array', items: { type: 'string' } },
    skillProof: SKILL_PROOF,
  },
}

// ---------------------------------------------------------------------------
// Prompt builders — each names its tier, lists the skills to load, forbids
// out-of-stage activity (pipeline-collapse rule), and requires skillProof.
// ---------------------------------------------------------------------------

function skillBlock(skills) {
  return [
    'FIRST step: invoke the Skill tool for each skill below by exact name.',
    'Quote one verbatim sentence from each loaded skill in the skillProof',
    'field of your structured output — "I loaded X" is insufficient evidence.',
    ...skills.map(s => `- ${s}`),
  ].join('\n')
}

function planPrompt(a) {
  return [
    `You are P1 — test planner for issue ${a.issueId} in repo ${a.repo}.`,
    skillBlock(a.skills),
    'Design the test list from these acceptance criteria:',
    ...a.acceptanceCriteria.map(c => `- ${c}`),
    `Tests will live in: ${a.testFiles.join(', ')}.`,
    'Read the existing code and test conventions in the repo before designing.',
    'STAY IN STAGE: design the test list only. Do NOT write test code,',
    'implementation code, run CI, or review work.',
    'Return one entry per test: its name and the acceptance criterion it covers.',
  ].join('\n')
}

function testAuthorPrompt(a, plan) {
  return [
    `You are P2 — test author for issue ${a.issueId} in repo ${a.repo}.`,
    skillBlock(a.skills),
    'Write FAILING tests implementing exactly this plan (one test per entry):',
    JSON.stringify(plan.tests),
    `Write tests ONLY in: ${a.testFiles.join(', ')}.`,
    'Run the full CI task (mise run ci) and confirm the ONLY failures are the',
    'new tests, then commit with a test: conventional commit and push.',
    'STAY IN STAGE: do NOT write implementation code, modify lib/src files,',
    'or review work. The deliberate red is the spec.',
    'Return the commit sha and a one-line summary.',
  ].join('\n')
}

function implPrompt(a, testSha) {
  return [
    `You are P3 — implementer for issue ${a.issueId} in repo ${a.repo}.`,
    skillBlock(a.skills),
    `Check out test commit ${testSha.sha} and make its failing tests pass.`,
    `Test files are FROZEN: ${a.testFiles.join(', ')}.`,
    `Verify before you commit: git diff ${testSha.sha}..HEAD -- ${a.testFiles.join(' ')} must be empty.`,
    'If a test is genuinely wrong, STOP and say so in your summary — do not edit it.',
    'STAY IN STAGE: implement only. Do NOT redesign the plan, rewrite tests,',
    'or self-review.',
    'Commit with a conventional commit and return the commit sha and a one-line summary.',
  ].join('\n')
}

function ciPrompt(a) {
  return [
    `You are P4 — CI runner for issue ${a.issueId} in repo ${a.repo}.`,
    skillBlock(a.skills),
    'Run mise run ci. Capture the verbatim output and report green or red.',
    'STAY IN STAGE: run and report only. Do NOT fix failures, edit files,',
    'or commit anything.',
  ].join('\n')
}

function fixPrompt(a, output) {
  return [
    `You are the fix agent for issue ${a.issueId} in repo ${a.repo}.`,
    skillBlock(a.skills),
    'Fix these CI failures, then commit:',
    output,
    `Test files are FROZEN: ${a.testFiles.join(', ')}. Do NOT modify them.`,
    'STAY IN STAGE: fix the reported failures only. Do NOT add features,',
    'rewrite tests, or refactor beyond the failures.',
    'Return the commit sha and a one-line summary.',
  ].join('\n')
}

function reviewPrompt(a) {
  return [
    `You are P5 — reviewer for issue ${a.issueId} in repo ${a.repo}.`,
    skillBlock(a.skills),
    'Verify each acceptance criterion is exercised by a test and satisfied by',
    'the implementation:',
    ...a.acceptanceCriteria.map(c => `- ${c}`),
    'Check for overfit-to-tests and missed edge cases.',
    'STAY IN STAGE: read and judge only. Do NOT edit files, run fixes,',
    'or commit anything.',
    'Return approved true/false plus a findings list (empty when approved).',
  ].join('\n')
}

// ---------------------------------------------------------------------------
// Escalation ladder — haiku → sonnet → opus by default; the chain comes from
// args so no model name is hardcoded. Returns null when the whole chain fails.
// ---------------------------------------------------------------------------

async function withEscalation(prompt, opts) {
  for (const model of args.escalationChain) {
    try {
      return await agent(prompt, { ...opts, model })
    } catch (e) {
      log(`${opts.phase || 'stage'}: failed on ${model}, promoting`)
    }
  }
  return null
}

function escalate(reason, extra) {
  return { status: 'escalate', issueId: args.issueId, reason, ...extra }
}

// ---------------------------------------------------------------------------
// Pipeline — sequential; every agent() call is a fresh context, so the
// adversarial separation between tiers is structural.
// ---------------------------------------------------------------------------

log(`five-tier-issue: starting ${args.issueId}`)

// P1 — test planner
const plan = await withEscalation(planPrompt(args), { phase: 'Plan', schema: TEST_PLAN })
if (!plan) return escalate('P1 planner failed across escalation chain')

// P2 — test author (frozen on commit)
const testSha = await withEscalation(testAuthorPrompt(args, plan), { phase: 'Test', schema: COMMIT })
if (!testSha) return escalate('P2 test author failed across escalation chain', { plan })

// P3 — implementer (separate invocation; cannot modify test files)
const impl = await withEscalation(implPrompt(args, testSha), { phase: 'Impl', schema: COMMIT })
if (!impl) return escalate('P3 implementer failed across escalation chain', { testSha })

// Stage gate: adversarial diff boundary, enforced not narrated.
const touched = await agent(
  [
    `In repo ${args.repo}, run: git diff ${testSha.sha}..HEAD -- ${args.testFiles.join(' ')}`,
    'Report nonEmpty=true when the diff has any content, with the diff text.',
    'Run the command and report — do not edit anything.',
  ].join('\n'),
  { phase: 'Impl', label: 'diff-boundary gate', schema: DIFF },
)
if (!touched || touched.nonEmpty) {
  return escalate('implementer modified test files (diff boundary violated)', { testSha, impl, touched })
}

// P4 — CI runner + bounded validator/fix loop (3 cycles, then escalate)
let ci = await agent(ciPrompt(args), { phase: 'CI', schema: CI_RESULT })
let cycles = 0
while (ci && !ci.green && cycles < 3) {
  log(`CI red — fix cycle ${cycles + 1} of 3`)
  await withEscalation(fixPrompt(args, ci.output), { phase: 'CI', schema: COMMIT })
  ci = await agent(ciPrompt(args), { phase: 'CI', schema: CI_RESULT })
  cycles++
}
if (!ci || !ci.green) {
  return escalate('validation stalled after 3 fix cycles', { testSha, impl, ci })
}

// P5 — reviewer
const review = await withEscalation(reviewPrompt(args), { phase: 'Review', schema: VERDICT })
if (!review) return escalate('P5 reviewer failed across escalation chain', { testSha, impl, ci })

log(`five-tier-issue: ${args.issueId} → ${review.approved ? 'done' : 'rework'}`)

// Merge approval stays operator-owned (Phase 4) — the workflow stops here.
return {
  status: review.approved ? 'done' : 'rework',
  issueId: args.issueId,
  testSha: testSha.sha,
  implSha: impl.sha,
  ciGreen: ci.green,
  fixCycles: cycles,
  review,
}
