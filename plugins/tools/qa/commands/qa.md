---
description: "Validate an application against a Gherkin user story by spawning a QA team that drives the running app"
argument-hint: "<path-to-user-story> [--fix]"
---

Validate the application against the Gherkin user story at the given path. Spawns the `qa-lead` agent, which parses the story, detects the application stack, decomposes scenarios into parallel workers (Playwright for UI, Tidewave for Phoenix backends, generic backend probes otherwise), aggregates the workers' delta reports, and routes filed issues through the `bees-manager` agent into the target repo's `.bees/` database.

**What it does:**

1. **Parse the user story** — `qa-lead` reads `<path-to-user-story>` and validates the Gherkin format. Rejects on bad format.
2. **Detect the stack** — Probes the repo for Phoenix (`mix.exs`), web UI (`package.json` + `playwright.config.*`), or generic backends. Verifies the app is reachable at the URL declared in `Background:`.
3. **Spawn workers** — One worker per `Scenario:`, dispatched by assertion shape (UI → qa-playwright, Phoenix runtime → qa-tidewave, generic → qa-backend, mixed → both, correlated by scenario name).
4. **Aggregate deltas** — Each worker emits a `BEES REQUESTS:` block in its report. The lead deduplicates across workers and routes ONE batch to `bees-manager` per run.
5. **Report** — Lists filed bees issue IDs, scenarios that passed, scenarios that failed, and the next-step guidance.
6. **(With `--fix`)** — Per filed issue, spawns an adversarial TDD pair: `qa-test-writer` (sonnet, may only edit tests) writes ONE failing test; `qa-implementer` (sonnet, may only edit production code) writes the smallest fix to make it pass. The lead inspects `git diff` between phases to enforce the boundary — neither agent can touch the other's files. Runs `mise run ci` / `mise run test` after the fix, re-runs the originating validator. Three rounds max. Reports the diff and halts; the user decides whether to commit.

**Arguments:**

- `<path-to-user-story>` — path to a Gherkin file under `docs/user-stories/<slug>.md` in the target repo. Required.
- `--fix` — opt-in to the post-validation fix loop.

**Examples:**

```
/qa docs/user-stories/checkout.md
/qa docs/user-stories/checkout.md --fix
```

**Skills the lead loads (no globs — explicit names):**

- `/qa:qa`
- `/core:agent-loop`
- `/core:tdd`
- `/core:anti-fabrication`
- `/core:bees`
- `/core:nushell`
- `/claude-code:claude-teams`

**Task instructions:**

Use the `qa-lead` subagent. Pass it the absolute path of the user-story file (resolve `` against the current working directory), the repo root (current working directory unless the path is in a subrepo — in that case, walk up to find the nearest `.git/`), and the `--fix` flag if present. Reject before spawning if the file does not exist or sits outside `docs/user-stories/`.
