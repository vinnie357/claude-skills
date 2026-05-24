# Agent dispatch and delegation discipline

These rules apply to any leader (Tier 1 or Tier 2) authoring an Agent or Task spawn prompt.

## Model selection is explicit, never inherited

Every spawn prompt sets `model:` (or the equivalent `subagent_type` argument) explicitly to `haiku`, `sonnet`, or `opus`. Inheriting model from the parent's session wastes tokens — leads run on opus by default and inherit their model to haiku-class tasks if unconstrained.

## Use specialized subagent types

When the project ships specialized subagent types (`Explore`, `Plan`, `bees-manager`, `code-review-orchestrator`, etc.), spawn the specialized type rather than `general-purpose`. The specialized types carry tool allowlists and prompt scaffolding tuned to their role.

## Tier 1 leads delegate ALL execution

A Tier 1 lead runs zero direct work: no `Bash`, no `Edit`, no `Write`, no `Read` of source files. CI runs through a haiku validator. Fixes run through a sonnet or opus fix-agent. The lead's tool surface is `Read` (the lead's own loaded skills and the spec it is composing), bees state queries, the `Task`/`Agent` spawn tool, and the user-facing message channel.

## Tier 1 leads framing

The leader speaks of itself as "Tier 1" and spawned agents as Tier 2 (sub-lead), Tier 3 (worker), Tier 4 (validator), Tier 5 (fix-agent / reviewer). Spawned agents are NEVER called "team lead" — that term is reserved for Tier 1 to avoid recursive confusion in spawn prompts.

## Branch from fresh main, explicitly

Every PR-opening spawn prompt's Step 0 is:

```bash
git fetch origin main
git checkout origin/main
git checkout -b <branch>
```

Without this step, the spawned agent inherits the working tree's current branch — often a sibling PR's stale branch — and produces a PR that contains both the new work and the sibling's diff.

## No timed polling loops in workers

Spawned agents do not sustain timed polling loops. The `Monitor` tool is restricted; `sleep` longer than a few seconds is blocked. Polling work decomposes into one-shot snapshot agents the lead re-spawns at intervals OR external orchestration that pings on event.

## Verify tool state via host inspection, not agent perception

Before claiming "tool X is missing on host Y", the lead spawns a snapshot agent that runs `which <tool>` / `ls /path/to/<tool>` / equivalent ON THE HOST and reports the literal command output. Agent perception ("I do not see tool X in the prompt context") is not evidence of absence; it usually means the agent's PATH or env differs from the host's actual install.

## Search prior decision records before proposing architecture

Before any architectural proposal, search the project's decision-records directory (`architecture/decisions/`, `docs/adrs/`, etc.) for prior coverage. Inventing a design that contradicts an existing ADR wastes review cycles; extending or amending an existing ADR is the correct path.
