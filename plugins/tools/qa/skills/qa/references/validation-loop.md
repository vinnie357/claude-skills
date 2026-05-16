# QA Validation Loop

How Gherkin scenarios map onto the `/core:tdd` Red-Green-Refactor cycle, and how the `--fix` loop drives a scenario from RED to GREEN.

## The Red-Green-Refactor Cycle

Quoted verbatim from `plugins/core/skills/tdd/SKILL.md` lines 32–55:

> The micro-cycle is a three-state machine:
>
> ```
>     ┌──────────────────────────────────────┐
>     │                                      │
>     ▼                                      │
>   [RED] ──── write minimal code ────► [GREEN] ──── refactor ────► [GREEN]
>     ▲                                                                │
>     │                                                                │
>     └──────────── write next failing test ◄──────────────────────────┘
> ```
>
> **RED**: Write a test that fails. Confirm it fails for the *right reason* — the missing behavior, not a syntax error or wrong import.
>
> **GREEN**: Make the test pass with the simplest change possible. "Sinful" code is fine — hardcoded values, copy-paste, whatever gets green fastest.
>
> **REFACTOR**: Clean up while all tests stay green. Remove duplication between test and production code. Improve names. Extract methods. This is where design emerges.
>
> Rules:
> - Never write production code without a failing test
> - Never write more test code than needed to fail
> - Never write more production code than needed to pass

In `/qa`, the Gherkin file IS the outer-loop acceptance test (per `/core:tdd` Double-Loop TDD). Each scenario is one acceptance assertion. The fix loop, when enabled, drives an inner Red-Green-Refactor cycle to make a failing scenario pass.

## Gherkin → TDD State Mapping

| Gherkin clause | TDD role | Worker behavior |
|---|---|---|
| `Background: Given <precondition>` | Shared fixture / setup | Bring the app into the stated state, or assert it already holds. If setup itself fails, the scenario is reported BLOCKED, not RED — the test couldn't run. |
| `Given <precondition>` | Test setup (scenario-specific) | Same as Background, scoped to the scenario. |
| `When <action>` | Exercise the system under test | Drive the action via the worker's MCP / HTTP / CLI tools. |
| `Then <expectation>` | Assertion | Capture observed behavior with tool-output evidence. Compare against the stated expectation. |
| `Then` matches | GREEN | Report PASS for that step with evidence (snapshot text, SQL row, HTTP response). |
| `Then` mismatches | RED | Emit a `BEES REQUESTS:` entry. Continue to the next `Then` in the scenario if more remain. |
| All `Then` clauses GREEN | Scenario PASS | Report PASS for the scenario. |
| Any `Then` clause RED | Scenario FAIL | Report FAIL with the list of failing assertions. |

## Default Run (no `--fix`)

```
┌─────────────────┐
│ /qa <story>     │
└────────┬────────┘
         ▼
┌─────────────────┐
│ qa-lead parses, │
│ detects stack,  │
│ spawns workers  │
└────────┬────────┘
         ▼
┌─────────────────┐    PASS    ┌──────────────────────┐
│ workers run     ├───────────►│ scenario passes      │
│ scenarios       │            │ (no delta)           │
└────────┬────────┘            └──────────────────────┘
         │ FAIL
         ▼
┌─────────────────┐
│ worker emits    │
│ BEES REQUESTS:  │
└────────┬────────┘
         ▼
┌─────────────────┐
│ lead aggregates,│
│ routes to       │
│ bees-manager    │
└────────┬────────┘
         ▼
┌─────────────────┐
│ Report to user: │
│ filed issue IDs │
│ + PASS/FAIL list│
└─────────────────┘
```

The loop stops here. Filed issues are picked up via the regular `/core:bees` flow.

## Fix Run (`--fix`) — adversarial TDD pair

The fix loop uses two opposed agents per issue. They are intentionally split so neither can quietly relax the contract:

- **qa-test-writer** — writes ONE failing test. MAY edit tests only. MUST NOT touch production code.
- **qa-implementer** — writes the smallest production-code change to make the test pass. MAY edit production code only. MUST NOT touch tests.

The lead inspects `git diff --name-only` between phases. Any boundary crossing aborts the round with a `BLOCKED: <agent> crossed boundary` report.

