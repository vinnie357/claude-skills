---
name: prd
description: "Structured PRD authoring where the PRD is the contract for specs delivered to implementing teams, human or agent. Use when writing a product requirements document, turning a spec-harvest feature inventory into per-feature PRDs, running /pm:prd, or defining scope boundaries and acceptance criteria for an engineering handoff."
license: MIT
---

# PRD Authoring

Author a Product Requirements Document that serves as the handoff contract between product intent and an implementing team — human or AI agent. The PRD states WHAT the feature does and WHY it exists; it never prescribes HOW to build it.

## When to Use

Activate when:
- The `/pm:prd` command is invoked.
- Turning one feature-area entry from a `/pm:spec-harvest` feature inventory into a standalone PRD.
- Defining scope boundaries, acceptance criteria, or success metrics before an engineering handoff.
- Reviewing an existing PRD for implementation leakage (tech names, schemas, API shapes) or missing non-goals.

## PRD as Contract

A PRD is complete when the implementing team needs no follow-up questions to start work. Treat every unanswerable question as a defect in the document, not a gap the implementer fills in.

**Non-goals are as firm as goals.** State exclusions positively and explicitly — "does not support X" — never by silent omission. An agent implementer cannot infer a boundary from absence: omitting "do not implement X" from the PRD is how an agent ends up building X. A human team asks follow-up questions; an agent team does not, so write for the stricter reader.

**The PRD stays at the WHAT/WHY altitude.** A PRD is not a software requirements specification. Writing a PRD ensures user-centric context; a separate, downstream implementation spec — authored by a PM or engineer AFTER this PRD, never inside it — is where SRS-level HOW-level agent operating instructions (file layout, framework choice, API contracts) belong.

**Completeness test:** before calling a PRD done, walk every section and confirm a different engineering team with a different tech stack could implement it without contacting the author.

## Two Modes

`/pm:prd` runs `pm-prd-author` in one of two modes:

1. **Interactive** (default) — the `/pm:prd` command session runs the questionnaire (problem, users, goals, non-goals, stories, constraints, phasing) via `AskUserQuestion`, since the spawned `pm-prd-author` agent has no channel to the operator. The agent then composes the PRD from the collected answers, each tagged `[operator-stated]`.
2. **Harvest-grounded** (`--inventory=<path>`) — the feature inventory from `/pm:spec-harvest` is the grounding document. One PRD is authored per major feature area named in the inventory; requirements are lifted from inventory entries and carry their original confidence tags. Sections the inventory cannot answer become Open Questions rows rather than invented content.

## Template Walkthrough

`templates/prd.md` is the skeleton every PRD composes against. Section intent:

| Section | What belongs there |
|---|---|
| Header | Title, ISO date, status, change history — who changed what and when |
| Problem / Opportunity | The problem and why it matters now, not the solution |
| Target Users & Personas | Who is affected, with the primary persona called out |
| Goals & Success Metrics | Outcomes and how they are measured, not features |
| Non-Goals / Out of Scope | Explicit exclusions with a reasoning column — prevents scope creep and agent over-implementation |
| User Stories + Acceptance Criteria | As a X, I want Y, so that Z — with Given/When/Then acceptance criteria per story |
| Data Shapes | Fields and relationships in prose or tables — never DDL, never a schema definition |
| UX & Interaction Requirements | Experiences and interactions — never named frameworks or components |
| Constraints & Dependencies | Business, legal, or sequencing constraints — not technical implementation constraints |
| Release Phasing | What ships first vs. later, and why the split |
| Open Questions | Question, owner, blocking? — for everything the author could not answer |
| Grounding Documents | Links back to the feature inventory or bees issues that grounded this PRD |

## Implementation-Agnostic Rules

Every requirement obeys four not-rules:

- Behaviors, not implementations.
- Data shapes, not schemas.
- Interactions, not APIs.
- User experiences, not frameworks.

**Portability test:** a requirement passes only if a different engineering team with a different tech stack could implement it from the sentence alone.

```
Bad:  "Store the draft in a Postgres jsonb column and debounce autosave via a
      React useEffect hook calling PATCH /api/drafts/:id every 2 seconds."
Good: "The user's in-progress draft persists automatically without an explicit
      save action. Persistence happens frequently enough that a browser crash
      loses no more than a few seconds of work."
```

## Anti-Fabrication

Every requirement traces to a questionnaire answer or a feature-inventory entry — never invented. Tag every requirement with its origin:

- `[operator-stated]` — given directly by the user in the interactive questionnaire.
- `[seen-in-code: <path>]` — lifted from a feature-inventory entry that cites a source file.
- `[inferred — needs verification]` — a reasonable inference not directly stated; must also appear as an Open Questions row.

A section the source material cannot answer becomes an Open Questions row, never fabricated prose.

## References

- `templates/prd.md` — the copyable PRD skeleton with all sections above.
- `/pm:spec-harvest` — produces the feature inventory that grounds harvest mode.
