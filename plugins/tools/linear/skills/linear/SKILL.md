---
name: linear
description: "Linear project management via MCP or GraphQL API: issue queries, state transitions, epic authoring for VantageEx agent teams, and epic auditing. Use when interacting with Linear issues, creating or auditing epics, querying workflow states, or managing Linear project data."
license: MIT
---

# Linear

Manage Linear issues, author VantageEx-compatible epics, and interact with the Linear API via MCP or direct GraphQL.

## When to Use

Activate when:
- Querying, creating, or updating Linear issues
- Authoring epics for VantageEx agent consumption
- Auditing existing epics for VantageEx compatibility
- Grooming epics to fix audit findings
- Transitioning issue workflow states
- Attaching GitHub PRs to Linear issues
- Working with Linear comments or description sections

## MCP Setup (Preferred)

The Linear MCP server provides tool-based access to Linear. Set up once:

```bash
claude mcp add --transport http linear-server https://mcp.linear.app/mcp
```

Then run `/mcp` in a Claude Code session to complete OAuth authentication (opens browser).

After setup, use MCP tools directly for all Linear operations. The MCP server handles authentication and provides structured tool interfaces.

For full setup details, troubleshooting, and alternative client configurations, read `references/mcp-setup.md`.

## GraphQL Fallback

When MCP is unavailable (headless environments, scripting, CI), use the GraphQL API directly.

**Endpoint**: `https://api.linear.app/graphql`
**Auth**: Bearer token via `LINEAR_API_KEY` environment variable

```bash
# Test connectivity
curl -s -H "Authorization: Bearer $LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ viewer { id name email } }"}' \
  https://api.linear.app/graphql
```

For the full query catalog, read `references/graphql-api.md`.

The nushell client at `scripts/0.1.0/linear.nu` wraps common GraphQL operations.

## Common Operations

### Query an Issue

By key (e.g., `MT-686`):

```graphql
query IssueByKey($key: String!) {
  issue(id: $key) {
    id identifier title url description
    state { id name type }
    project { id name }
    labels { nodes { name } }
    attachments { nodes { title url sourceType } }
  }
}
```

### Create an Issue

```graphql
mutation CreateIssue($teamId: String!, $title: String!, $description: String, $stateId: String, $labelIds: [String!]) {
  issueCreate(input: {
    teamId: $teamId
    title: $title
    description: $description
    stateId: $stateId
    labelIds: $labelIds
  }) {
    success
    issue { id identifier url }
  }
}
```

### Update Issue State

Always fetch team workflow states first to get the exact `stateId`:

```graphql
query IssueTeamStates($id: String!) {
  issue(id: $id) {
    team {
      states { nodes { id name type } }
    }
  }
}
```

Then transition:

```graphql
mutation MoveIssue($id: String!, $stateId: String!) {
  issueUpdate(id: $id, input: { stateId: $stateId }) {
    success
    issue { id identifier state { name } }
  }
}
```

### Add a Comment

```graphql
mutation CreateComment($issueId: String!, $body: String!) {
  commentCreate(input: { issueId: $issueId, body: $body }) {
    success
    comment { id url }
  }
}
```

### Attach a GitHub PR

Prefer the GitHub-specific mutation for PR metadata:

```graphql
mutation AttachPR($issueId: String!, $url: String!, $title: String) {
  attachmentLinkGitHubPR(issueId: $issueId, url: $url, title: $title, linkKind: links) {
    success
    attachment { id title url }
  }
}
```

### List Workflow States

```graphql
query TeamStates($teamId: String!) {
  team(id: $teamId) {
    states { nodes { id name type position } }
  }
}
```

## Introspection

When an unfamiliar mutation or type is needed, query the schema:

```graphql
query ListMutations {
  __type(name: "Mutation") { fields { name } }
}

query InspectInput($typeName: String!) {
  __type(name: $typeName) {
    inputFields { name type { kind name ofType { kind name } } }
  }
}
```

