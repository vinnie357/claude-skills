// five-tier-issue.workflow.js — runnable Claude Code workflow script for the
// five-tier pipeline (P1 plan / P2 test / P3 impl / P4 CI / P5 review).
// Complete version of the abbreviated example in references/workflows-execution.md.
//
// This is the N=1 linear case. Forge (templates/forge-issue.workflow.js) is the
// canonical shape: it adds hands-built startup indexes per principal and fans the
// single implementer out to N implementor+test-runner pairs across the planner's
// slices. Use this script for a one-slice issue; use forge-issue.workflow.js otherwise.
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
//     "stageModels": {
//       "plan":   "opus",    // P1 — doctrine default: opus
//       "test":   "sonnet",  // P2 — doctrine default: sonnet
//       "impl":   "sonnet",  // P3 — doctrine default: sonnet
//       "ci":     "haiku",   // P4 — doctrine default: haiku
//       "review": "opus"     // P5 — doctrine default: opus
//     },
//     "repo": "/absolute/path/to/repo"
//   }
//
// Doctrine defaults above are from the Five-Tier Decomposition Pipeline table in
// plugins/core/skills/agent-loop/SKILL.md. The caller supplies them — no model
// name is hardcoded in this script (12-factor rule: config comes from args).
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
    'The deliberate red must be assertion failures or missing symbols in the',
    "PROJECT's own modules — a compile error naming a stdlib or third-party",
    'API is the test author\'s bug and blocks handoff, not a valid red. If a',
    'test needs a symbol that does not exist yet, write a throwaway stub',
    "module satisfying just the referenced symbols, compile the test file",
    'against the stub (it must build, failing only on assertions), then',
    'DELETE the stub before committing so the red is real.',
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
    'Require a clean working tree before reporting green — a dirty tree green is an illusion.',
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
    'If the fix cannot land within these prohibitions, ESCALATE — never shim.',
    'Never vendor, fork, overlay, or redirect the language stdlib or toolchain;',
    'a removed API means migrate the call site or escalate, not paper over it.',
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
// Escalation ladder — starts at the stage's designated model and escalates
// through the suffix of args.escalationChain from that model onward.
// Falls back to the full chain when the stage model is not found in the chain
// (e.g. an opus start yields ['opus'] — no promotion, escalate upstream on
// failure, matching doctrine). Each model is attempted twice before promoting.
// Returns null when the whole ladder fails.
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
      try {
        return await agent(prompt, { ...opts, model })
      } catch (e) {
        if (!isLast || attempt === 0) {
          log(`${opts.phase || 'stage'}: failed on ${model} (attempt ${attempt + 1})`)
        }
      }
    }
    if (!isLast) {
      log(`${opts.phase || 'stage'}: promoting from ${model} to ${ladder[i + 1]}`)
    }
  }
  return null
}

function escalate(reason, extra) {
  return { status: 'escalate', issueId: args.issueId, reason, ...extra }
}

// Diff-boundary gate: the implementer must not have touched the frozen test
// files, committed OR uncommitted. Re-checked after the fix loop, not only
// before it — an implementer can make frozen tests pass via uncommitted
// edits, which a committed-diff-only gate misses.
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
// Pipeline — sequential; every agent() call is a fresh context, so the
// adversarial separation between tiers is structural.
// ---------------------------------------------------------------------------

log(`five-tier-issue: starting ${args.issueId}`)

// P1 — test planner
const plan = await withEscalation(planPrompt(args), { phase: 'Plan', schema: TEST_PLAN }, args.stageModels.plan)
if (!plan) return escalate('P1 planner failed across escalation chain')

// P2 — test author (frozen on commit)
const testSha = await withEscalation(testAuthorPrompt(args, plan), { phase: 'Test', schema: COMMIT }, args.stageModels.test)
if (!testSha) return escalate('P2 test author failed across escalation chain', { plan })

// P3 — implementer (separate invocation; cannot modify test files)
const impl = await withEscalation(implPrompt(args, testSha), { phase: 'Impl', schema: COMMIT }, args.stageModels.impl)
if (!impl) return escalate('P3 implementer failed across escalation chain', { testSha })

// Stage gate: adversarial diff boundary, enforced not narrated. Checks both
// the committed diff AND uncommitted working-tree state (frozenIntact).
if (!(await frozenIntact(args.testFiles, testSha.sha, 'Impl'))) {
  return escalate('implementer modified test files (diff boundary violated)', { testSha, impl })
}

// P4 — CI runner + bounded validator/fix loop (3 cycles, then escalate)
let ci = await agent(ciPrompt(args), { phase: 'CI', schema: CI_RESULT, model: args.stageModels.ci })
let cycles = 0
while (ci && !ci.green && cycles < 3) {
  log(`CI red — fix cycle ${cycles + 1} of 3`)
  await withEscalation(fixPrompt(args, ci.output), { phase: 'CI', schema: COMMIT }, args.stageModels.ci)
  ci = await agent(ciPrompt(args), { phase: 'CI', schema: CI_RESULT, model: args.stageModels.ci })
  cycles++
}
if (!ci || !ci.green) {
  return escalate('validation stalled after 3 fix cycles', { testSha, impl, ci })
}

// Re-check the diff-boundary gate after the fix loop, not only before it —
// a fix cycle can reintroduce a frozen-test edit that the pre-CI check missed.
if (!(await frozenIntact(args.testFiles, testSha.sha, 'CI'))) {
  return escalate('fix loop modified test files (diff boundary violated)', { testSha, impl, ci })
}

// P5 — reviewer
const review = await withEscalation(reviewPrompt(args), { phase: 'Review', schema: VERDICT }, args.stageModels.review)
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
