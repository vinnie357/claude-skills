# CI discipline and docs-first TDD

These rules extend the Red-Green-Refactor cycle with project-level enforcement gates.

## `mise run ci` (or equivalent) passes before EVERY commit

The strictest local CI suite — `mise run ci`, `npm run ci`, `cargo test --all`, or the project's equivalent — runs and passes before EVERY commit, not just before push. This is the integration of the TDD micro-cycle with the project's quality bar.

"I'll run CI before push" is insufficient. Multi-commit branches accumulate broken commits between CI runs; the next commit's red is attributed to the wrong change.

## CI green = local AND remote both passing

"CI green" is the AND of two conditions:
- Local strictest suite (`mise run ci` or equivalent) passes.
- Remote CI (`gh pr checks --watch` or equivalent) passes.

Neither alone is sufficient. Local-only passing hides environment differences (CI runs different OS / different concurrency / different env vars). Remote-only passing hides the fact that the worker never ran the full suite locally and was reactive to remote failures.

## Verbatim CI output as evidence

When a worker reports CI status to a leader, the report includes the verbatim final lines of the CI output (test counts, lint warnings, format checks). "I ran it and it passed" is insufficient evidence; the leader cannot verify without the output. Paste the last 20-50 lines of `mise run ci` (or equivalent) into the worker's final report.

## No pre-existing failure carve-outs

Every failing test in the CI run is the current worker's responsibility, regardless of which prior commit introduced it. "That test was already broken on main" is not an acceptable carve-out — either fix it in this PR or open a separate PR FIRST that fixes main, then rebase. Carve-outs accumulate; the codebase ends with N "not my problem" tests that nobody owns.

## Post-merge main CI verification

After a PR squash-merges, verify post-merge main CI separately. Squash-merging can produce a main-only failure that did not appear on the PR branch (different commit hash → different cache key → different test result). Sequence merges (don't batch two PRs into the same hour without verifying main-CI between them).

## Docs-first TDD

Architectural Decision Records (ADRs) and design documents precede implementation. The test list (the TDD roadmap) derives from the ADR's acceptance criteria, not from "what feels reasonable". Implementing first then writing the ADR retroactively produces ADRs that describe what the code does, not what the design decided — the artifact is degraded.

## No fabricated time estimates

Time estimates ("this will take 2 hours", "quick task") without measurement violate `/core:anti-fabrication`. When asked for an estimate, the worker:

1. Counts files affected (`Glob`).
2. Measures code complexity at the change sites (`Read` + analysis).
3. Identifies integration points (`Grep` for imports / call sites).
4. Returns "estimate requires analysis of <factors>", OR an estimate grounded in those measurements.
