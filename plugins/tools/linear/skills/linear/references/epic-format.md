# VantageEx Epic Format Specification

## Table of Contents

- [Overview](#overview)
- [Three-Level Hierarchy](#three-level-hierarchy)
- [Required Sections](#required-sections)
- [Optional Sections](#optional-sections)
- [Title and Slug](#title-and-slug)
- [Description Sections (ADR-027)](#description-sections-adr-027)
- [Instructions Flow](#instructions-flow)
- [Anti-Patterns](#anti-patterns)
- [Example Epic](#example-epic)

## Overview

VantageEx parses Linear issue descriptions programmatically. The epic body uses markdown `## Section` headers that VantageEx reads at pick time and on every poll. Sections must use exact header names — the parser matches on these strings.

Source: ADR-027 (Epic Messaging), ADR-016 (Layered Tasking), ADR-025 (Epic Lifecycle).

## Three-Level Hierarchy

| Level | Created By | Purpose |
|-------|-----------|---------|
| **Epic** | User | Assignment: objective, skills, constraints. No implementation details. |
| **Issues** | Team leader | Independently deliverable slices with acceptance criteria |
| **Tasks** | Agents | Granular implementation steps, invisible to the user |

The user's job is to write a great epic. The team leader handles decomposition. Agents create their own tasks.

## Required Sections

### `## Objective`

2-3 sentences defining what success looks like. The team leader uses this to validate completion and decompose the epic into issues.

- Immutable after creation (user-written)
- Read at pick time and every poll
- Must define acceptance criteria at a high level

Good: "Users can authenticate via Google/GitHub OAuth2 with PKCE. Tokens refresh automatically. All auth endpoints pass OWASP top-10 checks."

Bad: "Make auth work better"

### `## Skills`

Domain-specific skills needed for this epic. Listed as a comma-separated list or YAML array.

Core skills are always loaded and must NOT be listed:
- anti-fabrication, git, tdd, twelve-factor, security, mise, nushell

Only list domain-specific extras:

```yaml
skills: [elixir, oauth, security]
```

Skills must exist in the marketplace at: https://github.com/vinnie357/claude-skills/blob/main/.claude-plugin/marketplace.json

### `## Repos`

Target repositories this epic touches:

```
- vinnie357/vantageex
- vinnie357/runex
```

May be a single repo or multiple. ADR-023 supports multi-repo epics with parallel execution.

## Optional Sections

### `## Instructions` (ADR-027)

User guidance added when re-queuing an epic from `needs_help` state. Takes priority over general conventions.

- Written by the user via dashboard text area or manually in Linear
- VantageEx writes back to Linear idempotently
- Agents receive as `EPIC_INSTRUCTIONS` environment variable
- Agent prompt: "If the epic has a ## Instructions section, read it carefully. These take priority over general conventions."
- Separate from objective for historical preservation

### `## Constraints`

Real boundaries that apply to the entire epic. Defaults if omitted:

```yaml
constraints:
  - All code must pass `mise run ci`
  - No attribution in commits
  - Feature branch: feature/<epic-slug>
  - Squash merge only
```

Only include constraints that differ from defaults or add specific boundaries.

### `## Team`

Team composition and model assignments:

```yaml
team:
  lead: sonnet
  default_model: haiku
  escalation: haiku -> sonnet -> opus
```

If omitted, the system infers team shape from epic complexity.

### `## Escalation`

Failure and ambiguity policies:

```yaml
escalation:
  on_agent_failure: promote_model
  on_ambiguity: ask_user
  on_dependency_conflict: ask_user
```

Model promotion follows: haiku -> sonnet -> opus (max 2 promotions per agent).

### `## PR`

Written by the agent when a PR is submitted. Contains the pull request URL.

- Not user-authored
- VantageEx reads this section to track PR state
- Written once at submission time

## Title and Slug

### Title

A clear, imperative statement of what gets built.

- Good: "Implement OAuth2 PKCE flow for API gateway"
- Bad: "Auth stuff" / "Fix login"

### Slug

Short, URL-safe identifier used in session names and branch names.

- Format: kebab-case
- Max ~30 characters
- Good: `oauth-pkce-flow`
- Bad: `implement-the-full-oauth2-pkce-flow-for-our-api-gateway`

The slug determines the feature branch name: `feature/<epic-slug>`

Max 80 characters when combined with role prefix: `<epic-slug>/_team/leader-<model>`

## Description Sections (ADR-027)

Two communication channels:

### Channel 1: Description Sections (Structured Configuration)

| Section | Who Writes | Who Reads | Lifecycle |
|---------|-----------|----------|-----------|
| `## Objective` | User (immutable) | Poller, agents | Read at pick time and every poll |
| `## Skills` | User (immutable) | Poller | Matched against agent capabilities |
| `## Repos` | User (immutable) | Poller | May be multiple |
| `## Instructions` | User/dashboard | Agents | Optional; present only if user provided guidance |
| `## PR` | Agent | User via dashboard | Written once at submission |

### Channel 2: Comments (Conversational Messaging)

- Append-only conversation threads in Linear
- Polled only for `in_progress` epics (minimize overhead)
- Incremental polling via `last_comment_check_at` cursor
- Users, agents, and VantageEx can post comments
- Broadcast via PubSub for real-time dashboard updates

## Instructions Flow

When an epic lands in `needs_help`:

1. Agent posts comment with blocker details
2. User reads comment, provides guidance
3. User moves epic to `up_next` via dashboard with "Re-queue Guidance" text
4. VantageEx writes `## Instructions` section to Linear (idempotent)
5. VantageEx sets `epic.user_instructions` field
6. New agent picked, receives `EPIC_INSTRUCTIONS` env var
7. Agent reads instructions, implements with corrected approach

Previous instructions are visible in the comment thread for history.

## Anti-Patterns

Do NOT include in epics:

- **Implementation details** — let agents decide HOW
- **File paths** — let agents discover the codebase
- **Step-by-step instructions** — that is what skills are for
- **Acceptance criteria per issue** — the team leader writes those during decomposition
- **Model assignments per task** — the system optimizes this
- **Core skills in the skills list** — they are always loaded

## Example Epic

### Title
Implement OAuth2 PKCE flow for API gateway

### Slug
`oauth-pkce-flow`

### Description (Linear issue body)

```markdown
## Objective

Users can authenticate via Google/GitHub OAuth2 with PKCE. Tokens refresh
automatically. All auth endpoints pass OWASP top-10 checks.

## Skills

skills: [elixir, oauth, security]

## Repos

- vinnie357/vantageex

## Constraints

- Must support both Google and GitHub providers
- Token refresh must be transparent to the user
- Rate limit auth endpoints to 10 req/min per IP

## Team

- lead: sonnet
- default_model: haiku
- escalation: haiku -> sonnet -> opus
```
