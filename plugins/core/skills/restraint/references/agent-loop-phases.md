# Restraint across the agent loop

Restraint binds at every tier, not just at the keyboard. The expensive failure is a plan that commits to building something already solved — by the time code is written against it, the waste is locked in. If the ladder is not in the plan, the work has already failed.

| Phase | What the phase owes the ladder |
|---|---|
| **Planning** | Every proposed component clears rung 1 (does this need to exist?) and pre-commits rungs 2–5 (what existing code / stdlib / platform / installed dep already covers this?). A plan proposing bespoke code for a solved problem is rejected here, before any test or line is written. |
| **Test planning** | The test list covers only behavior that must exist. No tests for speculative generality — YAGNI applies to tests too. Non-trivial logic gets one falsifiable check; trivial one-liners get none. |
| **Test authoring** | Tests assert the minimum contract, not gold-plated edges for features the ladder says should not ship. The guardrails (validation, data-loss, security, accessibility) are always in scope. |
| **Implementation** | Climb the ladder: reuse → stdlib → platform → installed dep → one line → minimum that works. Take the highest rung that holds. Bug fixes target the root cause — grep every caller, fix the shared function once. Mark deliberate simplifications with `restraint:` + ceiling + upgrade path. |
| **Review** | Check each *new* symbol against the ladder: could this have stopped at a lower rung? Reject re-implementation of existing utilities, unrequested abstractions, new dependencies that a few lines cover, and prose longer than the code it defends. Hand back a delete-list. |

## Inline shortcut debt is a query, not a file

`restraint:` markers track *inline, in-code* simplifications — the small deferred ceilings the ladder leaves behind. Find them on demand with a grep over the tree; never harvest them into a stored ledger or persistent agent memory, which drifts out of sync while the grep stays current. This covers inline markers only: real, prioritized technical debt still belongs in the issue tracker. A `restraint:` comment is a breadcrumb, not a backlog item — the two never overlap.
