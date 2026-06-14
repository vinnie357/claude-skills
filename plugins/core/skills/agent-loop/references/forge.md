# Forge: paired teams and implementation fan-out

Forge is the default operating model for working one issue. It replaces the linear single
implementer + single tester — the shape that grinds on a too-large slice and fails late — with
paired teams of principals and cheap hands, fanned out across the issue's slices.

Forge is the canonical shape for *all* work, not a mode reserved for large issues. A small issue
runs the same structure with fan-out width `N=1` and finishes fast because there is less to do —
not because a different code path ran. Removing the trivial-vs-complex threshold removes the exact
spot where a lead misjudges and under-decomposes.

Pair the hands pattern in `researcher.md` with the dispatch rules in `dispatch-discipline.md`.

## The pairs

Models are defaults, overridable via the env-var convention in the agent-loop skill body. "Hands"
means the smallest fast model (`AGENT_LOOP_HANDS_MODEL`, `Explore` for text); the model names below
are the current defaults, not fixed values.

| Pair | Principal | Hands / partner | Fan-out |
|------|-----------|-----------------|---------|
| Plan | Test Planner (opus) | Research hands (smallest) | 1 |
| Author tests | Test Author (sonnet) | Test Reviewer (opus) + its own hands (smallest) | 1 |
| Implement | Implementor (sonnet) | Test Runner (haiku) | × N slices, parallel by dep wave |
| Review | Reviewer (opus) | Research hands (smallest) | 1 |
| Final review | Final Reviewer (opus) | Research hands (smallest) | 1 |
| Remediate | Implementor (sonnet) | Test Runner (haiku) | per review-finding batch |

## Reviewers are the best-thinker tier

Every reviewing role — the Test Reviewer in the author pair, the Reviewer, and the Final Reviewer —
defaults to opus, each paired with haiku hands. Thinking is expensive and stays on the strong
model; fetching is cheap and stays on the small model. The reviewer never searches; its hands
surface the exact artifact to judge.

The **Test Reviewer** has a specific charter: using haiku hands to surface *only* the Test Author's
new tests, verify the tests follow the Test Planner's plan and carry no redundancy. Catching
plan-drift and duplicate tests *before* the implementor starts raises the implementor's chance of
first-pass success — a cheap gate that prevents an expensive failed implementation loop.

## Startup index per principal

Before each principal is spawned, its lead runs a hands pass scoped to that principal's job and
embeds the result as the principal's `## Starting index`:

- **Planner** → the specs / acceptance-criteria sources and the target modules it will plan against.
- **Reviewer** → the implementation diff and the relevant decision records (ADRs).
- **Final Reviewer** → the prior review notes and the remediation diff.

The principal opens oriented and never burns its first moves searching. It spawns further focused
hands on demand for anything the startup index does not cover.

## Slicing and fan-out

The Test Planner (with its hands) decomposes the issue into independent test groups — slices. The
Sub-team Leader spawns one Implementor + Test Runner pair per slice and dispatches them in
dependency waves: recompute the ready set from completed slices, dispatch the wave, merge results,
repeat. A single up-front readiness filter strands any slice whose dependency completes mid-run.

`N` (the number of implementor pairs) equals the slice count. `N=1` is a one-slice issue running
the same path, just narrower. Width scales to the work; the structure is constant.

## Gates between pairs

- Tests reviewed by the Test Reviewer before any implementor starts.
- Diff-boundary: an implementor cannot modify the frozen test files (assert the diff is empty;
  check both committed diff and the working tree).
- CI green per slice before that slice's pair reports done.
- The Reviewer consumes its hands index rather than searching the tree itself.
- Review findings route to the Remediation pair (Implementor + Test Runner), which fixes and
  re-runs; the Final Reviewer then re-checks against the remediation diff.

## Why this beats threshold-gating

A threshold ("trivial → single agent, complex → pipeline") asks the lead to judge size up front —
and an oversized estimate produces one overloaded implementor that fails late. Forge moves the size
decision into the planner's slicing, where it is concrete (count the independent test groups) and
where getting it wrong costs one extra small pair, not one long failed run. The cheap-search
discipline then applies everywhere by construction, because every principal in every pair is handed
its index instead of searching.
