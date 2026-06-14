# Workflow Execution Substrate (optional)

Claude Code dynamic workflows are a JavaScript runtime that orchestrates subagents at scale. They are an optional execution substrate for the five-tier decomposition pipeline and its Forge generalization (paired teams + implementor fan-out): when available and opted-in, encode the pipeline as a workflow script so the adversarial separation and stage gates become structural instead of discipline the lead must remember. When unavailable, spawn Task agents exactly as the default path describes. See the `/claude-code:claude-workflows` skill for the full script API, and "Forge: hands-indexed principals and implementor fan-out" below for the fanned-out shape.

## When this applies

The work is already decomposed — issues exist in bees (gate States A, C, or D). The workflow executes issues; it never decomposes them.

Then check two deterministic signals, mirroring the Phase 1.5 gate. Both are required:

1. **Capability:** the `Workflow` tool is present in the session's toolset. Presence is the deterministic capability signal. The version, plan, and configuration requirements behind that availability are documented in the `/claude-code:claude-workflows` skill (managing-runs reference). Do not probe versions, plans, or config flags separately.
2. **Opt-in:** at least one of the three trigger forms from the `/claude-code:claude-workflows` skill ("How to trigger a workflow") holds:
   - the operator's request contains the word "workflow", or
   - `/effort ultracode` is active for the session, or
   - the operator invoked a saved or bundled workflow as `/<workflow-name>`.

Absent either signal, use the default Task-spawn path. Also skip the substrate — even with both signals present — when the run needs mid-flight user input or for a single trivial issue.

## The hard boundary — what stays in the interactive loop

A workflow has no mid-run user input; only an agent's own permission prompt pauses a run. Three responsibilities therefore never move into a workflow:

- **Decomposition and Phase 1.5a clarifying questions** (`AskUserQuestion`). The Team Leader decomposes and clarifies in the main loop, then hands the issue list to the workflow. This matches the existing rule: fan-out happens at the Sub-team Leader, not the epic decomposer.
- **Merge approval** (Phase 4). A workflow drives commit, push, and PR creation up to the squash-merge gate, which stays operator-owned.
- **Escalation to the user** on opus-failure, dependency conflict, or ambiguity. The script surfaces the condition in its return value; the lead escalates.

## Five-tier pipeline as a script

The pipeline's "separate Agent invocation per tier, no SendMessage continuation, each tier adversarial against the next" is automatic — every `agent()` call is a fresh context. The stage gates the lead must verify by hand (`test commit present before P3`, `test files unmodified before P5`) become deterministic assertions between stages.

```javascript
export const meta = {
  name: 'five-tier-issue',
  description: 'Run one complex issue through plan/test/impl/ci/review',
  phases: [
    { title: 'Plan' }, { title: 'Test' }, { title: 'Impl' },
    { title: 'CI' }, { title: 'Review' },
  ],
}

// args = { issueId, acceptanceCriteria, testFiles, skills }
const plan = await agent(planPrompt(args), { phase: 'Plan', schema: TEST_LIST })
const testSha = await agent(testAuthorPrompt(args, plan), { phase: 'Test', schema: COMMIT })
const impl = await agent(implPrompt(args, plan, testSha), { phase: 'Impl', schema: COMMIT })

// Stage gate: the adversarial-TDD diff boundary, enforced not narrated
const touched = await agent(`Return git diff ${testSha.sha}..HEAD -- ${args.testFiles.join(' ')}`, { schema: DIFF })
if (touched.nonEmpty) return { status: 'escalate', reason: 'implementer modified test files', testSha }

const ci = await agent('Run mise run ci, return verbatim output and green/red.', { phase: 'CI', schema: CI_RESULT })
if (!ci.green) return { status: 'ci-red', ci }

const review = await agent(reviewPrompt(args), { phase: 'Review', schema: VERDICT })
return { status: review.approved ? 'done' : 'rework', review }
```

Each stage prompt still names its tier (`You are P2 — test author for issue <id>`) and forbids out-of-stage activity, per the pipeline-collapse rule. The complete runnable version of this abbreviated example — full stage prompts, per-stage `skillProof` schemas, the diff-boundary gate, the escalation ladder, and the bounded fix loop — is `templates/five-tier-issue.workflow.js` in this skill.

## Proof of loading as a schema field

The proof-of-loading rule (see "Proof of loading" in the agent-loop SKILL.md: each spawned agent quotes one sentence from each loaded skill before work proceeds) maps to a required `skillProof` field in every stage schema — an array of `{skill, quote}` objects. Schema validation happens at the tool-call layer and retries on mismatch, so a stage result without proof never reaches the script — the same way the diff-boundary gate became an assertion instead of lead discipline.

```javascript
const COMMIT = {
  type: 'object',
  required: ['sha', 'skillProof'],
  properties: {
    sha: { type: 'string' },
    skillProof: { type: 'array', items: { type: 'object', required: ['skill', 'quote'],
      properties: { skill: { type: 'string' }, quote: { type: 'string' } } } },
  },
}
```

The schema enforces structure, not truth — an agent can still fabricate a quote. Spot-check `skillProof` entries against the named skill files when a stage result looks wrong.

