---
name: claude-workflows
description: Guide for Claude Code dynamic workflows — JavaScript scripts that orchestrate many subagents in one background run. Use when a task needs more agents than one conversation can coordinate, codifying repeatable orchestration, running codebase-wide sweeps or large migrations, authoring or reading a workflow script, or deciding between a workflow, a subagent, and a skill.
license: MIT
---

# Claude Code Workflows

A dynamic workflow is a JavaScript script that orchestrates subagents at scale. Claude writes the script for a task you describe, a runtime executes it in the background, and only the final answer returns to your conversation. The script — not Claude's context — holds the loop, the branching, and the intermediate results, so one run coordinates tens to hundreds of agents instead of the few a single turn manages.

Status: research preview, Claude Code v2.1.154+. Available on paid plans (Pro toggle in `/config`; Max, Team, Enterprise) and via the Anthropic API, Amazon Bedrock, Google Cloud Vertex AI, and Microsoft Foundry.

## When to use a workflow

Reach for a workflow when fan-out exceeds one turn, when the orchestration itself must be repeatable, or when work needs independent verification passes before results reach you. Examples: a codebase-wide bug sweep, a 500-file migration, research that cross-checks sources, or a hard plan drafted from several angles before commitment.

Use a single subagent (the `Agent` tool) for one-off delegated work whose result lands directly in your context. Use a skill for instructions Claude follows inline. Use a workflow when neither scales.

| Aspect | Subagents | Skills | Workflows |
|--------|-----------|--------|-----------|
| Scale | A few tasks per turn | Same as subagents | Dozens to hundreds of agents per run |
| Intermediate results live in | Claude's context | Claude's context | Script variables |
| What's repeatable | Worker definition | Instructions | The orchestration itself |
| Interruption | Restarts the turn | Restarts the turn | Resumable in the same session |

## How to trigger a workflow

Workflows require explicit opt-in. Three paths:

1. **Include the word "workflow" in the prompt.** Claude writes and runs a workflow script for the task — e.g. `Run a workflow to audit every endpoint under src/routes/ for missing auth checks`.
2. **`/effort ultracode`.** Combines `xhigh` reasoning with automatic orchestration; Claude decides per task when a workflow is warranted. One request can spawn several workflows (understand → change → verify).
3. **Run a saved or bundled workflow** as `/<name>`. `/deep-research` is the built-in workflow; scripts saved to `.claude/workflows/` become their own commands.

## Script anatomy

Every script begins with a pure-literal `export const meta = {...}` block, then a body that uses the orchestration hooks. The body runs in an async context — `await` directly.

```javascript
export const meta = {
  name: 'audit-endpoints',
  description: 'Find endpoints missing auth checks and propose fixes',
  phases: [
    { title: 'Scan', detail: 'list route files' },
    { title: 'Review', detail: 'one agent per route file' },
  ],
}

phase('Scan')
const files = await agent('List every route file under src/routes/.', { schema: FILES_SCHEMA })

phase('Review')
const findings = await parallel(files.paths.map(p => () =>
  agent(`Check ${p} for endpoints missing auth middleware.`, { schema: FINDING_SCHEMA })))

return findings.filter(Boolean)
```

`meta` must be a pure literal — no variables, function calls, spreads, or template interpolation. Required fields: `name`, `description`. Reuse the same `phase()` titles in `meta.phases` so progress groups match.

## Core hooks at a glance

- `agent(prompt, opts?)` — spawn one subagent; returns its final text, or a validated object when `opts.schema` is set. Options: `label`, `phase`, `schema`, `model`, `isolation`, `agentType`.
- `pipeline(items, ...stages)` — run each item through all stages independently, no barrier between stages. The default for multi-stage work.
- `parallel(thunks)` — run thunks concurrently and await all (a barrier). A thunk that throws resolves to `null`; `.filter(Boolean)` before use.
- `phase(title)` — start a progress group; later `agent()` calls fall under it.
- `log(message)` — emit a narrator line to the user.
- `workflow(nameOrRef, args?)` — run another saved workflow inline as a sub-step (one level of nesting only).
- `args` — the value passed as the workflow's input. `budget` — the turn's token target (`budget.total`, `budget.spent()`, `budget.remaining()`).

Full signatures, return values, schema usage, worktree isolation, model overrides, and resume in `references/script-api.md`.

## pipeline() vs parallel()

Default to `pipeline()`. It streams each item through every stage with no synchronization point, so item A reaches stage 3 while item B is still in stage 1 — wall-clock equals the slowest single chain, not the sum of slowest-per-stage.

Use `parallel()` only when stage N genuinely needs every result of stage N-1 at once: dedup or merge across the full set, early-exit on a zero count, or a prompt that compares against "the other findings." Needing to flatten, map, or filter is not a barrier reason — do that inside a pipeline stage.

```javascript
// pipeline — review and verify stream per-item, no wasted wall-clock
const results = await pipeline(
  dimensions,
  d => agent(d.prompt, { phase: 'Review', schema: FINDINGS }),
  review => parallel(review.findings.map(f => () =>
    agent(`Adversarially verify: ${f.title}`, { phase: 'Verify', schema: VERDICT })
      .then(v => ({ ...f, verdict: v })))),
)
```

Orchestration patterns (adversarial verify, judge panel, loop-until-dry, multi-modal sweep, completeness critic) are in `references/patterns.md`.

## Constraints

- JavaScript only — no TypeScript type annotations, interfaces, or generics.
- `Date.now()`, `Math.random()`, and argless `new Date()` throw (they break resume). Pass timestamps via `args`; vary randomness by index.
- The script has no filesystem or shell access — agents do that work; the script coordinates them.
- Concurrent `agent()` calls cap at `min(16, cpu_cores - 2)` per workflow; excess queues. Lifetime cap is 1000 agents per run.
- Spawned agents run in `acceptEdits` mode and inherit the session's tool allowlist regardless of session mode.
- No mid-run user input — only an agent's own permission prompt can pause a run.

## Managing runs

Run `/workflows` to list and monitor runs — each phase shows agent count, token total, and elapsed time. Press `Ctrl+G` to view or edit the raw script before approval. A run pauses and resumes within the same session (completed agents replay from cache); exiting Claude Code restarts it fresh on relaunch.

Keybindings, the approval flow, save locations, and disabling workflows are in `references/managing-runs.md`.

## Anti-fabrication

A workflow's final return value is only as trustworthy as the agent results it synthesizes. Return what agents actually reported — never invent findings, counts, or verdicts to fill a schema. When a workflow bounds coverage (top-N, sampling, no-retry), `log()` what was dropped so partial coverage never reads as complete. Apply `/core:anti-fabrication` to every claim the workflow surfaces.

## References

- `references/script-api.md` — full hook signatures, schema, isolation, model overrides, budget, resume/runId
- `references/patterns.md` — orchestration patterns and scale guidance
- `references/managing-runs.md` — `/workflows` TUI, triggering, save locations, config toggles, availability
