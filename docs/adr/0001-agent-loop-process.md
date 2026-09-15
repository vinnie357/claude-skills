# ADR 0001: Agent loop process

## Context

Agents inherit whatever the repo holds. A stale tracker row, a finished spec, or a ticket reference left in code steers the next team's decisions long after the item that produced it closed. This repo runs agent teams across many sessions and many branches, and each session starts from what the previous one left behind on `main`.

`vantage_ex` ADR-120 (Proposed) already decides that a per-repo bees database is a gitignored working set, not a durable archive — disposable once its team's work rolls up elsewhere. This ADR extends that framing to every artifact the loop produces, not only bees, and adds two rules ADR-120 does not cover: how a loop epic relates to the repos and ADRs it touches, and how a reviewer inside the loop gathers evidence and reports findings.

## Decision

1. Durable artifacts are the system of record on `main`: code, comments, ADRs (the repo's decision records), and user stories (`docs/user-stories/`). Ephemeral artifacts live only on a session or a branch: bees issues and epics, specs, and plans. A team prunes ephemeral artifacts before they reach `main`. Links point one way: a durable artifact never cites an ephemeral one. (2026-09-15)

2. An external epic lives in one external system of record and tracks user stories, repos, and ADRs. An agent team chooses its own implementation; the team must satisfy the stories and record each decision in an ADR. ADRs drive specs; a spec changes as the team implements, then the team discards it. (2026-09-15)

3. Bees issues are a team's or a lead's scratch tracker, shared with that team's agents. `issues.jsonl` can preseed a new agent's clone through `bees import`; the handoff step is not built. Bees issues are not a system of record. (2026-09-15)

4. Reviewers judge; execution hands execute. Every reviewer — plan, test, pipeline, or PR gate — evaluates the artifact against ADRs and user stories. It also checks acceptance criteria and the relevant skills. A reviewer never runs a suite, a build, or the app. It obtains execution through execution hands on the smallest fast tier. A reviewer that cannot spawn agents requests bounded execution through its lead. Execution hands report per the Execution evidence section of `/claude-code:claude-output-styles` `assets/ci-evidence-format.md`, not whole logs. Missing required evidence blocks approval and never authorizes the reviewer to execute. The reviewer names the missing evidence. A reviewer rejects evidence from a revision other than the one under review. Findings stay terse: `[severity] path:line — defect and impact; basis. Fix: one sentence.` The basis names the ADR or skill when one applies. A plan without stable lines uses a section reference. Specialist reviewers keep their `## VERDICTS` lines unchanged; the finding line applies outside that block. (2026-09-15; amended 2026-09-15)

5. A team selects a model by capability tier: strongest reasoning, deep reasoning, general, smallest fast, or multimodal. Each harness maps a tier to its own model, for example claude, codex, or agy. Process text never names a literal model. Effort defaults to medium for every tier. The launcher passes it wherever the harness accepts an effort setting. High effort is a per-run exception. (2026-09-15)

6. Every loop agent emits the minimum words, tokens, code, and comments that meet its goal, per `/core:restraint` and `/core:technical-english`. (2026-09-15)

7. Code, comments, tests, fixtures, commit messages, and shipped docs carry no tracker ids. A PR body may link its own tracker item. An ADR citation stays allowed. (2026-09-15)

8. A committed ADR is decided. Every decision stays mutable as user stories change. Each decision records its adoption date and each amendment's date. A team never reuses a decision number. (2026-09-15; amended 2026-09-15)

## Consequences

- This repo still tracks `.bees/issues.jsonl` and still instructs `chore(bees)` commits until pruning lands — decisions 1 and 7 state the target shape, not the current state.
- Existing tracker ids in code and docs need a burn-down; this ADR does not schedule it.
- `/core:agent-loop` ships this outline as `references/process.md`.
- Skill, reference, and template text that conflicts with decisions 4, 5, or 7 stays until later changes amend it.

## Open questions

- Which single external system of record: GitHub issues (public) or Linear (private).
- Prune and preseed mechanics: how ADR-120's seeding and rollup questions extend past per-repo bees to specs and plans.
- The fate of the workspace-wide bees tier under decision 1's durable/ephemeral split.
