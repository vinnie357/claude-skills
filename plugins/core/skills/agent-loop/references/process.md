# Agent loop process

Decided in claude-skills ADR 0001 (`docs/adr/0001-agent-loop-process.md`).

1. Durable artifacts: code, comments, ADRs (`docs/adr/`), user stories (`docs/user-stories/`). Ephemeral artifacts: bees issues and epics, specs, plans, review scratch — session/branch only, pruned before `main`. A durable artifact never cites an ephemeral one.

2. An external epic tracks user stories, repos, and ADRs in one system of record. A team chooses its own implementation, satisfies the stories, and records each decision in an ADR. ADRs drive specs; specs change during implementation, then get discarded.

3. Bees issues are a team's or lead's scratch tracker, shared with that team's agents, preseeded via `issues.jsonl`. Bees issues are not a system of record.

4. Reviewers judge; hands execute. Every reviewer evaluates the artifact against ADRs, user stories, acceptance criteria, and the relevant skills. A reviewer never runs a suite, a build, or the app — it spawns hands on the smallest fast tier to run a named command and judges the verbatim output. Findings: `[severity] path:line — defect. Fix: one sentence.`

5. Models are chosen by capability tier — strongest reasoning, deep reasoning, general, smallest fast, multimodal — mapped per harness, never by name in process text. Effort defaults to medium, passed explicitly; high is a per-run exception.

6. Every loop agent emits the minimum words, tokens, code, and comments that meet its goal, per `/core:restraint` and `/core:technical-english`.

7. No tracker ids in code, comments, tests, fixtures, commit messages, or shipped docs. A PR body may link its tracker item. ADRs may be cited.
