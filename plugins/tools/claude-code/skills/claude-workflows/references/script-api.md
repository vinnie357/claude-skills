# Workflow Script API

Full reference for the hooks and globals available inside a workflow script. The script is plain JavaScript running in an async context. Source: the Claude Code Workflow tool contract.

## Table of contents

- [meta block](#meta-block)
- [agent()](#agent)
- [pipeline()](#pipeline)
- [parallel()](#parallel)
- [phase() and log()](#phase-and-log)
- [workflow()](#workflow)
- [args global](#args-global)
- [budget global](#budget-global)
- [Structured output (schema)](#structured-output-schema)
- [Worktree isolation](#worktree-isolation)
- [Model overrides](#model-overrides)
- [Resume and runId](#resume-and-runid)
- [Concurrency and caps](#concurrency-and-caps)

## meta block

Every script begins with `export const meta = {...}` as a pure literal — no variables, function calls, spreads, or template interpolation.

- `name` (required) — workflow identifier.
- `description` (required) — one line, shown in the permission dialog.
- `phases` (optional) — one entry per `phase()` call: `{ title, detail }`. Match titles exactly to `phase()` calls so progress groups align. Add `model` to a phase entry when that phase uses a model override.
- `whenToUse` (optional) — shown in the saved-workflow list.

A `phase()` call with no matching `meta.phases` entry still gets its own progress group.

## agent()

```
agent(prompt: string, opts?: {
  label?: string,
  phase?: string,
  schema?: object,
  model?: string,
  isolation?: 'worktree',
  agentType?: string
}): Promise<any>
```

Spawns one subagent. Without `schema`, returns the agent's final text as a string. With `schema`, the agent is forced to call a StructuredOutput tool and `agent()` returns the validated object. Returns `null` if the user skips the agent mid-run — filter with `.filter(Boolean)`.

- `label` — overrides the display label.
- `phase` — explicitly assigns this agent to a progress group. Use inside `pipeline()`/`parallel()` stages to avoid races on the global `phase()` state.
- `model` — overrides the model for this call (see [Model overrides](#model-overrides)).
- `isolation: 'worktree'` — runs in a fresh git worktree (see [Worktree isolation](#worktree-isolation)).
- `agentType` — uses a custom subagent type (e.g. `'Explore'`) instead of the default workflow subagent. Resolved from the same registry as the Agent tool; composes with `schema`.

Subagents are told their final text IS the return value, so they return raw data, not human-facing prose.

## pipeline()

```
pipeline(items, stage1, stage2, ...): Promise<any[]>
```

Runs each item through all stages independently — NO barrier between stages. Item A can be in stage 3 while item B is still in stage 1. This is the default for multi-stage work; wall-clock equals the slowest single-item chain.

Every stage callback receives `(prevResult, originalItem, index)` — use `originalItem`/`index` in later stages to label work without threading context through earlier returns. A stage that throws drops that item to `null` and skips its remaining stages.

## parallel()

```
parallel(thunks: Array<() => Promise<any>>): Promise<any[]>
```

Runs tasks concurrently and awaits all of them — a BARRIER. A thunk that throws (or whose agent errors) resolves to `null` in the result array; the call itself never rejects, so `.filter(Boolean)` before using results.

Use only when stage N needs all of stage N-1 together: dedup/merge across the full set, early-exit on a zero count, or a prompt that references the other findings. Flatten/map/filter alone do not justify a barrier — do them inside a pipeline stage.

## phase() and log()

```
phase(title: string): void
log(message: string): void
```

`phase()` starts a new progress group; subsequent `agent()` calls group under it. `log()` emits a narrator line above the progress tree. Inside `pipeline()`/`parallel()` stages, prefer `agent(..., { phase: 'X' })` over the global `phase()` to avoid races.

## workflow()

```
workflow(nameOrRef: string | { scriptPath: string }, args?: any): Promise<any>
```

Runs another workflow inline as a sub-step and returns its result. Pass a name to invoke a saved workflow, or `{ scriptPath }` to run a script file. The child shares this run's concurrency cap, agent counter, abort signal, and token budget; its agents appear under a `▸ name` group in `/workflows` and its tokens count toward `budget.spent()`. The `args` param becomes the child's `args` global. Nesting is one level only — `workflow()` inside a child throws. Throws on unknown name, unreadable scriptPath, or child syntax error; catch to handle gracefully.

## args global

`args` is the value passed as the Workflow tool's `args` input, verbatim (`undefined` if not provided). Pass arrays/objects as actual JSON values, not a JSON-encoded string — a stringified list reaches the script as one string, so `args.filter`/`args.map` throw. Use it to parameterize saved workflows (a research question, a target path, a config object).

## budget global

```
budget: { total: number|null, spent(): number, remaining(): number }
```

The turn's token target from a `+500k`-style directive. `budget.total` is `null` if no target was set. `budget.spent()` returns output tokens spent this turn across the main loop and all workflows — the pool is shared. `budget.remaining()` returns `max(0, total - spent())`, or `Infinity` if no target. The target is a hard ceiling: once `spent()` reaches `total`, further `agent()` calls throw.

Guard budget loops on `budget.total` — with no target, `remaining()` is `Infinity` and the loop runs to the 1000-agent cap:

```javascript
while (budget.total && budget.remaining() > 50_000) {
  const r = await agent('Find bugs in this codebase.', { schema: BUGS })
  bugs.push(...r.bugs)
}
```

## Structured output (schema)

Pass a JSON Schema as `opts.schema` and the agent is forced to call a StructuredOutput tool; `agent()` returns the validated object. Validation happens at the tool-call layer, so the model retries on mismatch — no parsing in the script. This is the reliable way to get machine-readable data back from an agent.

## Worktree isolation

`isolation: 'worktree'` runs the agent in a fresh git worktree — expensive (~200-500ms setup plus disk per agent). Use only when agents mutate files in parallel and would otherwise conflict. The worktree is auto-removed if unchanged.

## Model overrides

`opts.model` overrides the model for one `agent()` call. Default to omitting it — the agent inherits the main-loop model (the resolved session model), which is almost always correct. Set it only when highly confident a different tier fits the task; when unsure, omit.

## Resume and runId

Every invocation persists its script under the session directory and returns a `scriptPath` and a `runId` in the tool result. To resume after a pause, kill, or script edit, relaunch with `{ scriptPath, resumeFromRunId }`. The longest unchanged prefix of `agent()` calls returns cached results instantly; the first edited or new call and everything after it runs live. Same script + same args → 100% cache hit. Resume is same-session only; stop the prior run before resuming.

To iterate on a workflow, edit the persisted script file and re-invoke with `{ scriptPath }` instead of resending the full script inline.

## Concurrency and caps

Concurrent `agent()` calls cap at `min(16, cpu_cores - 2)` per workflow; excess calls queue and run as slots free. `parallel()`/`pipeline()` still accept 100+ items — they all complete, only ~10 run at any moment. Total agent count across a workflow's lifetime caps at 1000 (a runaway-loop backstop). Child workflows share the parent's cap and counter.
