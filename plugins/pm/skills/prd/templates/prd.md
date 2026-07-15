<!-- Copy this file to author a new PRD. Replace every <angle-bracket> placeholder.
     Keep every requirement at the WHAT/WHY altitude — see /pm:prd "Implementation-Agnostic Rules". -->

# <Feature Area Title>

<!-- Header: title, ISO date, status, change history. -->
- **Date:** <YYYY-MM-DD>
- **Status:** <Draft | In Review | Approved>
- **Change History:**
  | Date | Change | Author |
  |---|---|---|
  | <YYYY-MM-DD> | Initial draft | <name> |

## Problem / Opportunity

<!-- The problem and why it matters now — not the solution. -->
<One to three paragraphs describing the problem or opportunity. [operator-stated] or [seen-in-code: <path>]>

## Target Users & Personas

<!-- Who is affected; call out the primary persona explicitly. -->
- **Primary persona:** <name/role> — <one-line description>
- **Secondary personas:** <name/role> — <one-line description>

## Goals & Success Metrics

<!-- Outcomes and how they are measured — not features. -->
| Goal | Success Metric | Confidence |
|---|---|---|
| <outcome the feature achieves> | <how it is measured> | [operator-stated] |

## Non-Goals / Out of Scope

<!-- Explicit exclusions with reasoning. Non-empty on every PRD — an agent implementer
     cannot infer a boundary from omission. -->
| Excluded Item | Why Excluded |
|---|---|
| <capability explicitly not being built> | <reasoning — e.g. "deferred to phase 2", "out of scope per operator decision"> |

## User Stories + Acceptance Criteria

<!-- As a X, I want Y, so that Z. Acceptance criteria in Given/When/Then form,
     consistent with the qa Gherkin dialect. -->

### Story: <short story title>

As a <persona>, I want <capability>, so that <benefit>. `[operator-stated]`

**Acceptance Criteria:**

```gherkin
Scenario: <scenario name>
  Given <precondition>
  When <action>
  Then <expected outcome>
```

## Data Shapes

<!-- Fields and relationships in prose or tables — never DDL, never a schema definition. -->
| Entity | Fields | Relationships |
|---|---|---|
| <entity name> | <field: description>, <field: description> | <relationship to other entities> |

## UX & Interaction Requirements

<!-- Experiences and interactions — never named frameworks or components. -->
- <The user can accomplish X without Y friction.>

## Constraints & Dependencies

<!-- Business, legal, or sequencing constraints — not technical implementation constraints. -->
- <constraint or dependency, with source tag>

## Release Phasing

<!-- What ships first vs. later, and why the split. -->
| Phase | Scope | Rationale |
|---|---|---|
| Phase 1 | <minimum scope> | <why this ships first> |

## Open Questions

<!-- Everything the author could not answer. Never fabricate a value here — file the question instead. -->
| Question | Owner | Blocking? |
|---|---|---|
| <example: what is the maximum acceptable latency for this action?> `[inferred — needs verification]` | <role or name> | Yes |

## Grounding Documents

<!-- Links to the feature inventory or bees issues that grounded this PRD (harvest mode only). -->
- <link to feature-harvest inventory section, or bees issue reference>
