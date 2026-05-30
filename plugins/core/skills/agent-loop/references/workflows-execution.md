# Workflow Execution Substrate (optional)

Claude Code dynamic workflows are a JavaScript runtime that orchestrates subagents at scale. They are an optional execution substrate for the five-tier decomposition pipeline: when available and opted-in, encode the pipeline as a workflow script so the adversarial separation and stage gates become structural instead of discipline the lead must remember. When unavailable, spawn Task agents exactly as the default path describes. See the `/claude-code:claude-workflows` skill for the full script API.

## When this applies

- The work is already decomposed — issues exist in bees (gate States A, C, or D). The workflow executes issues; it never decomposes them.
- The session is on a paid plan with workflows enabled, and the operator opts in (the word "workflow" in the request, `/effort ultracode`, or a saved workflow command).

Skip the substrate and use Task spawns when workflows are disabled, when the run needs mid-flight user input, or for a single trivial issue.

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

Each stage prompt still names its tier (`You are P2 — test author for issue <id>`) and forbids out-of-stage activity, per the pipeline-collapse rule.

## Model escalation as a retry ladder

The `haiku → sonnet → opus`, max-two-promotions rule and the overridable `AGENT_LOOP_ESCALATION_CHAIN` map to a loop. The chain is read by the process that launches the workflow and passed in via `args` — the model name never appears as a literal in the prompt body.

```javascript
async function withEscalation(prompt, opts) {
  for (const model of args.escalationChain) {        // e.g. ['haiku','sonnet','opus']
    try { return await agent(prompt, { ...opts, model }) }
    catch (e) { log(`escalating from ${model}`) }
  }
  return { status: 'escalate', reason: 'opus failed' } // hand back to the lead
}
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

The two-tier authority boundary (Team Leader manages the epic, Sub-team Leader runs the pipeline per issue) maps onto `workflow()` nesting, which is allowed exactly one level deep — the same depth as the authority model. The epic workflow fans over ready issues; each issue runs the five-tier pipeline as a sub-step.

```javascript
const ready = args.issues.filter(i => i.depsSatisfied)
const results = await parallel(ready.map(issue => () =>
  workflow('five-tier-issue', issue)))   // one level only; the sub-step does not nest further
return results.filter(Boolean)
```

Respect dependency ordering in the lead's selection of `ready` — do not pass an issue whose dependencies have not completed.

## Worktree isolation solves working-tree contention

The default path forbids git worktrees and uses shallow clones because parallel workers in one tree pollute each other's checkouts. A workflow spawns each parallel implementer with its own auto-cleaned worktree, removing the footgun directly:

```javascript
agent(implPrompt(issue), { isolation: 'worktree' })   // ~200-500ms + disk per agent
```

Use it only for agents that mutate files in parallel; it is expensive and pointless for read-only or single-writer stages.

## Budget-scaled thoroughness and resume

- `budget` scales fan-out to the operator's token directive. Guard on `budget.total` (null when no target is set, which makes `remaining()` Infinity).
- Long epic runs are resumable in-session via `{ scriptPath, resumeFromRunId }`: completed stages replay from cache, the rest run live. This complements bees — bees is the durable cross-session tracker; resume is the in-session fast-replay.

## Permissions and limits

Workflow agents run in `acceptEdits` mode and inherit the session's tool allowlist regardless of session mode. Concurrent `agent()` calls cap at `min(16, cpu_cores - 2)`; lifetime cap is 1000 agents per run. Scripts are plain JavaScript — no TypeScript annotations, and `Date.now()` / `Math.random()` / argless `new Date()` throw. Pass timestamps and the escalation chain through `args`.
