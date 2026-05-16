# <Feature title — human readable>

<Optional prose explaining the feature, the user, and why this scenario matters. Not parsed by `/qa`.>

```gherkin
Feature: <one-line feature title>

  Background:
    Given the <app|service> is running at <http://localhost:PORT>
    And <any shared seed data or auth state>

  Scenario: <Golden-path scenario — the single most important happy flow>
    Given <starting condition>
    When <user action>
    And <another action if needed>
    Then <observable expected outcome>
    And <another expectation if the outcome has multiple facets>

  Scenario: <Edge / error scenario — optional, repeat as needed>
    Given <starting condition>
    When <user action>
    Then <expected guardrail or error message>
```

## Notes for authors

- Keep each `Scenario:` focused on one user-visible outcome. If a scenario has more than ~5 `Then` clauses, split it.
- `Background:` is shared by every scenario in the file. Put the app URL there.
- The golden-path scenario goes first. Edge cases follow.
- `When` describes user actions; `Then` describes observable outcomes. Don't put internal implementation details in `Then` — assert on what a user can see (UI text, an HTTP response field, a row in a public table), not on private state.
- Steps are single-line. No multi-line `When` or `Then` in v0.1.0.
- The parser rules and rejection criteria are in `references/gherkin-format.md` of the `/qa:qa` skill.