## Model escalation as a retry ladder

The `haiku → sonnet → opus`, max-two-promotions rule and the overridable `AGENT_LOOP_ESCALATION_CHAIN` map to a loop. The chain is read by the process that launches the workflow and passed in via `args` — the model name never appears as a literal in the prompt body.

```javascript
async function withEscalation(prompt, opts, stageModel) {
  // Start at stageModel's position in the chain; fall back to full chain if not found.
  const idx = args.escalationChain.indexOf(stageModel)
  const ladder = idx === -1 ? args.escalationChain.slice() : args.escalationChain.slice(idx)
  for (let i = 0; i < ladder.length; i++) {
    const model = ladder[i]
    const isLast = i === ladder.length - 1
    for (let attempt = 0; attempt < 2; attempt++) {  // two attempts per model before promoting
      try { return await agent(prompt, { ...opts, model }) }
      catch (e) {
        if (!isLast || attempt === 0) log(`escalating: ${model} attempt ${attempt + 1} failed`)
        // no log on final attempt of the last model — nothing follows
      }
    }
  }
  return null // hand back to the lead; caller checks for null and surfaces an escalate result
}
```

## Routing Explore and Plan stages via agentType

The Model Selection table in the agent-loop SKILL.md routes research and codebase exploration to the Explore subagent and architecture design to the Plan subagent; in a workflow script, express that routing with the `agentType` option, which resolves custom subagent types from the same registry as the Agent tool and composes with `schema`.

```javascript
const survey = await agent(researchPrompt(args), { phase: 'Plan', agentType: 'Explore', schema: SURVEY })
```

## Validator ↔ Fix Agent loop-until-green

Phase 3's "Validator and Fix Agent iterate until clean, escalate after 3 stalled cycles" is a bounded loop.

```javascript
let cycles = 0
let ci = await agent('Run mise run ci.', { phase: 'CI', schema: CI_RESULT })
while (!ci.green && cycles < 3) {
  await agent(`Fix these failures without touching tests: ${ci.output}`, { phase: 'Fix' })
  ci = await agent('Run mise run ci.', { phase: 'CI', schema: CI_RESULT })
  cycles++
}
if (!ci.green) return { status: 'escalate', reason: 'validation stalled', ci }
```

## Teams of teams via nested workflow()

The two-tier authority boundary (Team Leader manages the epic, Sub-team Leader runs the pipeline per issue) maps onto `workflow()` nesting, which is allowed exactly one level deep — the same depth as the authority model. The epic workflow runs a dependency-wave loop: recompute the ready set from accumulated completions, dispatch the wave, merge results, repeat. A single up-front readiness filter strands every issue whose dependencies complete during the run — never dispatch from one static filter.

```javascript
// args.issues: [{ id, deps: [issueIds], ...pipelineArgs }]
const completed = new Set()
const escalations = []
const merged = []
let pending = args.issues

while (pending.length > 0) {
  const ready = pending.filter(i => i.deps.every(d => completed.has(d)))
  if (ready.length === 0) {                       // cycle or failed-dependency guard
    log(`stranded issues (unsatisfiable deps): ${pending.map(i => i.id).join(', ')}`)
    break
  }
  const results = await parallel(ready.map(issue => () =>
    workflow('five-tier-issue', issue)))   // one level only; the sub-step does not nest further

  let progressed = false
  ready.forEach((issue, idx) => {
    const res = results[idx]    // a failed thunk resolves to null — stays pending
    if (res && res.status === 'done') {
      // Issue complete — unblocks dependents in the next wave.
      completed.add(issue.id)
      merged.push(res)
      progressed = true
    } else if (res) {
      // Non-done result (rework / escalate) — remove from pending so it is not
      // re-dispatched; surface to the lead for handling outside the workflow.
      // The hard boundary: this script surfaces the condition; the lead escalates.
      escalations.push({ issue, result: res })
    }
    // null (failed thunk) — issue stays in pending; stalled-wave guard below
    // terminates the loop if no progress was made.
  })
  pending = pending.filter(i => !completed.has(i.id) && !escalations.some(e => e.issue.id === i.id))
  if (!progressed) {                              // stalled-wave guard: nothing new completed
    log(`no progress this wave; stranded issues: ${pending.map(i => i.id).join(', ')}`)
    break
  }
}
return { merged, escalations }
```

The per-wave `parallel()` barrier is required, not incidental: each wave's completions are the input to the next readiness computation, so the barrier is the dependency edge itself.

## Worktree isolation solves working-tree contention

The default path forbids git worktrees and uses shallow clones because parallel workers in one tree pollute each other's checkouts. A workflow spawns each parallel implementer with its own auto-cleaned worktree, removing the footgun directly:

```javascript
agent(implPrompt(issue), { isolation: 'worktree' })   // ~200-500ms + disk per agent
```

Use it only for agents that mutate files in parallel; it is expensive and pointless for read-only or single-writer stages.

## Budget-scaled thoroughness and resume

