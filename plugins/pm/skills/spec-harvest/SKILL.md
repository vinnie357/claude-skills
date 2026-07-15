---
name: spec-harvest
license: MIT
description: "Extracts implementation-agnostic feature specs from working prototypes with SDLC guardrails. Use when handing off a prototype to an engineering team, reverse-engineering prototype code into user stories and acceptance criteria, assessing licensing, security, or supportability risks, or reading bees epics to produce coding specs for a production implementation."
---

# Spec Harvest

Extracts a customer-value feature inventory, an SDLC risk assessment, and per-feature PRDs from a working prototype — without carrying the prototype's implementation choices into the spec. `/pm:harvest` runs all four phases end-to-end via an agent team; `/pm:assess` runs phase 3 alone against an existing inventory.

## When to Use

Activate when:
- Handing a prototype to an engineering team that will rebuild it for production.
- Reverse-engineering prototype code into user stories and acceptance criteria.
- Assessing licensing, security, or supportability risk before a production build.
- Reading bees epics alongside prototype code to produce a coding spec.
- Separating customer-value behavior from prototype shortcuts before scoping work.

## Four Phases

1. **Discovery** — pure inventory, no judgment. Record what is observed: routes/pages, data models, external integrations, dependencies, technology stack and framework choices. Every entry carries a confidence tag (see Anti-Fabrication below).
2. **Separation** — split discovery findings into (a) customer-value features: behaviors users actually want regardless of implementation — what a user can do, what data shapes and interactions matter, what outcomes the user cares about; and (b) prototype shortcuts that must NOT carry forward: zero/minimal authentication, hardcoded data, scale/performance assumptions.
3. **SDLC assessment** — run `references/sdlc-checklist.md` against the prototype: licensing, security, supportability. `/pm:assess` invokes this phase standalone.
4. **Spec generation** — three artifact types: the feature inventory (`templates/feature-inventory.md`), the SDLC assessment (`templates/sdlc-assessment.md`), and one PRD per major feature area authored via `/pm:prd` in grounded mode.

## Team Shape

| Agent | Model | Phase | Responsibility |
|---|---|---|---|
| pm-lead | opus | all | Orchestrates the team, sequences phases, aggregates worker reports. |
| pm-discovery | haiku | 1 | Runs one of four inventory shards: routes-pages, data-models, integrations-deps-stack, bees-map. |
| pm-separator | sonnet | 2 | Splits discovery output into customer-value features vs. prototype shortcuts. |
| pm-sdlc-assessor | sonnet | 3 | Runs the SDLC checklist, produces risk findings. |
| pm-spec-writer | sonnet | 4 | Writes the feature inventory and SDLC assessment artifacts. |
| pm-prd-author | sonnet | 4 | Authors one PRD per major feature area via `/pm:prd`. |

pm-lead never runs discovery, separation, or assessment itself — it spawns workers per phase and aggregates their reports. Phase 1 fans out to three-to-four pm-discovery shards in parallel — the bees-map shard runs only when `.bees/` exists; phases 2–4 run one worker at a time against the accumulated findings.

## Implementation-Agnostic Writing Rules

Every artifact this skill produces describes behaviors, not implementations; data shapes, not schemas; interactions, not APIs; user experiences, not frameworks. Name the WHAT and the WHY, never the HOW.

**Portability test**: a different engineering team with a different technology stack could implement the spec without reading the prototype's source.

| Implementation-specific (reject) | Implementation-agnostic (accept) |
|---|---|
| `When I POST to /api/v1/cart/checkout with {"items": [...]}` | `When they click "Checkout"` |
| `Then the orders row in Postgres has status_id = 3` | `Then they see "Order confirmed"` |
| `When the GenServer receives a :checkout cast` | `When they fill in "Shipping address" with "123 Main St"` |

A finding that names a database column, an HTTP verb, a process model, or a specific library belongs in the discovery shard's evidence trail, not in a user story or acceptance criterion. `references/user-story-format.md` has the full authoring rules and a worked example.

## Bees Integration (Read-Only)

pm-discovery's bees-map shard reads `.bees/` for roadmap intent (open issues) and completed-work provenance (closed issues, cited by ID) when the prototype has a bees tracker. No phase in this skill ever calls a bees write command — `bees list`, `bees show`, `bees ready`, `bees prime`, `bees dep list`, and `bees comment list` are the entire surface. Full detection and mapping rules live in `references/bees-to-spec.md`.

## SDLC Assessment

The checklist in `references/sdlc-checklist.md` covers three areas — licensing (SPDX identifiers, copyleft exposure, vendored code provenance), security (OWASP Top 10 2025 categories), and supportability (observability, rollback, secrets handling) — each with prototype-specific evidence to collect and typical shortcuts to flag. pm-sdlc-assessor runs every checklist row against the prototype and records findings with a severity and a confidence tag.

## User Story Format

Feature inventory entries use a Gherkin dialect that mirrors the qa plugin's parser (`plugins/tools/qa/skills/qa/references/gherkin-format.md`, cited as source): `Feature:` once, optional `Given`-only `Background:`, one or more `Scenario:` blocks each needing at least one `When` and one `Then`. Full authoring rules, cucumber step semantics, and a worked example are in `references/user-story-format.md`.

## Anti-Fabrication Confidence Tags

Every claim in every artifact this skill produces carries one of two tags:

- `[seen-in-code: <path>]` — the claim traces to a specific file the agent read.
- `[inferred — needs verification]` — the claim is a reasonable inference (from a route name, a bees issue, an incomplete code path) that no file confirms directly.

An entry with neither tag is incomplete. `/core:anti-fabrication` governs this rule; load it at the start of every phase.

Example evidence line from a feature-inventory entry:

```
- Checkout is blocked when the cart has zero items. [seen-in-code: lib/store/cart.ex]
- Guest checkout does not require an account. [inferred — needs verification]
```

## Output Convention

Artifacts are markdown only. `OUTPUT_DIR` defaults to `docs/pm/` in the target repo. Filenames carry an ISO date:

- `<OUTPUT_DIR>/<YYYY-MM-DD>-feature-inventory.md`
- `<OUTPUT_DIR>/<YYYY-MM-DD>-sdlc-assessment.md`
- `<OUTPUT_DIR>/prd/<YYYY-MM-DD>-<feature-area>.md`

## Reference files

- `references/user-story-format.md` — Gherkin dialect for user stories, cucumber step semantics, confidence annotation syntax, good-vs-bad examples, one worked example.
- `references/bees-to-spec.md` — read-only bees command surface, detection rule, mapping workflow from bees issues to feature-inventory entries.
- `references/sdlc-checklist.md` — licensing, security (OWASP Top 10 2025), and supportability checklist rows for pm-sdlc-assessor.
- `templates/feature-inventory.md` — copyable skeleton for the phase 4 feature inventory artifact.
- `templates/sdlc-assessment.md` — copyable skeleton for the phase 4 SDLC assessment artifact.
