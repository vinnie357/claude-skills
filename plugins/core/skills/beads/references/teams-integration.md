# Claude Teams Integration Protocol

Mirroring protocol for coordinating beads tasks with Claude's built-in task list when running Agent Teams.

## Overview

- **Beads** = persistent source of truth (git-backed, survives sessions)
- **Claude Task List** = ephemeral coordination layer (session-scoped, visible to all teammates)

Beads tasks are mirrored into Claude's task list so teammates can discover, claim, and coordinate work without polling `bd ready` manually. The two systems stay in sync through conventions described below.

## When to Use

Mirror beads tasks into Claude's task list when **all** of these apply:

- 3 or more parallelizable tasks exist
- Multiple agents will work simultaneously (Agent Teams enabled)
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set

When working solo or with sequential tasks, beads alone is sufficient.

## Subject Line Convention

Every mirrored Claude task includes `[bd:ID]` in its subject:

```
[bd:abc12345] Implement login API endpoint
```

This makes cross-referencing trivial — grep for `[bd:abc1]` in either system to find the matching entry. Use at least 4 characters of the beads hash ID.

## TaskCreate Conventions

When mirroring a beads task into Claude's task list:

```
TaskCreate
  subject: "[bd:<id>] <beads task title>"
  description: "<brief summary>. Skills: <skill1>, <skill2>. See bd show <id> for full spec."
  activeForm: "<present continuous form of work>"
```

Include in the description:
- One-line summary of the work
- `Skills:` list from `skill:` labels on the beads task
- `See bd show <id>` pointer so teammates can get the full spec
- File ownership hints if relevant (e.g., "Owns: src/auth/*, tests/auth/*")

## Dependency Mirroring

Map beads dependencies to Claude task dependencies:

```bash
# Beads: session depends on login
bd dep add session456 login789

# Claude: mirror the same relationship
TaskUpdate taskId="<session-claude-id>" addBlockedBy=["<login-claude-id>"]
```

Only mirror direct dependencies. Claude's task system handles transitive blocking automatically.

## State Transitions

### Create

```bash
bd create "Task title" --labels "story,skill:git"
# Then mirror:
TaskCreate subject="[bd:<id>] Task title" description="..."
```

### Claim

```bash
bd update <id> --status in_progress
TaskUpdate taskId="<claude-id>" status="in_progress"
```

### Complete

Always close beads first (persistent system), then Claude (ephemeral):

```bash
bd close <id>
bd sync
TaskUpdate taskId="<claude-id>" status="completed"
```

### Fail / Block

Do not close either system. Document the blocker:

```bash
bd comment <id> "Blocked: <reason>"
# If blocked by another task:
TaskUpdate taskId="<claude-id>" addBlockedBy=["<blocker-claude-id>"]
```

## Divergence Resolution

If the two systems get out of sync (e.g., a teammate closes a Claude task but not the beads task):

1. **Beads wins** — it is the persistent source of truth
2. The team lead reconciles by checking `bd list --json` against `TaskList`
3. Update Claude tasks to match beads state
4. Add a beads comment noting the reconciliation

Common causes of divergence:
- Agent crash mid-completion (closed beads but session died before TaskUpdate)
- Manual `bd close` outside of the teams workflow
- Session restart (Claude tasks are ephemeral and lost)

After session restart, the team lead should re-mirror active beads tasks.

## Scaling Guidance

| Team Size | Recommendation |
|-----------|---------------|
| 1 agent | Beads only, no mirroring needed |
| 2-3 agents | Mirror all parallelizable tasks |
| 4-5 agents | Mirror + assign file ownership in descriptions |
| 6+ agents | Consider splitting into sub-epics with separate leads |

### Epic Size Thresholds

- **Small** (1-3 tasks): No mirroring needed, single agent handles it
- **Medium** (4-8 tasks): Mirror into Claude tasks, single team lead
- **Large** (9+ tasks): Split into sub-epics, each with its own lead and task group

### File Ownership Hints

For larger teams, include ownership hints in task descriptions to prevent merge conflicts:

```
TaskCreate subject="[bd:abc1] Auth middleware"
  description="Implement JWT validation middleware.
  Skills: security, twelve-factor.
  Owns: src/middleware/auth.*, tests/middleware/auth.*
  See bd show abc1 for full spec."
```

Teammates should avoid modifying files owned by other active tasks.

## Detection Heuristic

The beads-worker agent detects teams mode by checking whether `TaskList` returns results. If it does, the worker mirrors its beads actions into the Claude task list. If `TaskList` returns nothing, the worker operates in standalone beads mode.

This avoids coupling to the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` environment variable name, which may change.
