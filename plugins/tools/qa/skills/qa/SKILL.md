---
name: qa
description: "QA workflow that validates a running application against Gherkin user stories. Use when running /qa or /qa:new-story, writing user stories under docs/user-stories/, decomposing Gherkin scenarios into Playwright and Tidewave validation work, mapping Given/When/Then to a RED/GREEN TDD loop, or filing observed behavior deltas as bees issues."
license: MIT
---

# QA Workflow

A team-driven validation loop that exercises a running application against a Gherkin user story, treats every `Then` clause as a TDD assertion, and files behavior deltas as bees issues via the existing `bees-manager` agent.

## When to Use

Activate when:
- The `/qa <path>` slash command is invoked.
- The `/qa:new-story <name>` slash command is invoked.
- Reasoning about how to validate a documented golden path end-to-end.
- Decomposing a Gherkin user story into parallel work items.
- Mapping Given/When/Then to RED/GREEN states for `/core:tdd`.
- Authoring a new Gherkin file in `docs/user-stories/`.

## Inputs

The `/qa` command expects:

- A path to a Gherkin user story under `docs/user-stories/<slug>.md` in the target repo. Paths outside that directory are rejected.
- Optional `--fix` flag to enable the fix loop after deltas are filed.

The `/qa:new-story` command expects a kebab-case slug; the file at `docs/user-stories/<slug>.md` must not already exist.

The accepted Gherkin dialect, parsing rules, and rejection criteria live in `references/gherkin-format.md`.

## Stack Detection

The `qa-lead` agent probes the repo before decomposing work:

- `mix.exs` present → Phoenix path. `qa-tidewave` validates backend assertions.
- `package.json` + `playwright.config.{ts,js,mjs}` → UI present. `qa-playwright` drives scenarios.
- Neither → generic. `qa-backend` uses HTTP/CLI/log probing through Bash.
- Mixed (e.g. Phoenix + UI) → spawn both UI and backend workers; correlate by scenario name.

Full probe tree in `references/stack-detection.md`.

## Worker Decomposition

One `Scenario:` block per worker. The lead assigns workers by the assertion targets in the `Then` clauses:

| Scenario type | Worker | Tools |
|---|---|---|
| UI flow (clicks, form fill, navigation) | qa-playwright | Playwright MCP browser tools |
| Phoenix runtime / DB / log assertions | qa-tidewave | Tidewave MCP tools |
| HTTP API / CLI / generic backend | qa-backend | Bash, WebFetch |
| Scenario asserts both UI and backend | qa-playwright + qa-tidewave (or qa-backend) | Both, correlated by scenario name |

The lead never runs validation itself — it spawns workers via the Task tool and aggregates their reports.

## TDD Mapping

Each `Scenario:` is a TDD assertion against running application behavior. The standard Red-Green-Refactor loop maps directly onto Gherkin:

| Gherkin | TDD state | Worker action |
|---|---|---|
| `Given <precondition>` | Test setup | Bring app to the stated initial state (or assert it). |
| `When <action>` | Exercise | Execute the action against the running app. |
| `Then <expectation>` | Assertion | Capture observed behavior with tool output as evidence. |
| `Then` matches expectation | GREEN | Report PASS for that scenario step. |
| `Then` mismatches | RED | Emit a `BEES REQUESTS:` entry; the lead routes it to `bees-manager`. |
| `--fix` flag passed | Fix loop | `qa-test-writer` writes ONE failing test (RED). `qa-implementer` then writes the smallest production change to make it pass (GREEN). The two never touch each other's files — qa-lead inspects the diff between phases to enforce the boundary. |

Full mapping with examples in `references/validation-loop.md`. The `/core:tdd` skill defines the canonical Red-Green-Refactor cycle and Three Laws — load it whenever a worker enters the fix loop.

## Delta Filing Protocol

Workers MUST NOT call `bees new`, `bees close`, `bees dep add`, `bees update`, or `bees comment add` directly. They emit a `BEES REQUESTS:` block in their final report. The `qa-lead` aggregates these across all workers and routes the batch to ONE `bees-manager` agent invocation per repo cwd.

