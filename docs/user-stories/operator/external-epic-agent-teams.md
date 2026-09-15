# External epic drives agent teams

**Persona**: `operator`

The operator files work as an external epic and expects an agent team to plan, implement, and land it without leaving tracker debris or tracker ids on `main`. This story validates the process decided in ADR 0001 (`docs/adr/0001-agent-loop-process.md`): durable vs. ephemeral artifacts, the epic-to-team relationship, reviewer evidence discipline, harness-agnostic model selection, and the tracker-id lint.

```gherkin
Feature: External epic drives agent teams

  Background:
    Given an external epic lists user stories, repos, and ADRs to satisfy

  Scenario: Golden path from epic to merged PR
    Given a lead reads the external epic's user stories, repos, and ADRs
    When the lead dispatches an agent team to implement the epic
    And the team chooses its own implementation and records each decision in an ADR
    Then the merged PR adds only code, ADR changes, and user story updates to main

  Scenario: Branch scratch is pruned before merge
    Given the team used bees issues and a spec on its feature branch
    When the team merges the branch to main
    Then main holds neither the bees issues nor the spec

  Scenario: Reviewer gathers evidence through hands, not direct execution
    Given a reviewer needs to confirm a test result
    When the reviewer spawns a hand on the smallest fast tier to run the test
    Then the reviewer posts findings as path:line lines and runs no command itself

  Scenario: Any harness runs the same loop
    Given claude, codex, or agy launches the loop
    When each role starts its tier
    Then each role receives its tier's mapped model at medium effort

  Scenario: A tracker id in a diff fails the repo lint
    Given a PR adds a tracker id to a code file
    When the repo lint runs on the diff
    Then the lint fails
```