## VantageEx Epic Format

VantageEx epics follow a three-level hierarchy: **Epic** (user-authored) -> **Issues** (team leader creates) -> **Tasks** (agents create).

The user authors the epic description in Linear. The epic body uses markdown sections that VantageEx parses.

### Required Sections

| Section | Purpose | Author |
|---------|---------|--------|
| `## Objective` | 2-3 sentences defining success criteria | User (immutable) |
| `## Skills` | Domain-specific skills needed (core skills implicit) | User (immutable) |
| `## Repos` | Target repositories | User (immutable) |

### Optional Sections

| Section | Purpose | Author |
|---------|---------|--------|
| `## Instructions` | User guidance added at re-queue (ADR-027) | User or dashboard |
| `## Constraints` | Boundaries (defaults: `mise run ci`, no attribution, squash merge) | User |
| `## Team` | Lead model, default model, escalation policy | User |
| `## Escalation` | Failure and ambiguity policies | User |
| `## PR` | Pull request URL when submitted | Agent |

### Title and Slug

- **Title**: Imperative statement ("Implement OAuth2 PKCE flow for API gateway")
- **Slug**: kebab-case, max ~30 chars, URL-safe (`oauth-pkce-flow`)
- **Branch**: `feature/<epic-slug>`

For the full epic specification with examples and anti-patterns, read `references/epic-format.md`.

## Workflow States

Linear uses typed workflow states. VantageEx maps these to its lifecycle:

| VantageEx Status | Linear State | Meaning |
|-----------------|--------------|---------|
| `ready` | Backlog / Ready | Epic in backlog, all fields present |
| `up_next` | Up Next | User approved for agent work |
| `in_progress` | In Progress | Agent actively working |
| `needs_help` | Needs Help | Agent exhausted fix cycles |
| `review` | In Review | CI passed, PR created |
| `complete` | Done | PR merged |
| `archived` | Archived | Hidden from dashboard |

Key transitions:
- `ready` -> `up_next`: **User only** (the gate)
- `up_next` -> `in_progress`: EpicPickerWorker (automatic)
- `in_progress` -> `needs_help`: ValidateWorker (after 3 fix cycles)
- `needs_help` -> `up_next`: User re-queues with `## Instructions`
- `in_progress` -> `review`: Agent submits PR
- `review` -> `complete`: User merges PR

For the full state machine and cross-system mapping, read `references/workflow-states.md`.

## Commands

| Command | Purpose |
|---------|---------|
| `/linear:plan-epic` | Create a new VantageEx-compatible epic in Linear |
| `/linear:audit-epics` | Audit existing epics for VantageEx compatibility |
| `/linear:groom-epics` | Fix issues found by audit |

## References

| File | Content |
|------|---------|
| `references/mcp-setup.md` | Linear MCP server setup and troubleshooting |
| `references/graphql-api.md` | Full GraphQL query catalog |
| `references/epic-format.md` | VantageEx epic specification |
| `references/audit-checklist.md` | Epic validation checks |
| `references/workflow-states.md` | State machine and cross-system mapping |

## Templates

| File | Content |
|------|---------|
| `templates/0.1.0/epic.md` | Epic description template |
| `templates/0.1.0/audit-report.md` | Audit output format |
| `templates/0.1.0/team-definition.md` | Team section template |

## Scripts

| File | Content |
|------|---------|
| `scripts/0.1.0/linear.nu` | Nushell GraphQL client for non-MCP use |

## Usage Rules

- Prefer MCP tools over raw GraphQL when the Linear MCP server is configured
- For state transitions, always fetch team states first — never hardcode `stateId` values
- Prefer `attachmentLinkGitHubPR` over `attachmentLinkURL` when linking GitHub PRs
- Keep queries narrow — request only the fields needed
- Treat top-level `errors` array in GraphQL responses as failures
- When writing epic descriptions, follow the section format exactly — VantageEx parses these programmatically