The block shape is fixed (it IS the input contract for `bees-manager`):

```
BEES REQUESTS (cwd: <repo-root>):
- new title="qa: <scenario name> — <failing assertion>" body="<reproduction + observed vs expected>" priority=P2 external-ref="<repo>/docs/user-stories/<slug>.md#<scenario>" labels="qa,golden-path"
```

Full grammar in `references/delta-format.md`. Reuses the contract from `plugins/core/skills/bees/agents/bees-manager.md` lines 33–41 verbatim — that agent is the source of truth.

Filed issues land in the target repo's `.bees/` DB only. Global `~/github/.bees/` is out of scope for `/qa`.

## Fix Loop (`--fix`) — adversarial TDD pair

Default behavior (no flag): file deltas, report the issue list, stop.

With `--fix`, the fix loop uses TWO opposed agents per issue. They are intentionally split to enforce `/core:tdd` honesty — the agent writing the test cannot also write the implementation, so neither can quietly relax the contract.

1. **qa-test-writer** (sonnet) — Reads the bees issue. Writes ONE failing test that captures the bug. MAY edit files only inside the repo's test directory. MUST NOT touch production code. Confirms the test fails for the right reason. Returns a test artifact: `{path, test_name, runner_command}` and the verbatim failure output.
2. **Lead diff inspection** — Runs `git diff --name-only` after qa-test-writer. If any modified path is outside the test directory, the run is REJECTED and reported as `BLOCKED: qa-test-writer crossed boundary`. No qa-implementer spawn happens.
3. **qa-implementer** (sonnet) — Receives only the test artifact (NOT the failure output). MAY edit any file OUTSIDE the test directory. MUST NOT touch the test. Writes the smallest production-code change to make the test pass. Runs the targeted test, then `mise run ci` / `mise run test` for regressions.
4. **Lead diff inspection** — Runs `git diff --name-only` again. If any modified path is inside the test directory (added since qa-test-writer), the run is REJECTED as `BLOCKED: qa-implementer crossed boundary`. The implementer's changes are rolled back.
5. **Re-run validator** — qa-playwright / qa-tidewave / qa-backend re-runs the original scenario against the live app.
6. Round budget: at most 3 rounds per issue. After 3, the lead halts and reports the stall. The lead does NOT promote models; stalls are visible.

Why two agents? If one agent writes both the test and the fix, it can subtly weaken the test to make its own implementation pass — what looks like GREEN is actually "I moved the goalposts." Splitting the work means the test is fixed-in-place before the implementer ever runs. If the test is genuinely wrong, the user re-runs `/qa` to amend the story, and the loop restarts with a new test artifact.

Neither agent commits or pushes. After the loop, the lead reports the full diff and the user decides whether to commit.

## Authoring Stories (`/qa:new-story`)

The `qa-author` agent (haiku) runs a short questionnaire and writes a parser-valid Gherkin file to `docs/user-stories/<slug>.md`. It refuses to overwrite existing files. It validates its own output against the parser in `references/gherkin-format.md` before reporting success.

Copy `templates/user-story.md` for a manual authoring starting point.

## Anti-Fabrication

Every PASS claim requires tool-output evidence:

- `qa-playwright`: include the matching text from `browser_snapshot` output or screenshot caption.
- `qa-tidewave`: include the SQL query result, the `project_eval` return value, or the log line excerpt.
- `qa-backend`: include the HTTP status + body excerpt, CLI exit code + output, or log line.

No scenario is reported PASS on faith. Load `/core:anti-fabrication` at agent start.

## References

- `references/gherkin-format.md` — accepted Gherkin dialect, parsing rules, rejection criteria, full example.
- `references/stack-detection.md` — probe tree and worker assignment matrix.
- `references/validation-loop.md` — full RED/GREEN/REFACTOR mapping with worked examples; quotes `/core:tdd`.
- `references/delta-format.md` — `BEES REQUESTS:` block grammar and field rules.
- `templates/user-story.md` — copyable Gherkin starting file.