- `budget` scales fan-out to the operator's token directive. Guard on `budget.total` (null when no target is set, which makes `remaining()` Infinity).
- Long epic runs are resumable in-session via `{ scriptPath, resumeFromRunId }`: completed stages replay from cache, the rest run live. This complements bees — bees is the durable cross-session tracker; resume is the in-session fast-replay.

## Budget-gated P5 review panel

The single-opus P5 reviewer is the default. When `budget.total` is set and `budget.remaining()` leaves headroom, run P5 as a panel of distinct lenses — acceptance-criteria coverage, overfit-to-tests, missed edge cases — one `agent()` per lens via `parallel()`. Take the majority verdict; forward the rejecting lenses' findings to the rework dispatch. Guard on `budget.total`, not `remaining()`: `budget.total` is `null` when no target is set, which makes `remaining()` `Infinity` and the guard always true.

```javascript
let review
if (budget.total && budget.remaining() > 150_000) {
  const lenses = ['acceptance-criteria coverage', 'overfit-to-tests', 'missed edge cases']
  const verdicts = (await parallel(lenses.map(lens => () =>
    agent(reviewPrompt(args, lens), { phase: 'Review', schema: VERDICT })))).filter(Boolean)
  const rejecting = verdicts.filter(v => !v.approved)
  review = { approved: rejecting.length < verdicts.length / 2,
             findings: rejecting.flatMap(v => v.findings) }   // input to the rework dispatch
} else {
  review = await agent(reviewPrompt(args), { phase: 'Review', schema: VERDICT })
}
```

Distinct lenses catch failure modes redundant identical reviewers cannot: one prompt asking "is this correct?" three times converges on the same blind spot, while three single-concern prompts each interrogate a different way the implementation can pass CI and still be wrong.

## Forge: hands-indexed principals and implementor fan-out

The five-tier script above is the `N=1` linear case. **Forge** generalizes it: a hands pass feeds
each principal a startup index, and the single implementer becomes `N` implementor + test-runner
pairs across the planner's slices. The complete runnable script is `templates/forge-issue.workflow.js`.

Each principal stage is preceded by a hands pass whose index becomes the stage's startup context —
the same `agentType: 'Explore'` routing as the survey example above, with the model chosen by
capability:

```javascript
function handsPass(objective, vision) {
  const o = { schema: INDEX, model: vision ? args.handsVisionModel : args.handsModel }
  if (!vision) o.agentType = 'Explore'         // text/code; vision needs a multimodal model, not Explore
  return agent(handsPrompt(objective, vision), o)
}
const planIndex = await handsPass(`Index the specs + target modules for ${args.issueId}.`, false)
const plan = await agent(planPrompt(args, planIndex), { phase: 'Plan', schema: TEST_PLAN })
```

The planner returns slices; implementor pairs fan out by dependency wave (the per-wave `parallel()`
barrier is the dependency edge, exactly as in the epic loop). Each slice runs implementor →
diff-boundary gate → test runner; `isolation: 'worktree'` keeps parallel implementors from polluting
one tree:

```javascript
const ready = remaining.filter(s => (s.deps || []).every(d => done.has(d)))
const results = await parallel(ready.map(slice => async () => {
  const impl = await agent(implPrompt(args, slice, testSha),
    { phase: 'Impl', label: `impl:${slice.id}`, schema: COMMIT, isolation: 'worktree' })
  // frozenIntact() checks BOTH git diff testSha..HEAD AND git status --porcelain on the test files
  if (!impl || !(await frozenIntact(slice.testFiles, testSha.sha, 'Impl'))) return { id: slice.id, ok: false }
  const ci = await agent(ciPrompt(args, slice.id), { phase: 'Impl', schema: CI_RESULT, model: args.stageModels.ci })
  return { id: slice.id, ok: !!(ci && ci.green) }
}))
```

Reviewers run on the best-thinker model (`stageModels.review` / `.final`, opus by default) with
haiku hands; the Reviewer's findings drive a Remediation pair (implementor + test-runner) bounded at
three cycles, then a fresh-context Final Reviewer with its own hands index.

### Invoke as `/forge-issue`

Save `forge-issue.workflow.js` to `.claude/workflows/` and trigger it by any of the three forms in
`/claude-code:claude-workflows` ("How to trigger a workflow"): the operator's request contains
"workflow", `/effort ultracode` is active, or the operator invokes `/forge-issue` directly. The
`/work` command (interactive operator front door) loads `/core:agent-loop` and runs Forge, dispatching
this workflow per issue when the substrate is opted-in.

At the epic level, the nested `workflow()` dep-wave loop is unchanged — swap the per-issue call:

```javascript
const results = await parallel(ready.map(issue => () => workflow('forge-issue', issue)))
```

## Permissions and limits

Workflow agents run in `acceptEdits` mode and inherit the session's tool allowlist regardless of session mode. Concurrent `agent()` calls cap at `min(16, cpu_cores - 2)`; lifetime cap is 1000 agents per run. Scripts are plain JavaScript — no TypeScript annotations, and `Date.now()` / `Math.random()` / argless `new Date()` throw. Pass timestamps and the escalation chain through `args`.
