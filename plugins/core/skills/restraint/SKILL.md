---
name: restraint
description: Engineering restraint — stop at the first rung that already solves the problem before writing new code. Use when planning, authoring tests, implementing, or reviewing any code change; loads as a standing principle alongside TDD and twelve-factor.
license: MIT
---

# Restraint

The best code is the code you never wrote. Write only what the task needs; cut scope, never correctness. Code ends up small because it is necessary, not golfed.

This is a standing principle, like `/core:tdd` and `/core:twelve-factor` — it governs every phase of a change, not a command you run.

## The ladder

Understand the problem first. Read the task and the code it touches, trace the real flow end to end, then climb. The ladder shortens the solution, never the reading — a small diff you do not understand is a second bug, not a clean fix.

Then, before writing any code — or any documentation: an ADR, a diagram, a README — stop at the first rung that holds:

```
1. Does this need to exist?      → no: skip it, say so in one line.   (YAGNI)
2. Already in this codebase?      → reuse the helper/util/pattern.     (Reuse-First)
3. Stdlib does it?                → use it.                            (Reuse-First)
4. Native platform feature?       → use it.                           (Reuse-First)
5. Installed dependency?          → use it; add none for a few lines.  (Reuse-First)
6. One line?                      → make it one line.
7. Only then                      → write the minimum that works.
```

- **Rung 1 — YAGNI.** Speculative need is no need. No interface with one implementation, no factory for one product, no config for a value that never changes, no scaffolding "for later."
- **Rungs 2–5 — Reuse-First.** Re-implementing what already exists a few files over is the most common agent slop. Grep before you write. Prefer the platform: `<input type="date">` over a picker lib, CSS over JS, a DB constraint over app code. Use an installed dependency; add a new one only when a few lines cannot cover it.
- **Rungs 6–7 — Minimum.** One line if one line works. The minimum that works is the last rung, not the first move.

Two rungs both work → take the **higher** one and move on. Two stdlib options the same size → take the one that is correct on edge cases. Restraint means less code, never the flimsier algorithm.

The ladder governs documentation the same way: does this ADR or diagram need to exist, or does an existing one already cover it? Amend the existing doc instead of adding a parallel one; write the minimum that conveys the decision. An unread page or a duplicate diagram is over-production like any other. Document only what is built, not what is planned — an ADR or diagram describing unbuilt or changed behavior is the prose form of dead code.

## Scope — commodity code, not strategic surface

The ladder governs incidental, commodity code: plumbing a task needs in
passing — parsing, HTTP, retries, glue. It does NOT relitigate product surface
a project has deliberately chosen to own. Building a first-party tool,
framework, runtime, or library is a strategic decision; "an off-the-shelf X
already does this" is not a rung-1 or rung-5 objection to that surface.
Reuse-First applies *within* what you own — don't reinvent your own helpers —
never *against* the decision to own it.

## Never lazy about

These sit outside the ladder. Never simplify them away:

- Input validation at trust boundaries, error handling that prevents data loss, security, accessibility. See `/core:security`.
- Honest claims about what the code does — tool-verified, never asserted for brevity. See `/core:anti-fabrication`.
- Understanding the problem (above).
- Calibration that real hardware needs — a clock drifts, a sensor reads off. Leave the knob, not just less code.
- Anything explicitly requested. The user insists on the full version → build it, no re-arguing.

Restraint without its check is unfinished. Non-trivial logic (a branch, loop, parser, money/security path) leaves ONE runnable check behind — the smallest thing that fails if the logic breaks. Drive that through `/core:tdd`. YAGNI applies to tests; non-trivial logic still leaves one runnable check. — this sentence is shared verbatim with `/core:tdd` as the reconciliation between tdd's thoroughness and restraint's minimalism.

## The `restraint:` comment

Mark a deliberate simplification with a `restraint:` comment so a reader sees intent, not ignorance. A shortcut with a known ceiling names the ceiling and the upgrade path:

```python
# restraint: global lock — switch to per-account locks if throughput matters
```

These inline markers are a grep, not a stored ledger — find outstanding shortcuts on demand. Real, prioritized technical debt still belongs in the issue tracker; a `restraint:` marker is a breadcrumb, not a backlog item.

## Bug fix = root cause, not symptom

A report names a symptom. Before editing, grep every caller of the function you touch and fix the shared function once. One guard there is a smaller diff than one per caller — and patching only the path the ticket names leaves a sibling caller still broken. The lazy fix IS the root-cause fix.

## Anti-prose

If the explanation is longer than the code, delete the explanation. Every paragraph defending a simplification is complexity smuggled back in as prose. Boring over clever — clever is what someone decodes at 3am.

## In the agent loop

This principle binds at every tier — if restraint is not in the plan, the work has already failed. See `references/agent-loop-phases.md` for what each phase owes the ladder: planning, test planning, test authoring, implementation, review.

## References

- `references/agent-loop-phases.md` — what each agent-loop phase owes the ladder
- `references/attribution.md` — source and license
- `scripts/restraint-audit.nu` — greps `restraint:` markers repo-wide; paired with the `/core:restraint-audit` command
