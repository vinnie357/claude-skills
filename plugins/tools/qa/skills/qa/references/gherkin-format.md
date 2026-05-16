# Gherkin Format Reference

The dialect `/qa` accepts, the parsing rules, and the rejection criteria.

## File Layout

User stories live at `docs/user-stories/<slug>.md` in the target repo. One story per file. The slug is kebab-case and becomes the file name.

The file is a markdown document with **at least one** fenced Gherkin block:

````markdown
# <Human-readable title>

Optional prose context — not parsed.

```gherkin
Feature: <one-line feature title>

  Background:
    Given <shared precondition 1>
    And <shared precondition 2>

  Scenario: <scenario name>
    Given <precondition>
    When <action>
    Then <expected outcome>

  Scenario: <another scenario name>
    Given <precondition>
    When <action>
    And <another action>
    Then <expected outcome>
    And <another expectation>
```
````

The lead concatenates the content of every ```gherkin fenced block in the file before parsing. Prose outside fences is informational.

## Accepted Keywords

| Keyword | Purpose | Cardinality |
|---|---|---|
| `Feature:` | Top-level title. One per file. | Exactly 1 (across all blocks combined). |
| `Background:` | Shared steps applied before every `Scenario:` in the file. | 0 or 1. |
| `Scenario:` | One discrete validation work item. Becomes one worker invocation. | At least 1. |
| `Scenario Outline:` | Parameterized scenario. Pairs with `Examples:`. | 0+. |
| `Examples:` | Table of inputs for the immediately preceding `Scenario Outline:`. | 0+, one per outline. |
| `Given` | Precondition step. | 0+ per scenario or background. |
| `When` | Action step. | 1+ per scenario. |
| `Then` | Expectation step. | 1+ per scenario. |
| `And` | Continuation of the immediately preceding `Given`/`When`/`Then`. | 0+. |
| `But` | Negative continuation of the preceding step. Treated like `And`. | 0+. |
| `#` | Comment line. Ignored by the parser. | 0+. |

Tags (lines starting with `@`) are tolerated but currently ignored — they have no effect on worker assignment.

## Parsing Rules

1. **Feature title** is the text after `Feature:` on the same line. Required.
2. **Background steps** apply to every `Scenario:` and `Scenario Outline:` in the same file. They are prepended (in declared order) to each scenario's step list before worker assignment.
3. **Scenario name** is the text after `Scenario:` on the same line. Used in `BEES REQUESTS:` titles. Must be non-empty.
4. **Step continuation**: `And` and `But` inherit the keyword of the most recent `Given`/`When`/`Then` line.
5. **`Scenario Outline:` expansion**: one work item per row in the `Examples:` table. The `<placeholder>` markers in steps are substituted from each row before dispatch.
6. **No nested fences**: a ```gherkin block cannot contain another ``` fence.
7. **No code, no comments inside steps**: a step is a single line of plain text after its keyword. Multiline step text and data tables are NOT supported in v0.1.0 — keep steps to one line each.

## Rejection Criteria

The `qa-lead` aborts (no workers spawned) if any of the following hold. Each rejection includes the rule number in the error report so the user can fix the file.

1. File does not exist at the resolved path.
2. Path is outside `docs/user-stories/` in the target repo.
3. No ```gherkin fenced block present.
4. Zero `Feature:` lines, or more than one.
5. Zero `Scenario:` / `Scenario Outline:` blocks.
6. A `Scenario:` has zero `When` lines or zero `Then` lines.
7. An `And` or `But` line appears before any `Given`/`When`/`Then` in its scenario.
8. A `Scenario Outline:` is missing its `Examples:` table, or the table is empty, or a step references a `<placeholder>` not present in the table header.
9. A multiline step (continuation without a leading keyword) is detected.
10. `Background:` contains a `When` or `Then` (Background may only contain `Given` and continuations).

## Worker Assignment Hints

The lead inspects each fully-expanded scenario's step text to assign a worker, per `references/stack-detection.md`:

- Step text mentions a URL, page, button, link, form, click, type, see, scroll, navigate → likely UI → `qa-playwright`.
- Step text mentions a record, row, query, schema, GenServer, log, Phoenix module, Ecto, supervisor → likely Phoenix backend → `qa-tidewave`.
- Step text mentions an endpoint, status code, response body, JSON, HTTP, CLI command, exit code → generic backend → `qa-backend`.
- Mixed → multiple workers correlate by scenario name.

The hints are heuristic. When uncertain, the lead asks via AskUserQuestion before spawning.

## Full Example

````markdown
# Checkout flow

Validates the guest checkout golden path against a Phoenix LiveView storefront.

```gherkin
Feature: Guest checkout

  Background:
    Given the storefront is running at http://localhost:4000
    And the product "Coffee Mug" exists with price 1500 cents in inventory

  Scenario: Guest can complete an order with a single item
    Given a guest user on the cart page with one "Coffee Mug" in the cart
    When they click "Checkout"
    And they fill in "Email" with "guest@example.com"
    And they fill in "Shipping address" with "123 Main St"
    And they click "Place order"
    Then they see "Order confirmed"
    And the orders table contains a row with email "guest@example.com" and total 1500

  Scenario: Cart-empty guard prevents checkout
    Given a guest user on the cart page with an empty cart
    When they click "Checkout"
    Then they see "Your cart is empty"
    And the URL stays on /cart
```
````

The lead expands this into two work items:

- Scenario 1 → split: `qa-playwright` covers the UI assertions ("see Order confirmed"), `qa-tidewave` covers the DB assertion ("orders table contains a row…"). Correlated by scenario name.
- Scenario 2 → `qa-playwright` only.
