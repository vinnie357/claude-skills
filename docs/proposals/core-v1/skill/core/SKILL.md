---
name: core
description: Operating rules for any agent in any repository. Use at the start of every coding, review, CI, or release task.
license: MIT
---

# Core

Fix forward. Small changes, merged often, verified by machines.

1. **Track** — The repo's system of record holds issues: goals, decisions, reports, merge authority. Infer it from where the task came from, else ask once and record it in `AGENTS.md`. A lead's breakdown of an issue is an ephemeral list in its worktree; items are named `<issue>.<n>`, get no tracker numbers, and are never committed. With a human in the session, decide together and end by filing issues; without one, work from the issue and ask only through `BLOCKED`.
2. **Branch** — Low risk: target `main`, release on green CI. Higher risk: `dev` stays current; each `dev`→`main` merge bumps semver and deploys.
3. **Fix forward** — A red build is fixed by the next commit. Never rewrite shared history. Commit as the repo owner (`git config user.name` and `user.email`), never as an agent identity; single-line conventional messages, no attribution.
4. **Gates** — Every check is a mise task; `mise run ci` runs them all. Missing gate? Write it first. Fail fast: warnings are errors, stop at the first failure, fix one thing at a time. Gates print one PASS/FAIL/ERROR line and the first failure; full output stays in an untracked file. Logs and large files are read with filters, never whole.
5. **Merge** — Local `ci` green → push → remote CI green → one review sized to the diff → merge into the integration branch without waiting. Tiny diffs are reviewed by their gates, small ones by one light pass, large or risky ones in full; over budget is split, not reviewed. Stop only before production unless the issue, or its epic, is labelled `auto-merge`.
6. **Test** — No behaviour without a test. A fix starts with a failing one.
7. **Hands** — Each item gets a brief: goal, files in scope, done-when, gate command, skill paths, budget. A test author writes failing tests; a separate implementer makes them pass and never edits tests (a test it cannot satisfy goes `BLOCKED` to a reviewer under `auto-merge`, else to a human). No one reviews their own work. Pick models by role from the harness config already present: low effort for focused work, high effort for review, a larger model only for risk. Two failures promote one tier, at most twice, then `BLOCKED`.
8. **Two readers** — Tools and docs serve people and agents: `--help`, `--json`, errors that say what to do next. Instructions, issues, reports, commits and errors are strict: one meaning per term, active voice, one instruction per sentence of at most 20 words, the plain word, warnings before the step, no hedges. READMEs and rationale may be looser. `lint:prose` enforces what it can (spirit of `technical-english`).
9. **Contain** — Run `skills env` once; use the strongest containment it shows (a sandbox, else the harness's own permission mode) and ignore tools it does not list. Secrets are referenced, never read or printed. Branch protection on the remote enforces rule 5 wherever it exists.
10. **Report** — The work is the output. One line back: `DONE|FAIL|BLOCKED <item> <what> <ref>`; `BLOCKED` adds the decision needed, a recommendation, and why. No justification prose; a code comment says only why, in one line, and never restates the code. Claims cite a command run in this session.
11. **Restraint** — Do what the issue asks. Need a skill? `skills find "<task>"`, read only what it returns. Prefer existing skills; when one is verbose or harness-bound, distill its spirit into a line and link the source. Lean on files, git, mise and the tracker, not harness features that change often. If a rule can be a gate, it is not prose. `AGENTS.md` is project rules only.
12. **Build** — Ship the smallest thing that works; change it when it breaks or a user, human or agent, asks. Name the trade-off when choosing a stack or fixing a bug (compile time, long-run memory, repetition, distribution). Run OCI images in micro-VMs or Wasm/WASI before bare containers; Kubernetes only when the need is proven. Cost is measured in tokens from the harness; never guess time or money.
