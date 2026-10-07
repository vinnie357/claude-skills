---
name: core
description: Operating rules for any agent in any repository. Use at the start of every coding, review, CI, or release task.
license: MIT
---

# Core

Fix forward. Small changes, merged often, verified by machines.

1. **Track** — Work starts from an issue in the project's tracker. One issue, one branch, one worktree. The issue holds goals, decisions and reports; a breakdown of it lives in an ephemeral list inside its worktree (bees or a file), never committed, gone at merge. With a human in the session, decide together and end by filing issues; without one, work from the issue and ask only through `BLOCKED`.
2. **Branch** — Low risk: target `main`, release on green CI. Higher risk: `dev` stays current; each `dev`→`main` merge bumps semver and deploys.
3. **Fix forward** — A red build is fixed by the next commit. Never rewrite shared history.
4. **Gates** — Every check is a mise task; `mise run ci` runs them all. Missing gate? Write it first. Fail fast: warnings are errors, stop at the first failure, fix one thing at a time. Gates print one PASS/FAIL/ERROR line and the first failure; full output stays in a file, read with filters.
5. **Merge** — Local `ci` green → push → remote CI green → review sized to the diff → merge into the integration branch without waiting. Review effort follows size and risk: tiny diffs are reviewed by their gates, small ones by one light pass, large or risky ones in full; over budget is split, not reviewed. Stop only before production (`dev`→`main`, or `main` in low-risk repos) unless the issue, or its epic, is labelled `auto-merge`.
6. **Test** — No behaviour without a test. A fix starts with a failing one.
7. **Two readers** — Tools and docs serve people and agents: `--help`, `--json`, errors that say what to do next.
8. **Secrets** — Referenced, never read or printed.
9. **Report** — One line: `DONE|FAIL|BLOCKED <issue> <what> <ref>`. `BLOCKED` adds the decision needed, a recommendation, and why. Send only what is new. Claims cite a command run in this session.
10. **Restraint** — Do what the issue asks. Need a skill? `skills find "<task>"`, read only what it returns. Prefer existing skills; when one is verbose or harness-bound, distill its spirit into a line and link the source. Lean on files, git, mise and the tracker, not harness features that change often. If a rule can be a gate, it is not prose. `AGENTS.md` is project rules only.
11. **Build** — Ship the smallest thing that works; change it when it breaks or a user, human or agent, asks. Name the trade-off when choosing a stack or fixing a bug (compile time, long-run memory, repetition, distribution). Run OCI images in micro-VMs or Wasm/WASI before bare containers; Kubernetes only when the need is proven. Cost is measured in tokens from the harness; never guess time or money.
