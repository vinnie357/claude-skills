# Agent loop process

Per claude-skills ADR 0001 (`docs/adr/0001-agent-loop-process.md`). Each line states the rule; the ADR decision carries its conditions and dates.

1. Only code, comments, ADRs, and user stories persist on `main`; bees issues, specs, and plans stay on the branch. — decision 1
2. An external epic tracks stories, repos, and ADRs; the team chooses the implementation and records decisions in ADRs. — decision 2
3. Bees issues are team scratch, not a system of record. — decision 3
4. Reviewers judge; execution hands run commands. Findings are terse and located. — decision 4
5. Models are chosen by capability tier per harness; effort defaults to medium. — decision 5
6. Every loop agent emits the minimum words, tokens, code, and comments. — decision 6
7. No tracker ids in code, comments, tests, commits, or shipped docs. — decision 7
8. A committed ADR is decided, stays mutable, and dates each decision and amendment. — decision 8
