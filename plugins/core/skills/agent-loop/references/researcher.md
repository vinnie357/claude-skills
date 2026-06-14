# Research hands (the hands pattern)

Hands are read-only research agents that any principal spawns to do its searching, indexing, and
knowledge-gathering. Hands run on the smallest fast model; the principal stays on the expensive
model and spends its context on judgment, not on `Grep`/`Glob`/large `Read` sweeps. Hands gather;
the principal decides.

This is the Forge mechanism for "planners and reviewers do not search." A principal is *handed* the
relevant `file:line` pointers instead of discovering them. See `forge.md` for how hands pair with
each principal role, and `dispatch-discipline.md` for the delegate-search-before-you-search rule.

## Two invocation modes

1. **Startup / onboarding.** A lead runs a hands pass *before* spawning a fresh principal, then
   embeds the resulting index in the principal's spawn prompt under a `## Starting index` section.
   The principal opens already-oriented — it reads the pointers and starts judging immediately.
2. **On-demand.** A working principal spawns new focused hands for a follow-up objective it
   discovers mid-task. Follow-ups default to *new* hands (fresh context, one objective each, per
   the no-SendMessage-continuation rule). Continue the same hands via `SendMessage` only for a
   tightly-related follow-up where the harness supports it.

Spawn as many focused hands as the job needs. One hands agent answers one specific objective.

## Spawn contract

The caller gives hands a *specific* objective, not "go understand the repo":

- Bad: "research the codebase."
- Good: "find where `serialize_workflow/1` is defined and every caller; report the definition and
  each call site."

## Output contract — an index, not a narrative

Hands return a structured index: a list of `{file, lines, why}` pointers plus a short excerpt
(≤ ~15 lines) per pointer. Never whole-file dumps. Never prose that drops the `file:line`
provenance. The principal `Read`s only the lines the index names.

```json
[
  { "file": "lib/runex/workflows.ex", "lines": "28-34",
    "why": "serialize_workflow/1 — reuse for the import path",
    "excerpt": "def serialize_workflow(%Workflow{} = w) do ... end" },
  { "file": "docs/adrs/0007-bundle-import.md", "lines": "12-19",
    "why": "prior decision: imports are multipart, not JSON",
    "excerpt": "We accept tar.gz multipart uploads at POST /api/bundles/import ..." }
]
```

## Model selection — by capability, set by config

- **Text / code research** runs on the smallest fast model — the `Explore` subagent type — via
  `AGENT_LOOP_HANDS_MODEL`.
- **Vision-requiring research** runs on a multimodal-capable model the current harness offers, via
  `AGENT_LOOP_HANDS_VISION_MODEL`. The trigger is the *artifact type*, decided when the principal
  spawns the hands: images, screenshots, rendered web pages, visual PDFs, or Playwright / visual
  MCP output.

Select by capability, never by a hardcoded name. The available multimodal model shifts with the
harness and the model family; the env var carries it (12-factor config), the same way the
`AGENT_LOOP_*_MODEL` tier vars do. An empty-string value falls through to the default.

## Tool surface

Read-only. Text hands: `Read`, `Grep`, `Glob` (and `Bash` for `which` / `ls` host inspection).
Vision hands add the harness's visual tools — `WebFetch`, the Playwright MCP, or an image-capable
reader. Hands never `Edit`, `Write`, or commit.

## Forbidden

- No design decisions, architecture recommendations, or test/implementation choices.
- No code, no edits, no commits.
- No whole-file dumps and no provenance-free summaries — the index is the deliverable.

## Worked examples

**Text/code (startup index for a planner).** Objective: "for issue repo-42, index the existing
HTTP controller, its router entry, and the serializer the new endpoint reuses." Hands return three
`{file, lines, why, excerpt}` pointers. The planner reads those ~40 lines, never the whole repo,
and writes its test list from them.

**Visual (on-demand for a reviewer).** A LiveView issue ships a screenshot of the expected layout.
The reviewer spawns vision hands (`AGENT_LOOP_HANDS_VISION_MODEL`) with the objective "describe the
header layout and the empty-state copy in this screenshot," then judges the implementation against
the returned description — without loading a multimodal model into its own review context.
