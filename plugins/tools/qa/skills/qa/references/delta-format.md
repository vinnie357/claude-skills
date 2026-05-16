# BEES REQUESTS Block Format

The exact shape workers emit and the lead aggregates before routing to the `bees-manager` agent.

This grammar mirrors the input contract in `plugins/core/skills/bees/agents/bees-manager.md` lines 33–41 — that agent file is the source of truth. Keep this reference and that agent in sync; if the lead routes a block the manager cannot parse, the contract is broken.

## Block Shape

A worker's final report contains exactly one `BEES REQUESTS:` block. The block has a header line naming the cwd, followed by one entry per line. Empty list (no deltas) means PASS — the worker writes `BEES REQUESTS (cwd: <repo>): none` or omits the block entirely.

```
BEES REQUESTS (cwd: <absolute-repo-root>):
- new title="<title>" body="<body>" priority=P<N> external-ref="<url-or-path-fragment>" labels="<csv>"
- close github-<N> reason="<reason>"
- dep add github-<NEW> --blocks-on github-<EXISTING>
- update github-<N> <field>="<value>"
```

The lead concatenates blocks from every worker in the run before routing.

## Field Rules

### `new` entries (the only kind workers emit during default validation)

| Field | Required | Format | Notes |
|---|---|---|---|
| `title` | yes | `qa: <scenario-name> — <failing-assertion>` | Keep under ~100 chars. Use the scenario name exactly as written in the story. |
| `body` | yes | Free-form multi-line text | MUST include observed value, expected value, reproduction steps, and tool-output evidence. |
| `priority` | yes | `P0`–`P3` | `P0` only for golden-path scenarios that 100% block users. Default to `P2` for golden-path deltas, `P3` for edge-case deltas. |
| `external-ref` | yes | `<repo>/docs/user-stories/<slug>.md#<scenario>` | Anchors the issue back to the story scenario. `bees-manager` dedupes on external-ref. |
| `labels` | yes | Comma-separated list | Always includes `qa`. Add `golden-path` for the primary happy-path scenario. Add `edge` for failure-path scenarios. |

### `close` and `dep add` entries

Workers do NOT emit these. Only the lead may add them, after the fix loop completes. The lead emits a `close github-<N> reason="fixed in qa-fixer round <K>"` per scenario that went from RED to GREEN, batched into the same `bees-manager` invocation as any further `new` entries from the post-fix re-run.

## Body Template

Workers populate this template; `qa-lead` does not rewrite it.

```
Observed: <one-line summary of what the assertion captured>
Expected: <one-line summary of what the scenario said>

Scenario: <scenario name>
Step:     <the failing Then clause, verbatim>

Reproduction:
1. <first preceding Given/When>
2. <second preceding Given/When>
…

Evidence (<tool>):
<tool output excerpt — snapshot text / SQL result / HTTP response / log line>
```

Evidence is mandatory. A `new` entry without an `Evidence:` section is rejected by the lead before routing — it would let a fabricated delta slip through.

## Worker Output Discipline

Each worker's final message contains, in this order:

1. Skill-load proof (one sentence quoted per loaded skill).
2. Stack triple (echoed from the lead's brief, for traceability).
3. Per-scenario report:
   - Scenario name.
   - PASS/FAIL.
   - For PASS: a one-line summary + tool-output evidence.
   - For FAIL: the full body template above.
4. The single `BEES REQUESTS:` block (or `none`).

The lead's aggregator parses block #4 from every worker. It does not parse evidence text — evidence is the worker's contract with the user, not with the manager.

## Deduplication

The lead dedupes by `(title, external-ref)` before routing. When two workers (e.g. `qa-playwright` + `qa-tidewave` correlated on the same scenario) flag overlapping failures, the lead keeps one entry, concatenates both `body` fields under separate `Evidence:` sections, and routes a single `new` to the manager.

## Routing

Once aggregated, the lead spawns ONE `bees-manager` subagent (subagent_type `bees-manager`) with the full block as its input. Per `bees-manager` line 28: "The lead spawns ONE `bees-manager` per batch — never two in parallel against the same DB." For two repos in one run (which `/qa` does not currently support), serialize the manager calls.

## Example

Two workers, one scenario, two failing assertions, deduped to one entry:

```
BEES REQUESTS (cwd: /Users/dev/storefront):
- new title="qa: Guest can complete an order — orders.total off by one" body="Observed: orders.total=1499 in DB. Expected: 1500 per scenario.

Scenario: Guest can complete an order
Step:     And the orders table contains a row with email \"guest@example.com\" and total 1500

Reproduction:
1. Given a guest user on the cart page with one \"Coffee Mug\" in the cart
2. When they click \"Place order\"

Evidence (tidewave execute_sql_query):
SELECT email, total FROM orders ORDER BY id DESC LIMIT 1;
 email                | total
----------------------+-------
 guest@example.com    |  1499

Evidence (playwright browser_snapshot):
heading \"Order confirmed\" present at #order-summary
" priority=P2 external-ref="storefront/docs/user-stories/checkout.md#Guest-can-complete-an-order" labels="qa,golden-path"
```

The manager files this once; both pieces of evidence travel with it.
