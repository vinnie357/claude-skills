---
name: core
description: Operating rules for any agent in any repository. Use at the start of every coding, review, CI, or release task.
license: MIT
---

# Core

Fix forward. Small changes, merged often, verified by machines.

1. **Track** — The tracker holds issues: goals, decisions, reports, merge authority. A lead's breakdown of an issue is an ephemeral list in its worktree (bees or a file); items are named `<issue>.<n>` after their parent, get no tracker numbers, and are never committed. With a human in the session, decide together and end by filing issues; without one, work from the issue and ask only through `BLOCKED`.
2. **Branch** — Low risk: target `main`, release on green CI. Higher risk: `dev` stays current; each `dev`→`main` merge bumps semver and deploys.
3. **Fix forward** — A red build is fixed by the next commit. Never rewrite shared history.
4. **Gates** — Every check is a mise task; `mise run ci` runs them all. Missing gate? Write it first. Fail fast: warnings are errors, stop at the first failure, fix one thing at a time. Gates print one PASS/FAIL/ERROR line and the first failure; full output stays in a file, read with filters.
5. **Merge** — Local `ci` green → push → remote CI green → review sized to the diff → merge into the integration branch without waiting. Review effort follows size and risk: tiny diffs are reviewed by their gates, small ones by one light pass, large or risky ones in full; over budget is split, not reviewed. Stop only before production (`dev`→`main`, or `main` in low-risk repos) unless the issue, or its epic, is labelled `auto-merge`.
6. **Test** — No behaviour without a test. A fix starts with a failing one.
7. **Hands** — A lead gives each worker a brief: goal, files in scope, done-when, the gate command, skill paths, budget. Nothing else. The lead picks the worker and sandbox from `skills env`; the worker validates with the same gates.
8. **Two readers** — Tools and docs serve people and agents: `--help`, `--json`, errors that say what to do next.
9. **Contain** — Run `skills env` once; use the strongest containment it shows (a sandbox, else the harness's own permission mode) and ignore tools it does not list. Secrets are referenced, never read or printed. Branch protection on the remote enforces rule 5 wherever it exists.
10. **Report** — The work is the output. One line back: `DONE|FAIL|BLOCKED <item> <what> <ref>`; `BLOCKED` adds the decision needed, a recommendation, and why. No justification prose; a code comment says only why, in one line, and never restates the code. Claims cite a command run in this session.
11. **Restraint** — Do what the issue asks. Need a skill? `skills find "<task>"`, read only what it returns. Prefer existing skills; when one is verbose or harness-bound, distill its spirit into a line and link the source. Lean on files, git, mise and the tracker, not harness features that change often. If a rule can be a gate, it is not prose. `AGENTS.md` is project rules only.
12. **Build** — Ship the smallest thing that works; change it when it breaks or a user, human or agent, asks. Name the trade-off when choosing a stack or fixing a bug (compile time, long-run memory, repetition, distribution). Run OCI images in micro-VMs or Wasm/WASI before bare containers; Kubernetes only when the need is proven. Cost is measured in tokens from the harness; never guess time or money.
