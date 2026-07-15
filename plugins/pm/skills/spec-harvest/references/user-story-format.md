# User Story Format

The dialect pm-spec-writer uses to author user stories inside the feature inventory, and the confidence-annotation syntax that ties each story back to prototype evidence.

## Dialect Source

This dialect mirrors the qa plugin's Gherkin parser at `plugins/tools/qa/skills/qa/references/gherkin-format.md` (repo path, cited as source) — stay consistent with it rather than inventing a parallel grammar. Cucumber semantics below are sourced from https://cucumber.io/docs/gherkin/reference/ (fetched 2026-07-15).

## Accepted Keywords

| Keyword | Purpose | Cardinality |
|---|---|---|
| `Feature:` | Top-level title. | Exactly 1 per file. |
| `Background:` | Shared preconditions before every scenario. Given-only — no `When`/`Then`. | 0 or 1. |
| `Scenario:` | One discrete story. | 1 or more. |
| `Scenario Outline:` + `Examples:` | Parameterized scenario with an input table. | 0 or more, paired. |
| `Given` / `When` / `Then` / `And` / `But` | Step keywords; `And`/`But` inherit the preceding keyword. | Per the cardinality rules below. |
| `#` comments | Ignored by the parser. | 0 or more. |
| `@tags` | Tolerated, currently unused by worker assignment. | 0 or more. |

A `Scenario:` needs at least one `When` and at least one `Then`. NOT supported: `Rule:`, multiline steps, data tables — keep every step to one line.

## Cucumber Step Semantics

Per the Cucumber reference (fetched 2026-07-15):

- **Given** describes the known state of the system before the user starts interacting — preconditions, not actions.
- **When** describes user or system events, "deliberately avoiding implementation specifics."
- **Then** steps "only verify an outcome that is observable for the user (or external system)."
- Cucumber's authoring guidance: "Try hard to come up with examples that don't make any assumptions about technology or user interface."

These three rules are the enforcement mechanism for the implementation-agnostic writing rules in `SKILL.md` — a step that names a route, a table, or a process model violates the When/Then guidance above before it violates any project-specific style rule.

## Story File Shape

Each story inside the feature inventory follows this shape:

````markdown
# <Feature title>

**Persona**: <actor>

```gherkin
Feature: <feature title>

  Scenario: <golden-path scenario name>
    Given <precondition>
    When <action>
    Then <expected outcome>

  Scenario: <edge case scenario name>
    Given <precondition>
    When <action>
    Then <expected outcome>
```
````

The golden-path scenario comes first; edge cases and negative paths follow. Exactly one fenced ` ```gherkin ` block per story.

## Story Header

Above the fenced block, state the actor and intent using the standard form: `As a <actor>, I want <behavior>, so that <outcome>` (form per https://www.agilealliance.org/glossary/user-stories/, fetched 2026-07-15). That page names the INVEST criteria without expanding them; any INVEST expansion used during authoring is standard engineering knowledge, not a claim sourced from that page.

## Confidence Annotation Syntax

Attach one tag to every acceptance criterion and every data-shape or interaction claim in a story:

- `[seen-in-code: path/to/file]` — traced to a specific file.
- `[inferred — needs verification]` — a reasonable inference with no direct file confirmation.

Tags attach to prose (acceptance criteria, data shape notes) surrounding the fenced Gherkin block, not inside the Gherkin steps themselves — the steps stay dialect-clean for the qa parser.

## Good vs. Bad Examples

| Implementation-specific (reject) | Implementation-agnostic (accept) | Why |
|---|---|---|
| `When I POST to /api/v1/cart/checkout with {"items": [...]}` | `When they click "Checkout"` | Names a route and payload shape instead of the user action. |
| `Then the orders row in Postgres has status_id = 3` | `Then they see "Order confirmed"` | Names a database column and a magic number instead of a user-observable outcome. |
| `When the GenServer receives a :checkout cast` | `When they fill in "Shipping address" with "123 Main St"` | Names an OTP process model instead of a user interaction. |

## Full Worked Example

````markdown
# Guest checkout

**Persona**: guest shopper

```gherkin
Feature: Guest checkout

  Scenario: Guest completes an order with one item
    Given a guest with one item in their cart
    When they click "Checkout"
    And they fill in "Email" with "guest@example.com"
    And they fill in "Shipping address" with "123 Main St"
    And they click "Place order"
    Then they see "Order confirmed"

  Scenario: Empty cart blocks checkout
    Given a guest with an empty cart
    When they click "Checkout"
    Then they see "Your cart is empty"
```

Acceptance criteria:
- Order confirmation displays after checkout with a non-empty cart. `[seen-in-code: web/router.ex]`
- Checkout is blocked when the cart has zero items. `[seen-in-code: lib/store/cart.ex]`
- Guest checkout does not require an account. `[inferred — needs verification]`
````
