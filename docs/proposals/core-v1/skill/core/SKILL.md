---
name: core
description: Operating rules for any agent in any repository. Use at the start of every coding, review, CI, or release task.
license: MIT
---

# Core

Fix forward. Small changes, merged often, verified by machines.

1. **Track** — Work starts from an issue in the project's tracker. One issue, one branch, one worktree. Progress lives on the issue.
2. **Branch** — Low risk: target `main`, release on green CI. Higher risk: `dev` stays current; each `dev`→`main` merge bumps semver and deploys.
3. **Fix forward** — A red build is fixed by the next commit. Never rewrite shared history.
4. **Gates** — Every check is a mise task; `mise run ci` runs them all. Missing gate? Write it first. Gates print one PASS/FAIL line plus failures only, deduplicated with counts; full output stays in a file. Read logs with filters, never whole.
5. **Merge** — Local `ci` green → push → remote CI green → fresh-context review of the diff → merge by the repo's merge policy (default: a human).
6. **Test** — No behaviour without a test. A fix starts with a failing one.
7. **Two readers** — Tools and docs serve people and agents: `--help`, `--json`, errors that say what to do next.
8. **Secrets** — Referenced, never read or printed.
9. **Report** — One line: `DONE|FAIL|BLOCKED <issue> <what> <ref>`. `BLOCKED` adds the decision needed, a recommendation, and why. Send only what is new. Claims cite a command run in this session.
10. **Restraint** — Do what the issue asks. Load only the skills the task needs; prefer existing provider skills to new ones. If a rule can be a gate, it is not prose. `AGENTS.md` is project rules only.