```
… (default run through bees-manager) …
         │
         ▼
┌──────────────────────────┐
│ For each filed bees      │
│ issue: detect test       │
│ boundary, snapshot diff  │
└────────────┬─────────────┘
             ▼
┌──────────────────────────┐    ARTIFACT  ┌──────────────────────────┐
│ Spawn qa-test-writer:    ├─────────────►│ {path, test_name,        │
│ writes ONE failing test  │              │  runner_command}         │
│ in test/ ONLY            │              │ + verbatim RED output    │
└────────────┬─────────────┘              └────────────┬─────────────┘
             ▼                                         ▼
┌──────────────────────────┐                ┌──────────────────────────┐
│ Lead: git diff --name-   │  any non-test  │ REJECT — roll back       │
│ only HEAD.               ├───────────────►│ test-writer changes,     │
│ All paths must be in     │  path appears  │ halt this issue's loop   │
│ test/.                   │                │                          │
└────────────┬─────────────┘                └──────────────────────────┘
             │ clean
             ▼
┌──────────────────────────┐
│ Spawn qa-implementer:    │
│ given artifact (NOT      │
│ failure text). Writes    │
│ smallest fix outside     │
│ test/.                   │
└────────────┬─────────────┘
             ▼
┌──────────────────────────┐                ┌──────────────────────────┐
│ Lead: git diff --name-   │  any NEW test/ │ REJECT — roll back       │
│ only HEAD.               │  path appears  │ implementer changes      │
│ No new test-dir paths    ├───────────────►│ (keep test in place),    │
│ allowed.                 │                │ halt this issue's loop   │
└────────────┬─────────────┘                └──────────────────────────┘
             │ clean
             ▼
┌──────────────────────────┐    GREEN       ┌──────────────────────────┐
│ Re-run originating       ├───────────────►│ scenario passes — lead   │
│ validator                │                │ queues close for         │
│ (qa-playwright/tidewave/ │                │ bees-manager batch       │
│  backend)                │                │                          │
└────────────┬─────────────┘                └──────────────────────────┘
             │ still RED
             ▼
┌──────────────────────────┐
│ round += 1               │
│ if round == 3 → halt +   │
│ report stall             │
└──────────────────────────┘
```

Each agent honors the Three Laws (per `/core:tdd`): no production code without a failing test, no more test than is sufficient to fail, no more production code than is sufficient to pass. The boundary makes the laws structurally enforced rather than self-policed. Neither agent commits; the lead reports the diff and the user decides.

## Worked Example

Story scenario:

```gherkin
Scenario: Guest can complete an order
  Given a guest user on the cart page with one "Coffee Mug" in the cart
  When they click "Place order"
  Then they see "Order confirmed"
  And the orders table contains a row with email "guest@example.com" and total 1500
```

Round 1 (qa-playwright + qa-tidewave correlated):

- `qa-playwright` drives the UI; `Then "Order confirmed"` is **GREEN** — snapshot contains "Order confirmed".
- `qa-tidewave` runs `SELECT email, total FROM orders ORDER BY id DESC LIMIT 1` — returns `("guest@example.com", 1499)`. Expected `1500`. **RED**. Emits:

```
BEES REQUESTS (cwd: /repo):
- new title="qa: Guest can complete an order — orders.total off by one" body="Observed total=1499, expected 1500. SQL: SELECT email, total FROM orders ORDER BY id DESC LIMIT 1; result: (guest@example.com, 1499). Likely a cents-vs-tax rounding bug in OrderTotals.calc/2." priority=P2 external-ref="repo/docs/user-stories/checkout.md#Guest-can-complete-an-order" labels="qa,golden-path"
```

`bees-manager` files `github-42`. Default run ends here.

With `--fix`:

- `qa-test-writer` reads `github-42`. Writes `test/orders/totals_test.exs` asserting `OrderTotals.calc/2` returns 1500 for the fixture. Runs it. RED for the right reason. Returns artifact `{path: "test/orders/totals_test.exs", test_name: "OrderTotalsTest test calc/2 returns 1500 for the Coffee Mug fixture", runner_command: "mix test test/orders/totals_test.exs:23"}` + verbatim failure output.
- Lead `git diff --name-only`: only `test/orders/totals_test.exs` appeared. Boundary clean.
- `qa-implementer` receives only the artifact (no failure text). Reads the test file (read-only). Runs the targeted test — RED. Locates `lib/orders/totals.ex`. Writes the minimal fix. Runs the targeted test — GREEN. Runs `mise run test` — green.
- Lead `git diff --name-only`: `test/orders/totals_test.exs` (from test-writer) + `lib/orders/totals.ex` (from implementer). No NEW test paths. Boundary clean.
- Validator re-runs; SQL returns `1500`. Scenario PASSES. Lead routes `close github-42 reason="fix loop round 1: scenario now passes"` to `bees-manager`.
