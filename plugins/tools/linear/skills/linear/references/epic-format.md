# VantageEx Epic Format Specification

## Table of Contents

- [Overview](#overview)
- [Three-Level Hierarchy](#three-level-hierarchy)
- [Required Sections](#required-sections)
- [Optional Sections](#optional-sections)
- [Title and Slug](#title-and-slug)
- [Description Sections](#description-sections)
- [Instructions Flow](#instructions-flow)
- [Epic Sizing Heuristics](#epic-sizing-heuristics)
- [Dependency Ordering](#dependency-ordering)
- [Anti-Patterns](#anti-patterns)
- [Example Epic](#example-epic)

## Overview

VantageEx parses Linear issue descriptions programmatically. The epic body uses markdown `## Section` headers that VantageEx reads at pick time and on every poll. Sections must use exact header names — the parser matches on these strings.

The epic format follows the VantageEx epic messaging convention, the VantageEx layered tasking model, and the VantageEx epic lifecycle.

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

Domain-specific skills needed for this epic. Listed as a comma-separated list.

Core skills are always loaded and must NOT be listed:
- anti-fabrication, git, tdd, twelve-factor, security, mise, nushell

Only list domain-specific extras:

elixir, oauth, security

Skills must exist in the marketplace at: https://github.com/vinnie357/claude-skills/blob/main/.claude-plugin/marketplace.json

### `## Repos`

Target repositories this epic touches:

```
- vinnie357/vantageex
- vinnie357/runex
```

May be a single repo or multiple. The VantageEx multi-repo epic support enables parallel execution across repos.

## Optional Sections

### `## Instructions`

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

### `## Agents` (Optional)

Per-epic agent priority list — ordered, comma-separated agent types the picker walks when dispatching.

- Allowed values (v1): `claude`, `codex`, `antigravity`, `local`
- `gemini` access goes through `antigravity` (the Google CLI runs Gemini under the hood) — write `antigravity`, not `gemini`
- Missing section defaults to `[claude]`
- Picker walks the list in order; for each type it checks (a) driver registered, (b) usage under cap. First match wins.
- Types without a registered driver are logged and skipped
- Per-account scoping is opaque in v1 (single account per type); per-issue `account_id` is a follow-up

Example:

```markdown
## Agents

claude, local
```

### `## Dependencies` (Optional)

Declares the intended dependency ordering among the issues this epic will decompose into. The team leader uses this section when creating issues in Linear to record formal `blockedBy` edges.

Format: plain prose or a bullet list describing which issues depend on which others. Foundational issues (no incoming dependencies) are listed first.

Example:

```
## Dependencies

- Set up auth service (foundational — no prerequisites)
- Add login endpoint → depends on: Set up auth service
- Add token refresh → depends on: Add login endpoint
```

Do not declare cycles. See "Dependency Ordering" in this document for rules.


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

## Description Sections

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

## Self-Contained Bodies

Epic bodies are read by workers on any machine. Local-filesystem paths (e.g. `~/.claude/plans/foo.md`, `/Users/<name>/...`) resolve only on the author's system and fail elsewhere.

- **Embed**, do not reference. When the epic depends on a design plan, ADR draft, or research note authored locally, paste the content into the epic body under a `## Design context` (or similarly named) section.
- **Cross-link by URL**, not path. When two epics relate, link by Linear issue URL (`https://linear.app/<workspace>/issue/<KEY>`), never by filesystem path.
- **Split when too large**. When design context exceeds a comfortable body length, split into paired epics — one docs epic, one implementation epic — each self-contained and linked to its partner by URL.

## Epic Sizing Heuristics

An epic must decompose into a small set of independently-shippable issues, each completable by a single worker within one session (one feature branch → one PR), without exhausting the worker's time or token budget.

**Adopted convention**: aim for approximately 6–8 issues per epic. This figure is an adopted project convention, not an empirically measured limit. Use it as a planning signal, not an absolute rule.

**When to split**: split an epic into multiple epics when it:
- Would require more issues than the convention suggests,
- Spans many repositories with large cross-cutting changes, or
- Contains sections that can be sequenced as separate deliverables.

**Prefer vertical slices over horizontal layers.** A vertical slice delivers a thin end-to-end capability (e.g., a single feature from UI to database). A horizontal layer delivers a whole tier (e.g., all database migrations). Vertical slices ship incrementally; horizontal layers tend to block downstream work.

Do not describe scope as "simple", "quick", or "straightforward" without verification. Scope assessment requires analysis of the actual codebase.

## Dependency Ordering

Issue dependencies within an epic must be declared explicitly and form a valid directed acyclic graph (DAG).

**Rules**:
- Order issues topologically: earlier issues must unblock later ones.
- Place foundational and shared work first; no issue should depend on work that has not yet been created or started.
- **No cycles**: if a dependency cycle is detected (issue A blocks issue B which blocks issue A), halt decomposition and resolve the cycle before proceeding.
- Record dependency edges via the tracker's native mechanism (e.g., Linear's `blockedBy` / dependency edges). Do not describe ordering only in comments or prose.

**Declare ordering intent in the epic body** using a `## Dependencies` section (see Optional Sections). The team leader translates this into formal tracker edges during decomposition.

**Anti-pattern**: decomposing all issues as fully parallel (no declared dependencies) when logical sequencing exists. If one issue lays foundations that others require, the dependency must be declared.

## Anti-Patterns

Do NOT include in epics:

- **Implementation details** — let agents decide HOW
- **Local filesystem paths as the source of truth** — `~/.claude/plans/...`, `/Users/<name>/...`, and similar host-specific paths break on every machine except the author's. Embed the content or link by URL instead.
- **File paths to codebase locations** — let agents discover the codebase
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

elixir, oauth, security

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
