# Claude Teams Integration Protocol

Mirroring protocol for coordinating bees issues with Claude's built-in task list when running Agent Teams.

## Overview

- **Bees** = persistent source of truth (SQLite-backed, survives sessions)
- **Claude Task List** = ephemeral coordination layer (session-scoped, visible to all teammates)

Bees issues are mirrored into Claude's task list so teammates can discover, claim, and coordinate work without polling `bees ready` manually. The two systems stay in sync through conventions described below.

## When to Use

Mirror bees issues into Claude's task list when **all** of these apply:

- 3 or more parallelizable issues exist
- Multiple agents will work simultaneously (Agent Teams enabled)
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set

When working solo or with sequential issues, bees alone is sufficient.

## Subject Line Convention

Every mirrored Claude task includes `[bees:ID]` in its subject:

```
[bees:abc12345] Implement login API endpoint
```

This makes cross-referencing trivial -- grep for `[bees:abc1]` in either system to find the matching entry. Use at least 4 characters of the bees issue ID.

## TaskCreate Conventions

When mirroring a bees issue into Claude's task list:

```
TaskCreate
  subject: "[bees:<id>] <bees issue title>"
  description: "<brief summary>. Skills: <skill1>, <skill2>. See bees show <id> for full spec."
  activeForm: "<present continuous form of work>"
```

Include in the description:
- One-line summary of the work
- `Skills:` list from `skill:` labels on the bees issue
- `See bees show <id>` pointer so teammates can get the full spec
- File ownership hints if relevant (e.g., "Owns: src/auth/*, tests/auth/*")

## Dependency Mirroring

Map bees dependencies to Claude task dependencies:

```bash
# Bees: session depends on login
bees dep add session456 login789

# Claude: mirror the same relationship
TaskUpdate taskId="<session-claude-id>" addBlockedBy=["<login-claude-id>"]
```

Only mirror direct dependencies. Claude's task system handles transitive blocking automatically.

## State Transitions

### Create

```bash
bees create "Issue title" -l "story,skill:git"
# Then mirror:
TaskCreate subject="[bees:<id>] Issue title" description="..."
```

### Claim

```bash
bees update <id> --status in_progress
TaskUpdate taskId="<claude-id>" status="in_progress"
```

### Complete

Always close bees first (persistent system), then Claude (ephemeral):

```bash
bees close <id>
bees sync
TaskUpdate taskId="<claude-id>" status="completed"
```

### Fail / Block

Do not close either system. Document the blocker:

```bash
bees comment add <id> "Blocked: <reason>"
# If blocked by another issue:
TaskUpdate taskId="<claude-id>" addBlockedBy=["<blocker-claude-id>"]
```

## Divergence Resolution

If the two systems get out of sync (e.g., a teammate closes a Claude task but not the bees issue):

1. **Bees wins** -- it is the persistent source of truth
2. The team lead reconciles by checking `bees list --json` against `TaskList`
3. Update Claude tasks to match bees state
4. Update the bees issue description noting the reconciliation

Common causes of divergence:
- Agent crash mid-completion (closed bees but session died before TaskUpdate)
- Manual `bees close` outside of the teams workflow
- Session restart (Claude tasks are ephemeral and lost)

After session restart, the team lead should re-mirror active bees issues.

## Scaling Guidance

| Team Size | Recommendation |
|-----------|---------------|
| 1 agent | Bees only, no mirroring needed |
| 2-3 agents | Mirror all parallelizable issues |
| 4-5 agents | Mirror + assign file ownership in descriptions |
| 6+ agents | Consider splitting into sub-epics with separate leads |

### Epic Size Thresholds

- **Small** (1-3 issues): No mirroring needed, single agent handles it
- **Medium** (4-8 issues): Mirror into Claude tasks, single team lead
- **Large** (9+ issues): Split into sub-epics, each with its own lead and issue group

### File Ownership Hints

For larger teams, include ownership hints in task descriptions to prevent merge conflicts:

```
TaskCreate subject="[bees:abc1] Auth middleware"
  description="Implement JWT validation middleware.
  Skills: security, twelve-factor.
  Owns: src/middleware/auth.*, tests/middleware/auth.*
  See bees show abc1 for full spec."
```

Teammates should avoid modifying files owned by other active tasks.

## Detection Heuristic

The bees-worker agent detects teams mode by checking whether `TaskList` returns results. If it does, the worker mirrors its bees actions into the Claude task list. If `TaskList` returns nothing, the worker operates in standalone bees mode.

This avoids coupling to the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` environment variable name, which may change.
