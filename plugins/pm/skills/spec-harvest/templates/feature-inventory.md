# Feature Inventory: <prototype name>

**Date**: <YYYY-MM-DD>
**Prototype path**: <path>

## Feature Summary

| ID | Name | Value statement | Confidence |
|---|---|---|---|
| F1 | <feature name> | <what the user gets and why they want it> | seen-in-code / inferred |

## F1: <feature name>

**As a** <actor>, **I want** <behavior>, **so that** <outcome>.

```gherkin
Feature: <feature title>

  Scenario: <golden-path scenario name>
    Given <precondition>
    When <action>
    Then <expected outcome>
```

**Data shapes** (prose, no schemas): <what data the feature reads or produces, described by shape and meaning, not column names>

**Interactions** (no APIs): <what the user does and what they see back>

**Evidence**:
- <claim> `[seen-in-code: <path>]`
- <claim> `[inferred — needs verification]`

**Bees provenance**: <issue IDs, open = roadmap / closed = shipped, or "no bees tracker found">

## Prototype Shortcuts (do NOT carry forward)

| Shortcut | Risk | Production requirement |
|---|---|---|
| <e.g. hardcoded seed data> | <what breaks in production> | <what replaces it> |

## Bees Appendix

- **Open issues (roadmap intent)**: <list, or "none" / "no bees tracker found">
- **Closed issues (completed-work provenance)**: <list, or "none" / "no bees tracker found">
